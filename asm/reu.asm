reu_status   = $DF00
reu_command  = $DF01
reu_c64base  = $DF02
reu_reubase  = $DF04
reu_translen = $DF07
reu_irqmask  = $DF09
reu_control  = $DF0A

!zone reu {
.no_reu
	lda #78 + 128
.print_reply_and_return
	jsr kernal_printchar
	lda #13
	jsr kernal_printchar
.no_reu_present	
	rts

reu_start
	lda #0
	sta use_reu
	sta $c6 ; Empty keyboard buffer
	ldx reu_c64base
	inc reu_c64base
	inx
	cpx reu_c64base
	bne .no_reu_present
; REU detected
	lda #>.use_reu_question
	ldx #<.use_reu_question
	jsr printstring_raw
-	jsr kernal_getchar
    beq -
	cmp #89
	bne .no_reu
	ldx #$80 ; Use REU, set vmem to reu loading mode
	stx use_reu
	ora #$80
	bne .print_reply_and_return ; Always branch

copy_page_from_reu
	; a,x = REU page
	; y = C64 page
	jsr store_reu_transfer_params
	lda #%10010001;  REU -> c64 with immediate execution
	sta reu_command
	rts

store_reu_transfer_params
	; a,x = REU page
	; y = C64 page
	sta reu_reubase + 2
	stx reu_reubase + 1
	sty reu_c64base + 1
	lda #0
	sta reu_control ; to make sure both addresses are counted up
	sta reu_c64base
	sta reu_reubase
	sta reu_translen
	lda #>$0100 ; Transfer one page
	sta reu_translen + 1
	rts


.use_reu_question
    !pet "Use REU? (Y/N) ",0
}

	