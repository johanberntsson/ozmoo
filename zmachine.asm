z_pc				!byte 0, 0, 0
z_extended_opcode 	!byte 0
z_operand_count		!byte 0
z_operand_type_arr  !byte 0, 0, 0, 0, 0, 0, 0, 0
z_operand_high_arr  !byte 0, 0, 0, 0, 0, 0, 0, 0
z_operand_low_arr   !byte 0, 0, 0, 0, 0, 0, 0, 0

; These get zeropage addresses in constants.asm:
; z_opcode 
; z_opcode_number

z_opcode_extended = 190
z_opcode_call_vs2 = 236
z_opcode_call_vn2 = 250


z_init
!zone {
	lda #0
	sta z_pc
	lda story_start + header_initial_pc
	sta z_pc + 1
	lda story_start + header_initial_pc + 1
	sta z_pc + 2
	rts
}

z_execute
!zone {
	; Set all operand types to 0, since this will be convenient when ROL:ing types into these bytes
	lda #0
	ldx #7
-	sta z_operand_type_arr,x
	dex
	bpl -

	jsr read_byte_at_z_pc_then_inc
	sta z_opcode
	
!ifdef DEBUG {	
	jsr print_following_string
	!pet "opcode: ",0
	ldx z_opcode
	jsr printx
	lda z_opcode
}
	and #%00011111
	sta z_opcode_number ; This is correct for VAR and LONG forms. Fix others later.
	lda z_opcode
	bit z_opcode
	bpl .top_bits_are_0x
	bvc .top_bits_are_10

	; Top bits are 11. Form = Variable
	and #%00100000
	bne .get_4_ops
	ldy #2
	bne .get_y_ops
	
.top_bits_are_10
	; Form = Short
	and #%00001111
	sta z_opcode_number
	lda z_opcode
	asl
	asl
	asl
	rol z_operand_type_arr
	asl
	rol z_operand_type_arr
	ldx #0
	jsr clear_remaining_types
	jmp .read_operands
	
.top_bits_are_0x
!ifdef Z5PLUS {
	cmp #z_opcode_extended
	bne .long_form
	; Form = Extended
	jsr read_byte_at_z_pc_then_inc
	sta z_extended_opcode
	jmp .get_4_ops
}
	
.long_form	
	; Form = Long
	asl
	sta zp_temp
	lda #%10
	bit zp_temp
	bmi +
	lda #%10
+	sta z_operand_type_arr
	lda #%10
	bvs +
	lda #%01
+	sta z_operand_type_arr + 1
	ldx #1
	jsr clear_remaining_types
	jmp .read_operands
	
.get_4_ops
	ldy #4
.get_y_ops
	ldx #0
	jsr z_get_op_types
	lda z_opcode
	cmp #z_opcode_call_vs2
	beq +
	cmp #z_opcode_call_vn2
	beq +
	ldx #4
	jsr clear_remaining_types_2
	jmp .read_operands

	; Get another byte of operand types
+	ldy #4
	ldx #4
	jsr z_get_op_types

.read_operands
	ldy #0
.read_next_operand
	lda z_operand_type_arr,y
	bne .op_is_not_large_constant
	jsr read_word_at_z_pc_then_inc
	sta z_operand_high_arr,y
	txa
	sta z_operand_low_arr,y
	jmp .op_loaded
.op_is_not_large_constant
	cmp #%11
	beq .op_is_omitted
	lda #0
	sta z_operand_high_arr,y
	jsr read_byte_at_z_pc_then_inc
	sta z_operand_low_arr,y
.op_loaded
	iny
	cpy #8
	bcc .read_next_operand
.op_is_omitted
	sty z_operand_count
	
.process_instruction
	; TODO: Perform the instruction!
	rts
}

z_get_op_types
	; x = index of first operand (0 or 4), y = number of operands (1-4) 
!zone {
	jsr read_byte_at_z_pc_then_inc
.get_next_op_type
	asl
	rol z_operand_type_arr,x
	asl
	rol z_operand_type_arr,x
	inx
	dey
	bne .get_next_op_type
	; Set remaining types to 11 (no operand) up to y = 3 or y = 7
	dex
clear_remaining_types	
-	inx
	txa
	and #%11
	beq +
clear_remaining_types_2
	lda #%11
	sta z_operand_type_arr,x
	bne -
+	rts
}
