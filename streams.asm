; Routines to handle output streams and input streams

!zone streams {
streams_current_entry		!byte 0,0,0,0
streams_stack				!fill 60, 0
streams_stack_items			!byte 0
streams_buffering			!byte 1,1
streams_output_selected		!byte 0, 0, 0, 0

.streams_tmp	!byte 0,0,0
.current_character !byte 0
character_translation_table
; Pairs of values (zscii code, petscii code). End with 0,0.
	!byte $8, $14 ; Backspace
	!byte 129, 145 ; Cursor up
	!byte 130, 17 ; Cursor down
	!byte 131, 157 ; Cursor left
	!byte 132, 29 ; Cursor right
	!byte $5f, $a4 ; Underscore = underscore-like graphic character
	!byte $7c, $7d ; Pipe = pipe-like graphic character
!ifdef SWEDISH_CHARS {
	!byte $c9, $5d ; å = ]
	!byte $9b, $5b ; ä = [
	!byte $9c, $5c ; ö = £
	!byte $ca, $7d ; Å = ]
	!byte $9e, $7b ; Ä = [
	!byte $9f, $7c ; Ö = £
}
	!byte 0,0


	
streams_init
	; Setup/Reset streams handling
	; input: 
	; output:
	; side effects: Sets all variables/tables to their starting values
	; used registers: a
	lda #0
	sta streams_stack_items
	sta streams_output_selected + 1
	sta streams_output_selected + 2
	sta streams_output_selected + 3
	lda #1
	sta streams_buffering
	sta streams_buffering + 1
	sta streams_output_selected
	rts
	
streams_print_output
	; Print a character
	; input:  character in a
	; output:
	; side effects: -
	; affected registers: p
	pha
	lda streams_output_selected + 2
	bne .mem_write
	pla
	jsr translate_zscii_to_petscii
	;jmp printchar_unbuffered
	jmp printchar_buffered
.mem_write
	lda streams_current_entry + 2
	sta .print_byte_to_mem + 1
	lda streams_current_entry + 3
	sta .print_byte_to_mem + 2
	pla
.print_byte_to_mem
	sta $8000 ; Will be modified!
	inc streams_current_entry + 2
	bne +
	inc streams_current_entry + 3
+	rts

z_ins_output_stream
	; Set output stream held in z_operand 0
	; input:  z_operand 0: 1..4 to enable, -1..-4 to disable. If enabling stream 3, also provide z_operand 1: z_address of table
	; output:
	; side effects: Uses zp_temp (2 bytes)
	; used registers: a,x,y
	bit z_operand_value_low_arr
	bmi .negative
	lda z_operand_value_low_arr
	beq .unsupported_stream
	cmp #5
	bcs .unsupported_stream
	tax
	lda #1
	sta streams_output_selected - 1,x
	cpx #3
	beq .turn_on_mem_stream
	rts
.unsupported_stream
    lda #ERROR_UNSUPPORTED_STREAM
	jsr fatalerror
.negative
	lda z_operand_value_low_arr
	cmp #-4
	bmi .unsupported_stream
	eor #$ff
	clc
	adc #1
	cmp #3
	beq .turn_off_mem_stream
	tax
	lda #0
	sta streams_output_selected - 1,x
	rts
.turn_on_mem_stream
	lda streams_stack_items
	beq .add_first_level
	cmp #16
	bcs .stream_nesting_error
	asl
	asl
	tay
	; Move current level to stack
	ldx #3
-	lda streams_current_entry,x
	sta streams_stack - 4 + 3,y
	dey
	dex
	bpl -
.add_first_level
	; Setup pointer to start of table
	lda z_operand_value_low_arr + 1
	sta streams_current_entry
	lda z_operand_value_high_arr + 1
	clc
	adc #>story_start
	sta streams_current_entry + 1
	; Setup pointer to current storage location
	lda streams_current_entry
	adc #2
	sta streams_current_entry + 2
	lda streams_current_entry + 1
	adc #0
	sta streams_current_entry + 3
	inc streams_stack_items
	rts
.stream_nesting_error
    lda #ERROR_STREAM_NESTING_ERROR
	jsr fatalerror
.turn_off_mem_stream
	lda streams_stack_items
	beq .stream_nesting_error
	; Copy length to first word in table
	lda streams_current_entry
	sta zp_temp
	lda streams_current_entry + 1
	sta zp_temp + 1
	lda streams_current_entry + 2
	sec
	sbc #2
	tay
	lda streams_current_entry + 3
	sbc #0
	tax
	tya
	sec
	sbc zp_temp
	ldy #1
	sta (zp_temp),y
	txa
	sbc zp_temp + 1
	dey
	sta (zp_temp),y
	; Pop item off stack
	dec streams_stack_items
	lda streams_stack_items
	beq .remove_first_level
	asl
	asl
	tay
	; Move top stack entry to current level
	ldx #3
-	lda streams_stack - 4 + 3,y
	sta streams_current_entry,x
	dey
	dex
	bpl -
	rts
.remove_first_level
	; Turn off stream 3 output (A is always 0 here)
	sta streams_output_selected + 2
	rts

translate_zscii_to_petscii
	cmp #$5e
	bne +
	lda #$0d
+	sty .streams_tmp + 1
	sta .streams_tmp
	ldy #0
-	lda character_translation_table,y
	beq ++
	iny
	cmp .streams_tmp
	beq +
	iny
	bne - ; Always branch
++	lda .streams_tmp
	jmp +++
+	lda character_translation_table,y
+++	ldy .streams_tmp + 1
; case conversion
	cmp #$41
	bcc .case_conversion_done
	cmp #$5b
	bcs .not_upper_case
	; Upper case. $41 -> $c1
	ora #$80
	bcc .case_conversion_done
.not_upper_case
	cmp #$61
	bcc .case_conversion_done
	cmp #$7b
	bcs .case_conversion_done
	; Lower case. $61 -> $41
	and #$df
.case_conversion_done
	rts
	

	
	
}
