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

!ifdef TARGET_C128 {
SETBORDERMACRO_DEFINED = 1
!macro SetBorderColour {
	jsr C128SetBorderColour
}
!macro SetBackgroundColour {
	jsr C128SetBackgroundColour
}
}


!ifdef TARGET_PLUS4 {
SETBORDERMACRO_DEFINED = 1
!macro SetBorderColour {
	stx s_stored_x
	pha
	tax
	lda plus4_vic_colours,x
	sta reg_bordercolour
	pla
	ldx s_stored_x
}
!macro SetBackgroundColour {
	stx s_stored_x
	pha
	tax
	lda plus4_vic_colours,x
	sta reg_backgroundcolour
	pla
	ldx s_stored_x
}
}

!ifndef SETBORDERMACRO_DEFINED {
!macro SetBorderColour {
	sta reg_bordercolour
}
!macro SetBackgroundColour {
	sta reg_backgroundcolour
}
}


; colours		!byte 144,5,28,159,156,30,31,158,129,149,150,151,152,153,154,155
zcolours	!byte $ff,$ff ; current/default colour
			!byte COL2,COL3,COL4,COL5  ; black, red, green, yellow
			!byte COL6,COL7,COL8,COL9  ; blue, magenta, cyan, white
darkmode	!byte 0
bgcol		!byte BGCOL, BGCOLDM
fgcol		!byte FGCOL, FGCOLDM
bordercol	!byte BORDERCOL_FINAL, BORDERCOLDM_FINAL
!ifdef USE_INPUTCOL {
inputcol	!byte INPUTCOL, INPUTCOLDM
}
!ifdef Z3 {
statuslinecol !byte STATCOL, STATCOLDM
}
cursorcol !byte CURSORCOL, CURSORCOLDM
current_cursor_colour !byte CURSORCOL
cursor_character !byte CURSORCHAR

!ifdef TARGET_PLUS4 {
plus4_vic_colours
	;     PLUS4  VIC-II
	!byte $00    ; black
	!byte $71  ; white
	!byte $32    ; red
	!byte $63   ; cyan
	!byte $54    ; purple
	!byte $55   ; green
	!byte $36    ; blue
	!byte $77  ; yellow
	!byte $28   ; orange
	!byte $18   ; brown 
	!byte $72   ; light red
	!byte $11   ; dark grey
	!byte $41   ; grey
	!byte $75   ; light green
	!byte $76   ; light blue
	!byte $61   ; light grey
}


!ifdef TARGET_C128 {
!source "vdc.asm"

.stored_a !byte 0
.stored_x_or_y !byte 0

; Mapping between VIC-II and VDC colours
; VDC:
; 00 = dark black
; 01 = light black (dark gray)
; 02 = dark blue
; 03 = light blue
; 04 = dark green
; 05 = light green
; 06 = dark cyan
; 07 = light cyan
; 08 = dark red
; 09 = light red
; 10 = dark purple
; 11 = light purple
; 12 = dark yellow (brown/orange)
; 13 = light yellow
; 14 = dark white (light gray)
; 15 = light white
vdc_vic_colours
	;     VDC    VIC-II
	!byte 0    ; black
	!byte 15   ; white
	!byte 8    ; red
	!byte 7    ; cyan
	!byte 10   ; purple
	!byte 4    ; green
	!byte 3    ; blue
	!byte 13   ; yellow
	!byte 12   ; orange
	!byte 12   ; brown 
	!byte 9    ; light red
	!byte 1    ; dark grey
	!byte 14   ; grey
	!byte 5    ; light green
	!byte 3    ; light blue
	!byte 14   ; light grey

C128SetBackgroundColour
	stx .stored_x_or_y
	ldx COLS_40_80
	beq +
	; 80 columns mode selected
	sta .stored_a
	tax
	lda vdc_vic_colours,x
	ldx #VDC_COLORS
	jsr VDCWriteReg
	lda .stored_a
	jmp ++
+	sta reg_backgroundcolour
++	ldx .stored_x_or_y
	rts

C128SetBorderColour
	stx .stored_x_or_y
	ldx COLS_40_80
	bne + ; no border in VDC, only use background
	; 40 column mode
	sta reg_bordercolour
+	ldx .stored_x_or_y
	rts

VDCGetChar
	; 80 columns, use VDC screen
	sty .stored_x_or_y
	lda zp_screenline + 1
	sec
	sbc #$04 ; adjust from $0400 (VIC-II) to $0000 (VDC)
	tay
	lda zp_screenline
	clc
	adc .stored_x_or_y
	bcc +
	iny
+	jsr VDCSetAddress
	ldy .stored_x_or_y
	ldx #VDC_DATA
	jmp VDCReadReg

VDCPrintChar
	; 80 columns, use VDC screen
	sty .stored_x_or_y
	sta .stored_a
	lda zp_screenline + 1
	sec
	sbc #$04 ; adjust from $0400 (VIC-II) to $0000 (VDC)
	tay
	lda zp_screenline
	clc
	adc .stored_x_or_y
	bcc +
	iny
+	jsr VDCSetAddress
	lda .stored_a
	ldy .stored_x_or_y
	ldx #VDC_DATA
	jmp VDCWriteReg

VDCPrintColour
	; 80 columns, use VDC screen
	sty .stored_x_or_y
	; adjust color from VIC-II to VDC format
	tax
	lda vdc_vic_colours,x
	ora #$80 ; lower-case
	sta .stored_a
	lda zp_colourline + 1
	sec
	sbc #$d0 ; adjust from $d800 (VIC-II) to $0800 (VDC)
	tay
	lda zp_colourline
	clc
	adc .stored_x_or_y
	bcc +
	iny
+	jsr VDCSetAddress
	lda .stored_a
	ldy .stored_x_or_y
	ldx #VDC_DATA
	jmp VDCWriteReg
}

!ifdef TARGET_MEGA65 {
mega65io
	; enable C65GS/VIC-IV IO registers
	;
	; (they will only be active until the first access
	; so mega65io needs to be called before any extended I/O)
	lda #$47
	sta $d02f
	lda #$53
	sta $d02f
	rts

init_mega65
	; MEGA65 IO enable
	jsr mega65io
	; set 40MHz CPU
	lda #65
	sta 0
	; set 80-column mode
	lda #$c0
	sta $d031
	lda #$c9
	sta $D016
	; set screen at $0800
	;lda #$26
	;sta $d018
	; disable VIC-II/VIC-III hot registers
	lda $d05d
	and #$7f
	sta $d05d
	rts
	
colour2k
	; start mapping 2nd KB of colour RAM to $DC00-$DFFF
	sei
	pha
	jsr mega65io
	lda #$01
	sta $d030
	pla
	rts

colour1k
	; stop mapping 2nd KB of colour RAM to $DC00-$DFFF
	pha
	jsr mega65io
	lda #$00
	sta $d030
	pla
	cli
	rts
}

s_screen_width !byte 0
s_screen_height !byte 0
s_screen_width_plus_one !byte 0
s_screen_width_minus_one !byte 0
s_screen_height_minus_one !byte 0
s_screen_size !byte 0, 0

s_init
	; set up screen_width and screen_width_minus_one
!ifdef TARGET_C128 {
	lda #40
	ldx COLS_40_80
	beq +
	; 80 columns mode selected
	lda #80
+
} else {
	lda #SCREEN_WIDTH
}
	sta s_screen_width
	sta s_screen_width_plus_one
	sta s_screen_width_minus_one
	inc s_screen_width_plus_one
	dec s_screen_width_minus_one

	; set up screen_height and screen_width_minus_one
	lda #SCREEN_HEIGHT
	sta s_screen_height
	sta s_screen_height_minus_one
	dec s_screen_height_minus_one

	; calculate total screen size
	lda s_screen_height
	sta multiplier
	lda s_screen_width
	sta multiplicand
	lda #0
	sta multiplier + 1
	sta multiplicand + 1
	jsr mult16
	lda product
	sta s_screen_size;
	lda product + 1
	sta s_screen_size + 1;

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
+	cpx s_screen_height
	bcc +
	ldx s_screen_height_minus_one
+	stx zp_screenrow
	sty zp_screencolumn
	jmp .update_screenpos

s_set_text_colour
	sta s_colour
	rts

s_delete_cursor
	lda #$20 ; blank space
!ifdef TARGET_C128 {
	ldx COLS_40_80
	beq +
	jmp VDCPrintChar
+
}
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
	bcc ++ ; .normal_char
	cmp #$a0
	bcc + ; bcs .normal_char
++	jmp .normal_char
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
	ldy zp_screencolumn
	jsr s_delete_cursor
	dec zp_screencolumn ; move back
	bpl ++
	inc zp_screencolumn ; Go back to 0 if < 0
	lda zp_screenrow
	ldy current_window
	cmp window_start_row + 1,y
	bcc ++
	dec zp_screenrow
	lda s_screen_width_minus_one ; #SCREEN_WIDTH-1
	sta zp_screencolumn
++  jsr .update_screenpos
	lda #$20
	ldy zp_screencolumn
!ifdef TARGET_C128 {
	ldx COLS_40_80
	bne .col80_1
	; 40 columns, use VIC-II screen
	sta (zp_screenline),y
	lda s_colour
	sta (zp_colourline),y
	jmp .col80_1_end
.col80_1
	jsr VDCPrintChar
.col80_1_end
} else {
	sta (zp_screenline),y
	!ifdef TARGET_MEGA65 {
		jsr colour2k
	}
	lda s_colour
	sta (zp_colourline),y
	!ifdef TARGET_MEGA65 {
		jsr colour1k
	}
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
	beq +
	jmp .printchar_end
	; reverse off
+   ldx #0
	stx s_reverse
	bne .normal_char
	jmp .printchar_end ; Always jump
	
.normal_char
	; TODO: perhaps we can remove all testing here and just
	; continue at .resume_printing_normal_char	?
	ldx zp_screencolumn
	bpl +
	; Negative column. Increase column but don't print anything.
	inc zp_screencolumn
-	jmp .printchar_end
+	; Skip if column > SCREEN_WIDTH - 1
	cpx s_screen_width ; #SCREEN_WIDTH
	bcs - ; .printchar_end
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
!ifdef TARGET_C128 {
	ldx COLS_40_80
	bne .col80_2
	; 40 columns, use VIC-II screen
	sta (zp_screenline),y
	lda s_colour
	sta (zp_colourline),y
	jmp .col80_2_end
.col80_2
	jsr VDCPrintChar
	lda s_colour
	jsr VDCPrintColour
.col80_2_end
} else {
	sta (zp_screenline),y
	!ifdef TARGET_MEGA65 {
		jsr colour2k
	}
	lda s_colour
!ifdef TARGET_PLUS4 {
	tax
	lda plus4_vic_colours,x
}
	sta (zp_colourline),y
	!ifdef TARGET_MEGA65 {
		jsr colour1k
	}
}
	iny
	sty zp_screencolumn
	ldx current_window
	bne .printchar_end ; For upper window and statusline (in z3), don't advance to next line.
	cpy s_screen_width ; #SCREEN_WIDTH
	bcc .printchar_end
	dec s_ignore_next_linebreak,x ; Goes from 0 to $ff
	lda #0
	sta zp_screencolumn
	inc zp_screenrow
	lda zp_screenrow
	cmp s_screen_height
	bcs +
	jsr .update_screenpos
	jmp .printchar_end
+
!ifdef TARGET_C128 {
	ldx COLS_40_80
	bne .col80_3
	; 40 columns, use VIC-II screen
	jsr .s_scroll
	jmp .col80_3_end
.col80_3
	jsr .s_scroll_vdc
.col80_3_end
} else {
	jsr .s_scroll
}
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
	bcc +
	sty cursor_row
+	jmp .resume_printing_normal_char ; Always branch
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
!ifdef TARGET_C128 {
	ldx COLS_40_80
	bne .col80_4
	; 40 columns, use VIC-II screen
	jsr .s_scroll
	jmp .col80_4_end
.col80_4
	jsr .s_scroll_vdc
.col80_4_end
} else {
	jsr .s_scroll
}
	jsr .update_screenpos
	jmp .printchar_end

s_erase_window
	lda #0
	sta zp_screenrow
-   jsr s_erase_line
	inc zp_screenrow
	lda zp_screenrow
	cmp s_screen_height
	bne -
	lda #0
	sta zp_screenrow
	sta zp_screencolumn
	rts

.update_screenpos
	; set screenpos (current line) using row
	ldx zp_screenrow
	cpx s_current_screenpos_row
	beq .same_row
	; need to recalculate zp_screenline
	stx s_current_screenpos_row
!ifdef TARGET_MEGA65 {
	; calculate zp_screenline = zp_current_screenpos_row * 40
	; Use MEGA65's hardware multiplier
	jsr mega65io
	stx $d770
	lda #0
	sta $d771
	sta $d772
	sta $d773
	sta $d775
	sta $d776
	sta $d777
	lda s_screen_width ; #SCREEN_WIDTH
	sta $d774
	;
	; add screen offsets
	;
	lda $d778
	sta zp_screenline
	sta zp_colourline
	lda $d779
	and #$07
	clc
	adc #>SCREEN_ADDRESS ; add screen start ($0400 for C64)
	sta zp_screenline+1
	clc
	adc #>COLOUR_ADDRESS_DIFF ; add colour start ($d800 for C64)
	sta zp_colourline+1
} else {
	; calculate zp_screenline = zp_current_screenpos_row * s_screen_width
	stx product + 1
	txa
	asl ; 2x
	asl ; 4x
	adc product + 1 ; 5x
	asl ; 10x
	asl
	ldx #0
	stx product + 1
	rol product + 1 ; 20x
	asl
	rol product + 1 ; 40x
!ifdef TARGET_C128 {
	ldx COLS_40_80
	beq ++
	asl
	rol product + 1
++
}
	sta zp_screenline
	sta zp_colourline
	lda product + 1
	;
	; add screen offsets
	;
	adc #>SCREEN_ADDRESS ; add screen start ($0400 for C64)
	sta zp_screenline +1
	adc #>COLOUR_ADDRESS_DIFF ; add colour start ($d800 for C64)
	sta zp_colourline + 1
}
.same_row
	rts

!ifdef TARGET_C128 {
.s_scroll_vdc
	; scroll routine for 80 column C128 mode, using the blitter
	lda zp_screenrow
	cmp s_screen_height
	bpl +
	rts
+   ; set up copy mode
	ldx #VDC_VSCROLL
	jsr VDCReadReg
	ora #$80 ; set copy bit
	jsr VDCWriteReg
	; scroll characters
	lda #$00
	jsr .s_scroll_vdc_copy
	; scroll colours
	lda #$08
	jsr .s_scroll_vdc_copy
	; prepare for erase line
	sty zp_screenrow
	lda #$ff
	sta s_current_screenpos_row ; force recalculation
	jmp s_erase_line

.s_scroll_vdc_copy
	; input: a = offset (0 for characters, $08 for colours)
	;
	; calculate start position (start_row * screen_width)
	pha
	lda window_start_row + 1 ; how many top lines to protect
	sta multiplier
	lda s_screen_width
	sta multiplicand
	lda #0
	sta multiplier + 1
	sta multiplicand + 1
	jsr mult16
	; set up source and destination
	pla
	clc
	adc product + 1
	tay
	lda product
	jsr VDCSetAddress ; where to copy to (first line)
	clc
	adc s_screen_width
	bcc +
	iny
+	jsr VDCSetCopySourceAddress ; where to copy from (next line)
	; start copying
	ldy window_start_row + 1 ; how many top lines to protect
-	lda #80 ;copy 80 bytes
	ldx #VDC_COUNT
	jsr VDCWriteReg
	iny
	cpy s_screen_height_minus_one
	bne -
	rts
}

.s_scroll
	lda zp_screenrow
	cmp s_screen_height
	bpl +
	rts
+	
!ifdef TARGET_MEGA65 {
	jsr colour2k	
}
	ldx window_start_row + 1 ; how many top lines to protect
	stx zp_screenrow
	inc zp_screenrow
	jsr .update_screenpos
	lda zp_screenline
	sta .scroll_load_screen + 1
	lda zp_screenline + 1
	sta .scroll_load_screen + 2
	lda zp_colourline
	sta .scroll_load_colour + 1
	lda zp_colourline + 1
	sta .scroll_load_colour + 2
	dec zp_screenrow
	jsr .update_screenpos
	lda s_screen_height_minus_one
	sec
	sbc zp_screenrow
	tax
-
	ldy s_screen_width_minus_one
.scroll_load_screen
	lda $8000,y ; This address is modified above
	sta (zp_screenline),y
.scroll_load_colour
	lda $8000,y ; This address is modified above
	sta (zp_colourline),y
	dey
	bpl .scroll_load_screen
	dex
	beq .done_scrolling
	lda zp_screenline
	clc
	adc s_screen_width
	sta zp_screenline
	bcc +
	inc zp_screenline + 1
+		
	lda zp_colourline
	clc
	adc s_screen_width
	sta zp_colourline
	bcc +
	inc zp_colourline + 1
+	
	lda .scroll_load_screen + 1
	clc
	adc s_screen_width
	sta .scroll_load_screen + 1
	bcc +
	inc .scroll_load_screen + 2
+		
	lda .scroll_load_colour + 1
	clc
	adc s_screen_width
	sta .scroll_load_colour + 1
	bcc +
	inc .scroll_load_colour + 2
+	jmp -

.done_scrolling
!ifdef TARGET_MEGA65 {
	jsr colour1k
}
	lda s_screen_height_minus_one
	sta zp_screenrow
	lda #$ff
	sta s_current_screenpos_row ; force recalculation
s_erase_line
	; registers: a,x,y
	lda #0
	sta zp_screencolumn
	jsr .update_screenpos
	ldy #0
.erase_line_from_any_col	
!ifdef TARGET_C128 {
	ldx COLS_40_80
	bne .col80_5
	; 40 columns, use VIC-II screen
-	cpy s_screen_width
	bcs .done_erasing
	lda #$20
	sta (zp_screenline),y
	lda s_colour
	txa
	lda vdc_vic_colours,x
	sta (zp_colourline),y
	iny
	bne - ; Always branch
	jmp .done_erasing	
.col80_5
	; erase line in VDC
	tya
	pha
-	cpy s_screen_width
	bcs +
	lda #$20
	jsr VDCPrintChar
	iny
	bne -
	; also reset attributes/colours
+	pla
	tay
-	cpy s_screen_width
	bcs .done_erasing
	lda s_colour
	jsr VDCPrintColour
	iny
	bne -
} else {
-	cpy s_screen_width
	bcs .done_erasing
	; set character
	lda #$20
	sta (zp_screenline),y
    ; set colour
    !ifdef TARGET_MEGA65 {
        jsr colour2k
    }
!ifdef TARGET_PLUS4 {
	ldx s_colour
	lda plus4_vic_colours,x
} else {
	lda s_colour
}
	sta (zp_colourline),y
    !ifdef TARGET_MEGA65 {
        jsr colour1k
    }
	iny
	bne -
}
.done_erasing	
 	rts
s_erase_line_from_cursor
	jsr .update_screenpos
	ldy zp_screencolumn
	jmp .erase_line_from_any_col


!ifndef NODARKMODE {
toggle_darkmode

; z_temp + 6: New foreground colour, as C64 colour 
; z_temp + 7: New foreground colour, tranformed for target platform
; z_temp + 8: New background colour, adapted to target platform
; z_temp + 9: Old foreground colour, adapted to target platform
; z_temp + 10, 11: Pointer into colour RAM

!ifdef Z5PLUS {
	; We will need the old fg colour later, to check which characters have the default colour
	ldx darkmode ; previous darkmode value (0 or 1)
	ldy fgcol,x
	lda zcolours,y
!ifdef TARGET_C128 {
	ldy COLS_40_80
	beq +
	; 80 columns mode selected
	tay
	lda vdc_vic_colours,y
+
}
!ifdef TARGET_PLUS4 {
	tay
	lda plus4_vic_colours,y
}
	sta z_temp + 9 ; old fg colour
} else { ; This is z3 or z4
!ifdef USE_INPUTCOL {

	; We will need the old input colour later, to check which characters are input text
	ldx darkmode ; previous darkmode value (0 or 1)
	ldy inputcol,x
	lda zcolours,y
!ifdef TARGET_C128 {
	ldy COLS_40_80
	beq +
	; 80 columns mode selected
	tay
	lda vdc_vic_colours,y
+
}
!ifdef TARGET_PLUS4 {
	tay
	lda plus4_vic_colours,y
}
	sta z_temp + 9 ; old input colour

	; If the mode we switch *from* has inputcol = fgcol, make sure inputcol is never matched
	lda inputcol,x
	cmp fgcol,x
	bne +
	inc z_temp + 9
+
} ; USE_INPUTCOL

} ; else (not Z5PLUS)



; Toggle darkmode
	lda darkmode
	eor #1
	sta darkmode
	tax
	
!ifdef USE_INPUTCOL {
	ldy inputcol,x
	lda zcolours,y
!ifdef TARGET_C128 {
	ldy COLS_40_80
	beq +
	; 80 columns mode selected
	tay
	lda vdc_vic_colours,y
+
}
!ifdef TARGET_PLUS4 {
	tay
	lda plus4_vic_colours,y
}
	sta z_temp + 8 ; new input colour

} ; USE_INPUTCOL	
	
; Set fgcolour
	ldy fgcol,x
	lda zcolours,y
	sta z_temp + 6 ; New foreground colour, as C64 colour 
	jsr s_set_text_colour
!ifdef TARGET_C128 {
	ldy COLS_40_80
	beq +
	; 80 columns mode selected
	tay
	lda vdc_vic_colours,y
+
}
!ifdef TARGET_PLUS4 {
	tay
	lda plus4_vic_colours,y
}
	sta z_temp + 7 ; New foreground colour, tranformed for target platform
!ifdef TARGET_MEGA65 {
	jsr colour2k
}
; Set cursor colour
	ldy cursorcol,x
	lda z_temp + 6
	cpy #1
	beq +
	lda zcolours,y
+	sta current_cursor_colour
; Set bgcolour
	ldy bgcol,x
	lda zcolours,y
	+SetBackgroundColour
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
	+SetBorderColour

	; update colour memory with new colours
!ifdef Z3 {

; For Z3: Set statusline colour
	ldy statuslinecol,x
	lda zcolours,y
!ifdef TARGET_C128 {
	ldy COLS_40_80
	beq +
	; 80 columns mode selected
	tay
	lda vdc_vic_colours,y
+
}
!ifdef TARGET_PLUS4 {
	tay
	lda plus4_vic_colours,y
}
	ldy s_screen_width_minus_one
-
!ifdef TARGET_C128 {
	ldx COLS_40_80
	bne +
	sta COLOUR_ADDRESS,y
	jmp ++
+
	; 80 columns mode selected
	sty s_stored_y
	pha
	ldy #$08
	lda s_stored_y
	jsr VDCSetAddress
	pla
	ora #$80 ; lower-case
	ldx #VDC_DATA
	jsr VDCWriteReg
	ldy s_stored_y
++
} else {
	sta COLOUR_ADDRESS,y
}
	dey
	bpl -
}
	;; Work out how many pages of colour RAM to examine
	ldx s_screen_size + 1
	inx
	ldy #>COLOUR_ADDRESS
	sty z_temp + 11
	ldy #0
	sty z_temp + 10
!ifdef Z3 {
	ldy s_screen_width ; Since we have coloured the statusline separately, skip it now
}
!ifndef Z5PLUS {
;	ldy #0 ; But y is already 0, so we skip this
	lda z_temp + 7 ; For Z3 and Z4 we can just load this value before the loop  
}
.compare
!ifdef TARGET_C128 {
	lda z_temp + 7  ; too much work to read old colour from VDC
	bit COLS_40_80
	bmi .toggle_80
} ; else {
!ifdef Z5PLUS {
	lda (z_temp + 10),y
!ifndef TARGET_PLUS4 {
	and #$0f
}
	cmp z_temp + 9
	beq .change
	cmp z_temp + 8
	bne .dont_change
.change	
	lda z_temp + 7
}

!ifdef USE_INPUTCOL {
	lda (z_temp + 10),y
!ifndef TARGET_PLUS4 {
	and #$0f
}
	cmp z_temp + 9
	bne .change
	lda z_temp + 8
	bne + ; Always branch
.change	
	lda z_temp + 7
+
}

.toggle_80

; }
!ifdef TARGET_C128 {
	pha
	lda COLS_40_80
	bne +
	pla
	sta (z_temp + 10),y
	jmp ++
+
	; 80 columns mode selected
	stx s_stored_x
	sty s_stored_y
	lda z_temp + 11
	sec
	sbc #$d0 ; adjust from $d800 (VIC-II) to $0800 (VDC)
	tay
	lda z_temp + 10
	clc
	adc s_stored_y
	bcc +
	iny
+	jsr VDCSetAddress
	pla
	ora #$80 ; lower-case
	ldy s_stored_y
	ldx #VDC_DATA
	jsr VDCWriteReg
	ldx s_stored_x
++
} else {
	sta (z_temp + 10),y
}
.dont_change
	iny
	bne .compare
	inc z_temp + 11
	dex
	bne .compare
!ifdef TARGET_MEGA65 {
	jsr colour1k
}

!ifdef USE_INPUTCOL {
	; Switch to the new input colour, if input colour is active (we could be at a MORE prompt or in a timed input)
	lda input_colour_active
	beq +
	jsr activate_inputcol
	ldx darkmode
+
}
	jmp update_cursor
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
	ldy #header_default_bg_colour
	jsr read_header_word
	lda zcolours,x
+   
	+SetBackgroundColour
; Also set bordercolour to same as background colour, if bordercolour is set to the magic value 0
	cpy #0
	bne .current_background
	+SetBorderColour
.current_background

; Set foreground colour
	ldx z_operand_value_low_arr
	beq .current_foreground
	lda zcolours,x
	bpl + ; Branch unless it's the special value $ff, which means "default colour"
	ldy #header_default_fg_colour
	jsr read_header_word
	lda zcolours,x
+
; Also set bordercolour to same as foreground colour, if bordercolour is set to the magic value 1
	cpy #1
	bne +
	+SetBorderColour
+
	jsr s_set_text_colour ; change foreground colour
.current_foreground

; Set cursor colour
	lda s_colour
	ldx darkmode
	ldy cursorcol,x
	cpy #1
	beq +
	lda zcolours,y
+	sta current_cursor_colour

	rts
}

!ifdef TESTSCREEN {

.testtext
	!pet 2, 5,147,18,"Status Line 123         ",146,13    ; white REV
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

