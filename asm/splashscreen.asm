!zone splash_screen {

!ifdef TARGET_X16 {
x16_switch_to_mode_and_clear_screen
;	pha
	; lda #1
	; jsr kernal_printchar
	; ldx darkmode
	; lda bgcol,x
	; tax
	; lda zcolours,x
	; tax
	; lda colour_petscii,x
	; jsr kernal_printchar
	; lda #1
	; jsr kernal_printchar
;	pla
	clc
	jsr $ff5f
	jsr s_init
	+init_screen_model
	ldx #0
	ldy #0
	jmp set_cursor
	; lda #147
	; jmp s_printchar
}


splash_screen
!ifdef TARGET_X16 {
	lda s_x16_screen_mode
	pha
	lda #3
	jsr x16_switch_to_mode_and_clear_screen
}
	ldy #0
	sty z_temp ; String number currently printing
splash_line_y
	ldx splash_index_line,y
!ifdef TARGET_X16 {
	cpx #20
	bcc +
	inx
	inx
	inx
	inx
+
}
	
	lda splash_index_col,y
!ifdef TARGET_C128 {
	bit COLS_40_80
	bpl +
	clc
	adc #20
+
}
!ifdef TARGET_MEGA65 {
	clc
	adc #20
}
	tay
	jsr set_cursor
	ldy z_temp
	ldx splash_index_lb,y
	lda splash_index_hb,y
	jsr printstring_raw
	inc z_temp
	ldy z_temp
	cpy #8
	bne splash_line_y

.restart_timer
!ifdef TARGET_X16 {
	lda #0
	sta 0 ; Bank in timer
}
	lda #<($10000-SPLASHWAIT*60)
	sta z_temp + 1
	lda #>($10000-SPLASHWAIT*60)
	sta z_temp + 2
	; lda ti_variable + 2
	; clc
	; adc #<(SPLASHWAIT*60)
	; sta z_temp + 2
	; lda ti_variable + 1
	; adc #>(SPLASHWAIT*60)
	; sta z_temp + 1	

-	jsr kernal_getchar
; !ifndef NODARKMODE {
	; tay
; }
	cmp #0
	bne +
	jsr wait_a_jiffy
	inc z_temp + 1
	bne -
	inc z_temp + 2
	bne -
+
!ifndef NODARKMODE {
	cmp #$85
	bne .exit_splash
	jsr toggle_darkmode
	jmp .restart_timer
}
.exit_splash
!ifdef TARGET_X16 {
	pla
	jmp x16_switch_to_mode_and_clear_screen
} else {
	lda #147
	jmp s_printchar
}

!source "splashlines.asm"

splash_index_line
	!byte 2, 4, 6, 8, 20, 22, 23, 24
splash_index_lb
	!byte <splashline0, <splashline1, <splashline2, <splashline3, <splashline4, <splashline5, <splashline6, <splashline7
splash_index_hb
	!byte >splashline0, >splashline1, >splashline2, >splashline3, >splashline4, >splashline5, >splashline6, >splashline7
}	
