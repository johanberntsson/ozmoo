; ---------------------------------------------------------------------------
; Ozmoo Apple II spike, RWTS read
;
; The second of the Apple II boot sector spikes (tools/apple2-prototype.as
; is the first).  It belongs to no build and is sourced by nothing; 
; tools/apple2-rwts-spike.rb builds and runs it.
;
; Step 1 of is RWTS read in the spike: and stage-2 loads a multi-track payload
; with checksum verification; measure throughput vs; interleave choices.
;
; It proves:
;
;   * the boot chain past one sector.  Byte 0 of the boot sector is the number
;     of sectors the Disk II boot PROM loads from track 0 before jumping to
;     $0801 (it reads them to $0800, $0900, ... in ascending sector order), so
;     a 2K stage 2 needs no hand-rolled chain loader at all.  That is how DOS
;     3.3 boots too, and it is the only thing we take from the PROM: after the
;     jump this code never calls it again.
;   * head stepping.  Half-track at a time, phase (halftrack & 3) energised for
;     PHASE_ON_MS and released, because a full track is two half-steps and
;     jumping two phases at once has no defined direction.
;   * the address field.  D5 AA 96, then volume/track/sector/checksum in
;     4-and-4 (value = ((odd * 2) | 1) & even), checksum verified.  A field
;     naming a track we are not on tells us where the head really is, which is
;     how this recovers from a mis-seek rather than retrying blindly.
;   * the data field.  D5 AA AD, 86 aux nibbles then 256 data nibbles then a
;     checksum nibble, each decoded through a 256-byte table and EOR-chained
;     with the running value; the chain must come out zero.  Then the 6-and-2
;     recombination: three data bytes share one aux byte, two bits each, and
;     the two bits are stored bit-swapped, which is exactly what LSR-into-carry
;     + ROL-into-the-byte, twice, puts back.
;   * that the whole thing keeps up.  A nibble arrives every 32 CPU cycles and
;     the two decode loops are 26 and 27 cycles, so nothing is dropped.
;   * how much the interleave is worth.  The payload is laid down with a skew
;     (SKEW, a build-time define) and read back in the same order, and the
;     spike counts every address field that passes under the head.  With a good
;     skew that count is close to one per sector; with a bad one it is closer
;     to sixteen, because the drive spends a whole revolution per sector.
;
; What it does: reads PAYLOAD_TRACKS tracks (1..PAYLOAD_TRACKS) into $1000 and
; up, one page per sector, then one sector from FAR_TRACK (a long seek) and one
; from track 1 again (the long seek back), verifies every byte of all of it
; against the pattern make.rb's ancestor wrote, and prints the counts.
;
; The pattern in a sector is: byte 0 = its track, byte 1 = its index within the
; track, and byte n = (seed + n) & $FF from there, seed being the page it is
; read into.  So a sector delivered to the wrong place, doubled, or shifted by
; a byte is caught, which a plain checksum would not do.
;
; The memory map:
;
;   $0100-$01FF  6502 stack
;   $0300-$03FF  the boot PROM's aux buffer and decode table - dead once we
;                have control, and left alone here because Ozmoo wants the page
;                for its vmap.  This RWTS carries its own.
;   $0400-$07FF  text page 1
;   $0800-$0DFF  this program: stage 2 + the RWTS
;   $0E00-$0E55  the RWTS's 86-byte aux nibble buffer
;   $0F00-$0FFF  the RWTS's 6-and-2 decode table, built at run time from the
;                64 valid disk bytes.  Page aligned so the EOR that reads it is
;                four cycles and never five.
;   $1000-$AFFF  the payload
;   $B000-$B0FF  the far-track sector
; ---------------------------------------------------------------------------

!cpu 6502

; --- build-time knobs, set by tools/apple2-rwts-spike.rb --------------------
!ifndef SKEW { SKEW = 1 }                       ; physical sectors per step
!ifndef PAYLOAD_TRACKS { PAYLOAD_TRACKS = 10 }  ; tracks 1..n
FAR_TRACK       = 34            ; the far end of the disk, for the long seek

; --- hardware ---------------------------------------------------------------
SCREEN          = $0400
KBD             = $C000
KBDSTRB         = $C010

; Disk II soft switches.  All of them are indexed by x = slot * 16, and the
; phase switches by x = slot * 16 + phase * 2, which is why the stepper builds
; its own index rather than keeping the slot in x throughout.
PHASEOFF        = $C080
PHASEON         = $C081
MOTOROFF        = $C088
MOTORON         = $C089
DRIVE1          = $C08A
Q6L             = $C08C         ; read a nibble here; bit 7 set = one is ready
Q6H             = $C08D
Q7L             = $C08E         ; read mode
Q7H             = $C08F

; --- stepper timing ---------------------------------------------------------
; Deliberately conservative: we own no real hardware, so this errs on the slow
; side of every published figure rather than on the fast side of ours.  A
; half-track step is 4 ms with the phase held, and the head is given 20 ms to
; stop ringing after the last one.  The settle is paid once per seek, not once
; per step, and not at all when the head is already on the wanted track.
PHASE_ON_MS     = 4
SETTLE_MS       = 20
READ_RETRIES    = 12

; --- our own scratch --------------------------------------------------------
RWTS_AUX        = $0E00         ; 86 bytes
DECODE_TABLE    = $0F00         ; 256 bytes, page aligned

PAYLOAD_PAGE    = $10           ; track 1 sector 0 lands here
FAR_PAGE        = $B0           ; and the far-track sector here

ROWS            = 24
COLS            = 40

; --- zero page --------------------------------------------------------------
; The whole zero page is ours once the PROM has finished: there is no DOS and
; we call no ROM.
zp_screenline   = $06           ; -> first cell of the current row
zp_string       = $08           ; -> string being printed
scr_col         = $0a

rw_slot         = $40           ; slot * 16
rw_track        = $41           ; wanted track
rw_sector       = $42           ; wanted physical sector
rw_dest         = $43           ; 2 bytes, -> destination page
rw_half         = $45           ; where the head is, in half-tracks
rw_idx          = $46           ; buffer index, parked while the nibble loops
                                ; borrow y to index the decode table
rw_tmp          = $47
rw_delay        = $48
rw_retry        = $49
rw_moved        = $4a           ; did this seek step at all?
rw_avol         = $4b           ; what the last address field said
rw_atrk         = $4c
rw_asec         = $4d
rw_niblo        = $4e           ; nibbles seen while hunting for a prologue
rw_nibhi        = $4f
ver_ptr         = $50           ; 2 bytes

* = $0800

; ---------------------------------------------------------------------------
; Byte 0 is never executed: the PROM reads this sector to $0800, then keeps
; reading sectors while its counter is below this byte, and jumps to $0801.  So
; this is the size of the whole stage 2, in sectors.
        !byte (image_end - $0800 + 255) / 256

!zone start
start
        jsr scr_clear
        jsr build_decode_table
        jsr rwts_init

        lda #<title
        ldy #>title
        ldx #0
        jsr scr_print_at
        lda #<subtitle
        ldy #>subtitle
        ldx #1
        jsr scr_print_at

        ; --- the timed part: read the payload ------------------------------
        lda #1
        sta spike_phase
        jsr read_payload
        lda #2
        sta spike_phase

        ; --- and check every byte of it ------------------------------------
        jsr verify_payload
        lda #3
        sta spike_phase

        jsr report
        lda #4
        sta spike_phase

        ; Echo keys into the bottom right cell, as the step 0 spike does, so an
        ; interactive run has something to prove it is alive.
.key
        lda KBD
        bpl .key
        sta KBDSTRB
        and #$7f
        cmp #$60
        bcc .key_upper
        and #$df
.key_upper
        ora #$80
        sta SCREEN + $3d0 + COLS - 1
        jmp .key

; ===========================================================================
; The test itself
; ===========================================================================

; ---------------------------------------------------------------------------
; read_payload: tracks 1..PAYLOAD_TRACKS into $1000 and up, one page per
; sector, in the order the skew table gives; then FAR_TRACK sector 0 into
; $B000; then track 1 sector 0 again, to prove the seek back.
; ---------------------------------------------------------------------------
!zone read_payload
read_payload
        lda #1
        sta cur_track
.track
        lda #0
        sta cur_index
.sector
        lda cur_track
        sta rw_track
        ldx cur_index
        lda skew_table,x
        sta rw_sector
        lda #0
        sta rw_dest
        lda cur_track           ; the destination page is track * 16 + index,
        asl                     ; which is also the sector's pattern seed
        asl
        asl
        asl
        ora cur_index
        sta rw_dest + 1
        jsr rwts_read
        bcs .failed
        jsr count_sector
        inc cur_index
        lda cur_index
        cmp #16
        bne .sector
        inc cur_track
        lda cur_track
        cmp #PAYLOAD_TRACKS + 1
        bne .track

        ; The long seek out...
        lda #FAR_TRACK
        sta rw_track
        lda #0
        sta rw_sector
        sta rw_dest
        lda #FAR_PAGE
        sta rw_dest + 1
        jsr rwts_read
        bcs .failed
        jsr count_sector

        ; ...and back again, re-reading a sector we have already checked.
        lda #1
        sta rw_track
        lda #0
        sta rw_sector
        sta rw_dest
        lda #PAYLOAD_PAGE
        sta rw_dest + 1
        jsr rwts_read
        bcs .failed
        jsr count_sector
        rts

.failed
        lda #1
        sta err_flag
        lda rw_track
        sta err_track
        lda rw_sector
        sta err_sector
        rts

!zone count_sector
count_sector
        inc sec_count
        bne +
        inc sec_count + 1
+       rts

; ---------------------------------------------------------------------------
; verify_payload: every sector we read, byte for byte.  A sector's bytes are
; track, index, then a ramp from its own page number, so a sector read into the
; wrong page - or read twice, or shifted - is caught, not just corrupted.
; ---------------------------------------------------------------------------
!zone verify_payload
verify_payload
        lda err_flag
        bne .out                ; nothing was read past the failure
        lda #1
        sta cur_track
.track
        lda #0
        sta cur_index
.sector
        lda cur_track
        asl
        asl
        asl
        asl
        ora cur_index
        jsr verify_page         ; a = page, cur_track/cur_index = what it holds
        bcs .bad
        inc cur_index
        lda cur_index
        cmp #16
        bne .sector
        inc cur_track
        lda cur_track
        cmp #PAYLOAD_TRACKS + 1
        bne .track

        lda #FAR_TRACK
        sta cur_track
        lda #0
        sta cur_index
        lda #FAR_PAGE
        jsr verify_page
        bcs .bad
.out    rts
.bad
        lda #1
        sta ver_flag
        lda cur_track
        sta ver_track
        lda cur_index
        sta ver_index
        rts

; a = the page to check.  Carry set if it is wrong.
!zone verify_page
verify_page
        sta ver_ptr + 1
        sta rw_tmp              ; the seed is the page number
        lda #0
        sta ver_ptr
        tay
        lda (ver_ptr),y
        cmp cur_track
        bne .bad
        iny
        lda (ver_ptr),y
        cmp cur_index
        bne .bad
        ldy #2
.byte
        tya
        clc
        adc rw_tmp
        cmp (ver_ptr),y
        bne .bad
        iny
        bne .byte
        clc
        rts
.bad    sec
        rts

; ---------------------------------------------------------------------------
; report: what happened, on screen.
; ---------------------------------------------------------------------------
!zone report
report
        lda #<l_sectors
        ldy #>l_sectors
        ldx #3
        jsr scr_print_at
        lda sec_count + 1
        ldy sec_count
        jsr scr_hex16

        lda #<l_fields
        ldy #>l_fields
        ldx #4
        jsr scr_print_at
        lda af_count + 1
        ldy af_count
        jsr scr_hex16

        lda #<l_retries
        ldy #>l_retries
        ldx #5
        jsr scr_print_at
        lda retry_count + 1
        ldy retry_count
        jsr scr_hex16

        lda #<l_causes
        ldy #>l_causes
        ldx #6
        jsr scr_print_at
        lda err_seek
        jsr scr_hex8
        lda #' '
        jsr scr_putc
        lda err_timeout
        jsr scr_hex8
        lda #' '
        jsr scr_putc
        lda err_prologue
        jsr scr_hex8
        lda #' '
        jsr scr_putc
        lda err_checksum
        jsr scr_hex8

        ldx #7
        lda err_flag
        bne .read_bad
        lda #<l_read_ok
        ldy #>l_read_ok
        jsr scr_print_at
        jmp .data
.read_bad
        lda #<l_read_bad
        ldy #>l_read_bad
        jsr scr_print_at
        lda err_track
        jsr scr_hex8
        lda #' '
        jsr scr_putc
        lda err_sector
        jsr scr_hex8

.data
        ldx #8
        lda err_flag
        bne .data_skip
        lda ver_flag
        bne .data_bad
        lda #<l_data_ok
        ldy #>l_data_ok
        jsr scr_print_at
        rts
.data_bad
        lda #<l_data_bad
        ldy #>l_data_bad
        jsr scr_print_at
        lda ver_track
        jsr scr_hex8
        lda #' '
        jsr scr_putc
        lda ver_index
        jsr scr_hex8
        rts
.data_skip
        lda #<l_data_skip
        ldy #>l_data_skip
        jsr scr_print_at
        rts

; ===========================================================================
; The RWTS.  Read only - the write path is step 8's problem.
; ===========================================================================

; ---------------------------------------------------------------------------
; rwts_init: the PROM leaves the motor running, the drive selected and the
; head recalibrated to track 0, so this only has to record that and make sure
; the controller is in read mode.
; ---------------------------------------------------------------------------
!zone rwts_init
rwts_init
        lda $2b                 ; slot * 16, left by the boot PROM
        sta rw_slot
        tax
        lda Q7L,x               ; read mode
        lda Q6L,x
        lda DRIVE1,x
        lda MOTORON,x

        ; The PROM recalibrates by energising phases 3,2,1,0 in turn and leaves
        ; the last one - phase 0 - still pulling.  A magnet left on fights every
        ; step we make afterwards: the head is drawn back to track 0 the moment
        ; we release the phase we stepped with.  Release all four.
        lda PHASEOFF,x
        lda PHASEOFF + 2,x
        lda PHASEOFF + 4,x
        lda PHASEOFF + 6,x

        lda #0
        sta rw_half
        rts

; ---------------------------------------------------------------------------
; rwts_seek: put the head on rw_track, one half-track at a time.
; ---------------------------------------------------------------------------
!zone rwts_seek
rwts_seek
        lda #0
        sta rw_moved
        lda rw_track
        asl
        sta rw_tmp              ; the destination, in half-tracks
.loop
        lda rw_tmp
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
; rwts_recalibrate: step out past track 0 and call that home.  Used when a
; sector will not read, which usually means the head is not where we think.
; ---------------------------------------------------------------------------
!zone rwts_recalibrate
rwts_recalibrate
        ; Eighty half-steps outwards, which is more than the disk is wide, so
        ; wherever the head was it ends against the stop at track 0.  The phase
        ; comes from the descending counter rather than from rw_half, because
        ; rw_half is exactly the thing we have stopped believing: energising the
        ; phase of the half-track the head is already on moves nothing.
        lda #80
        sta rw_tmp
.out
        lda rw_tmp
        and #3
        asl
        clc
        adc rw_slot
        tax
        lda PHASEON,x
        lda #PHASE_ON_MS
        jsr delay_ms
        lda PHASEOFF,x
        dec rw_tmp
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
; rwts_read: read rw_track / rw_sector (physical) into the page at rw_dest.
; Carry clear if it worked.
; ---------------------------------------------------------------------------
!zone rwts_read
rwts_read
        lda #READ_RETRIES
        sta rw_retry
.try
        jsr rwts_seek           ; cheap when the head is already there
        jsr read_sector
        bcc .ok
        inc retry_count
        bne +
        inc retry_count + 1
+       dec rw_retry
        beq .give_up
        lda rw_retry            ; every fourth failure, start from track 0
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
; read_sector: hunt for our address field and read the data field behind it.
; x = slot * 16 throughout, because every nibble read is lda Q6L,x.
; ---------------------------------------------------------------------------
!zone read_sector
read_sector
        lda #0
        sta rw_niblo
        sta rw_nibhi
.scan
        ; --- the address field prologue, D5 AA 96 --------------------------
        ; A byte that fails one of the tests may still be the start of the next
        ; prologue, so a mismatch goes back to the D5 test rather than to the
        ; top.  The nibble counter is the only timeout there is: a disk with
        ; nothing on it would otherwise spin here for ever.
.a1     lda Q6L,x
        bpl .a1
        inc rw_niblo
        bne .a1_ok
        inc rw_nibhi
        bne .a1_ok
        jmp .fail_timeout       ; 65536 nibbles, about ten revolutions
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

        inc af_count            ; one more sector has gone past the head
        bne +
        inc af_count + 1
+
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
        bne .scan               ; the field is damaged; wait for another

        lda rw_atrk
        cmp rw_track
        bne .wrong_track
        lda rw_asec
        cmp rw_sector
        bne .scan               ; someone else's sector

        ; --- the data field prologue, D5 AA AD -----------------------------
        ; It follows its address field immediately, so give it a few dozen
        ; nibbles and no more.
        ldy #$30
.d1     lda Q6L,x
        bpl .d1
        dey
        beq .fail_prologue
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
        ; a carries the running EOR the whole way; y is borrowed to index the
        ; decode table, so the buffer index is parked in rw_idx.  26 cycles a
        ; nibble, against the 32 the drive gives us.  The buffer fills
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
        sta (rw_dest),y
        iny
        bne .data

        ; --- and the byte that closes the chain ----------------------------
.ck_w   ldy Q6L,x
        bpl .ck_w
        eor DECODE_TABLE,y
        bne .fail_checksum

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
        lda (rw_dest),y
        lsr RWTS_AUX,x
        rol
        lsr RWTS_AUX,x
        rol
        sta (rw_dest),y
        iny
        bne .pn

        ldx rw_slot             ; the unpack borrowed x
        clc
        rts

; Why a read failed, counted separately, because the four causes mean very
; different things: a mis-seek is the head in the wrong place, a missing data
; prologue is a damaged sector, a bad checksum is a dropped nibble (which on
; this machine means the decode loop was too slow), and a timeout is no disk.
.wrong_track
        ; The field tells us where the head really is; believe it, and let the
        ; caller seek again from there.
        inc err_seek
        lda rw_atrk
        asl
        sta rw_half
        jmp .fail
.fail_timeout
        inc err_timeout
        jmp .fail
.fail_prologue
        inc err_prologue
        jmp .fail
.fail_checksum
        inc err_checksum
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
; build_decode_table: disk byte -> its six bits.  The 64 valid disk bytes in
; ascending order are the codes 0..63, so the table is just that list turned
; inside out.  Everything else decodes to $FF, which cannot help but break the
; running checksum, which is what we want from a nibble that should not exist.
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

; The order the payload's sectors were laid down in, and so the order we ask
; for them.  SKEW must be odd, or the walk does not visit all sixteen.
skew_table
        !for .i, 0, 15 {
                !byte (.i * SKEW) & 15
        }

; ===========================================================================
; Screen
; ===========================================================================

; ---------------------------------------------------------------------------
; scr_setrow: zp_screenline -> row x, column 0.  Preserves x.
; ---------------------------------------------------------------------------
!zone scr_setrow
scr_setrow
        lda row_lo,x
        sta zp_screenline
        lda row_hi,x
        sta zp_screenline + 1
        lda #0
        sta scr_col
        rts

; ---------------------------------------------------------------------------
; scr_putc: a = ASCII, folded to upper case and written in normal video.
; ---------------------------------------------------------------------------
!zone scr_putc
scr_putc
        cmp #'a'
        bcc .no_fold
        cmp #'z' + 1
        bcs .no_fold
        sec
        sbc #$20
.no_fold
        ora #$80
        sty .save_y
        ldy scr_col
        sta (zp_screenline),y
        inc scr_col
        ldy .save_y
        rts
.save_y !byte 0

; ---------------------------------------------------------------------------
; scr_print_at: print the string at a/y on row x, from column 0.
; scr_print: print the string at a/y at the cursor.
; ---------------------------------------------------------------------------
!zone scr_print_at
scr_print_at
        sta zp_string
        sty zp_string + 1
        jsr scr_setrow
        jmp .go
scr_print
        sta zp_string
        sty zp_string + 1
.go
        ldy #0
.next
        lda (zp_string),y
        beq .done
        sty .save_y
        jsr scr_putc
        ldy .save_y
        iny
        bne .next
.done
        rts
.save_y !byte 0

; ---------------------------------------------------------------------------
; scr_hex8 / scr_hex16: a (and y, low byte) as hex at the cursor.
; ---------------------------------------------------------------------------
!zone scr_hex16
scr_hex16
        sty .low
        jsr scr_hex8
        lda .low
        jmp scr_hex8
.low    !byte 0

!zone scr_hex8
scr_hex8
        pha
        lsr
        lsr
        lsr
        lsr
        jsr .digit
        pla
        and #$0f
.digit
        cmp #10
        bcc .decimal
        clc
        adc #'A' - 10
        jmp scr_putc
.decimal
        clc
        adc #'0'
        jmp scr_putc

; ---------------------------------------------------------------------------
; scr_clear: spaces, every row, edge to edge.
; ---------------------------------------------------------------------------
!zone scr_clear
scr_clear
        ldx #ROWS - 1
.row
        jsr scr_setrow
        lda #' ' | $80
        ldy #COLS - 1
.cell
        sta (zp_screenline),y
        dey
        bpl .cell
        dex
        bpl .row
        rts

; The text page is three interleaved blocks of eight rows:
; $400 + (row & 7) * $80 + (row >> 3) * $28.
row_lo
        !for .r, 0, ROWS - 1 {
                !byte <(SCREEN + (.r & 7) * $80 + (.r >> 3) * $28)
        }
row_hi
        !for .r, 0, ROWS - 1 {
                !byte >(SCREEN + (.r & 7) * $80 + (.r >> 3) * $28)
        }

; ===========================================================================
; Data.  Everything the harness reads back by name lives here, so the labels
; in temp/apple2_rwts_labels.txt are the whole interface.
; ===========================================================================

spike_phase     !byte 0         ; 1 reading, 2 read done, 3 verified, 4 idle
spike_skew      !byte SKEW
spike_tracks    !byte PAYLOAD_TRACKS
sec_count       !byte 0, 0      ; sectors read
af_count        !byte 0, 0      ; address fields that went past the head
retry_count     !byte 0, 0
err_flag        !byte 0
err_track       !byte 0
err_sector      !byte 0
err_seek        !byte 0         ; the head was not where we thought
err_timeout     !byte 0         ; nothing readable went past at all
err_prologue    !byte 0         ; no data field behind the address field
err_checksum    !byte 0         ; the data field did not add up
ver_flag        !byte 0
ver_track       !byte 0
ver_index       !byte 0
cur_track       !byte 0
cur_index       !byte 0

title
        !text "ozmoo apple ][ rwts spike, step 1", 0
subtitle
        !text "reading tracks 1-", '0' + PAYLOAD_TRACKS / 10, '0' + PAYLOAD_TRACKS % 10
        !text " skew ", '0' + SKEW / 10, '0' + SKEW % 10, 0
l_sectors
        !text "sectors read   $", 0
l_fields
        !text "address fields $", 0
l_retries
        !text "retries        $", 0
l_causes
        !text "seek/none/pro/sum  $", 0
l_read_ok
        !text "read ok", 0
l_read_bad
        !text "read failed at t/s $", 0
l_data_ok
        !text "data ok", 0
l_data_bad
        !text "data bad at t/i $", 0
l_data_skip
        !text "data not checked", 0

image_end

; The stage 2 has to fit below the aux buffer, and the PROM will only load one
; track of it.
!if image_end > RWTS_AUX {
        !error "stage 2 is ", image_end - RWTS_AUX, " bytes too big"
}
!if (image_end - $0800 + 255) / 256 > 16 {
        !error "stage 2 does not fit on track 0"
}
        !fill (($0800 + (((image_end - $0800 + 255) / 256) * 256)) - *), 0
