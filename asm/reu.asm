reu_status   = $DF00
reu_command  = $DF01
reu_c64base  = $DF02
reu_reubase  = $DF04
reu_translen = $DF07
reu_irqmask  = $DF09
reu_control  = $DF0A

!zone reu {

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

}

	