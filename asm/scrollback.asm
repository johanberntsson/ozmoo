scrollback_start !byte 0,0,$09
scrollback_current !byte 0,0,$09
scrollback_line_count !word 0
scrollback_max_line_count !word 100
scrollback_has_wrapped !byte 0

copy_line_to_scrollback
	lda dynmem_pointer + 2
	pha
	ldx #3
-	lda scrollback_current - 1,x
	sta dynmem_pointer - 1, x
	dex
	bne -

	ldz s_screen_width_minus_one
	ldy s_screen_width_minus_one
-	lda (zp_screenline),y
	sta [dynmem_pointer],z
	dez
	dey
	bpl -

	; Increase scrollback_current by screen width
	clc
	lda scrollback_current
	adc s_screen_width
	sta scrollback_current
	bcc +
	inc scrollback_current + 1
	bne +
	inc scrollback_current + 2

	; Increase scrollback_line_count
+	inc scrollback_line_count
	bne +
	inc scrollback_line_count + 1

	; Check if we have reached max # of lines in buffer
+	lda scrollback_line_count
	cmp scrollback_max_line_count
	lda scrollback_line_count + 1
	sbc scrollback_max_line_count + 1
	bcc +

	; Reset current to start value.
	ldx #2
-	lda scrollback_start,x
	sta scrollback_current,x
	dex
	bpl -
	stx scrollback_has_wrapped
	inx
	stx scrollback_line_count
	stx scrollback_line_count + 1

	; Restore bank value of dynmem pointer
+	pla
	sta dynmem_pointer + 2
	rts


