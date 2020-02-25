!zone splash_screen {
splash_screen
	ldy #0
	sty z_temp ; String number currently printing
splash_line_y
	ldx splash_index_line,y
	lda splash_index_col,y
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

	lda $a2
	clc
	adc #<(SPLASHWAIT*60)
	sta z_temp + 2
	lda $a1
	adc #>(SPLASHWAIT*60)
	sta z_temp + 1
	
-	jsr kernal_getchar
	bne +
	lda z_temp + 2
	cmp $a2
	bne -
	lda z_temp + 1
	cmp $a1
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
