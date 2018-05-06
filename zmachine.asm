z_pc				!byte 0, 0, 0
; z_pc_instruction	!byte 0, 0, 0
z_extended_opcode 	!byte 0
z_operand_count		!byte 0
z_operand_type_arr  !byte 0, 0, 0, 0, 0, 0, 0, 0
z_operand_high_arr  !byte 0, 0, 0, 0, 0, 0, 0, 0
z_operand_low_arr   !byte 0, 0, 0, 0, 0, 0, 0, 0
z_operand_value_high_arr  !byte 0, 0, 0, 0, 0, 0, 0, 0
z_operand_value_low_arr   !byte 0, 0, 0, 0, 0, 0, 0, 0
z_local_var_count	!byte 0
z_global_vars_start	!byte 0, 0

z_opcount_var_jump_high_arr
!ifdef Z4PLUS {
	!byte >z_ins_call_vs
} else {
	!byte >z_ins_call
}

z_opcount_var_jump_low_arr
!ifdef Z4PLUS {
	!byte <z_ins_call_vs
} else {
	!byte <z_ins_call
}

z_last_implemented_var_opcode_number = * - z_opcount_var_jump_low_arr - 1
; These get zeropage addresses in constants.asm:
; z_opcode 
; z_opcode_number
; z_opcode_opcount ; 0 = 0OP, 1=1OP, 2=2OP, 3=VAR

z_opcode_extended = 190
z_opcode_call_vs2 = 236
z_opcode_call_vn2 = 250

z_opcode_opcount_op0 = 0
z_opcode_opcount_op1 = 1
z_opcode_opcount_op2 = 2
z_opcode_opcount_var = 3

z_init
!zone {
	lda #0
	sta z_pc
	lda story_start + header_initial_pc
	sta z_pc + 1
	lda story_start + header_initial_pc + 1
	sta z_pc + 2
	lda story_start + header_globals + 1
	clc
	adc #<(story_start - 32)
	sta z_global_vars_start
	lda story_start + header_globals
	adc #>(story_start - 32)
	sta z_global_vars_start + 1
	rts
}

z_execute
!zone {
.main_loop
	jsr print_following_string
	!pet "starting z_pc",0
	ldx z_pc + 2
	lda z_pc + 1
	jsr printinteger
	lda #$0d
	jsr kernel_printchar
	; Set all operand types to 0, since this will be convenient when ROL:ing types into these bytes
;	lda z_pc
;	sta z_pc_instruction
;	lda z_pc + 1
;	sta z_pc_instruction + 1
;	lda z_pc + 2
;	sta z_pc_instruction + 2
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
	lda #$0d
	jsr kernel_printchar
	lda z_opcode
}
	and #%00011111
	sta z_opcode_number ; This is correct for VAR and LONG forms. Fix others later.
	lda #z_opcode_opcount_op2
	sta z_opcode_opcount ; This is the most common case. Adjust value when other case is found.
	lda z_opcode
	bit z_opcode
	bpl .top_bits_are_0x
	bvc .top_bits_are_10

	; Top bits are 11. Form = Variable
	and #%00100000
	beq +
	inc z_opcode_opcount ; Set to VAR
	bne .get_4_ops ; Always branch
+	ldy #2
	bne .get_y_ops ; Always branch
	
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
	dec z_opcode_opcount ; Set to 1OP
	lda z_operand_type_arr
	cmp #%11
	bne +
	dec z_opcode_opcount ; Set to 0OP
+	ldx #0
	jsr clear_remaining_types
	jmp .read_operands
	
.top_bits_are_0x
!ifdef Z5PLUS {
	cmp #z_opcode_extended
	bne .long_form
	; Form = Extended
	inc z_opcode_opcount ; Set to VAR
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
	beq .get_4_more_ops
	cmp #z_opcode_call_vn2
	beq .get_4_more_ops
	ldx #4
	jsr clear_remaining_types_2
	jmp .read_operands

	; Get another byte of operand types
.get_4_more_ops
	ldy #4
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
	lda z_opcode_opcount
	cmp #z_opcode_opcount_var
	beq .perform_var
	bne .not_implemented ; Always branch
.perform_var
	lda #z_last_implemented_var_opcode_number
	cmp z_opcode_number
	bcc .not_implemented
	ldx z_opcode_number
	lda z_opcount_var_jump_low_arr,x
	sta .jsr_perform + 1
	lda z_opcount_var_jump_high_arr,x
	sta .jsr_perform + 2
.jsr_perform
	jsr $8000
	jmp .main_loop
	
.not_implemented
;	ldx z_opcode
;	jsr printx
;	lda #$0d
;	jsr kernel_printchar
	jsr fatalerror
	!pet "opcode not implemented!",0
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
	beq + ; if x mod 4 == 0
clear_remaining_types_2
	lda #%11
	sta z_operand_type_arr,x
	bne -
+	rts
}

!zone {
get_variable
	; Variable in x
	; Returns value in a,x
	; TODO: Retrieve value
	sty zp_temp + 3
	cpx #0
	beq .read_from_stack
	txa
	cmp #16
	bcs .read_global_var
	; Local variable
	asl
	tay
	iny
	lda (z_local_vars_ptr),y
	tax
	dey
	lda (z_local_vars_ptr),y
	ldy zp_temp + 3
	rts
.read_from_stack
	jsr stack_pull
	ldy zp_temp + 3
	rts
.read_global_var
	ldx #0
	stx zp_temp + 1
	asl
	rol zp_temp + 1
	clc
	adc z_global_vars_start
	sta zp_temp
	lda zp_temp + 1
	adc z_global_vars_start + 1
	sta zp_temp + 1
	ldy #1
	lda (zp_temp),y
	tax
	dey
	lda (zp_temp),y
	ldy zp_temp + 3
	rts
set_variable
	; Value in a,x
	; Variable in y
	; TODO: Store value
	rts
}

!zone {
evaluate_all_args
	ldy #0
-	cpy z_operand_count
	bcs .done
	lda z_operand_type_arr,y
	cmp #%10
	beq .is_var
	lda z_operand_high_arr,y
	sta z_operand_value_high_arr,y
	lda z_operand_low_arr,y
	sta z_operand_value_low_arr,y
	iny
	bne - ; Always branch
.is_var
	ldx z_operand_low_arr,y
	jsr get_variable
	sta z_operand_value_high_arr,y
	txa
	sta z_operand_value_low_arr,y
	iny
	bne - ; Always branch
.done
	rts
}

!zone {
check_for_routine_0
	; If value in argument 0 is 0, set status flag Z to 1 and return 
	lda #0
	cmp z_operand_value_high_arr
	bne +
	cmp z_operand_value_low_arr
+	rts
check_for_routine_0_and_store
	; If value in argument 0 is 0, store 0 in the variable in byte at Z_PC, then set status flag Z to 1 and return 
	jsr check_for_routine_0
	bne .not_0
	jsr read_byte_at_z_pc_then_inc
	tay
	lda #0
	tax
	jsr set_variable
	lda #0
.not_0
	rts
}

!zone {
z_ins_call
z_ins_call_vs
	jsr evaluate_all_args
	jsr check_for_routine_0_and_store
	bne +
	rts
+	ldx z_operand_count
	dex
	ldy #1 ; Store result = 1
	jmp stack_call_routine
}
	
