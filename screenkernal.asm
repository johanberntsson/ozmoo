; replacement for these C64 kernal routines and their variables:
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

;TESTSCREEN = 1

ASSERTCHAR = 1

!zone screenkernal {
s_init
    ; init cursor
    lda #0
    sta .col
    sta .row
    sta .reverse
    lda #$ff
    sta .current_screenpos_row ; force recalculation first time
    ldx #1
    stx s_scrollstart ; how many top lines to protect
    rts

s_plot
    jmp kernel_plot
    ; y=column (0-39)
    ; x=row (0-24)
    bcc +
    ; get_cursor
    ldx .row
    ldy .col
    rts
+   ; set_cursor
    stx .row
    sty .col
    rts

s_printchar
!ifdef ASSERTCHAR {
    sta $de01
    sta $de02
}
    jmp $ffd2
    ; replacement for CHROUT ($ffd2)
    ; input: A = byte to write (PETASCII)
    ; output: -
    ; used registers: -
    stx .stored_x
    sty .stored_y
    ; check if colour code
    ldx #0
-   cmp .colors,x
    bne +
    ; color <x> found
    stx .color
    jmp .printchar_end
+   inx
    cpx #16
    bne -
    cmp #20
    bne +
    ; delete
    dec .col ; move back
    bpl ++
    inc .col ; return to 0 if < 0
++  jmp .printchar_end
+   cmp #$0d
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
+   cmp #146 ; $92
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
!ifdef ASSERTCHAR {
    cmp #$20
    bpl +
    sta $de01 ; < $20 (control chars)
    sta $de02
+   cmp #$7a
    bcc +
    sta $de01 ; > $7a (control chars)
    sta $de02
+
}
    cmp #$40
    bcc ++    ; no change if numbers or special chars
    cmp #$60
    bpl +
    sec
    sbc #64
    bne ++ ; always jump
+   cmp #$80
    bpl +
    sec
    sbc #32
    bne ++ ; always jump
+   sec
    sbc #128
++  ; print the char
;    and .reverse
    pha
    jsr .update_screenpos
    lda s_screenpos
    sta s_screencol
    lda s_screenpos + 1
    clc
    adc #$d4
    sta s_screencol + 1
    ldy .col
    pla
    sta (s_screenpos),y
    lda .color
    sta (s_screencol),y
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
    ; need to recalculate s_screenpos
    stx .current_screenpos_row
    stx s_screenpos
    ; use the fact that .row * 40 = .row * (32+8)
    lda #0
    sta s_screenpos + 1
    asl s_screenpos ; *2 no need to rol s_screenpos + 1 since 0 < .row < 24
    asl s_screenpos ; *4
    asl s_screenpos ; *8
    ldx s_screenpos ; store *8 for later
    asl s_screenpos ; *16
    rol s_screenpos + 1
    asl s_screenpos ; *32
    rol s_screenpos + 1  ; *32
    txa
    clc
    adc s_screenpos ; add *8
    sta s_screenpos
    lda s_screenpos + 1
    adc #$04        ; add screen start ($0400)
    sta s_screenpos +1
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

.s_scroll
    lda .row
    cmp #25
    bpl +
    rts
+   ldx s_scrollstart ; how many top lines to protect
    stx .row
-   jsr .update_screenpos
    lda s_screenpos
    sta s_screencol
    lda s_screenpos + 1
    sta s_screencol + 1
    inc .row
    jsr .update_screenpos
    ; move characters
    ldy #0
--  lda (s_screenpos),y ; .row
    sta (s_screencol),y ; .row - 1
    iny
    cpy #40
    bne --
    ; move color info
    lda s_screenpos + 1
    pha
    clc
    adc #$d4
    sta s_screenpos + 1
    lda s_screencol + 1
    clc
    adc #$d4
    sta s_screencol + 1
    ldy #0
--  lda (s_screenpos),y ; .row
    sta (s_screencol),y ; .row - 1
    iny
    cpy #40
    bne --
    pla
    sta s_screenpos + 1
    lda .row
    cmp #24
    bne -
    jmp .erase_line

.row !byte 0
.col !byte 0
.color !byte 254 ; light blue as default
.reverse !byte 0
.stored_x !byte 0
.stored_y !byte 0
.current_screenpos_row !byte $ff
.colors !byte 144,5,28,159,156,30,31,158,129,149,150,151,152,153,154,155

!ifdef TESTSCREEN {

.testtext !pet 147,146,5,"Status Line 123         ",18,13
          !pet 28,"tesx",20,"t aA@! ",146,"Test aA@!",18,13
          !pet 155,"third line",13
          !pet "fourth line",13
          !pet 13,13,13,13,13,13
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

