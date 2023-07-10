!zone splash_screen {
splash_screen
	ldy #0
	sty z_temp ; String number currently printing
splash_line_y
	ldx splash_index_line,y
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
	lda ti_variable + 2
	clc
	adc #<(SPLASHWAIT*60)
	sta z_temp + 2
	lda ti_variable + 1
	adc #>(SPLASHWAIT*60)
	sta z_temp + 1	
	
-	jsr kernal_getchar
!ifndef NODARKMODE {
	tay
}
	cmp #0
	bne +
	ldx z_temp + 2
	cpx ti_variable + 2
	beq ++
	inx
	cpx ti_variable + 2
	bne -
++	lda z_temp + 1
	cmp ti_variable + 1
	bne -
+
!ifndef NODARKMODE {
	; sty SCREEN_ADDRESS
; -
	; jmp -
	cpy #$85
	bne +
	jsr toggle_darkmode
	jmp .restart_timer
+
}
	lda #147
	jmp s_printchar

!source "splashlines.asm"

splash_index_line
	!byte 2, 4, 6, 8, 20, 22, 23, 24
splash_index_lb
	!byte <splashline0, <splashline1, <splashline2, <splashline3, <splashline4, <splashline5, <splashline6, <splashline7
splash_index_hb
	!byte >splashline0, >splashline1, >splashline2, >splashline3, >splashline4, >splashline5, >splashline6, >splashline7
}	
