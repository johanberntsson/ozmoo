!zone scrollback {
scrollback_prebuffer_size = $10; (in pages) $1000 = 4KB
scrollback_prebuffer_size_32 !byte 0, scrollback_prebuffer_size, 0, 0
scrollback_prebuffer_start !byte 0, 0, $20, $08 ; First two bytes must be 0
scrollback_start_minus_50_lines !le32 $08200000 + (scrollback_prebuffer_size << 8) - 50 * 80
scrollback_start !byte 0, scrollback_prebuffer_size, $20, $08
scrollback_current !byte 0, scrollback_prebuffer_size, $20, $08
scrollback_line_count !word 0
scrollback_max_line_count !word 100, 0 ; First word must be in range 51-13000 (line length * count >= 4 KB). Second word must be 0.
scrollback_has_wrapped !byte 0
.scrollback_screen_ram !le32 $00010000
.selected_top_line !word 0, 0
.adjusted_top_line !word 0, 0
.lowest_top_line !word 0, 0
.highest_top_line !word 0, 0
.scrollback_instructions 
	!scrxor $80, " SCROLLBACK MODE    Use Cursor Up/Down, F5, F7                     Enter = Exit "
.exit_keys !byte 136, 81, 88, 95, 32, 13 ; F7, Q, X, Left arrow, Space, Enter
.exit_keys_count = * - .exit_keys

copy_line_to_scrollback
	lda read_text_level
	beq +
	rts
+
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

launch_scrollback
	; Backup screen and colour RAM pointers to safe place
	jsr mega65io
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
	lda #scrollback_prebuffer_size
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
	sbcq scrollback_prebuffer_size_32
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
	lda .selected_top_line + 1
	adc scrollback_max_line_count + 1
	sta .selected_top_line
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
	stx z_temp + 10 ; Counter for PgUp/PgDown

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
	
	rts

scrollback_adjust_top_line
	ldx .selected_top_line
	stx .adjusted_top_line
	lda .selected_top_line + 1
	sta .adjusted_top_line + 1
	ora .selected_top_line
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
	inq .selected_top_line
	ldq .selected_top_line
; CMPQ is called CPQ in Acme
	cpq scrollback_max_line_count
	bne +
	lda #0
	tax
	stq .selected_top_line
+	rts
}