; replacement for these C64 kernal routines and their variables:
; setcursor $e50c
; printchar $ffd2
; plot      $fff0
; zp_cursorswitch $cc
; zp_screenline $d1
; zp_screencolumn $d3
; zp_screenrow $d6
;
; needed to be able to customize the text scrolling to
; not include status lines, especially big ones used in
; Border Zone, and Nord and Bert.

;TESTSCREEN = 1

screen_h 
    !byte $04,$04,$04,$04,$04
    !byte $04,$04,$05,$05,$05
    !byte $05,$05,$05,$06,$06
    !byte $06,$06,$06,$06,$06
    !byte $07,$07,$07,$07,$07
screen_l 
    !byte $00,$28,$50,$78,$a0
    !byte $c8,$f0,$18,$40,$68
    !byte $90,$b8,$e0,$08,$30
    !byte $58,$80,$a8,$d0,$f8
    !byte $20,$48,$70,$98,$c0

scroll_buffer
    pha
    ldy #3
-   lda screen_l,y
    sta .sl + 4
    lda screen_h,y
    sta .sl + 5
    iny
    lda screen_l,y
    sta .sl + 1
    lda screen_h,y
    sta .sl + 2
    ldx #0
.sl lda $0428,x
    sta $0400,x
    inx
    cpx #40
    bne .sl
    cpy #24
    bne -
    lda #32 ; space
    ldx #0
-   sta $07c0,x
    inx
    cpx #40
    bne -
    pla
    rts

oz_initscreen
    ; init cursor
    lda #10
    sta oz_col
    lda #1
    sta oz_row
    rts

oz_scroll
    lda oz_row
    cmp #25
    bpl +
    rts
    lda #24
    sta oz_row
    rts

oz_printchar
    cmp #$0d
    bne +
    lda #0
    sta oz_col
    inc oz_row
    jmp oz_scroll
+   jsr oz_ascii_to_screen
    pha
    ldy oz_row
    lda screen_h,y
    sta .oz_pc + 2
    lda screen_l,y
    sta .oz_pc + 1
    pla
    ldy oz_col
.oz_pc
    sta $0400,y
    inc oz_col
    lda oz_col
    cmp #40
    bpl +
    rts
+   lda #0
    sta oz_col
    inc oz_row
    jmp oz_scroll

oz_ascii_to_screen
    ; petascii to screen code conversion
    cmp #32
    bpl +
    ora #$80
    rts
+   cmp #64
    bpl +
    rts
+   cmp #96
    bpl +
    and #$bf
    rts
+   cmp #128
    bpl +
    and #$df
    rts
+   cmp #160
    bpl +
    ora #$40
    rts
+   cmp #192
    bpl +
    and #$bf
    rts
+   and #$7f
    rts


oz_row !byte 0
oz_col !byte 0

!ifdef TESTSCREEN {

testtext !pet "hello",13,"johan",0

testscreen
    lda #23 ; 23 upper/lower, 21 = upper/special (22/20 also ok)
    sta $d018 ; reg_screen_char_mode
    jsr oz_initscreen
    lda #$51 ; q
    jsr oz_printchar
    lda #$51 ; q
    jsr oz_printchar
    lda #$0d ; newline
    jsr oz_printchar
    lda #$51 ; q
    jsr oz_printchar
    rts
}

