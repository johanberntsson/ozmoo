; replacement for these C64 kernal routines and their variables:
; printchar $ffd2
; plot      $fff0
; zp_cursorswitch $cc
; zp_screenline $d1-$d2
; zp_screencolumn $d3
; zp_screenrow $d6
; zp_colourline $f3-$f4
;
; needed to be able to customize the text scrolling to
; not include status lines, especially big ones used in
; Border Zone, and Nord and Bert.
;
; usage: first call s_init, then replace
; $ffd2 with s_printchar and so on.
; s_scrollstart is set to the number of top lines to keep when scrolling
;
; Uncomment TESTSCREEN and call testscreen for a demo.

;TESTSCREEN = 1

!zone screenkernal {

!ifdef TARGET_MEGA65 {
mega65io
	lda #$47
	sta $d02f
	lda #$53
	sta $d02f
	rts
	
colour2k
	sei
	pha
        jsr mega65io
	lda #$01
	sta $d030
	pla
	rts

colour1k
	pha
        jsr mega65io
	lda #$00
	sta $d030
	pla
	cli
	rts
}

s_init
    ; init cursor
    lda #$ff
    sta s_current_screenpos_row ; force recalculation first time
    lda #0
    sta zp_screencolumn
    sta zp_screenrow
	; Set to 0: s_ignore_next_linebreak, s_reverse
    ldx #3
-	sta s_ignore_next_linebreak,x
	dex
	bpl -
    rts

s_plot
    ; y=column (0-(SCREEN_WIDTH-1))
    ; x=row (0- (SCREEN_HEIGHT-1))
    bcc .set_cursor_pos
    ; get_cursor
    ldx zp_screenrow
    ldy zp_screencolumn
    rts
.set_cursor_pos
+	cpx #SCREEN_HEIGHT
	bcc +
	ldx #SCREEN_HEIGHT-1
+	stx zp_screenrow
	sty zp_screencolumn
	jmp .update_screenpos

s_set_text_colour
	sta s_colour
	rts

s_delete_cursor
	lda #$20 ; blank space
	ldy zp_screencolumn
	sta (zp_screenline),y
	rts

s_printchar
    ; replacement for CHROUT ($ffd2)
    ; input: A = byte to write (PETASCII)
    ; output: -
    ; used registers: -
    stx s_stored_x
    sty s_stored_y

	; Fastlane for the most common characters
	cmp #$20
	bcc +
	cmp #$80
	bcc .normal_char
	cmp #$a0
	bcs .normal_char
+	
	cmp #$0d
    bne +
	; newline
	; but first, check if the current character is the cursor so that we may delete it
	lda cursor_character
	ldy zp_screencolumn
	cmp (zp_screenline),y
	bne +++
	jsr s_delete_cursor
+++	jmp .perform_newline
+   
    cmp #20
    bne +
    ; delete
    jsr s_delete_cursor
    dec zp_screencolumn ; move back
    bpl ++
	inc zp_screencolumn ; Go back to 0 if < 0
	lda zp_screenrow
	ldy current_window
	cmp window_start_row + 1,y
	bcc ++
	dec zp_screenrow
	lda #SCREEN_WIDTH-1
	sta zp_screencolumn
++  jsr .update_screenpos
    lda #$20
    ldy zp_screencolumn
    sta (zp_screenline),y
!ifdef TARGET_MEGA65 {
    jsr colour2k
}
    lda s_colour
    sta (zp_colourline),y
!ifdef TARGET_MEGA65 {
    jsr colour1k
}
    jmp .printchar_end
+   cmp #$93 
    bne +
    ; clr (clear screen)
    lda #0
    sta zp_screencolumn
    sta zp_screenrow
    jsr s_erase_window
    jmp .printchar_end
+   cmp #$12 ; 18
    bne +
    ; reverse on
    ldx #$80
    stx s_reverse
    jmp .printchar_end
+   cmp #$92 ; 146
    bne .printchar_end
    ; reverse off
    ldx #0
    stx s_reverse
    beq .printchar_end ; Always jump
; +
	; ; check if colour code
	; ldx #15
; -	cmp colours,x
	; beq ++
	; dex
	; bpl -
	; bmi .printchar_end ; Always branch
; ++	; colour <x> found
	; stx s_colour
	; beq .printchar_end ; Always jump
	
.normal_char
	ldx zp_screencolumn
	bpl +
	; Negative column. Increase column but don't print anything.
	inc zp_screencolumn
	jmp .printchar_end
+	; Skip if column > SCREEN_WIDTH - 1
	cpx #SCREEN_WIDTH
	bcs .printchar_end
	; Reset ignore next linebreak setting
	ldx current_window
	ldy s_ignore_next_linebreak,x
	bpl +
	inc s_ignore_next_linebreak,x
	; Check if statusline is overflowing TODO: Do we really need to check any more?
+	pha
	lda zp_screenrow
	ldy current_window 
	cmp window_start_row,y
	pla ; Doesn't affect C
	bcs .outside_current_window
.resume_printing_normal_char	
   ; convert from pet ascii to screen code
	cmp #$40
	bcc ++    ; no change if numbers or special chars
	cmp #$60
	bcs +
	and #%00111111
	bcc ++ ; always jump
+   cmp #$80
    bcs +
	and #%11011111
    bcc ++ ; always jump
+	cmp #$c0
	bcs +
	eor #%11000000
+	and #%01111111
++  ; print the char
    clc
    adc s_reverse
    pha
    jsr .update_screenpos
    pla
    ldy zp_screencolumn
    sta (zp_screenline),y
!ifdef TARGET_MEGA65 {
    jsr colour2k
}
    lda s_colour
    sta (zp_colourline),y
!ifdef TARGET_MEGA65 {
    jsr colour1k
}
    iny
    sty zp_screencolumn
	ldx current_window
	bne .printchar_end ; For upper window and statusline (in z3), don't advance to next line.
    cpy #SCREEN_WIDTH
    bcc .printchar_end
	dec s_ignore_next_linebreak,x ; Goes from 0 to $ff
    lda #0
    sta zp_screencolumn
    inc zp_screenrow
	lda zp_screenrow
	cmp #SCREEN_HEIGHT
	bcs +
	jsr .update_screenpos
	jmp .printchar_end
+	jsr .s_scroll
.printchar_end
    ldx s_stored_x
    ldy s_stored_y
    rts

.outside_current_window
!ifdef Z4 {
	jmp .printchar_end
} else {
	cpy #1
	bne .printchar_end
	; This is window 1. Expand it if possible.
	ldy zp_screenrow
	cpy window_start_row ; Compare to end of screen (window 0)
	bcs .printchar_end
	iny
	sty window_start_row + 1
	; Move lower window cursor if it gets hidden by upper window
	cpy cursor_row
	bcc .resume_printing_normal_char
	sty cursor_row
	bcs .resume_printing_normal_char ; Always branch
}

.perform_newline
    ; newline/enter/return
	; Check ignore next linebreak setting
	ldx current_window
	ldy s_ignore_next_linebreak,x
	bpl +
	inc s_ignore_next_linebreak,x
	jmp .printchar_end
+	lda #0
    sta zp_screencolumn
    inc zp_screenrow
    jsr .s_scroll
    jsr .update_screenpos
    jmp .printchar_end

s_erase_window
    lda #0
    sta zp_screenrow
-   jsr s_erase_line
    inc zp_screenrow
    lda zp_screenrow
    cmp #SCREEN_HEIGHT
    bne -
    lda #0
    sta zp_screenrow
    sta zp_screencolumn
    rts

.update_screenpos
    ; set screenpos (current line) using row
    ldx zp_screenrow
    cpx s_current_screenpos_row
    beq +
    ; need to recalculate zp_screenline
    stx s_current_screenpos_row
!if SCREEN_WIDTH = 40 {
    ; use the fact that zp_screenrow * 40 = zp_screenrow * (32+8)
    lda #0
    sta zp_screenline + 1
	txa
    asl; *2 no need to rol zp_screenline + 1 since 0 < zp_screenrow < 24
    asl; *4
    asl; *8
    sta zp_colourline ; store *8 for later
    asl; *16
    rol zp_screenline + 1
    asl; *32
    rol zp_screenline + 1  ; *32
    clc
    adc zp_colourline ; add *8
    sta zp_screenline
    sta zp_colourline
    lda zp_screenline + 1
    adc #>SCREEN_ADDRESS ; add screen start ($0400 for C64)
    sta zp_screenline +1
    adc #>COLOUR_ADDRESS_DIFF ; add colour start ($d800)
    sta zp_colourline + 1
}
!ifdef TARGET_MEGA65 {
    ;; Use MEGA65's hardware multiplier
    jsr mega65io
    stx $d770
    lda #0
    sta $d771
    sta $d772
    sta $d773
    sta $d775
    sta $d776
    sta $d777
    lda #SCREEN_WIDTH
    sta $d774

    lda $d778
    sta zp_screenline
    sta zp_colourline
    lda $d779
    and #$07
    clc
    adc #>SCREEN_ADDRESS
    sta zp_screenline+1
    clc
;    adc #>($D800 - SCREEN_ADDRESS)
    adc #>COLOUR_ADDRESS_DIFF
    sta zp_colourline+1
}
+   rts

.s_scroll
    lda zp_screenrow
    cmp #SCREEN_HEIGHT
    bpl +
    rts
+   ldx window_start_row + 1 ; how many top lines to protect
    stx zp_screenrow
-   jsr .update_screenpos
    lda zp_screenline
    pha
    lda zp_screenline + 1
    pha
    inc zp_screenrow
    jsr .update_screenpos
    pla
    sta zp_colourline + 1
    pla
    sta zp_colourline
    ; move characters
    ldy #SCREEN_WIDTH-1
--
!ifdef TARGET_MEGA65 {
    jsr colour2k	
}
    lda (zp_screenline),y ; zp_screenrow
    sta (zp_colourline),y ; zp_screenrow - 1
    dey
    bpl --
!ifdef TARGET_MEGA65 {
    jsr colour1k
}
    ; move colour info
    lda zp_screenline + 1
    pha
    clc
;    adc #>($D800 - SCREEN_ADDRESS)
    adc #>COLOUR_ADDRESS_DIFF
    sta zp_screenline + 1
    lda zp_colourline + 1
    clc
;    adc #>($D800 - SCREEN_ADDRESS)
    adc #>COLOUR_ADDRESS_DIFF
    sta zp_colourline + 1
    ldy #SCREEN_WIDTH-1
--
!ifdef TARGET_MEGA65 {
    jsr colour2k
}
    lda (zp_screenline),y ; zp_screenrow
    sta (zp_colourline),y ; zp_screenrow - 1
    dey
    bpl --
!ifdef TARGET_MEGA65 {
    jsr colour1k
}
    pla
    sta zp_screenline + 1
    lda zp_screenrow
    cmp #24
    bne -
    lda #$ff
    sta s_current_screenpos_row ; force recalculation
s_erase_line
	; registers: a,x,y
	lda #0
	sta zp_screencolumn
	jsr .update_screenpos
	ldy #0
.erase_line_from_any_col	
	lda #$20
-	cpy #SCREEN_WIDTH
	bcs .done_erasing
	sta (zp_screenline),y
	iny
	bne -
.done_erasing	
 	rts
s_erase_line_from_cursor
	jsr .update_screenpos
	ldy zp_screencolumn
	jmp .erase_line_from_any_col


; colours		!byte 144,5,28,159,156,30,31,158,129,149,150,151,152,153,154,155
zcolours	!byte $ff,$ff ; current/default colour
			!byte COL2,COL3,COL4,COL5  ; black, red, green, yellow
			!byte COL6,COL7,COL8,COL9  ; blue, magenta, cyan, white
darkmode	!byte 0
bgcol		!byte BGCOL, BGCOLDM
fgcol		!byte FGCOL, FGCOLDM
bordercol	!byte BORDERCOL_FINAL, BORDERCOLDM_FINAL
!ifdef Z3 {
statuslinecol !byte STATCOL, STATCOLDM
}
cursorcol !byte CURSORCOL, CURSORCOLDM
current_cursor_colour !byte CURSORCOL
cursor_character !byte CURSORCHAR

!ifndef NODARKMODE {
toggle_darkmode
!ifdef Z5PLUS {
	; We will need the old fg colour later, to check which characters have the default colour
	ldx darkmode ; previous darkmode value (0 or 1)
	ldy fgcol,x
	lda zcolours,y
	sta z_temp + 9 ; old fg colour
}
; Toggle darkmode
	lda darkmode
	eor #1
	sta darkmode
	tax
; Set cursor colour
	ldy cursorcol,x
	lda zcolours,y
	sta current_cursor_colour
; Set bgcolor
	ldy bgcol,x
	lda zcolours,y
	sta reg_backgroundcolour
!ifdef Z5PLUS {
	; We will need the new bg colour later, to check which characters would become invisible if left unchanged
	sta z_temp + 8 ; new background colour
}
; Set border colour 
	ldy bordercol,x
!ifdef BORDER_MAY_FOLLOW_BG {
	beq .store_bordercol
}
!ifdef BORDER_MAY_FOLLOW_FG {
	cpy #1
	bne +
	ldy fgcol,x
+	
}
	lda zcolours,y
.store_bordercol
	sta reg_bordercolour
!ifdef Z3 {
; Set statusline colour
	ldy statuslinecol,x
	lda zcolours,y
	ldy #SCREEN_WIDTH-1
-	sta $d800,y
	dey
	bpl -
}
; Set fgcolour
	ldy fgcol,x
	lda zcolours,y
	jsr s_set_text_colour
!ifdef TARGET_MEGA65 {
	jsr colour2k
}
	;; Work out how many pages of colour RAM to examine
	ldx #1+>(SCREEN_WIDTH*SCREEN_HEIGHT)
	ldy #>$D800
	sty z_temp + 11
	ldy #0
	sty z_temp + 10
!ifdef Z3 {
	ldy #SCREEN_WIDTH
}
!ifdef Z5PLUS {
	sta z_temp + 7
}
.compare
!ifdef Z5PLUS {
	lda (z_temp + 10),y
	and #$0f
	cmp z_temp + 9
	beq .change
	cmp z_temp + 8
	bne .dont_change
.change	
	lda z_temp + 7
}
	sta (z_temp + 10),y
.dont_change
	iny
	bne .compare
	inc z_temp + 11
	dex
	bne .compare
!ifdef TARGET_MEGA65 {
	jsr colour1k
}
	jsr update_cursor
	rts 
} ; ifndef NODARKMODE

!ifdef Z5PLUS {
z_ins_set_colour
    ; set_colour foreground background [window]
    ; (window is not used in Ozmoo)
	jsr printchar_flush

; Load y with bordercol (needed later)
	ldx darkmode
	ldy bordercol,x

; Set background colour
    ldx z_operand_value_low_arr + 1
	beq .current_background
    lda zcolours,x
    bpl +
    ldx story_start + header_default_bg_colour ; default colour
    lda zcolours,x
+   sta reg_backgroundcolour
; Also set bordercolour to same as background colour, if bordercolour is set to the magic value 0
	cpy #0
	bne .current_background
	sta reg_bordercolour
.current_background

; Set foreground colour
    ldx z_operand_value_low_arr
	beq .current_foreground
    lda zcolours,x
    bpl + ; Branch unless it's the special value $ff, which means "default colour"
    ldx story_start + header_default_fg_colour ; default colour
    lda zcolours,x
+
; Also set bordercolour to same as foreground colour, if bordercolour is set to the magic value 1
	cpy #1
	bne +
	sta reg_bordercolour
+
    jsr s_set_text_colour ; change foreground colour
.current_foreground
    rts
}

!ifdef TESTSCREEN {

.testtext !pet 2, 5,147,18,"Status Line 123         ",146,13    ; white REV
          !pet 3, 28,"tesx",20,"t aA@! ",18,"Test aA@!",146,13  ; red
          !pet 155,"third",20,13                                ; light gray
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
    jsr init_screen_colours
!ifdef TARGET_PLUS4 {
    lda #212 ; 212 upper/lower, 208 = upper/special
} else {
    lda #23 ; 23 upper/lower, 21 = upper/special (22/20 also ok)
}
    sta reg_screen_char_mode
    jsr s_init
    ;lda #1
    ;sta s_scrollstart
    lda #25
    sta window_start_row ; 25 lines in window 0
    lda #1
    sta window_start_row + 1 ; 1 status line
    sta window_start_row + 2 ; 1 status line
    lda #0
    sta window_start_row + 3
    ldx #0
-   lda .testtext,x
    bne +
    rts
+   cmp #2
    bne +
    ; use upper window
    lda #1
	sta current_window
	jmp ++
+   cmp #3
    bne +
    ; use lower window
    lda #0
	sta current_window
	jmp ++
+   cmp #1
    bne +
    txa
    pha
--  jsr kernal_getchar
    beq --
    pla
    tax
    bne ++
    ; NOTE: s_printchar no longer recognizes the colour codes, so the
    ; colours will not change. But rev on/off still works
+   jsr s_printchar
++  inx
    bne -
}
}

