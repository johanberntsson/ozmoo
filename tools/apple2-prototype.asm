; ---------------------------------------------------------------------------
; Ozmoo Apple II spike (boot sector)
;
; A standalone boot sector, in the mould of tools/fcm-prototype.asm: it belongs
; to no build and is sourced by nothing.  It is only used to verify
; Ozmoo is touched:
;
;   * the toolchain      - ACME with --cpu 6502 --format plain produces a raw
;                          6502 binary at a chosen origin, no CBM load address;
;   * the boot chain     - the Disk II boot PROM at $C600 reads track 0 sector 0
;                          of our own filesystem-less .dsk into $0800 and jumps
;                          to $0801, and the code there runs;
;   * screen addressing  - the interleaved text page ($400 + (row&7)*$80 +
;                          (row>>3)*$28), which is problem 1 in the plan
;                          and the thing screenkernal.asm's .update_screenpos
;                          will need a row table for;
;   * the two video      - normal video is ASCII | $80, inverse is ASCII & $3F,
;     encodings            covering only $20-$5F.  Problem 2 in the plan, and
;                          what s_reverse becomes on this target;
;   * uppercase folding  - the II/II+ has no lowercase glyphs, so a-z is folded
;                          to A-Z on the way to the screen;
;   * the emulator loop  - build, boot, look, and read the keyboard at $C000.
;
; The screen it draws is meant to be checked by machine as well as by eye:
; every row is filled edge to edge with its own letter, row 0 = A up to row 23
; = X, even rows normal and odd rows inverse.  Any error in the row table shows
; up at once as a duplicated, missing or short row, and the last column proves
; a row is exactly 40 characters and does not run into the next one.  Two
; banners are written over that pattern, one normal and one inverse, in source
; lowercase, so the fold is visible too.  Then each key pressed is echoed into
; the bottom right cell, which gives a headless test something to change.
;
; Build and run it with tools/apple2-spike.rb.
; ---------------------------------------------------------------------------

!cpu 6502

; --- hardware ---------------------------------------------------------------
SCREEN          = $0400     ; text page 1
KBD             = $C000     ; bit 7 = key waiting, bits 0-6 = ASCII
KBDSTRB         = $C010     ; any access clears the strobe
MOTOROFF        = $C088     ; + slot*16

; --- zero page --------------------------------------------------------------
; $26/$27 and $28/$29 are the boot PROM's own scratch (buffer pointer and
; friends).  It has finished with them by the time we get control, and there is
; no DOS here, so the whole zero page is ours.
zp_screenline   = $26       ; -> first cell of the current row
zp_string       = $28       ; -> string being printed

ROWS            = 24
COLS            = 40

* = $0800

; The boot PROM reads this sector to $0800 and jumps to $0801, so byte 0 is
; never executed.  DOS 3.3 keeps its stage-2 sector count here; we keep the
; same convention so the sector looks ordinary to anything that inspects it.
        !byte $01

; ---------------------------------------------------------------------------
start
        ; The PROM leaves the drive spinning and the slot in $2B (slot * 16).
        ldx $2b
        lda MOTOROFF,x

        ; Fill row n with the letter 'A' + n, inverse on odd rows.  The screen
        ; is never cleared first, deliberately: the 24 rows cover all 960
        ; visible cells between them, so anything the boot PROM left behind
        ; that is still on screen afterwards is a hole in the row table.  (The
        ; four screen holes of each 128-byte block - $478-$47F and friends,
        ; which belong to peripheral cards - are not on screen and are never
        ; written.)
        ldx #0
.row
        jsr set_row
        txa
        and #1
        beq .row_normal
        txa
        clc
        adc #'A'
        and #$3f            ; inverse: $41+n -> $01+n
        bne .row_fill       ; always ($01..$18)
.row_normal
        txa
        clc
        adc #'A'
        ora #$80            ; normal
.row_fill
        ldy #COLS - 1
.row_cell
        sta (zp_screenline),y
        dey
        bpl .row_cell
        inx
        cpx #ROWS
        bne .row

        ; Two banners over the pattern, to show the fold and both encodings.
        lda #<banner1
        sta zp_string
        lda #>banner1
        sta zp_string + 1
        lda #0
        sta inverse
        ldx #0
        jsr print_string

        lda #<banner2
        sta zp_string
        lda #>banner2
        sta zp_string + 1
        lda #1
        sta inverse
        ldx #12
        jsr print_string

        ; Echo every key into the bottom right cell, in normal video so it
        ; stands out against row 23's inverse fill.  This is the whole of the
        ; keyboard for now: bit 7 of $C000 says a key is waiting, the low seven
        ; bits are its ASCII, and touching $C010 clears the strobe.
        ;
        ; The fold to upper case matters even though a real II+ keyboard cannot
        ; produce lower case - an emulator can, and does (typing Z here arrives
        ; as $7A).  The II/II+ character generator holds only 64 glyphs, so
        ; $E0-$FF would alias onto the upper case shapes on screen anyway; this
        ; just makes the byte in screen memory say what the screen shows.
.key
        lda KBD
        bpl .key
        sta KBDSTRB
        and #$7f
        cmp #$60
        bcc .key_upper
        and #$df            ; $60-$7F -> $40-$5F
.key_upper
        ora #$80
        sta SCREEN + $3d0 + COLS - 1    ; row 23, column 39
        jmp .key

; ---------------------------------------------------------------------------
; set_row: zp_screenline -> first cell of row x.  x is preserved.
; ---------------------------------------------------------------------------
set_row
        lda row_lo,x
        sta zp_screenline
        lda row_hi,x
        sta zp_screenline + 1
        rts

; ---------------------------------------------------------------------------
; print_string: write the zero-terminated ASCII string at zp_string to row x,
; starting at column 0, folding a-z to A-Z and applying normal or inverse video
; according to `inverse`.  Clobbers a, x, y.
; ---------------------------------------------------------------------------
print_string
        jsr set_row
        ldy #0
.next
        lda (zp_string),y
        beq .done
        cmp #'a'
        bcc .no_fold
        cmp #'z' + 1
        bcs .no_fold
        sec
        sbc #$20            ; a-z -> A-Z
.no_fold
        ldx inverse
        beq .normal
        and #$3f            ; $20-$5F -> $20-$3F
        bne .put            ; always (a space is $20 either way)
.normal
        ora #$80
.put
        sta (zp_screenline),y
        iny
        bne .next
.done
        rts

; ---------------------------------------------------------------------------
inverse
        !byte 0

; The row table that .update_screenpos will need: the text page is stored in
; three interleaved blocks of eight rows, so a row's base is
; $400 + (row & 7) * $80 + (row >> 3) * $28.
row_lo
        !for .r, 0, ROWS - 1 {
                !byte <(SCREEN + (.r & 7) * $80 + (.r >> 3) * $28)
        }
row_hi
        !for .r, 0, ROWS - 1 {
                !byte >(SCREEN + (.r & 7) * $80 + (.r >> 3) * $28)
        }

banner1
        !text "ozmoo apple ][ spike", 0
banner2
        !text "rows a-x, keys echo", 0

; ---------------------------------------------------------------------------
; One sector, and the image writer expects exactly 256 bytes.
!if * > $0900 {
        !error "boot sector is ", * - $0900, " bytes too big"
}
        !fill $0900 - *, 0
