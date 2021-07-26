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

!ifdef TARGET_MEGA65 {
	stx dma_dest_address + 1
	sta dma_dest_bank_and_flags
	sty dma_source_address + 1

	ldx #0
	stx dma_dest_address
	stx dma_source_address
	stx dma_source_bank_and_flags
	stx dma_source_address_top
	lda #$80 ; Base of HyperRAM
	sta dma_dest_address_top

	jsr m65_run_dma

} else {
; Not MEGA65
	clc
	jsr store_reu_transfer_params

-	lda #%10110000;  c64 -> REU with immediate execution
	sta reu_command

	; Verify
	
	lda #%10110011;  compare c64 to REU with immediate execution
	sta reu_command
	lda reu_status
	and #%00100000
	beq .update_progress_bar

	; Signal REU error and return
	sec
	rts
}

.update_progress_bar
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
!ifdef TARGET_MEGA65 {
	stx dma_source_address + 1
	sta dma_source_bank_and_flags
	sty dma_dest_address + 1

	ldx #0
	stx dma_source_address
	stx dma_dest_address
	stx dma_dest_address_top
	stx dma_dest_bank_and_flags
	lda #$80 ; Base of HyperRAM
	sta dma_source_address_top

	jmp m65_run_dma

} else { 
; Not MEGA65

!ifdef TARGET_C128 {
	pha
	lda #0
	sta allow_2mhz_in_40_col
	sta reg_2mhz	;CPU = 1MHz
	pla
}

	clc
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
} ; else (not MEGA65)


!ifndef TARGET_MEGA65 {
store_reu_transfer_params

	; a,x = REU page
	; y = C64 page
	; Transfer size: $01 if C is set, $100 if C is clear
	sta reu_reubase + 2
	stx reu_reubase + 1
	sty reu_c64base + 1
	ldx #0
	stx reu_irqmask
	stx reu_control ; to make sure both addresses are counted up
	stx reu_c64base
	stx reu_reubase
	; Transfer size: $01 if C is set, $100 if C is clear
	lda #>$0100 ; Transfer one page
	bcc +
	; Set transfer size to $01
	txa
	inx
+	stx reu_translen
	sta reu_translen + 1
	rts
}

.size = object_temp
.old = object_temp + 1
.temp = vmem_cache_start + 2


.reu_banks_to_check = 32 ; Can be up to 128, but make sure .reu_tmp has room 
.reu_tmp = streams_stack; 60 bytes, we only use 32

reu_banks !byte 0

check_reu_size

!ifdef TARGET_MEGA65 {
	; Start checking at address $08 00 00 00
	ldz #0
	ldy #0
	sty stack_tmp
	sty stack_tmp + 1
	sty stack_tmp + 2
	lda #$08
	sta stack_tmp + 3
.check_next_bank
	lda [stack_tmp],z
	sta .reu_tmp,y		; Store the old value for the first byte of bank

	iny
	tya
	sta [stack_tmp],z	; Save the bank number + 1 in the first byte of bank
	lda [stack_tmp],z
	sta stack_tmp + 4
	cpy stack_tmp + 4	; Check if the new value stuck
	beq +
	dey
	jmp .found_end_of_reu
	
+	dey
	tya
	sta [stack_tmp],z	; Save the bank number in the first byte of bank
	lda [stack_tmp],z
	sta stack_tmp + 4
	cpy stack_tmp + 4	; Check if the new value stuck
	bne .found_end_of_reu
	
	lda #0
	sta stack_tmp + 2
	lda [stack_tmp],z
	bne .found_end_of_reu ; Should be the bank number for bank #0 ( i.e. 0)
	
	iny
	sty stack_tmp + 2	; Set the next bank to test 
	cpy #.reu_banks_to_check
	bcc .check_next_bank
.found_end_of_reu
	; y is now 0 - .reu_banks_to_check, meaning the first unavailable bank number
	sty stack_tmp + 4
-	dey
	bmi +
	lda .reu_tmp,y
	sty stack_tmp + 2
	sta [stack_tmp],z ; Write the original value back
	jmp -

+	lda stack_tmp + 4
	rts
} else {
	; Target not MEGA65
	lda #8 ; Guess 512 KB
	rts
}

; Robin Harbron version
	; lda #0
	; sta $df04
	; sta $df05
	; sta $df08
	; sta $df0a
	; lda #1
	; sta $df07

	; lda #<.temp
	; sta $df02
	; lda #>.temp
	; sta $df03

	; ldx #0
; .loop1
	; stx $df06
	; stx .temp
	; lda #178
	; sta $df01
	; lda .temp
	; sta .temp+1,x
	; inx
	; bne .loop1

	; ldy #177
	; ldx #0
	; stx .old
; .loop2
	; stx $df06
	; sty $df01
	; lda .temp
	; cmp .old
	; bcc .next
	; sta .old
	; inx
	; bne .loop2
; .next
	; stx .size
	; ldy #176
	; ldx #255
; .loop3
	; stx $df06
	; lda .temp+1,x
	; sta .temp
	; sty $df01
	; dex
	; cpx #255
	; bne .loop3
	; lda .size
	rts



; My verison
	; ldx #0
	; stx object_temp
	; ; %%%
	; ; Backup the first value in each 64 KB block in REU, to C64 memory
; -	lda object_temp
	; ldx #0
	; ldy #1
	; sec
	; jsr store_reu_transfer_params
	; lda #%10110001;  REU -> c64 with immediate execution
	; sta reu_command
	; lda $100
	; ldx object_temp
	; sta $101,x

	; ; Write the number of the 64KB block to the first byte in the block
	; lda object_temp
	; sta $100
	; ldx #0
	; ldy #1 ; Should be able to skip this
	; sec
	; jsr store_reu_transfer_params
	; lda #%10110000;  c64 -> REU with immediate execution
	; sta reu_command
	
	; ; Read the number in the first byte of the first 64 KB block to see if it's untouched
	; lda #0
	; tax
	; ldy #1 ; Should be able to skip this
	; sec
	; jsr store_reu_transfer_params
	; lda #%10110001;  REU -> c64 with immediate execution
	; sta reu_command
	; lda $100
	; cmp #0
	; bne +
	; inc object_temp
	; lda object_temp
	; cmp #32
	; bcc -
; +		
	; ; Restore the original contents in all blocks
	; ldx object_temp ; This now holds the # of 64 KB blocks available in REU
	; dex
	; stx object_temp + 1
	
	; ; Write the original content of the first byte of each 64KB block to the REU
; -	ldx object_temp + 1
	; lda $101,x
	; sta $100
	; ldx #0
	; ldy #1 ; Should be able to skip this
	; sec
	; jsr store_reu_transfer_params
	; lda #%10110000;  c64 -> REU with immediate execution
	; sta reu_command
	; dec object_temp + 1
	; bpl -
	; rts

}

	