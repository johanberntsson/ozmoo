; ---------------------------------------------------------------------------
; Apple II write-path spike: the payload
;
; This is loaded and jumped to by the REAL boot chain (asm/apple2-rwts.asm), in
; the place the interpreter normally occupies, and it calls the real driver
; through the same three fixed addresses Ozmoo uses. So what is being tested is
; the resident RWTS itself, not a copy of it that might have drifted.
;
; What it does: fill a page with a pattern that says which sector it belongs
; to, write it to every sector of three tracks, read them all back and compare
; byte for byte. Then rewrite one sector with a second pattern, to prove that
; overwriting a data field in place works and does not disturb its neighbours.
;
; The counters are read out of memory by name (tools/apple2-write-spike.rb),
; and the screen gets a one line verdict for the windowed emulators.
; ---------------------------------------------------------------------------

!cpu 6502

A2_READ         = $0804
A2_TRACK        = $0807
A2_SECTOR       = $0808
A2_DEST         = $0809
A2_DEST_LO      = $080A
A2_WRITE        = $080B
A2_WPROT        = $080E         ; the drive refused, as against a bad verify

SCREEN          = $0400
PATTERN         = $2000         ; what we write
READBACK        = $2100         ; what comes back

; With NIB_DUMP the payload writes one track and then reads a whole track's
; worth of raw nibbles into NIB_BUF for the driver to pick apart on the host.
; It is how a data field that neither reader can decode gets looked at.
!ifndef NIB_DUMP { NIB_DUMP = 0 }
!ifndef WRITE_TWICE { WRITE_TWICE = 0 }
NIB_BUF         = $3000
NIB_BUF_PAGES   = 28            ; 7168 nibbles, more than a track holds

!ifndef TEST_TRACK_1 { TEST_TRACK_1 = 20 }
!ifndef TEST_TRACK_2 { TEST_TRACK_2 = 21 }
!ifndef TEST_TRACK_3 { TEST_TRACK_3 = 34 }
!ifndef SKEW { SKEW = 3 }

* = $1000

!zone start
start
        lda #0
        sta w_done
        sta w_bad
        sta w_write_fail
        sta w_read_fail
        sta w_sectors
        sta w_first_bad + 1

        ; --- write every sector of the three test tracks -------------------
        ldx #0
.write_tracks
        lda test_tracks,x
        sta cur_track
        stx track_index
        jsr write_one_track
        ldx track_index
        inx
        cpx #3
        bne .write_tracks

!if NIB_DUMP = 1 {
        jsr dump_nibbles
        lda #1
        sta w_done
.hang   jmp .hang
}

        ; --- and read them all back ----------------------------------------
        ldx #0
.read_tracks
        lda test_tracks,x
        sta cur_track
        stx track_index
        jsr verify_one_track
        ldx track_index
        inx
        cpx #3
        bne .read_tracks

        ; --- overwrite one sector, and check its neighbour survived ---------
        ; A data field is written inside a gap the formatter left, so a write
        ; that is a few bytes too long lands on the next sector's address
        ; field. Nothing in the checks above would notice; this does.
        lda #TEST_TRACK_1
        sta cur_track
        lda #7
        sta cur_sector
        lda #$5a
        sta pattern_salt
        jsr fill_pattern
        jsr write_sector
        jsr read_sector
        jsr compare
        lda #0
        sta pattern_salt

        lda #TEST_TRACK_1       ; the sector after it, in physical order
        sta cur_track
        lda #8
        sta cur_sector
        jsr fill_pattern
        jsr read_sector
        jsr compare

        ; --- verdict ---------------------------------------------------------
        lda w_bad
        ora w_write_fail
        ora w_read_fail
        bne .bad
        ldx #0
.ok_msg lda msg_ok,x
        beq .finish
        ora #$80
        sta SCREEN,x
        inx
        bne .ok_msg
.bad
        ; Which kind of failure, since on a machine with no debugger this one
        ; line is the whole report: a drive that refused the write outright
        ; says so, rather than looking like a driver that cannot write.
        lda A2_WPROT
        beq .bad_verify
        ldx #0
.prot_msg lda msg_prot,x
        beq .finish
        ora #$80
        sta SCREEN,x
        inx
        bne .prot_msg
.bad_verify
        ldx #0
.bad_msg lda msg_bad,x
        beq .finish
        ora #$80
        sta SCREEN,x
        inx
        bne .bad_msg
.finish
        lda #1
        sta w_done
.stop   jmp .stop

; ---------------------------------------------------------------------------
; write_one_track / verify_one_track: all sixteen sectors, in the order the
; interleave lays them down, which is the order Ozmoo reads and writes them.
; ---------------------------------------------------------------------------
!zone write_one_track
write_one_track
        lda #0
        sta sector_index
.next
        ldx sector_index
        lda skew_table,x
        sta cur_sector
        jsr fill_pattern
        jsr write_sector
!if WRITE_TWICE = 1 {
        jsr write_sector
}
        inc w_sectors
        inc sector_index
        lda sector_index
        cmp #16
        bne .next
        rts

!zone verify_one_track
verify_one_track
        lda #0
        sta sector_index
.next
        ldx sector_index
        lda skew_table,x
        sta cur_sector
        jsr fill_pattern
        jsr read_sector
        jsr compare
        inc sector_index
        lda sector_index
        cmp #16
        bne .next
        rts

; ---------------------------------------------------------------------------
; fill_pattern: byte 0 is the track, byte 1 the sector and the rest a ramp from
; their sum, so a sector that reads perfectly into the wrong place is caught -
; which a checksum would not do.
; ---------------------------------------------------------------------------
!zone fill_pattern
fill_pattern
        lda cur_track
        asl
        asl
        asl
        asl
        clc
        adc cur_sector
        eor pattern_salt
        tay
        ldx #0
.fill
        tya
        sta PATTERN,x
        iny
        inx
        bne .fill
        lda cur_track
        sta PATTERN
        lda cur_sector
        sta PATTERN + 1
        lda pattern_salt
        sta PATTERN + 2
        rts

; ---------------------------------------------------------------------------
; write_sector / read_sector: the driver, called exactly as Ozmoo calls it.
; ---------------------------------------------------------------------------
!zone write_sector
write_sector
        lda cur_track
        sta A2_TRACK
        lda cur_sector
        sta A2_SECTOR
        lda #>PATTERN
        sta A2_DEST
        lda #<PATTERN
        sta A2_DEST_LO
        jsr A2_WRITE
        bcc +
        inc w_write_fail
+       rts

!zone read_sector
read_sector
        lda cur_track
        sta A2_TRACK
        lda cur_sector
        sta A2_SECTOR
        lda #>READBACK
        sta A2_DEST
        lda #<READBACK
        sta A2_DEST_LO
        jsr A2_READ
        bcc +
        inc w_read_fail
+       rts

; ---------------------------------------------------------------------------
; compare: 256 bytes, and remember the first sector that disagreed.
; ---------------------------------------------------------------------------
!zone compare
compare
        ldx #0
.next
        lda PATTERN,x
        cmp READBACK,x
        bne .mismatch
        inx
        bne .next
        rts
.mismatch
        inc w_bad
        lda w_first_bad + 1
        bne +
        lda cur_track
        sta w_first_bad
        lda cur_sector
        sta w_first_bad + 1
        stx w_first_bad + 2
+       rts

; ---------------------------------------------------------------------------
; dump_nibbles: a track's worth of raw nibbles, exactly as they come off the
; head, into NIB_BUF. No decoding and no waiting for a marker - the host can
; find the fields itself, and what it is looking for is precisely the places
; where they are not where they should be.
; ---------------------------------------------------------------------------
!zone dump_nibbles
dump_nibbles
        lda #TEST_TRACK_1
        sta cur_track
        lda #0
        sta cur_sector
        jsr read_sector         ; seeks, and leaves the head on the track

        lda #>NIB_BUF
        sta .store + 2
        lda #NIB_BUF_PAGES
        sta .pages
        ldx #$60                ; slot 6
        ldy #0
.next
        lda $C08C,x
        bpl .next
.store
        sta NIB_BUF,y
        iny
        bne .next
        inc .store + 2
        dec .pages
        bne .next
        rts
.pages  !byte 0

msg_ok  !text "WRITE OK", 0
msg_bad !text "WRITE FAILED", 0
msg_prot !text "WRITE PROTECTED", 0

test_tracks
        !byte TEST_TRACK_1, TEST_TRACK_2, TEST_TRACK_3

skew_table
        !for .i, 0, 15 {
                !byte (.i * SKEW) & 15
        }

cur_track       !byte 0
cur_sector      !byte 0
sector_index    !byte 0
track_index     !byte 0
pattern_salt    !byte 0

w_done          !byte 0
w_sectors       !byte 0
w_bad           !byte 0
w_write_fail    !byte 0
w_read_fail     !byte 0
w_first_bad     !byte 0, 0, 0   ; track, sector, offset
