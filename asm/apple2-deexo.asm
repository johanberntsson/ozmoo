; ---------------------------------------------------------------------------
; Ozmoo Apple II: the exomizer decruncher the boot chain calls
;
; This file is not sourced by ozmoo.asm. Like asm/apple2-rwts.asm it is
; assembled on its own, by make.rb (build_a2_deexo), and it is the tail of the
; one blob the boot chain reads off the disk:
;
;   $BC00-$BFFF   this file, the top kilobyte of RAM
;   ...-$BC00     the crunched interpreter, ending just below it
;
; The boot chain loads the pair, jsr's the first byte of this, and jumps to
; TERP_LOAD when it returns. Both are dead afterwards - the vmem cache grows
; over them - so the kilobyte costs nothing.
;
; Build-time defines, all from make.rb:
;   DEEXO_ORG    where this is assembled and loaded, and its entry point
;   CRUNCH_SRC   the first byte of the crunched stream
;   TERP_LOAD    where the interpreter decrunches to
; ---------------------------------------------------------------------------

!cpu 6502

!ifndef DEEXO_ORG { DEEXO_ORG = $bc00 }
!ifndef CRUNCH_SRC { CRUNCH_SRC = $9000 }
!ifndef TERP_LOAD { TERP_LOAD = $1000 }

; The zero page belongs to Ozmoo, but none of Ozmoo is running yet and the RWTS
; uses none of it, so these bytes are free until the boot chain's final jmp.
; They are clear of the monitor's own workspace ($20 up) and of the slot byte
; at $2B that rwts_init reads.
zp_src          = $06           ; crunched read pointer
zp_out          = $08           ; output write pointer
zp_ref          = $0a           ; back-reference read pointer

* = DEEXO_ORG

; The bit buffer holds a sentinel: bits come out of bit 0, and the byte is
; exhausted exactly when the sentinel is the last thing left, which is what
; makes "the lsr left zero behind" the empty test.
!macro get_bit {
        lsr exo_bitbuf
        bne +
        jsr exo_refill          ; carry is the refilled byte's bit 0
+
}

; ---------------------------------------------------------------------------
; deexo: decrunch CRUNCH_SRC to TERP_LOAD. Both are assembled in, so the boot
; chain passes nothing and gets nothing back but an rts.
; ---------------------------------------------------------------------------
!zone deexo
deexo
        lda #<CRUNCH_SRC
        sta zp_src
        lda #>CRUNCH_SRC
        sta zp_src + 1
        lda #<TERP_LOAD
        sta zp_out
        lda #>TERP_LOAD
        sta zp_out + 1
        jsr exo_init
        ldy #0                  ; ...and y stays 0 from here on
.dx_loop
        +get_bit                ; 1 = literal, 0 = sequence
        bcc .dx_seq
        lda (zp_src),y          ; literal byte, straight to the output
        inc zp_src
        bne +
        inc zp_src + 1
+       sta (zp_out),y
        inc zp_out
        bne .dx_loop
        inc zp_out + 1
        bne .dx_loop            ; always

.dx_seq
        lda #0                  ; gamma: count leading zero bits
        sta exo_gamma
.dx_gamma
        +get_bit
        bcs .dx_havegamma
        inc exo_gamma
        bne .dx_gamma           ; always
.dx_havegamma
        ldx exo_gamma
        cpx #16                 ; gamma 16 is the end-of-stream marker
        bne +
        rts
+       jsr exo_cooked          ; length = cooked(gamma)
        lda exo_c_lo
        sta exo_len_lo
        lda exo_c_hi
        sta exo_len_hi
        ; i = min(length, 3) - 1: which of the three offset tables to use.
        ldx #2
        lda exo_len_hi
        bne .dx_havei
        lda exo_len_lo
        cmp #3
        bcs .dx_havei
        sec                     ; length is 1 or 2: i = length - 1
        sbc #1
        tax
.dx_havei
        stx exo_idx             ; keep i across the get_bits below
        lda exo_tabl_bit,x
        tax
        jsr exo_get_bits        ; v2 = tabl_off[i] + get_bits(tabl_bit[i])
        ldx exo_idx
        clc
        adc exo_tabl_off,x
        tax
        jsr exo_cooked          ; offset = cooked(v2)
        sec                     ; ref = out - offset
        lda zp_out
        sbc exo_c_lo
        sta zp_ref
        lda zp_out + 1
        sbc exo_c_hi
        sta zp_ref + 1

        ; Copy the sequence forwards, 255 bytes at a time so that y can be the
        ; index for the whole run and the two pointers are only fixed up once.
        ; Overlapping runs are the normal case (that is how exomizer writes a
        ; repeat), and copying forwards a byte at a time is what they mean.
.dx_run
        ldx exo_len_hi
        beq .dx_short
        ldx #255                ; more than a page left: do 255 of it
        bne .dx_copy            ; always
.dx_short
        ldx exo_len_lo
.dx_copy
        lda (zp_ref),y
        sta (zp_out),y
        iny
        dex
        bne .dx_copy

        tya                     ; out += y, ref += y, length -= y
        clc
        adc zp_out
        sta zp_out
        bcc +
        inc zp_out + 1
+       tya
        clc
        adc zp_ref
        sta zp_ref
        bcc +
        inc zp_ref + 1
+       tya
        eor #$ff                ; length -= y, 16 bit
        sec
        adc exo_len_lo
        sta exo_len_lo
        bcs +
        dec exo_len_hi
+       ldy #0
        lda exo_len_lo
        ora exo_len_hi
        bne .dx_run
        jmp .dx_loop

; ---------------------------------------------------------------------------
; exo_refill: the bit buffer is empty, so take the next crunched byte, hand its
; bit 0 back in the carry and keep the rest. a and the carry both survive for
; the caller: pla sets only N and Z, and inc does not touch the carry either.
; ---------------------------------------------------------------------------
!zone exo_refill
exo_refill
        pha
        lda (zp_src),y          ; y is 0 throughout
        inc zp_src
        bne +
        inc zp_src + 1
+       lsr                     ; carry = bit 0 of the new byte
        ora #$80                ; ...and the sentinel goes in at the top
        sta exo_bitbuf
        pla
        rts

; ---------------------------------------------------------------------------
; exo_get_bits: get x bits (0..16) MSB first, low byte in a and high byte in
; exo_bits_hi. Many table entries ask for 0 bits, which must return 0 without
; touching the stream, and most of the rest ask for 8 or fewer, which do not
; need the high byte rolled at all.
; ---------------------------------------------------------------------------
!zone exo_get_bits
exo_get_bits
        lda #0
        sta exo_bits_hi
        cpx #0
        beq .egb_ret
        cpx #9
        bcs .egb_wide
.egb_narrow
        lsr exo_bitbuf
        bne +
        jsr exo_refill
+       rol                     ; val = (val << 1) | carry, 8 bits or fewer
        dex
        bne .egb_narrow
        rts
.egb_wide
        lsr exo_bitbuf
        bne +
        jsr exo_refill
+       rol
        rol exo_bits_hi
        dex
        bne .egb_wide
.egb_ret
        rts

; ---------------------------------------------------------------------------
; exo_cooked: base = tabl_lo/hi[x], result = base + get_bits(tabl_bi[x]).
; x = index in, 16 bit result in exo_c_lo/exo_c_hi.
; ---------------------------------------------------------------------------
!zone exo_cooked
exo_cooked
        lda exo_tabl_lo,x
        sta exo_c_lo
        lda exo_tabl_hi,x
        sta exo_c_hi
        lda exo_tabl_bi,x
        tax
        jsr exo_get_bits
        clc
        adc exo_c_lo
        sta exo_c_lo
        lda exo_bits_hi
        adc exo_c_hi
        sta exo_c_hi
        rts

; ---------------------------------------------------------------------------
; exo_init: seed the bit buffer and build the 52 entry decode table (exodec.c
; table_init): a = 1 at each 16 entry boundary, else a += 1 << b, where b is
; the previous entry's 4 bit field. This runs once, before the y = 0 invariant
; the main loop keeps, so it borrows y for the table index and hands it back.
; ---------------------------------------------------------------------------
!zone exo_init
exo_init
        ldy #0
        sty exo_ti
        jsr exo_refill_first
        lda #0
        sta exo_a_lo
        sta exo_a_hi
        sta exo_b
.ei_loop
        lda exo_ti
        and #$0f
        bne .ei_add
        lda #1                  ; boundary: a = 1
        sta exo_a_lo
        lda #0
        sta exo_a_hi
        beq .ei_store           ; always
.ei_add
        lda exo_b               ; a += 1 << b
        jsr exo_shift_add
.ei_store
        ldy exo_ti
        lda exo_a_lo
        sta exo_tabl_lo,y
        lda exo_a_hi
        sta exo_tabl_hi,y
        ldx #4                  ; b = get_bits(4)
        ldy #0                  ; ...which reads the stream, so y must be 0
        jsr exo_get_bits
        sta exo_b
        ldy exo_ti
        sta exo_tabl_bi,y
        iny
        sty exo_ti
        cpy #52
        bne .ei_loop
        ldy #0
        rts

exo_refill_first
        ; The first crunched byte is the bit buffer as it stands, sentinel and
        ; all, rather than a byte to be shifted into place.
        lda (zp_src),y
        inc zp_src
        bne +
        inc zp_src + 1
+       sta exo_bitbuf
        rts

; ---------------------------------------------------------------------------
; exo_shift_add: exo_a += 1 << a, where a (0..15) is the shift count.
; ---------------------------------------------------------------------------
!zone exo_shift_add
exo_shift_add
        tax
        lda #1
        sta exo_t_lo
        lda #0
        sta exo_t_hi
        cpx #0
        beq +
-       asl exo_t_lo
        rol exo_t_hi
        dex
        bne -
+       clc
        lda exo_a_lo
        adc exo_t_lo
        sta exo_a_lo
        lda exo_a_hi
        adc exo_t_hi
        sta exo_a_hi
        rts

; --- the decoder's state ----------------------------------------------------
exo_bitbuf      !byte 0
exo_bits_hi     !byte 0         ; get_bits high byte; the low byte comes back in a
exo_len_lo      !byte 0
exo_len_hi      !byte 0
exo_gamma       !byte 0         ; leading zero bits of the current sequence
exo_a_lo        !byte 0         ; table_init accumulator a
exo_a_hi        !byte 0
exo_b           !byte 0         ; table_init: last 4 bit field
exo_ti          !byte 0         ; table_init index, which borrows y
exo_t_lo        !byte 0         ; scratch: 1 << b
exo_t_hi        !byte 0
exo_c_lo        !byte 0         ; cooked-code result
exo_c_hi        !byte 0
exo_idx         !byte 0         ; offset-table index i, kept across get_bits
exo_table       !fill 156, 0    ; tabl_lo(52), tabl_hi(52), tabl_bi(52)
exo_tabl_lo     = exo_table
exo_tabl_hi     = exo_table + 52
exo_tabl_bi     = exo_table + 104
exo_tabl_bit    !byte 2, 4, 4   ; static bit counts / offsets for lengths 1-3
exo_tabl_off    !byte 48, 32, 16

deexo_end

; It has to fit in the kilobyte make.rb reserves for it at the top of RAM.
!if deexo_end > $c000 {
        !error "the decruncher is ", deexo_end - $c000, " bytes too big"
}
