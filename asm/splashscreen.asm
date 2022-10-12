!zone splash_screen {
splash_screen
!ifndef NODARKMODE {
	inc .fkey_count
}
!ifndef NOSMOOTHSCROLL {
	inc .fkey_count
}
!ifdef SCROLLBACK {
	inc .fkey_count
}
	ldy #0
	sty z_temp ; String number currently printing
splash_line_y
	ldx splash_index_line,y
	cpx .title_line
	bne ++
	; move the title up to insert F-keys
	ldx .fkey_count
	inx
	txa
	lsr
	tax
	beq +
-	dec .title_line
	dex
	bne -
	ldx .title_line
++
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
	cpy #7
	bne splash_line_y

	lda .fkey_count
	beq +
	jsr .splash_fkeys
+

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
!ifndef NOSMOOTHSCROLL {
	cpy #137 ; F2
	bne +
	jsr toggle_smoothscroll
	jmp .restart_timer
+
}
	lda #147
	jmp s_printchar

.splash_fkeys
	ldy #0
	sty z_temp ; String number currently printing
.fkey_msg
	; compute the column
	lda s_screen_width
	sec
	sbc #40
	lsr
	tax ; amount to add if screen > 40 columns

	lda .fkey_count
	cmp #1
	beq ++
	; multiple F-keys; arrange in 2 columns
	clc
	lda z_temp
	and #$01
	beq +
	; 2nd column
	txa
	adc #20
	tax
+	txa
	adc #3
	bne +++ ; always
++
	; only one F-key, so center it
	ldy z_temp
	ldx .fkey_index_lb,y
	lda .fkey_index_hb,y
	jsr .center
+++
	tay

	; compute the line
	lda z_temp
	lsr
	clc
	adc .title_line
	tax
	inx
	inx

	; print the string
	jsr set_cursor
	ldy z_temp
	ldx .fkey_index_lb,y
	lda .fkey_index_hb,y
	jsr printstring_raw
	inc z_temp
	ldy z_temp
	cpy .fkey_count
	bne .fkey_msg
	rts

.center
; Prepare to center a message on the screen
; Parameters: Address in A,X to 0-terminated string
; Returns: Starting column in A
	stx .read_byte + 1
	sta .read_byte + 2
	ldx #0
.read_byte
	lda $8000,x
	beq +
	inx
	bne .read_byte
+	stx .length
	lda s_screen_width
	sec
	sbc .length
	lsr
	rts

!ifndef NODARKMODE {
.fkey1 !pet "F1=Darkmode", 0
}
!ifndef NOSMOOTHSCROLL {
.fkey2 !pet "F2=Smoothscroll", 0
}
!ifdef SCROLLBACK {
.fkey5 !pet "F5=Scrollback", 0
}
.fkey_index_lb
!ifndef NODARKMODE {
	!byte <.fkey1
}
!ifndef NOSMOOTHSCROLL {
	!byte <.fkey2
}
!ifdef SCROLLBACK {
	!byte <.fkey5
}
.fkey_index_hb
!ifndef NODARKMODE {
	!byte >.fkey1
}
!ifndef NOSMOOTHSCROLL {
	!byte >.fkey2
}
!ifdef SCROLLBACK {
	!byte >.fkey5
}
.fkey_count !byte 0
.title_line !byte 21
.length

!source "splashlines.asm"

splash_index_line
	!byte 2, 4, 6, 8, 21, 23, 24
splash_index_lb
	!byte <splashline0, <splashline1, <splashline2, <splashline3, <splashline4, <splashline5, <splashline6
splash_index_hb
	!byte >splashline0, >splashline1, >splashline2, >splashline3, >splashline4, >splashline5, >splashline6
}	
