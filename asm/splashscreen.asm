!zone splash_screen {
splash_screen
	ldy #0
	sty z_temp ; String number currently printing
splash_line_y
	ldx splash_index_line,y
	lda splash_index_col,y
!ifdef TARGET_C128 {
	ldy COLS_40_80
	beq +
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
	cpy #5
	bne splash_line_y

	lda ti_variable + 2
	clc
	adc #<(SPLASHWAIT*60)
	sta z_temp + 2
	lda ti_variable + 1
	adc #>(SPLASHWAIT*60)
	sta z_temp + 1
	
-	jsr kernal_getchar
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
	lda #147
	jmp s_printchar

!source "splashlines.asm"

splash_index_line
	!byte 4, 6, 8, 10, 24
splash_index_lb
	!byte <splashline0, <splashline1, <splashline2, <splashline3, <splashline4
splash_index_hb
	!byte >splashline0, >splashline1, >splashline2, >splashline3, >splashline4
}	
