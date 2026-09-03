; ---------------------------------------------------------------------------
; Ozmoo Apple II: the boot chain and the resident RWTS
;
; This file is not sourced by ozmoo.asm. It is assembled on its own, by make.rb
; (build_a2_boot), into a raw binary at $0800 which build_A2 writes to track 0,
; and it stays there for the whole session: it is both the loader that brings
; the interpreter in and the sector reader the interpreter calls afterwards.
;
; The Apple Disk II controller has no DOS in ROM, so there is nothing to call
; and nothing to be compatible with. What is standard here is the disk format
; (6-and-2 GCR, the D5 AA 96 and D5 AA AD field markers, 4-and-4 in the address field),
; which is public and which every emulator and every modern flux tool writes.
;
; How the boot works, and why there is no loader of our own on track 0 sector 0:
; the Disk II boot PROM reads that sector to $0800, and then keeps reading
; ascending sectors into $0900, $0A00 ... for as long as its counter is below
; *byte 0 of the sector it just read*, before jumping to $0801. So byte 0 below
; is the size of this whole file in sectors, and the PROM lays the lot down for
; us. That is also how DOS 3.3 boots. Everything after the jump to $0801 is
; ours; the PROM is never called again.
;
;   $0800-$0D50  this file
;   $0D51-$0DA9  the 89 nibbles of a data field's header: its D5 AA AD and the
;                86 encoded aux nibbles, ready to write
;   $0DAA-$0DFF  the 86 byte aux nibble buffer the read path unpacks from
;   $0E00-$0EFF  the 256 encoded data nibbles, page aligned so the write loop's
;                lda is four cycles on every one of them - a fifth cycle on the
;                iterations that crossed a page would put a bit on the disk
;                where no bit belongs
;   $0F00-$0FFF  the 6-and-2 decode table, built at run time from the 64 valid
;                disk bytes. Page aligned, so the EOR that reads it in the
;                inner loop is four cycles and never five.
;   $1000-       the interpreter, which this loads and jumps to.
;
; It uses no zero page at all. The decode loops have to keep up with a nibble
; every 32 CPU cycles, which is what pushed the spike into zero page; here the
; buffer is reached by self-modified absolute addressing instead, which is a
; cycle *faster* than (zp),y, and the one remaining loop variable is absolute
; at 28 cycles a nibble. That matters because the zero page on this target is
; Ozmoo's alone, and a resident driver quietly holding four bytes of it is
; exactly the kind of coupling that goes wrong later. The address is a full 16
; bits rather than a page, and costs nothing for it: a store is five cycles
; whether or not it crosses a page, so the timed loops do not care, and the
; save file - which is a byte stream that starts 13 bytes below the z-stack -
; can be read and written where it lies instead of through a staging page.
;
; Build-time defines, all from make.rb:
;   TERP_TRACK      first track of the interpreter
;   TERP_SECTORS    how many sectors it occupies
;   TERP_LOAD       where it loads, which is also its entry point
;   A2_INTERLEAVE   sectors between one block of it and the next
; ---------------------------------------------------------------------------

!cpu 6502

!ifndef TERP_TRACK { TERP_TRACK = 2 }
!ifndef TERP_SECTORS { TERP_SECTORS = 1 }
!ifndef TERP_LOAD { TERP_LOAD = $1000 }
!ifndef A2_INTERLEAVE { A2_INTERLEAVE = 3 }

; --- hardware ---------------------------------------------------------------
SCREEN          = $0400
TXTCLR          = $C050         ; these four put the screen in 40 column text,
TXTSET          = $C051         ; page 1, no mixed graphics
MIXCLR          = $C052
LOWSCR          = $C054
HIRESOFF        = $C056

; Disk II soft switches. All of them are indexed by x = slot * 16, and the
; phase switches by x = slot * 16 + phase * 2, which is why the stepper builds
; its own index rather than keeping the slot in x throughout.
PHASEOFF        = $C080
PHASEON         = $C081
MOTOROFF        = $C088
MOTORON         = $C089
DRIVE1          = $C08A
Q6L             = $C08C         ; read a nibble here; bit 7 set = one is ready
Q6H             = $C08D         ; load the write latch
Q7L             = $C08E         ; read mode
Q7H             = $C08F         ; write mode, and load the latch

BOOTSLOT        = $2B           ; slot * 16, left in place by the boot PROM

; --- our own scratch --------------------------------------------------------
; The two small buffers sit just under NIB_PRI, as high as they can, so that
; everything below them is code. NIB_HDR must not cross a page: the write loop
; reads it with an absolute,y that would take a fifth cycle if it did, and a
; fifth cycle is a bit on the disk.
NIB_HDR         = $0D51         ; 89 bytes: D5 AA AD and the 86 aux nibbles
NIB_HDR_LEN     = 89
RWTS_AUX        = $0DAA         ; 86 bytes
NIB_PRI         = $0E00         ; 256 bytes, page aligned (see the note above)
DECODE_TABLE    = $0F00         ; 256 bytes, page aligned

; --- stepper timing ---------------------------------------------------------
; Deliberately conservative: we own no real Apple hardware, so every figure
; here errs on the slow side of the published ones rather than the fast side of
; ours. The settle is paid once per seek, not once per step, and not at all
; when the head is already on the wanted track.
PHASE_ON_MS     = 4
SETTLE_MS       = 20
SPINUP_MS       = 250
READ_RETRIES    = 12
WRITE_RETRIES   = 12

; Sync bytes in front of a data field we write. Their job is to let a reader
; find the frame again, which it must: our bits begin wherever the head was
; when write mode came on, at no particular bit boundary.
!ifndef WRITE_SYNC { WRITE_SYNC = 5 }

; ...and how many cycles apart they go on the disk. A data byte is handed over
; every 32 cycles, eight bit cells; a sync byte is the same $ff handed over
; later, and the bits the shift register puts down while it waits are the zeros
; that mark it out.
!ifndef WRITE_SYNC_CYCLES { WRITE_SYNC_CYCLES = 40 }

; How many of the address field's three epilogue nibbles to let go by before
; the write begins. Where exactly it begins decides how much of the formatter's
; gap 2 is left in front of our own sync bytes.
!ifndef WRITE_EPI_SKIP { WRITE_EPI_SKIP = 3 }

; NOP by the yard. The count is cycles, not bytes, because cycles are what is
; being padded; every pad is even, and the odd three go in as a PHA.
!macro pad .cycles {
        !fill .cycles / 2, $ea
        !if (.cycles & 1) != 0 {
                !error "pad wants an even number of cycles"
        }
}

* = $0800

; ---------------------------------------------------------------------------
; The fixed part of the file. Byte 0 is data, read by the PROM and never
; executed; the three jumps and the parameter block below are the interpreter's
; whole interface to this driver, so their addresses must not move.
; ---------------------------------------------------------------------------
                                        ; $0800: how many sectors the PROM loads
        !byte (image_end - $0800 + 255) / 256

        jmp boot                        ; $0801: where the PROM jumps
a2_read_sector
        jmp rwts_read                   ; $0804: read one sector, see below
a2_track
        !byte 0                         ; $0807: physical track, 0..34
a2_sector
        !byte 0                         ; $0808: physical sector, 0..15
a2_dest
        !byte 0                         ; $0809: high byte of the address
a2_dest_lo
        !byte 0                         ; $080A: ...and its low byte
a2_write_sector
        jmp rwts_write                  ; $080B: write one sector, see below

; ---------------------------------------------------------------------------
; boot: clear the screen, bring the interpreter in, jump to it.
; ---------------------------------------------------------------------------
!zone boot
boot
        ; The autostart ROM leaves its own text on screen and the PROM adds
        ; nothing, so start from a clean 40 column text page rather than
        ; letting the interpreter's first output land in the middle of it.
        lda TXTSET
        lda MIXCLR
        lda LOWSCR
        lda HIRESOFF
        jsr clear_screen

        jsr build_decode_table
        jsr rwts_init

        lda #TERP_TRACK
        sta a2_track
        lda #>TERP_LOAD
        sta a2_dest
        lda #<TERP_LOAD
        sta a2_dest_lo
        lda #0
        sta .index
        lda #TERP_SECTORS
        sta .todo
.next
        ldx .index
        lda skew_table,x
        sta a2_sector
        jsr rwts_read
        bcs .failed

        inc a2_dest
        inc .index
        lda .index
        cmp #16
        bne .same_track
        lda #0
        sta .index
        inc a2_track
.same_track
        dec .todo
        bne .next

        jmp TERP_LOAD

.failed
        ldx #0
.msg    lda disk_error,x
        beq .stop
        ora #$80
        sta SCREEN,x
        inx
        bne .msg
.stop   jmp .stop

.index  !byte 0
.todo   !byte 0

disk_error
        !text "DISK ERROR", 0

; ---------------------------------------------------------------------------
; clear_screen: spaces over the whole text page. The four "screen holes" in
; each 128 byte block belong to peripheral cards and are not on screen, but
; writing a space into them harms nothing and this way it is eight instructions
; rather than a row table.
; ---------------------------------------------------------------------------
!zone clear_screen
clear_screen
        lda #' ' | $80
        ldx #0
.fill
        sta SCREEN,x
        sta SCREEN + $100,x
        sta SCREEN + $200,x
        sta SCREEN + $300,x
        inx
        bne .fill
        rts

; ===========================================================================
; The RWTS. Read only: the write path (saves) is a later step.
; ===========================================================================

; ---------------------------------------------------------------------------
; rwts_init: the PROM leaves the motor running, the drive selected and the head
; recalibrated to track 0, so this mostly just records that. What it must not
; skip is releasing the phase magnets: the PROM's recalibration ends with phase
; 0 still energised, and a magnet left pulling drags the head back to track 0
; the moment we release the phase we stepped with. In the spike that showed up
; only as four recovered mis-seeks in 162 reads, because the address field says
; which track the head is really on - it is the kind of fault that error
; recovery hides.
; ---------------------------------------------------------------------------
!zone rwts_init
rwts_init
        lda BOOTSLOT
        sta rw_slot
        tax
        lda Q7L,x               ; read mode
        lda Q6L,x
        lda DRIVE1,x
        lda MOTORON,x

        lda PHASEOFF,x
        lda PHASEOFF + 2,x
        lda PHASEOFF + 4,x
        lda PHASEOFF + 6,x

        lda #0
        sta rw_half
        lda #1
        sta rw_motor            ; the PROM left it spinning
        rts

; ---------------------------------------------------------------------------
; rwts_read: read the sector named by a2_track / a2_sector into the page named
; by a2_dest. Carry clear if it worked.
;
; This is the interpreter's entry point (through the jmp at $0804), so it takes
; its arguments from the fixed block at the top of the file rather than from
; the zero page, which belongs to Ozmoo.
; ---------------------------------------------------------------------------
!zone rwts_read
rwts_read
        lda #READ_RETRIES
        sta rw_retry
        bne rwts_read_entry     ; always
rwts_read_once
        ; One attempt only, for the verify after a write: a sector that does not
        ; read is going to be written again anyway, and a dozen retries with a
        ; recalibration every fourth would cost seconds for nothing.
        lda #1
        sta rw_retry
rwts_read_entry
        ; The destination reaches the inner loops as three absolute addresses.
        ; Self-modifying is a cycle cheaper than (zp),y and costs no zero page
        ; at all, and the address need not be a page: a store is five cycles
        ; whether or not it crosses one, so the timed loop is unaffected.
        lda a2_dest
        sta rd_data_store + 2
        sta rd_pn_load + 2
        sta rd_pn_store + 2
        lda a2_dest_lo
        sta rd_data_store + 1
        sta rd_pn_load + 1
        sta rd_pn_store + 1

        jsr motor_on
.try
        jsr rwts_seek           ; cheap when the head is already there
        jsr read_sector
        bcc .ok
        dec rw_retry
        beq .give_up
        lda rw_retry            ; every fourth failure, start again from track 0
        and #3
        bne .try
        jsr rwts_recalibrate
        jmp .try
.ok
        clc
        rts
.give_up
        sec
        rts

; ---------------------------------------------------------------------------
; motor_on: make sure the drive is spinning, and give it time to come up to
; speed if we are the ones who started it.
;
; Nothing turns it off again in phase one. A game pages from disk more or less
; continuously, and there is no timer on this machine to hang a "spin down
; after a second" on, so the drive runs for the session. Worth revisiting when
; there is a jiffy counter to count against.
; ---------------------------------------------------------------------------
!zone motor_on
motor_on
        ldx rw_slot
        lda rw_motor
        bne .running
        lda MOTORON,x
        lda #1
        sta rw_motor
        lda #SPINUP_MS
        jsr delay_ms
        ldx rw_slot
.running
        rts

; ---------------------------------------------------------------------------
; rwts_seek: put the head on a2_track, one half-track at a time. A full track
; is two half-steps, and jumping two phases at once has no defined direction,
; which is why this counts in half-tracks and not in tracks.
; ---------------------------------------------------------------------------
!zone rwts_seek
rwts_seek
        lda #0
        sta rw_moved
        lda a2_track
        asl
        sta rw_dest_half
.loop
        lda rw_dest_half
        cmp rw_half
        beq .arrived
        inc rw_moved
        bcs .outwards
        dec rw_half
        jmp .step
.outwards
        inc rw_half
.step
        lda rw_half
        and #3                  ; the stepper has four phases
        asl
        clc
        adc rw_slot
        tax
        lda PHASEON,x
        lda #PHASE_ON_MS
        jsr delay_ms
        lda PHASEOFF,x
        jmp .loop
.arrived
        lda rw_moved
        beq .done
        lda #SETTLE_MS
        jsr delay_ms
.done
        ldx rw_slot
        rts

; ---------------------------------------------------------------------------
; rwts_recalibrate: step out past track 0 and call that home. Used when a
; sector will not read, which usually means the head is not where we think.
; The phase comes from the descending counter rather than from rw_half, because
; rw_half is exactly the thing we have stopped believing: energising the phase
; of the half-track the head is already on moves nothing.
; ---------------------------------------------------------------------------
!zone rwts_recalibrate
rwts_recalibrate
        lda #80
        sta rw_count
.out
        lda rw_count
        and #3
        asl
        clc
        adc rw_slot
        tax
        lda PHASEON,x
        lda #PHASE_ON_MS
        jsr delay_ms
        lda PHASEOFF,x
        dec rw_count
        bne .out
        lda #0
        sta rw_half
        lda #SETTLE_MS
        jsr delay_ms
        ldx rw_slot
        rts

; ---------------------------------------------------------------------------
; delay_ms: a milliseconds, near enough (200 * 5 = 1000 cycles at 1.023 MHz).
; Preserves x, which the caller needs for the soft switches.
; ---------------------------------------------------------------------------
!zone delay_ms
delay_ms
        sta rw_delay
.outer
        ldy #200
.inner
        dey
        bne .inner
        dec rw_delay
        bne .outer
        rts

; ---------------------------------------------------------------------------
; find_address_field: wait for the address field of a2_track / a2_sector to
; come round, and return with the head just past its checksum - which is where
; both a read and a write of the data field begin. Carry clear if it is ours.
; x = slot * 16 throughout, because every nibble read is lda Q6L,x.
; ---------------------------------------------------------------------------
!zone find_address_field
find_address_field
        lda #0
        sta rw_niblo
        sta rw_nibhi
.scan
        ; --- the address field prologue, D5 AA 96 --------------------------
        ; A byte that fails one of the tests may still be the start of the next
        ; prologue, so a mismatch goes back to the D5 test rather than to the
        ; top. The nibble counter is the only timeout there is: a drive with no
        ; disk in it would otherwise spin here for ever.
.a1     lda Q6L,x
        bpl .a1
        inc rw_niblo
        bne .a1_ok
        inc rw_nibhi
        bne .a1_ok
        jmp .fail               ; 65536 nibbles, about ten revolutions
.a1_ok
.a_d5   cmp #$d5
        bne .a1
.a2     lda Q6L,x
        bpl .a2
        cmp #$aa
        bne .a_d5
.a3     lda Q6L,x
        bpl .a3
        cmp #$96
        bne .a_d5

        ; --- volume, track, sector, checksum, all 4-and-4 ------------------
        jsr read44
        sta rw_avol
        jsr read44
        sta rw_atrk
        jsr read44
        sta rw_asec
        jsr read44
        eor rw_avol
        eor rw_atrk
        eor rw_asec
        bne .scan               ; the field is damaged; wait for another one

        lda rw_atrk
        cmp a2_track
        bne .wrong_track
        lda rw_asec
        cmp a2_sector
        bne .scan               ; someone else's sector
        clc
        rts

.wrong_track
        ; The field tells us where the head really is; believe it, and let the
        ; caller seek again from there.
        lda rw_atrk
        asl
        sta rw_half
.fail
        ldx rw_slot
        sec
        rts

; ---------------------------------------------------------------------------
; read_sector: find our address field and read the data field behind it.
; ---------------------------------------------------------------------------
!zone read_sector
read_sector
        jsr find_address_field
        bcs .fail

        ; --- the data field prologue, D5 AA AD -----------------------------
        ; It follows its address field immediately, so give it a few dozen
        ; nibbles and no more.
        ldy #$30
.d1     lda Q6L,x
        bpl .d1
        dey
        beq .fail
.d_d5   cmp #$d5
        bne .d1
.d2     lda Q6L,x
        bpl .d2
        cmp #$aa
        bne .d_d5
.d3     lda Q6L,x
        bpl .d3
        cmp #$ad
        bne .d_d5

        ; --- 86 aux nibbles ------------------------------------------------
        ; a carries the running EOR the whole way and y is borrowed to index
        ; the decode table, so the buffer index is parked in rw_idx. 28 cycles
        ; a nibble, against the 32 the drive gives us. The buffer fills
        ; downwards, so the first nibble read is entry 0 of the encoding.
        ldy #$56
        lda #0
.aux    sty rw_idx
.aux_w  ldy Q6L,x
        bpl .aux_w
        eor DECODE_TABLE,y
        ldy rw_idx
        dey
        sta RWTS_AUX,y
        bne .aux

        ; --- 256 data nibbles, six bits each, straight into the page -------
.data   sty rw_idx
.data_w ldy Q6L,x
        bpl .data_w
        eor DECODE_TABLE,y
        ldy rw_idx
rd_data_store
        sta $ff00,y             ; high byte patched by rwts_read
        iny
        bne .data

        ; --- and the byte that closes the chain ----------------------------
.ck_w   ldy Q6L,x
        bpl .ck_w
        eor DECODE_TABLE,y
        bne .fail

        ; --- put the low two bits back -------------------------------------
        ; Each aux byte carries the bottom two bits of three data bytes, and
        ; carries them bit-swapped, so shifting one out into the carry and
        ; rolling it into the byte, twice, is both the unpack and the unswap.
        ; 86 * 3 = 258, so the index wraps twice and the last two slots of the
        ; third pass are the ones the encoder left empty.
        ldy #0
.pn_top ldx #$56
.pn     dex
        bmi .pn_top
rd_pn_load
        lda $ff00,y             ; high byte patched by rwts_read
        lsr RWTS_AUX,x
        rol
        lsr RWTS_AUX,x
        rol
rd_pn_store
        sta $ff00,y             ; high byte patched by rwts_read
        iny
        bne .pn

        ldx rw_slot             ; the unpack borrowed x
        clc
        rts

.fail
        ldx rw_slot
        sec
        rts

; ===========================================================================
; The write path.
;
; The Disk II has no timer of its own. Its write shift register puts a bit on
; the disk every four cycles, so a byte must be handed to it every 32 - no
; sooner, or the tail of the last one is lost, and no later, or zero bits are
; written where none belong. A sync byte is the same $ff handed over after 40
; cycles instead: the two extra zero bits are what lets a reader that is out of
; step find the frame again, which it must be here, since our bits start
; wherever the head happened to be when write mode came on.
; ===========================================================================


; ---------------------------------------------------------------------------
; rwts_write: write the 256 bytes at a2_dest / a2_dest_lo into the sector named
; by a2_track and a2_sector. Carry clear if it worked.
; ---------------------------------------------------------------------------
!zone rwts_write
rwts_write
        lda a2_dest
        sta wr_src_load + 2
        sta wr_src_cmp + 2
        lda a2_dest_lo
        sta wr_src_load + 1
        sta wr_src_cmp + 1

        jsr motor_on            ; returns with x = slot * 16

        ; Is the disk write protected? Q6H then Q7L leaves the answer in bit 7
        ; of the data register. Worth asking: the alternative is to write
        ; nothing, notice nothing, and tell the player the game was saved.
        lda Q6H,x
        lda Q7L,x
        bmi .protected
        lda Q6L,x               ; back to reading data

        lda #WRITE_RETRIES
        sta rw_retry
        lda #0
        sta wr_phase
.try
        jsr encode_sector       ; all the thinking, done before the drive cares
                                ; (and again per attempt: the verify below
                                ; reads the sector back over NIB_PRI)
        jsr rwts_seek
        jsr write_sector
        bcs .failed
        jsr verify_sector       ; a whole revolution, and worth it - see below
        bcc .ok
.failed
        inc wr_retries          ; how much of that is going on is worth knowing
        inc wr_phase            ; try again from a different point in the gap
        dec rw_retry
        beq .give_up
        lda rw_retry            ; every fourth failure, start again from track 0
        and #3
        bne .try
        jsr rwts_recalibrate
        jmp .try
.ok
        clc
        rts
.protected
.give_up
        sec
        rts

; ---------------------------------------------------------------------------
; verify_sector: read the sector we have just written back into NIB_PRI, which
; the write has finished with, and compare it against the bytes it was made
; from. Carry clear if the disk holds what we meant to put there.
;
; ---------------------------------------------------------------------------
!zone verify_sector
verify_sector
        lda #>NIB_PRI           ; the read decodes into the nibble buffer, which
        sta a2_dest             ; has done its work by now; a2_dest is restored
        lda #<NIB_PRI           ; at the end, since the caller owns it
        sta a2_dest_lo
        jsr rwts_read_once      ; patches the read's destination from a2_dest,
                                ; which we have just pointed at the nibble
                                ; buffer, and tries exactly once
        php                     ; keep the verdict while the address goes back
        lda wr_src_load + 2
        sta a2_dest
        lda wr_src_load + 1
        sta a2_dest_lo
        plp
        bcs .bad

        ldy #0
.compare
        lda NIB_PRI,y
wr_src_cmp
        cmp $ffff,y             ; the source, patched by rwts_write
        bne .bad
        iny
        bne .compare
        clc
        rts
.bad
        sec
        rts

; ---------------------------------------------------------------------------
; encode_sector: turn the 256 bytes at wr_src_load into the 89 nibbles of
; NIB_HDR and the 256 of NIB_PRI, ready to be handed to the drive one every 32
; cycles with nothing left to work out.
;
; 6-and-2 is six bits of each byte in one nibble and the other two bits packed
; three-to-a-nibble in front. The bottom two bits go in bit-swapped, which
; falls out of rolling them in: the reader shifts them back out the same way.
; Going *backwards* through the data is what puts the three pairs in an aux
; slot in the order the reader takes them out again - the reader's first pass
; wants the pair that was rolled in last.
; ---------------------------------------------------------------------------
!zone encode_sector
encode_sector
        lda #$d5
        sta NIB_HDR
        lda #$aa
        sta NIB_HDR + 1
        lda #$ad
        sta NIB_HDR + 2

        lda #0                  ; the aux slots are rolled into, so they start
        ldx #85                 ; empty
.clear
        sta NIB_HDR + 3,x
        dex
        bpl .clear

        ldx #83                 ; 85 - (255 mod 86): the slot the last byte's
        ldy #$ff                ; two bits belong to
.pair
wr_src_load
        lda $ffff,y             ; address patched by rwts_write
        lsr
        rol NIB_HDR + 3,x
        lsr
        rol NIB_HDR + 3,x
        sta NIB_PRI,y           ; the top six bits, not yet a disk byte
        dex
        bpl +
        ldx #85
+
        dey
        cpy #$ff
        bne .pair

        ; The running EOR chain and the translation to disk bytes. What goes on
        ; the disk is each nibble's difference from the one before it, so the
        ; reader's running EOR rebuilds the values; the extra nibble at the end
        ; is the final value itself, and a sector that has lost or gained a bit
        ; cannot agree with it.
        lda #0
        sta wr_prev
        ldy #3
.chain_hdr
        lda NIB_HDR,y
        sta wr_next
        eor wr_prev
        tax
        lda disk_bytes,x
        sta NIB_HDR,y
        lda wr_next
        sta wr_prev
        iny
        cpy #NIB_HDR_LEN
        bne .chain_hdr

        ldy #0
.chain_pri
        lda NIB_PRI,y
        sta wr_next
        eor wr_prev
        tax
        lda disk_bytes,x
        sta NIB_PRI,y
        lda wr_next
        sta wr_prev
        iny
        bne .chain_pri

        ldx wr_prev
        lda disk_bytes,x
        sta wr_check
        rts

; ---------------------------------------------------------------------------
; write_sector: find our address field and write the data field behind it.
;
; From the moment write mode comes on, every path through this is counted. The
; comment beside each loop is the cycles from one store to the next, which is
; the only number the drive is interested in.
; ---------------------------------------------------------------------------
!zone write_sector
write_sector
        jsr find_address_field
        bcc +                   ; .fail is past all the padding below, further
        jmp .fail               ; than a branch reaches
+

        ; The address field's epilogue nibbles. Letting them go by puts the head
        ; at the start of gap 2, which is where the sync bytes we are about to
        ; write belong - and where the formatter put its own.
!if WRITE_EPI_SKIP > 0 {
        ldy #WRITE_EPI_SKIP
.epi    lda Q6L,x
        bpl .epi
        dey
        bne .epi
}

        ; Where this attempt starts, in five cycle steps: nothing on the first
        ; pass, a little further into the gap on each retry.
        ldy wr_phase
        beq .no_phase
.phase  dey
        bne .phase
.no_phase
        php
        sei                     ; nothing on this machine raises an interrupt,
                                ; but this is the one place where one would be
                                ; unrecoverable rather than merely slow

        ; --- the sync bytes, one every WRITE_SYNC_CYCLES --------------------
        ; Write mode has to come on BEFORE the first byte is handed over, and
        ; that necessary: a store only loads the shift register when Q6
        ; and Q7 are both high, so a store to Q7H while Q6 is low - the obvious
        ; way to write "switch to write mode and give it this byte" - switches
        ; the mode and quietly writes whatever the register held from the last
        ; write-protect sense instead.
        lda Q7H,x               ; 4   write mode; the register shifts out the
                                ;     stale byte, harmlessly, inside the gap
        lda #$ff                ; 2
        ldy #WRITE_SYNC - 1     ; 2   (the first one is written below)
        sta Q6H,x               ; 5   Q6H + Q7H: now it really is loaded
        cmp Q6L,x               ; 4
        pha                     ; 3   \ the sync spacing, less the 12 above
        +pad WRITE_SYNC_CYCLES - 12
.sync
        sta Q6H,x               ; 5
        cmp Q6L,x               ; 4
        dey                     ; 2
        beq .sync_done          ; 2 not taken / 3 taken
        +pad WRITE_SYNC_CYCLES - 16 ; 5 + 4 + 2 + 2 + pad + 3 = the spacing
        jmp .sync               ; 3
.sync_done
        pla                     ; 4   (the pha above; 5 + 4 + 2 + 3 spent)
        +pad WRITE_SYNC_CYCLES - 24
        ldy #0                  ; 2   spacing = 14 + 4 + pad + 2 + 4(lda below)

        ; --- D5 AA AD and the 86 aux nibbles, one every 32 ------------------
.hdr
        lda NIB_HDR,y           ; 4
        sta Q6H,x               ; 5
        cmp Q6L,x               ; 4
        iny                     ; 2
        cpy #NIB_HDR_LEN        ; 2
        beq .hdr_done           ; 2 not taken / 3 taken
        +pad 10                 ; 10  5 + 4 + 2 + 2 + 2 + 10 + 3 + 4 = 32
        jmp .hdr                ; 3
.hdr_done
        +pad 10                 ; 10  32 = 16 spent + 10 + 2 + 4(lda below)
        ldy #0                  ; 2

        ; --- the 256 data nibbles, one every 32 -----------------------------
.pri
        lda NIB_PRI,y           ; 4
        sta Q6H,x               ; 5
        cmp Q6L,x               ; 4
        iny                     ; 2
        beq .pri_done           ; 2 not taken / 3 taken
        +pad 12                 ; 12  5 + 4 + 2 + 2 + 12 + 3 + 4 = 32
        jmp .pri                ; 3
.pri_done
        +pad 14                 ; 14  32 = 14 spent + 14 + 4(lda below)

        ; --- the checksum nibble and DE AA EB -------------------------------
        ; Twenty-one cycles between these, which is an odd number and NOP only
        ; comes in twos: the PHA/PLA pair makes up the seven that are left, and
        ; leaves the stack as it found it.
        lda wr_check            ; 4
        sta Q6H,x               ; 5
        cmp Q6L,x               ; 4
        pha                     ; 3
        pla                     ; 4
        +pad 14                 ; 14  5 + 4 + 21 + 2 = 32
        lda #$de                ; 2
        sta Q6H,x               ; 5
        cmp Q6L,x               ; 4
        pha                     ; 3
        pla                     ; 4
        +pad 14                 ; 14
        lda #$aa                ; 2
        sta Q6H,x               ; 5
        cmp Q6L,x               ; 4
        pha                     ; 3
        pla                     ; 4
        +pad 14                 ; 14
        lda #$eb                ; 2
        sta Q6H,x               ; 5
        cmp Q6L,x               ; 4
        +pad 24                 ; 24  the last byte needs its 32 cycles to leave
                                ;     the register before write mode is taken
        lda Q7L,x               ; 4   away from it
        lda Q6L,x               ; 4

        plp                     ; interrupts as they were
        ldx rw_slot
        clc
        rts

.fail
        ldx rw_slot
        sec
        rts

; ---------------------------------------------------------------------------
; read44: one byte in the address field's 4-and-4 encoding - odd bits in the
; first nibble, even bits in the second, both padded with 1s.
; ---------------------------------------------------------------------------
!zone read44
read44
.n1     lda Q6L,x
        bpl .n1
        sec
        rol
        sta rw_tmp
.n2     lda Q6L,x
        bpl .n2
        and rw_tmp
        rts

; ---------------------------------------------------------------------------
; build_decode_table: disk byte -> its six bits. The 64 valid disk bytes in
; ascending order are the codes 0..63, so the table is that list turned inside
; out. Everything else decodes to $FF, which cannot help but break the running
; checksum - which is exactly what we want from a nibble that should not exist.
; ---------------------------------------------------------------------------
!zone build_decode_table
build_decode_table
        lda #$ff
        ldx #0
.blank
        sta DECODE_TABLE,x
        inx
        bne .blank
        ldx #63
.fill
        ldy disk_bytes,x
        txa
        sta DECODE_TABLE,y
        dex
        bpl .fill
        rts

disk_bytes
        !byte $96,$97,$9a,$9b,$9d,$9e,$9f,$a6
        !byte $a7,$ab,$ac,$ad,$ae,$af,$b2,$b3
        !byte $b4,$b5,$b6,$b7,$b9,$ba,$bb,$bc
        !byte $bd,$be,$bf,$cb,$cd,$ce,$cf,$d3
        !byte $d6,$d7,$d9,$da,$db,$dc,$dd,$de
        !byte $df,$e5,$e6,$e7,$e9,$ea,$eb,$ec
        !byte $ed,$ee,$ef,$f2,$f3,$f4,$f5,$f6
        !byte $f7,$f9,$fa,$fb,$fc,$fd,$fe,$ff

; The order the interpreter's sectors were laid down in, and so the order we
; ask for them. Only the boot loader uses this; once the interpreter is running
; it works its own sector numbers out from the config track.
skew_table
        !for .i, 0, 15 {
                !byte (.i * A2_INTERLEAVE) & 15
        }

; ---------------------------------------------------------------------------
; State. All of it lives here rather than in the zero page, which is Ozmoo's.
; ---------------------------------------------------------------------------
rw_slot         !byte 0         ; slot * 16
rw_half         !byte 0         ; where the head is, in half-tracks
rw_dest_half    !byte 0
rw_moved        !byte 0         ; did this seek step at all?
rw_motor        !byte 0
rw_retry        !byte 0
rw_delay        !byte 0
rw_count        !byte 0
rw_idx          !byte 0         ; buffer index, parked while the nibble loops
                                ; borrow y to index the decode table
rw_tmp          !byte 0
rw_avol         !byte 0         ; what the last address field said
rw_atrk         !byte 0
rw_asec         !byte 0
rw_niblo        !byte 0         ; nibbles seen while hunting for a prologue
rw_nibhi        !byte 0
wr_phase        !byte 0         ; how far into the gap this attempt starts
wr_retries      !byte 0         ; writes that did not verify, since boot
wr_prev         !byte 0         ; the running value the EOR chain is against
wr_next         !byte 0
wr_check        !byte 0         ; the disk byte that closes the chain

image_end

; The file has to fit below the first of the nibble buffers, and the PROM will
; only load one track of it.
!if image_end > NIB_HDR {
        !error "the boot chain is ", image_end - NIB_HDR, " bytes too big"
}
!if (image_end - $0800 + 255) / 256 > 16 {
        !error "the boot chain does not fit on track 0"
}
        !fill (($0800 + (((image_end - $0800 + 255) / 256) * 256)) - *), 0
