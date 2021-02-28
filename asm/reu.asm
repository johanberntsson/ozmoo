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

	clc
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

.size = object_temp
.old = object_temp + 1
.temp = vmem_cache_start + 2
check_reu_size
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

	