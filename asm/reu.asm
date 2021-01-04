reu_status   = $DF00
reu_command  = $DF01
reu_c64base  = $DF02
reu_reubase  = $DF04
reu_translen = $DF07
reu_irqmask  = $DF09
reu_control  = $DF0A

reu_needs_loading !byte 0 ; Should be 0 from the start

!zone reu {

reu_error
	lda #0
	sta use_reu
	lda #>.reu_error_msg
	ldx #<.reu_error_msg
	jsr printstring_raw
-	jsr kernal_getchar
	beq -
	rts

.reu_error_msg
	!pet 13,"REU error, disabled. [SPACE]",0


copy_page_to_reu
	; a,x = REU page
	; y = C64 page

	jsr store_reu_transfer_params

-	lda #%10110000;  c64 -> REU with immediate execution
	sta reu_command

	; Verify
	
	lda #%10110011;  compare c64 to REU with immediate execution
	sta reu_command
	lda reu_status
	and #%00100000
	beq +

	; Signal REU error and return
	sec
	rts

+
	; Update progress bar
	dec progress_reu
	bne +
	lda reu_progress_base
	sta progress_reu
	lda #20
	jsr s_printchar
+	clc
	rts



copy_page_from_reu
	; a,x = REU page
	; y = C64 page
!ifdef TARGET_C128 {
	pha
	lda #0
	sta allow_2mhz_in_40_col
	sta reg_2mhz	;CPU = 1MHz
	pla
}

	jsr store_reu_transfer_params

	lda #%10110001;  REU -> c64 with immediate execution
	sta reu_command

!ifdef TARGET_C128 {
restore_2mhz
	lda #1
	sta allow_2mhz_in_40_col
	ldx COLS_40_80
	beq +
	lda use_2mhz_in_80_col
	sta reg_2mhz	;CPU = 2MHz
+
}
	rts


store_reu_transfer_params
	; a,x = REU page
	; y = C64 page
	sta reu_reubase + 2
	stx reu_reubase + 1
	sty reu_c64base + 1
	lda #0
	sta reu_irqmask
	sta reu_control ; to make sure both addresses are counted up
	sta reu_c64base
	sta reu_reubase
	sta reu_translen
	lda #>$0100 ; Transfer one page
	sta reu_translen + 1
	rts

}

	