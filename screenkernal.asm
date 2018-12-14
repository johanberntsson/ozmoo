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
;
; usage: first call s_init, then replace
; $ffd2 with s_printchar and so on.
; Uncomment TESTSCREEN and call testscreen for a demo.

s_screenpos = $c9 ; c9/ca = pointer to screen

;TESTSCREEN = 1

!zone screenkernal {
s_init
    ; init cursor
    lda #0
    sta .col
    sta .row
    sta .reverse
    lda #$ff
    sta .current_screenpos_row ; force recalculation first time
    rts

s_printchar
    ; replacement for CHROUT ($ffd2)
    ; input: A = byte to write (PETASCII)
    ; output: -
    ; used registers: -
    stx .stored_x
    sty .stored_y
    cmp #$0d
    bne +
    ; newline/enter/return
    lda #0
    sta .col
    inc .row
    jsr .s_scroll
    jmp .printchar_end
+   cmp #$93 
    bne +
    ; clr (clear screen)
    lda #0
    sta .col
    sta .row
    jsr .erase_window
    jmp .printchar_end
+   cmp #146
    bne +
    ; reverse on
    lda #128
    sta .reverse
    jmp .printchar_end
+   cmp #18
    bne +
    ; reverse off
    lda #0
    sta .reverse
    jmp .printchar_end
+   ; covert from pet ascii to screen code
    cmp #$40
    bcc ++    ; no change if numbers or special chars
    cmp #$60
    bcc +
    ; upper case letters (A - Z)
    sec
    sbc #128
    bne ++
+   ; lower case letters (a - z)
    sec
    sbc #64
++  ; print the char
    clc
    adc .reverse
    pha
    jsr .update_screenpos
    ldy .col
    pla
    sta (s_screenpos),y
    iny
    sty .col
    cpy #40
    bcc .printchar_end
    lda #0
    sta .col
    inc .row
    jsr .s_scroll
.printchar_end
    ldx .stored_x
    ldy .stored_y
    rts

.update_screenpos
    ; set screenpos (current line) using row
    ldx .row
    cpx .current_screenpos_row
    beq +
    stx .current_screenpos_row
-   lda .screen_l,x
    sta s_screenpos
    lda .screen_h,x
    sta s_screenpos + 1
+   rts

.erase_line
    lda #0
    sta .col
    jsr .update_screenpos
    ldy #0
    lda #$20
-   sta (s_screenpos),y
    iny
    cpy #40
    bne -
    rts
    
.erase_window
    lda #0
    sta .row
-   jsr .erase_line
    inc .row
    lda .row
    cmp #25
    bne -
    lda #0
    sta .row
    sta .col
    rts

.scroll_buffer
    rts

.s_scroll
    lda .row
    cmp #25
    bpl +
    rts
+   ldy #1 ; how many top lines to protect
-   lda .screen_l,y
    sta .sl + 4
    lda .screen_h,y
    sta .sl + 5
    iny
    lda .screen_l,y
    sta .sl + 1
    lda .screen_h,y
    sta .sl + 2
    ldx #0
.sl lda $0428,x
    sta $0400,x
    inx
    cpx #40
    bne .sl
    cpy #24
    bne -
    sty .row
    jmp .erase_line

.row !byte 0
.col !byte 0
.reverse !byte 0
.stored_x !byte 0
.stored_y !byte 0
.current_screenpos_row !byte 0

.screen_h 
    !byte $04,$04,$04,$04,$04
    !byte $04,$04,$05,$05,$05
    !byte $05,$05,$05,$06,$06
    !byte $06,$06,$06,$06,$06
    !byte $07,$07,$07,$07,$07
.screen_l 
    !byte $00,$28,$50,$78,$a0
    !byte $c8,$f0,$18,$40,$68
    !byte $90,$b8,$e0,$08,$30
    !byte $58,$80,$a8,$d0,$f8
    !byte $20,$48,$70,$98,$c0

!ifdef TESTSCREEN {

.testtext !pet 147,146,"Status Line 123         ",18,13
          !pet "test aA@! ",146,"Test aA@!",18,13
          !pet "third line",13
          !pet 13,13,13,13,13,13,13
          !pet 13,13,13,13,13,13,13
          !pet 13,13,13,13,13,13,13
          !pet "last line",1
          !pet "aaaaaaaaabbbbbbbbbbbcccccccccc",1
          !pet "d",1 ; last char on screen
          !pet "efg",1 ; should scroll here and put efg on new line
          !pet 13,"h",1; should scroll again and f is on new line
          !pet 0

testscreen
    lda #23 ; 23 upper/lower, 21 = upper/special (22/20 also ok)
    sta $d018 ; reg_screen_char_mode
    jsr s_init
    ldx #0
-   lda .testtext,x
    bne +
    rts
+   cmp #1
    bne +
    txa
    pha
--  jsr kernel_getchar
    beq --
    pla
    tax
    bne ++
+   jsr s_printchar
++  inx
    bne -
}
}

