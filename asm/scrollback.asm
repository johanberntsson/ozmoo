!zone scrollback {

scrollback_enabled !byte 0 ; This is set to $ff at init if an REU is present and there is space
!ifdef TARGET_MEGA65 {
scrollback_supported !byte $ff
normal_line_length = 80
scrollback_prebuffer_pages = $10; (in pages) $1000 = 4KB
scrollback_prebuffer_pages_32 !byte 0, scrollback_prebuffer_pages, 0, 0
.scrollback_screen_ram !le32 $00010000
scrollback_total_buffer_size = $100000;
scrollback_start_minus_50_lines !le32 $08200000 + (scrollback_prebuffer_pages << 8) - 50 * 80
} else {
scrollback_supported !byte 0
scrollback_total_buffer_size = $10000;
!ifdef TARGET_C128 {
normal_line_length = 80
scrollback_prebuffer_pages = $08; (in pages) $0800 = 2KB
scrollback_start_minus_25_lines !le32 $00000000 + (scrollback_prebuffer_pages << 8) - 25 * 80
} else {
normal_line_length = 40
scrollback_prebuffer_pages = $04; (in pages) $0400 = 1KB
scrollback_start_minus_25_lines !le32 $00000000 + (scrollback_prebuffer_pages << 8) - 25 * 40
}
}
scrollback_prebuffer_start !byte 0, 0, $20, $08 ; First two bytes must be 0. Third value is altered on init for C64/C128. Last value is ignored for C64/128
scrollback_start !byte 0, scrollback_prebuffer_pages, $20, $08
scrollback_current !byte 0, scrollback_prebuffer_pages, $20, $08
scrollback_line_count !word 0
; !ifdef TARGET_C64 {
; scrollback_max_line_count !word ((scrollback_total_buffer_size - scrollback_prebuffer_pages * 256) / 40), 0
; scrollback_prebuffer_copy_from !word 40*((scrollback_total_buffer_size - scrollback_prebuffer_pages * 256) / 40), 0
; } else {
; !ifdef TARGET_C128 {
; ; First word must be > 50. Second word must be 0.
; scrollback_max_line_count !word ((scrollback_total_buffer_size - scrollback_prebuffer_pages * 256) / 80), 0
; scrollback_prebuffer_copy_from !word 80*((scrollback_total_buffer_size - scrollback_prebuffer_pages * 256) / 80), 0
; } else {
; First word must be > 50. Second word must be 0.
scrollback_max_line_count 
	!word ((scrollback_total_buffer_size - scrollback_prebuffer_pages * 256) / normal_line_length), 0
scrollback_prebuffer_copy_from 
	!le32  $08200000 + normal_line_length * ((scrollback_total_buffer_size - scrollback_prebuffer_pages * 256) / normal_line_length)
; }
; } 
scrollback_has_wrapped !byte 0
!ifdef TARGET_MEGA65 {
}
.selected_top_line !word 0, 0
.adjusted_top_line !word 0, 0
.lowest_top_line !word 0, 0
.highest_top_line !word 0, 0
!ifndef TARGET_C64 {
.scrollback_instructions 
	!scrxor $80, " SCROLLBACK MODE    Use Cursor Up/Down, F5, F7                     Enter = Exit "
}
!ifndef TARGET_MEGA65 {
.scrollback_instructions_40
	!scrxor $80, "SCROLLBACK  Up/Dn, F5, F7   Enter = Exit"
}
.exit_keys !byte 81, 88, 95, 32, 13 ; Q, X, Left arrow, Space, Enter
.exit_keys_count = * - .exit_keys


!ifdef TARGET_MEGA65 {
copy_line_to_scrollback
	lda scrollback_enabled
	beq ++
	lda read_text_level
	beq +
++	rts
+
	lda dynmem_pointer + 2
	pha
	ldx #3
-	lda scrollback_current - 1,x
	sta dynmem_pointer - 1, x
	dex
	bne -

	ldz s_screen_width_minus_one
-	lda (zp_screenline),z
	sta [dynmem_pointer],z
	dez
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
.return	
	rts

launch_scrollback
	lda scrollback_enabled
	beq .return

	; Backup screen and colour RAM pointers to safe place
	jsr mega65io
	lda $d021
	sta z_operand_value_low_arr + 4
	ldq $d060
	stq z_temp + 4
	ldq $d064
	stq z_temp + 8 ; Note: We only care about the first two bytes
	ldq .scrollback_screen_ram
	stq $d060
	lda #0
	sta $d064
	lda #8
	sta $d065

	; Fill relevant portion of colour RAM (start at offset 2 KB) with the game's foreground colour
	ldx darkmode
	ldy bgcol,x
	lda zcolours,y
	sta $d021
	ldy fgcol,x
	lda zcolours,y
	sta dma_source_address
	ldx #0
	stx dma_dest_address
	lda #8
	sta dma_dest_address + 1
	sta dma_dest_bank_and_flags
	lda #$ff
	sta dma_dest_address_top
	lda #$03
	sta dma_command_lsb
	ldx #<4000 ; Enough for 25 or 50 rows
	stx dma_count
	ldx #>4000 ; Enough for 25 or 50 rows
	stx dma_count + 1
	jsr m65_run_dma
	lda #$00
	sta dma_command_lsb ; Has been changed to $03 (FILL), must be restored to $00 (COPY)

	lda #0
	tax
	taz
	ldy #$01
	stq z_operand_value_high_arr + 4
	ldz #79
	ldy #79
-	lda .scrollback_instructions,y
	sta [z_operand_value_high_arr + 4],z
	dey
	dez
	bpl -
	
	; Fill prebuffer with spaces OR with a copy of the text at end of buffer
	; Prebuffer always starts on a 64KB boundary
	lda #0
	sta dma_dest_address
	sta dma_dest_address + 1
	lda scrollback_prebuffer_start + 2
	pha
	and #$0f
	sta dma_dest_bank_and_flags
	pla
	lsr
	lsr
	lsr
	lsr
	ora #$80 ; Base of HyperRAM
	sta dma_dest_address_top
	lda #0
	sta dma_count
	lda #scrollback_prebuffer_pages
	sta dma_count + 1
	
	lda scrollback_has_wrapped
	bne .copy_end_to_beginning
	; Fill prebuffer with spaces
	lda #$20
	sta dma_source_address
	lda #$03
	sta dma_command_lsb
	bne .fill_or_copy_prebuffer ; Always branch
	
.copy_end_to_beginning
	jsr mega65io
	ldq scrollback_max_line_count
	stq $d770
	lda s_screen_width
	ldx #0
	stq $d774
	ldq $d778	
	sec
	sbcq scrollback_prebuffer_pages_32
	clc
	adcq scrollback_start
	sta dma_source_address
	stx dma_source_address + 1
	tya
	and #$0f
	sta dma_source_bank_and_flags
	tya
	lsr
	lsr
	lsr
	lsr
	ora #$80 ; Base of HyperRAM
	sta dma_source_address_top

.fill_or_copy_prebuffer
	jsr m65_run_dma
	lda #$00
	sta dma_command_lsb ; May have been changed to $03 (FILL), must be restored to $00 (COPY)
	
	; Init to show last screenful

	lda scrollback_line_count
	sta .lowest_top_line
	sec
	sbc s_screen_height_minus_one
	sta .selected_top_line
	sta .highest_top_line
	lda scrollback_line_count + 1
	sta .lowest_top_line + 1
	sbc #0
	sta .selected_top_line + 1
	sta .highest_top_line + 1
	
	lda scrollback_has_wrapped
	bne +
	ldx #0
	stx .lowest_top_line
	stx .lowest_top_line + 1
	
+	lda .selected_top_line + 1
	bpl ++ ; When selected top line is positive, skip this section
	; .selected_top_line is negative - adjust it!
	lda scrollback_has_wrapped
	bne .wrap_selected_top_line
	; Not wrapped, adjust selected line
	ldx #0
	stx .selected_top_line
	stx .selected_top_line + 1
	stx .lowest_top_line
	stx .lowest_top_line + 1
	stx .highest_top_line
	stx .highest_top_line + 1
		beq ++ ; Always branch
.wrap_selected_top_line
	lda .selected_top_line
	clc
	adc scrollback_max_line_count
	sta .selected_top_line
	sta .highest_top_line
	lda .selected_top_line + 1
	adc scrollback_max_line_count + 1
	sta .selected_top_line + 1
	sta .highest_top_line + 1
++
.adjust_and_show_screen
	jsr scrollback_adjust_top_line
		
	; Copy a screenful from scrollback buffer to screen
; +	
	; Calculate start address of data to copy to screen
	lda .adjusted_top_line
	clc
	adc #50 ; Account for 50 lines in pre-buffer
	sta $d770
	lda .adjusted_top_line + 1
	adc #0
	sta $d771
	ldy #0
	sty $d772
	sty $d773
	lda s_screen_width
	ldx #0
	ldz #0
	stq $d774
	ldq $d778
	clc
	adcq scrollback_start_minus_50_lines
	stq z_temp
	; [z_temp] now holds the start address of data to copy to screen 

	; Copy a screenful of text to $10050 (one line into bank 1)
	sta dma_source_address
	stx dma_source_address + 1
	tya
	and #$0f
	sta dma_source_bank_and_flags
	tya
	lsr
	lsr
	lsr
	lsr
	ora #$80 ; Base of HyperRAM
	sta dma_source_address_top
	ldx #1
	stx dma_dest_bank_and_flags
	dex
	stx dma_dest_address + 1
	stx dma_dest_address_top
	ldx #$50
	stx dma_dest_address
	ldx #<4000 ; Enough for 25 or 50 rows
	stx dma_count
	ldx #>4000 ; Enough for 25 or 50 rows
	stx dma_count + 1
	jsr m65_run_dma

	; Wait for keypresses and scroll accordingly in buffer
.get_char
	jsr kernal_getchar
	ldx s_screen_height_minus_one
	stx z_temp + 10 ; Counter for how many lines to scoll for PgUp/PgDown
	ldx #0
	stx z_temp + 11 ; Counter for how many lines were actually scrolled

	cmp #135
	bne ++
	; Scroll up a screen
-	jsr .scroll_up_one_line
	dec z_temp + 10
	bne -
	jmp .adjust_and_show_screen

++	cmp #136
	bne ++
	; Scroll down a screen
-	jsr .scroll_down_one_line
	dec z_temp + 10
	bne -
	lda z_temp + 11
	beq .done
	jmp .adjust_and_show_screen

++	cmp #145
	bne ++
	; Scroll up
	jsr .scroll_up_one_line
	jmp .adjust_and_show_screen

++	cpy #17
	bne ++
	; Scroll down
	jsr .scroll_down_one_line
	jmp .adjust_and_show_screen

++	ldx #.exit_keys_count
-	cmp .exit_keys - 1,x
	beq .done
	dex
	bne -
	jmp .get_char
	
.done
	; Restore screen and color RAM pointers from safe place
	jsr mega65io
	ldq z_temp + 4
	stq $d060
	ldq z_temp + 8 ; Note: We only care about the first two bytes
	sta $d064
	stx $d065
	lda z_operand_value_low_arr + 4
	sta $d021
	
	rts

; scrollback_adjust_top_line
	; ldx .selected_top_line
	; stx .adjusted_top_line
	; lda .selected_top_line + 1
	; sta .adjusted_top_line + 1
	; ora .selected_top_line
	; bne .adjust_maybe_wrap
	; ; .selected_top_line is 0.
	; lda scrollback_line_count
	; sec
	; sbc s_screen_height_minus_one
	; tax
	; lda scrollback_line_count + 1
	; sbc #0
	; bpl + ; No need to adjust
	; stx .adjusted_top_line
	; sta .adjusted_top_line + 1
; +	rts

; .adjust_maybe_wrap
	; lda scrollback_max_line_count
	; sec
	; sbc s_screen_height_minus_one
	; tax
	; lda scrollback_max_line_count + 1
	; sbc #0
	; cpx .selected_top_line
	; sbc .selected_top_line + 1
	; bcs .adjust_done
	; lda .selected_top_line
	; sec
	; sbc scrollback_max_line_count
	; sta .adjusted_top_line
	; lda .selected_top_line + 1
	; sbc scrollback_max_line_count + 1
	; sta .adjusted_top_line + 1
; .adjust_done
	; rts
	
.scroll_up_one_line
	ldq .selected_top_line
; CMPQ is called CPQ in Acme
	cpq .lowest_top_line
	beq + ; We are at lowest top line, ignore scroll request
	; Not at lowest top line
	deq .selected_top_line
	bpl +
	ldq scrollback_max_line_count
	deq
	stq .selected_top_line
+	rts

.scroll_down_one_line
	ldq .selected_top_line
; CMPQ is called CPQ in Acme
	cpq .highest_top_line
	beq + ; We are at highest top line, ignore scroll request
	; Not at highest top line
	inc z_temp + 11
	inq .selected_top_line
	ldq .selected_top_line
; CMPQ is called CPQ in Acme
	cpq scrollback_max_line_count
	bne +
	lda #0
	tax
	stq .selected_top_line
+	rts
} else { ; =================================================================================
; Not MEGA65, so this is REU version
scrollback_bank
!ifndef Z4PLUS {
	!byte 2,3 ; Bank to store text, bank to backup screen + colour RAM
} else {
	!ifdef Z7PLUS {
		!byte 8,9
	} else {
		!byte 4,5
	}
}
scrollback_screen_backup_page !byte 0,0
scrollback_colour_backup_page !byte $08,0
.space !byte 32

.msg_not_available !pet 13,"Scrollback not available.", 13, 13, 0

init_reu_scrollback
	lda scrollback_bank + 1
	!ifdef TARGET_C128 {
		ldx COLS_40_80
		beq +
		; In 80 column mode we don't need the second bank (used for VIC screen data backup)
		lda scrollback_bank
+
	}
	cmp reu_banks
	bcs .disable_scrollback
	dec scrollback_supported ; Set to $ff = supported
	
; Init values
	sta scrollback_screen_backup_page + 1
	sta scrollback_colour_backup_page + 1
	lda scrollback_bank
	sta scrollback_prebuffer_start + 2 ; Bank value
	sta scrollback_start_minus_25_lines + 2
	sta scrollback_start + 2
	sta scrollback_current + 2
	sta scrollback_prebuffer_copy_from + 2
!ifdef TARGET_C128 {
	ldx COLS_40_80
	bne .is_80_col
	; 40 column -> Set new values for some constants
	lda #<((scrollback_prebuffer_pages << 8) - 25 * 40)
	sta scrollback_start_minus_25_lines
	lda #>((scrollback_prebuffer_pages << 8) - 25 * 40)
	sta scrollback_start_minus_25_lines + 1
	lda #<((scrollback_total_buffer_size - scrollback_prebuffer_pages * 256) / 40)
	sta scrollback_max_line_count
	lda #>((scrollback_total_buffer_size - scrollback_prebuffer_pages * 256) / 40)
	sta scrollback_max_line_count + 1
	lda #<(40*((scrollback_total_buffer_size - scrollback_prebuffer_pages * 256) / 40))
	sta scrollback_prebuffer_copy_from
	lda #>(40*((scrollback_total_buffer_size - scrollback_prebuffer_pages * 256) / 40))
	sta scrollback_prebuffer_copy_from + 1
.is_80_col
}
	
	rts
.disable_scrollback
	lda #>.msg_not_available
	ldx #<.msg_not_available
	jsr printstring_raw
	jmp wait_a_sec
	; lda #147
	; jmp s_printchar

copy_line_to_scrollback
	lda scrollback_enabled
	beq ++
	lda read_text_level
	beq +
++	rts
+
	lda scrollback_current + 2
	ldx scrollback_current + 1
	ldy zp_screenline + 1
	sec
	jsr store_reu_transfer_params
	lda s_screen_width
	sta reu_translen
	lda scrollback_current
	sta reu_reubase
!ifdef TARGET_C128 {
	ldx COLS_40_80
	beq .copy_40_col
	; 80 column -> Get characters from VDC
	ldy #79
-	jsr VDCGetChar
	sta SCREEN_ADDRESS,y
	dey
	bpl -
	lda #>SCREEN_ADDRESS
	sta reu_c64base + 1
	lda #<SCREEN_ADDRESS
	beq .do_copy ; Always branch
.copy_40_col
}	
	lda zp_screenline
.do_copy
	sta reu_c64base
	lda #%10110000;  c64 -> REU with immediate execution
	sta reu_command
	
	; Increase scrollback_current by screen width
	clc
	lda scrollback_current
	adc s_screen_width
	sta scrollback_current
	bcc +
	inc scrollback_current + 1
	; bne +
	; inc scrollback_current + 2

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

.return
+	rts

launch_scrollback
	lda scrollback_enabled
	beq .return

	; Backup screen and colour RAM to safe place
	lda scrollback_screen_backup_page + 1
	ldx scrollback_screen_backup_page
	ldy #>SCREEN_ADDRESS
	clc
	jsr store_reu_transfer_params
	lda #<1000
	sta reu_translen
	lda #>1000
	sta reu_translen + 1
!ifdef TARGET_C128 {
	ldx COLS_40_80
	beq .bak_copy_40_col
	; 80 column -> Get characters from VDC
	; colours
	ldx #VDC_COLORS
	jsr VDCReadReg
	sta z_operand_value_low_arr + 5
	jsr VDCSetToScrollback

	; ; Fill relevant portion of colour RAM (start at offset $1800) with the game's foreground colour
	lda #$18
	ldx #VDC_DATA_HI
	jsr VDCWriteReg
	lda #$00
	ldx #VDC_DATA_LO
	jsr VDCWriteReg

	ldx darkmode
	ldy fgcol,x
	lda zcolours,y
	tay
	lda vdc_vic_colours,y
	ora #$80 ; Bit 7 = charset, bit 0-4 = fg colour
	ldx #VDC_DATA
	jsr VDCWriteReg
	; We have written default fg colour to the first position in colour RAM. Now fill 1999 more positions.
	lda #0 ; Set to Fill mode ; Not needed, we have 0 in A
	ldx #VDC_VSCROLL
	jsr VDCWriteReg
	ldy #8
	ldx #VDC_COUNT
	lda #214
-	jsr VDCWriteReg
	lda #255
	dey
	bne -

	; Print instructions
	lda #$10
	ldx #VDC_DATA_HI
	jsr VDCWriteReg
	lda #$00
	ldx #VDC_DATA_LO
	jsr VDCWriteReg
	ldy #0
	ldx #VDC_DATA
-	lda .scrollback_instructions,y
	jsr VDCWriteReg
	iny
	cpy #80
	bne -

	; lda zp_screenline
	; pha
	; lda zp_screenline + 1
	; pha
	; lda #<SCREEN_ADDRESS
	; sta zp_screenline
	; lda #>SCREEN_ADDRESS
	; sta zp_screenline + 1
	; lda #25 ; 25 lines on the 80 col screen
	; sta z_temp
	; lda scrollback_screen_backup_page
	; sta z_temp + 2
	; lda #0
	; sta z_temp + 1
; --	ldy #79
; -	jsr VDCGetChar
	; sta SCREEN_ADDRESS,y
	; dey
	; bpl -

	; lda scrollback_screen_backup_page + 1
	; ldx z_temp + 2
	; ldy #>SCREEN_ADDRESS
	; sec
	; jsr store_reu_transfer_params
	; lda z_temp + 1
	; sta reu_reubase
	; lda #80
	; sta reu_translen
	; sta reu_c64base
	; lda #%10110000;  c64 -> REU with immediate execution
	
	; lda z_temp + 1
	; clc
	; adc #80
	; sta z_temp + 1
	; bne +
	; inc z_temp + 2
; +
	; dec z_temp
	; bne --

	; beq .bak_have_copied_screen ; Always branch
	jmp .bak_have_copied_screen
.bak_copy_40_col
}	
	; lda zp_screenline
	; sta reu_c64base
	lda #%10110000;  c64 -> REU with immediate execution
	sta reu_command

	lda scrollback_colour_backup_page + 1
	ldx scrollback_colour_backup_page
	ldy #>COLOUR_ADDRESS
	clc
	jsr store_reu_transfer_params
	lda #>1000
	sta reu_translen + 1
	lda #<1000
	sta reu_translen
	lda #%10110000;  c64 -> REU with immediate execution
	sta reu_command
	lda $d021
	sta z_operand_value_low_arr + 4
	ldx darkmode
	ldy bgcol,x
	lda zcolours,y
	sta $d021
	; ; Fill colour RAM with the game's foreground colour
	ldy fgcol,x
	lda zcolours,y
	ldx #250
-	sta COLOUR_ADDRESS - 1,x
	sta COLOUR_ADDRESS + 250 - 1,x
	sta COLOUR_ADDRESS + 500 - 1,x
	sta COLOUR_ADDRESS + 750 - 1,x
	dex
	bne -
	
	ldy #39
-	lda .scrollback_instructions_40,y
	sta SCREEN_ADDRESS,y
	dey
	bpl -
	
.bak_have_copied_screen

	; ; Fill prebuffer with spaces OR with a copy of the text at end of buffer
	; ; Prebuffer always starts on a 64KB boundary

	lda scrollback_has_wrapped
	bne .copy_end_to_beginning

	lda scrollback_prebuffer_start + 2
	ldx scrollback_prebuffer_start + 1
	ldy #>.space
	clc
	jsr store_reu_transfer_params
	lda #<.space
	sta reu_c64base
	lda #scrollback_prebuffer_pages
	sta reu_translen + 1
	lda #$80
	sta reu_control ; Fix C64 address
	lda #%10110000;  c64 -> REU with immediate execution
	sta reu_command
	bne .done_filling_prebuffer ; Always branch

.copy_end_to_beginning
	jsr get_free_vmem_buffer
	sta z_operand_value_low_arr + 6

	; Copy prebuffer size pages from scrollback_prebuffer_copy_from to prebuffer
	ldx #scrollback_prebuffer_pages
	dex
	stx z_operand_value_low_arr + 7
-	lda z_operand_value_low_arr + 7
	clc
	adc scrollback_prebuffer_copy_from + 1
	tax
	lda scrollback_prebuffer_copy_from + 2
	ldy z_operand_value_low_arr + 6
	clc
	jsr store_reu_transfer_params
	lda scrollback_prebuffer_copy_from
	sta reu_reubase
	lda #%10110001;  REU -> c64 with immediate execution
	sta reu_command

	ldx z_operand_value_low_arr + 7
	lda scrollback_prebuffer_start + 2
	ldy z_operand_value_low_arr + 6
	clc
	jsr store_reu_transfer_params
	; lda #0
	; sta reu_reubase
	lda #%10110000;  c64 -> REU with immediate execution
	sta reu_command

	dec z_operand_value_low_arr + 7
	bpl -

.done_filling_prebuffer	

	; Init to show last screenful

	lda scrollback_line_count
	sta .lowest_top_line
	sec
	sbc s_screen_height_minus_one
	sta .selected_top_line
	sta .highest_top_line
	lda scrollback_line_count + 1
	sta .lowest_top_line + 1
	sbc #0
	sta .selected_top_line + 1
	sta .highest_top_line + 1
	
	lda scrollback_has_wrapped
	bne +
	ldx #0
	stx .lowest_top_line
	stx .lowest_top_line + 1
	
+	lda .selected_top_line + 1
	bpl ++ ; When selected top line is positive, skip this section
	; .selected_top_line is negative - adjust it!
	lda scrollback_has_wrapped
	bne .wrap_selected_top_line
	; Not wrapped, adjust selected line
	ldx #0
	stx .selected_top_line
	stx .selected_top_line + 1
	stx .lowest_top_line
	stx .lowest_top_line + 1
	stx .highest_top_line
	stx .highest_top_line + 1
	beq ++ ; Always branch
.wrap_selected_top_line
	lda .selected_top_line
	clc
	adc scrollback_max_line_count
	sta .selected_top_line
	sta .highest_top_line
	lda .selected_top_line + 1
	adc scrollback_max_line_count + 1
	sta .selected_top_line + 1
	sta .highest_top_line + 1
++
.adjust_and_show_screen
	jsr scrollback_adjust_top_line
		
	; ; Copy a screenful from scrollback buffer to screen
; ; +	
	; ; Calculate start address of data to copy to screen
	lda .adjusted_top_line
	clc
	adc #25 ; Account for 25 lines in pre-buffer
	sta z_operand_value_high_arr + 4
	lda .adjusted_top_line + 1
	adc #0
	sta z_operand_value_high_arr + 5
	sta z_operand_value_high_arr + 6
	lda z_operand_value_high_arr + 4
	asl
	rol z_operand_value_high_arr + 6
	asl
	rol z_operand_value_high_arr + 6
	adc z_operand_value_high_arr + 4
	pha
	lda z_operand_value_high_arr + 6
	adc z_operand_value_high_arr + 5
	sta z_operand_value_high_arr + 6
	pla
	ldy #3
!ifdef TARGET_C128 {
	ldx COLS_40_80
	beq +
	iny
+
}
-	asl
	rol z_operand_value_high_arr + 6
	dey
	bne -
	
	adc scrollback_start_minus_25_lines
	sta z_temp
	lda z_operand_value_high_arr + 6
	adc scrollback_start_minus_25_lines + 1
	sta z_temp + 1
	
	; (z_temp) now holds the start address of data to copy to screen 

	; ; Copy 24 lines of text to screen ($1050 in VDC or SCREEN_ADDRESS + 40 for VIC)
	
!ifdef TARGET_C128 {
	ldx COLS_40_80
	beq .copy_screenful_40

	; Copy a 24 * 80 (= 8 * 240) characters from REU to VDC

	lda #>($1000 + 80)
	ldx #VDC_DATA_HI
	jsr VDCWriteReg
	lda #<($1000 + 80)
	ldx #VDC_DATA_LO
	jsr VDCWriteReg

	lda #8
	sta z_operand_value_high_arr + 7

---
	lda scrollback_bank
	ldx z_temp + 1
	ldy #>SCREEN_ADDRESS
	sec
	jsr store_reu_transfer_params
	ldy z_temp
	sty reu_reubase
	lda #240
	sta reu_translen
	lda #%10110001;  REU -> c64 with immediate execution
	sta reu_command

	ldy #0
	ldx #VDC_DATA
-	lda SCREEN_ADDRESS,y
	jsr VDCWriteReg
	iny
	cpy #240
	bne -

	lda z_temp
	clc
	adc #240
	sta z_temp
	bcc +
	inc z_temp + 1

+	dec z_operand_value_high_arr + 7
	bne ---
	beq .get_char ; Always branch

.copy_screenful_40
}
	lda scrollback_bank
	ldx z_temp + 1
	ldy #>(SCREEN_ADDRESS + 40)
	clc
	jsr store_reu_transfer_params
	ldy z_temp
	sty reu_reubase
	ldy #<(SCREEN_ADDRESS + 40)
	sty reu_c64base
	lda #>(1000 - 40)
	sta reu_translen + 1
	lda #<(1000 - 40)
	sta reu_translen
	lda #%10110001;  REU -> c64 with immediate execution
	sta reu_command

	; ; Wait for keypresses and scroll accordingly in buffer
.get_char
	jsr kernal_getchar
	ldx s_screen_height_minus_one
	stx z_temp + 10 ; Counter for how many lines to scoll for PgUp/PgDown
	ldx #0
	stx z_temp + 11 ; Counter for how many lines were actually scrolled

	cmp #135
	bne ++
	; Scroll up a screen
-	jsr .scroll_up_one_line
	dec z_temp + 10
	bne -
	jmp .adjust_and_show_screen

++	cmp #136
	bne ++
	; Scroll down a screen
-	jsr .scroll_down_one_line
	dec z_temp + 10
	bne -
	lda z_temp + 11
	beq .done
	jmp .adjust_and_show_screen

++	
	cmp #145
	bne ++
	; Scroll up
	jsr .scroll_up_one_line
	jmp .adjust_and_show_screen

++	cpy #17
	bne ++
	; Scroll down
	jsr .scroll_down_one_line
	jmp .adjust_and_show_screen

++	ldx #.exit_keys_count
-	cmp .exit_keys - 1,x
	beq .done
	dex
	bne -
	jmp .get_char
	
.done
	; ; Restore screen and color RAM pointers from safe place
!ifdef TARGET_C128 {
	ldx COLS_40_80
	beq .restore_copy_40_col
	; 80 column -> Get characters from VDC
	jsr VDCInit
	; colours
	lda z_operand_value_low_arr + 5
	ldx #VDC_COLORS
	jsr VDCWriteReg
	; lda zp_screenline
	; pha
	; lda zp_screenline + 1
	; pha
	; lda #<SCREEN_ADDRESS
	; sta zp_screenline
	; lda #>SCREEN_ADDRESS
	; sta zp_screenline + 1
	; lda #25 ; 25 lines on the 80 col screen
	; sta z_temp
	; lda scrollback_screen_backup_page
	; sta z_temp + 2
	; lda #0
	; sta z_temp + 1
; --	ldy #79
; -	jsr VDCGetChar
	; sta SCREEN_ADDRESS,y
	; dey
	; bpl -

	; lda scrollback_screen_backup_page + 1
	; ldx z_temp + 2
	; ldy #>SCREEN_ADDRESS
	; sec
	; jsr store_reu_transfer_params
	; lda z_temp + 1
	; sta reu_reubase
	; lda #80
	; sta reu_translen
	; sta reu_c64base
	; lda #%10110000;  c64 -> REU with immediate execution
	
	; lda z_temp + 1
	; clc
	; adc #80
	; sta z_temp + 1
	; bne +
	; inc z_temp + 2
; +
	; dec z_temp
	; bne --

	; beq .bak_have_copied_screen ; Always branch
	jmp .restore_have_restored_screen
.restore_copy_40_col
}	
	lda scrollback_screen_backup_page + 1
	ldx scrollback_screen_backup_page
	ldy #>SCREEN_ADDRESS
	clc
	jsr store_reu_transfer_params
	lda #>1000
	sta reu_translen + 1
	lda #<1000
	sta reu_translen
	lda #%10110001;  REU -> c64 with immediate execution
	sta reu_command

	lda scrollback_colour_backup_page + 1
	ldx scrollback_colour_backup_page
	ldy #>COLOUR_ADDRESS
	clc
	jsr store_reu_transfer_params
	lda #>1000
	sta reu_translen + 1
	lda #<1000
	sta reu_translen
	lda #%10110001;  REU -> c64 with immediate execution
	sta reu_command

.restore_have_restored_screen

	lda z_operand_value_low_arr + 4
	sta $d021
	
	rts

.scroll_up_one_line
	lda .selected_top_line
	cmp .lowest_top_line
	bne +
	lda .selected_top_line + 1
	cmp .lowest_top_line + 1
	beq ++ ; We are at lowest top line, ignore scroll request
+	; Not at lowest top line
	dec .selected_top_line
	lda .selected_top_line
	cmp #$ff
	bne +
	dec .selected_top_line + 1
+	bit .selected_top_line + 1
	bpl ++
	lda scrollback_max_line_count
	sec
	sbc #1
	sta .selected_top_line
	lda scrollback_max_line_count + 1
	sbc #0
	sta .selected_top_line + 1
++	rts

.scroll_down_one_line
	lda .selected_top_line
	cmp .highest_top_line
	bne +
	lda .selected_top_line + 1
	cmp .highest_top_line + 1
	beq ++ ; We are at highest top line, ignore scroll request
+	; Not at highest top line
	inc z_temp + 11
	inc .selected_top_line
	bne +
	inc .selected_top_line + 1
+	lda .selected_top_line
	cmp scrollback_max_line_count
	bne ++
	lda .selected_top_line + 1
	cmp scrollback_max_line_count + 1
	bne ++
	lda #0
	sta .selected_top_line
	sta .selected_top_line + 1
++	rts

!ifdef TARGET_C128 {
VDCSetToScrollback
	; set the VDC configuration for scrollback mode
	; screen $1000 (reg 12,13)
	lda #$10  ; 7f
	ldx #VDC_DSP_HI
	jsr VDCWriteReg
	lda #$00
	ldx #VDC_DSP_LO
	jsr VDCWriteReg

	; Set background colour
	ldx darkmode
	ldy bgcol,x
	lda zcolours,y
	tay
	lda vdc_vic_colours,y
	ldx #VDC_COLORS
	jsr VDCWriteReg

	; attributes/colour $1800 (reg 20,21)
	lda #$18
	ldx #VDC_ATTR_HI
	jsr VDCWriteReg
	lda #$00
	ldx #VDC_ATTR_LO
	jsr VDCWriteReg
	; ; char mem
	; lda #$2f
	; ldx #VDC_CSET
	; jsr VDCWriteReg

	; !ifdef CUSTOM_FONT {
		; lda #$17 ; 0001 011X = $0400 $1800
	; } else {
		; lda #$16
	; }
	; sta reg_screen_char_mode


	; colours
	; lda #$f0
	; ldx #VDC_COLORS
	; jsr VDCWriteReg
	; ; number of lines
	; lda #$19
	; ldx #VDC_VDISP
	; jsr VDCWriteReg
	rts
}

} ; End of REU version

scrollback_adjust_top_line
	ldx .selected_top_line
	stx .adjusted_top_line
	lda .selected_top_line + 1
	sta .adjusted_top_line + 1
	ora .selected_top_line
	ora scrollback_has_wrapped
	bne .adjust_maybe_wrap
	; .selected_top_line is 0.
	lda scrollback_line_count
	sec
	sbc s_screen_height_minus_one
	tax
	lda scrollback_line_count + 1
	sbc #0
	bpl + ; No need to adjust
	stx .adjusted_top_line
	sta .adjusted_top_line + 1
+	rts

.adjust_maybe_wrap
	lda scrollback_max_line_count
	sec
	sbc s_screen_height_minus_one
	tax
	lda scrollback_max_line_count + 1
	sbc #0
	cpx .selected_top_line
	sbc .selected_top_line + 1
	bcs .adjust_done
	lda .selected_top_line
	sec
	sbc scrollback_max_line_count
	sta .adjusted_top_line
	lda .selected_top_line + 1
	sbc scrollback_max_line_count + 1
	sta .adjusted_top_line + 1
.adjust_done
	rts
	


} ; Zone scrollback