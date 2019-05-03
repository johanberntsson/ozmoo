reu_status   = $DF00
reu_command  = $DF01
reu_c64base  = $DF02
reu_reubase  = $DF04
reu_translen = $DF07
reu_irqmask  = $DF09
reu_control  = $DF0A

!zone {
reu_start
	lda #0
	sta use_reu
	ldx reu_c64base
	inc reu_c64base
	inx
	cpx reu_c64base
	bne .no_reu
; REU detected
	lda #>.use_reu_question
	ldx #<.use_reu_question
	jsr printstring_raw
-	jsr kernal_getchar
    beq -
	cmp #89
	bne .no_reu
; Use REU	
;	inc $d020
	lda #$80 ; Use REU, set vmem to reu loading mode
	sta use_reu
	
; Perform initial copy of data to REU	

	lda #0
	ldx nonstored_blocks
	stx z_temp ; Lowbyte of current page in Z-machine memory
	sta z_temp + 1 ; Highbyte of current page in Z-machine memory
	ldx #1
	stx z_temp + 2 ; Lowbyte of current page in REU memory
	sta z_temp + 3 ; Highbyte of current page in REU memory


.initial_copy_loop

	lda z_temp + 1
	ldx z_temp
	ldy #0 ; Value is unimportant except for the last block, where anything > 0 may be after file end
	jsr read_byte_at_z_address
	; Current Z-machine page is now in C64 page held in mempointer + 1
	lda z_temp + 3
	ldx z_temp + 2
	ldy mempointer + 1
	jsr copy_page_to_reu
	bcs .reu_error

	inc z_temp
	bne +
	inc z_temp + 1
+	lda z_temp
	cmp fileblocks + 1 ; Fileblocks is stored big-endian
	lda z_temp + 1
	sbc fileblocks
	bcs .done_copying
	inc z_temp + 2
	bne +
	inc z_temp + 3
+	bne .initial_copy_loop ; Always branch

.done_copying
	lda #$ff ; Use REU
	sta use_reu

.no_reu
	rts

.reu_error
	lda #0
	sta use_reu
	lda #>.reu_error_msg
	ldx #<.reu_error_msg
	jsr printstring_raw
-	jsr kernal_getchar
    beq -
	rts

copy_page_to_reu
	; a,x = REU page
	; y = C64 page
	jsr store_reu_transfer_params
	lda #%10010000;  c64 -> REU with immediate execution
	sta reu_command
	rts

copy_page_from_reu
	; a,x = REU page
	; y = C64 page
	jsr store_reu_transfer_params
	lda #%10010001;  REU -> c64 with immediate execution
	sta reu_command
	rts

store_reu_transfer_params
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
.reu_error_msg
    !pet "REU error. [SPACE]",0
}

	