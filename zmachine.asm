z_pc				!byte 0, $10, 0
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

z_opcount_0op_jump_high_arr
	!byte >z_ins_rtrue
	!byte >z_ins_rfalse
	!byte >z_ins_print
	!byte >z_not_implemented
	!byte >z_not_implemented
	!byte >z_not_implemented
	!byte >z_not_implemented
	!byte >z_not_implemented
	!byte >z_not_implemented
	!byte >z_not_implemented
	!byte >z_not_implemented
	!byte >z_ins_new_line
	

z_opcount_0op_jump_low_arr
	!byte <z_ins_rtrue
	!byte <z_ins_rfalse
	!byte <z_ins_print
	!byte <z_not_implemented
	!byte <z_not_implemented
	!byte <z_not_implemented
	!byte <z_not_implemented
	!byte <z_not_implemented
	!byte <z_not_implemented
	!byte <z_not_implemented
	!byte <z_not_implemented
	!byte <z_ins_new_line
	
z_last_implemented_0op_opcode_number = * - z_opcount_0op_jump_low_arr - 1



z_opcount_1op_jump_high_arr
	!byte >z_ins_jz
	!byte >z_ins_get_sibling
	!byte >z_ins_get_child
	!byte >z_ins_get_parent
	!byte >z_ins_get_prop_len
	!byte >z_ins_inc
	!byte >z_ins_dec
	!byte >z_ins_print_addr
	!byte >z_not_implemented
	!byte >z_ins_remove_obj
	!byte >z_ins_print_obj
	!byte >z_not_implemented
	!byte >z_ins_jump
	!byte >z_ins_print_paddr

z_opcount_1op_jump_low_arr
	!byte <z_ins_jz
	!byte <z_ins_get_sibling
	!byte <z_ins_get_child
	!byte <z_ins_get_parent
	!byte <z_ins_get_prop_len
	!byte <z_ins_inc
	!byte <z_ins_dec
	!byte <z_ins_print_addr
	!byte <z_not_implemented
	!byte <z_ins_remove_obj
	!byte <z_ins_print_obj
	!byte <z_not_implemented
	!byte <z_ins_jump
	!byte <z_ins_print_paddr
	
z_last_implemented_1op_opcode_number = * - z_opcount_1op_jump_low_arr - 1

z_opcount_2op_jump_high_arr
	!byte >z_not_implemented
	!byte >z_ins_je
	!byte >z_ins_jl
	!byte >z_ins_jg
	!byte >z_not_implemented
	!byte >z_not_implemented
	!byte >z_ins_jin
	!byte >z_not_implemented
	!byte >z_not_implemented
	!byte >z_ins_and
	!byte >z_ins_test_attr
	!byte >z_ins_set_attr
	!byte >z_ins_clear_attr
	!byte >z_ins_store
	!byte >z_ins_insert_obj
	!byte >z_ins_loadw
	!byte >z_ins_loadb
	!byte >z_ins_get_prop
	!byte >z_ins_get_prop_addr
	!byte >z_ins_get_next_prop
	!byte >z_ins_add
	!byte >z_ins_sub
	!byte >z_ins_mul
	!byte >z_not_implemented
	!byte >z_not_implemented
	!byte >z_not_implemented
	!byte >z_ins_call_2n

z_opcount_2op_jump_low_arr
	!byte <z_not_implemented
	!byte <z_ins_je
	!byte <z_ins_jl
	!byte <z_ins_jg
	!byte <z_not_implemented
	!byte <z_not_implemented
	!byte <z_ins_jin
	!byte <z_not_implemented
	!byte <z_not_implemented
	!byte <z_ins_and
	!byte <z_ins_test_attr
	!byte <z_ins_set_attr
	!byte <z_ins_clear_attr
	!byte <z_ins_store
	!byte <z_ins_insert_obj
	!byte <z_ins_loadw
	!byte <z_ins_loadb
	!byte <z_ins_get_prop
	!byte <z_ins_get_prop_addr
	!byte <z_ins_get_next_prop
	!byte <z_ins_add
	!byte <z_ins_sub
	!byte <z_ins_mul
	!byte <z_not_implemented
	!byte <z_not_implemented
	!byte <z_not_implemented
	!byte <z_ins_call_2n
	
z_last_implemented_2op_opcode_number = * - z_opcount_2op_jump_low_arr - 1

z_opcount_var_jump_high_arr
!ifdef Z4PLUS {
	!byte >z_ins_call_vs
} else {
	!byte >z_ins_call
}
	!byte >z_not_implemented
	!byte >z_ins_storeb
	!byte >z_ins_put_prop
!ifndef Z5PLUS {
	!byte >z_ins_sread
} else {
	!byte >z_ins_aread
}
	!byte >z_not_implemented
	!byte >z_not_implemented
	!byte >z_not_implemented
	!byte >z_not_implemented
	!byte >z_not_implemented
	!byte >z_not_implemented
	!byte >z_not_implemented
	!byte >z_not_implemented
	!byte >z_not_implemented
	!byte >z_not_implemented
	!byte >z_not_implemented
	!byte >z_not_implemented
	!byte >z_not_implemented
	!byte >z_not_implemented
	!byte >z_ins_output_stream


z_opcount_var_jump_low_arr
!ifdef Z4PLUS {
	!byte <z_ins_call_vs
} else {
	!byte <z_ins_call
}
	!byte <z_not_implemented
	!byte <z_ins_storeb
	!byte <z_ins_put_prop
!ifndef Z5PLUS {
	!byte <z_ins_sread
} else {
	!byte <z_ins_aread
}
	!byte <z_not_implemented
	!byte <z_not_implemented
	!byte <z_not_implemented
	!byte <z_not_implemented
	!byte <z_not_implemented
	!byte <z_not_implemented
	!byte <z_not_implemented
	!byte <z_not_implemented
	!byte <z_not_implemented
	!byte <z_not_implemented
	!byte <z_not_implemented
	!byte <z_not_implemented
	!byte <z_not_implemented
	!byte <z_not_implemented
	!byte <z_ins_output_stream

z_last_implemented_var_opcode_number = * - z_opcount_var_jump_low_arr - 1
; These get zeropage addresses in constants.asm:
; z_opcode 
; z_opcode_number
; z_opcode_opcount ; 0 = 0OP, 1=1OP, 2=2OP, 3=VAR

z_opcode_extended = 190
z_opcode_call_vs2 = 236
z_opcode_call_vn2 = 250

z_opcode_opcount_0op = 0
z_opcode_opcount_1op = 1
z_opcode_opcount_2op = 2
z_opcode_opcount_var = 3

z_init
!zone {
	; Copy z_pc from header
	lda #0
	sta z_pc
	lda story_start + header_initial_pc
	sta z_pc + 1
	lda story_start + header_initial_pc + 1
	sta z_pc + 2

	; Setup globals pointer
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
	jsr print_following_string
	!pet " @ ",0
	ldx z_pc + 2
	lda z_pc + 1
	jsr printinteger
	lda #$0d
	jsr kernel_printchar
	lda z_opcode
}
	and #%00011111
	sta z_opcode_number ; This is correct for VAR and LONG forms. Fix others later.
	lda #z_opcode_opcount_2op
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
	lda #%01
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
	jsr read_byte_at_z_pc_then_inc
	sta z_operand_low_arr,y
	tax
	lda #0
	cpx #$80
	bcc +
	lda #$ff
+	sta z_operand_high_arr,y
.op_loaded
	iny
	cpy #8
	bcc .read_next_operand
.op_is_omitted
	sty z_operand_count
	
.process_instruction
	; TODO: Perform the instruction!
	lda z_opcode_opcount
	cmp #z_opcode_opcount_0op
	beq .perform_0op
	cmp #z_opcode_opcount_1op
	beq .perform_1op
	cmp #z_opcode_opcount_2op
	beq .perform_2op
	cmp #z_opcode_opcount_var
	beq .perform_var
	bne z_not_implemented ; Always branch
.perform_0op
	lda #z_last_implemented_0op_opcode_number
	cmp z_opcode_number
	bcc z_not_implemented
	ldx z_opcode_number
	lda z_opcount_0op_jump_low_arr,x
	sta .jsr_perform + 1
	lda z_opcount_0op_jump_high_arr,x
	sta .jsr_perform + 2
	bne .jsr_perform ; Always branch
.perform_1op
	lda #z_last_implemented_1op_opcode_number
	cmp z_opcode_number
	bcc z_not_implemented
	ldx z_opcode_number
	lda z_opcount_1op_jump_low_arr,x
	sta .jsr_perform + 1
	lda z_opcount_1op_jump_high_arr,x
	sta .jsr_perform + 2
	bne .jsr_perform ; Always branch
.perform_2op
	lda #z_last_implemented_2op_opcode_number
	cmp z_opcode_number
	bcc z_not_implemented
	ldx z_opcode_number
	lda z_opcount_2op_jump_low_arr,x
	sta .jsr_perform + 1
	lda z_opcount_2op_jump_high_arr,x
	sta .jsr_perform + 2
	bne .jsr_perform ; Always branch
.perform_var
	lda #z_last_implemented_var_opcode_number
	cmp z_opcode_number
	bcc z_not_implemented
	ldx z_opcode_number
	lda z_opcount_var_jump_low_arr,x
	sta .jsr_perform + 1
	lda z_opcount_var_jump_high_arr,x
	sta .jsr_perform + 2
.jsr_perform
	jsr $8000
	jmp .main_loop
	
z_not_implemented
;	ldx z_opcode
;	jsr printx
;	lda #$0d
;	jsr kernel_printchar
!ifndef DEBUG {
	jsr print_following_string
	!pet "opcode: ",0
	ldx z_opcode
	jsr printx
	jsr print_following_string
	!pet " @ ",0
	ldx z_pc + 2
	lda z_pc + 1
	jsr printinteger
	lda #$0d
	jsr kernel_printchar
}
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
z_get_variable_reference
	; input: Variable in x
	; output: Address is returned in a,x
	; affects registers: p
	sty zp_temp + 3
	cpx #0
	beq .find_on_stack
	txa
	cmp #16
	bcs .find_global_var
	; Local variable
	asl
	clc
	adc z_local_vars_ptr
	tax
	lda z_local_vars_ptr + 1
	adc #0
	ldy zp_temp + 3
	rts
.find_on_stack
	lda stack_ptr
	sec
	sbc #2
	tax
	lda stack_ptr + 1
	sbc #0
	ldy zp_temp + 3
	rts
.find_global_var
	ldx #0
	stx zp_temp + 1
	asl
	rol zp_temp + 1
	clc
	adc z_global_vars_start
	tax
	lda zp_temp + 1
	adc z_global_vars_start + 1
	ldy zp_temp + 3
	rts

z_get_variable_value
	; Variable in x
	; Returns value in a,x
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

z_set_variable
	; Value in a,x
	; Variable in y
	cpy #0
	beq .write_to_stack
	sta zp_temp + 2
	stx zp_temp + 3
	tya
	cmp #16
	bcs .write_global_var
	; Local variable
	asl
	tay
	lda zp_temp + 2
	sta (z_local_vars_ptr),y
	iny
	lda zp_temp + 3
	sta (z_local_vars_ptr),y
	rts
.write_to_stack
	jsr stack_push
	rts
.write_global_var
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
	ldy #0
	lda zp_temp + 2
	sta (zp_temp),y
	iny
	lda zp_temp + 3
	sta (zp_temp),y
	rts
}

!zone {
evaluate_all_args
	ldx #$ff
evaluate_all_args_except_x
	stx zp_temp + 2
	ldy #0
-	cpy z_operand_count
	bcs .done
	cpy zp_temp + 2
	beq .not_this_one
	lda z_operand_type_arr,y
	cmp #%10
	beq .is_var
	lda z_operand_high_arr,y
	sta z_operand_value_high_arr,y
	lda z_operand_low_arr,y
	sta z_operand_value_low_arr,y
.not_this_one	
	iny
	bne - ; Always branch
.is_var
	ldx z_operand_low_arr,y
	jsr z_get_variable_value
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
	jsr z_set_variable
	lda #0
.not_0
	rts
}

!zone {
make_branch_true
	lda #$80
	bne +
make_branch_false
	lda #0
+	sta zp_temp
	jsr read_byte_at_z_pc_then_inc
	sta zp_temp + 1 ; First byte of branch data
	and #$c0
	eor #$80 ; Invert top bit, since 0 means branch if condition = false
	eor zp_temp
	sta zp_temp ; Top bit in zp_temp has now been inverted if it should. Ignore other bits.
	and #$40
	bne +
	; This is a 14-bit offset
	jsr read_byte_at_z_pc_then_inc
	sta zp_temp + 2 ; Second byte of branch data
	; Check if we should actually branch
+	bit zp_temp ; Top bit = 1 : branch
	bpl .done
	; Calculate and perform the jump
	bit zp_temp + 1
	bvc .two_byte_jump
	lda zp_temp + 1
	and #%00111111
	sta zp_temp + 2
	lda #0
	sta zp_temp + 1
	sta zp_temp
	beq .both_jumps
.two_byte_jump
	lda zp_temp + 1
	and #%00111111
	tax
	and #%00100000
	beq +
	; Propagate minus bit
	txa
	ora #%11000000
	sta zp_temp + 1
	lda #$ff
	sta zp_temp
	bne .both_jumps ; Always branch
+	txa
	sta zp_temp + 1
	lda #0
	sta zp_temp
.both_jumps
	ldx zp_temp + 2
	cpx #2
	bcs z_jump_to_offset_in_zp_temp
	lda zp_temp
	ora zp_temp + 1
	bne z_jump_to_offset_in_zp_temp
	; Return value in x	
	lda #0
	jmp stack_return_from_routine
z_jump_to_offset_in_zp_temp
	lda z_pc + 2
	clc
	adc zp_temp + 2
	tax
	lda z_pc + 1
	adc zp_temp + 1
	tay
	lda z_pc
	adc zp_temp
	pha
	txa
	sec
	sbc #2
	sta z_pc + 2
	tya
	sbc #0
	sta z_pc + 1
	pla
	sbc #0
	sta z_pc
.done
	rts
}

!zone {
z_store_result
	; input: a,x hold result
	pha
	jsr read_byte_at_z_pc_then_inc
	tay
	pla
	jmp z_set_variable
}

!zone {
calc_address_in_byte_array
	lda z_operand_value_low_arr
	clc
	adc z_operand_value_low_arr + 1
	sta zp_temp
	lda z_operand_value_high_arr
	adc z_operand_value_high_arr + 1
	adc #>story_start
	sta zp_temp + 1
	ldy #0
	rts
}

!zone {
; 0OP instructions
z_ins_rtrue
	lda #0
	ldx #1
	jmp stack_return_from_routine

z_ins_rfalse
	lda #0
	tax
	jmp stack_return_from_routine

; z_ins_print (moved to text.asm)

; z_ins_new_line (moved to text.asm)


; 1OP instructions

z_ins_jz
	jsr evaluate_all_args
	lda z_operand_value_low_arr
	ora z_operand_value_high_arr
	beq .branch_true
	bne .branch_false

; z_ins_get_sibling (moved to objecttable.asm)

; z_ins_get_child (moved to objecttable.asm)

; z_ins_get_parent (moved to objecttable.asm)

; z_ins_get_prop_len (moved to objecttable.asm)

z_ins_inc
	ldx z_operand_low_arr
	jsr z_get_variable_reference
	stx .ins_inc + 1
	sta .ins_inc + 2
	ldx #1
.ins_inc
	inc $0400,x
	bne +
	dex
	bpl .ins_inc
+	rts	
	
z_ins_dec
	ldx z_operand_low_arr
	jsr z_get_variable_reference
	stx .ins_dec + 1
	sta .ins_dec + 2
	ldx #1
.ins_dec
	dec $0400,x
	bne +
	dex
	bpl .ins_inc
+	rts

; z_ins_print_addr (moved to text.asm)
	
; z_ins_remove_obj (moved to objecttable.asm)

; z_ins_print_obj (moved to objecttable.asm)

z_ins_jump
	jsr evaluate_all_args
	lda #0
	bit z_operand_value_high_arr
	bpl +
	lda #$ff
+	sta zp_temp
	lda z_operand_value_high_arr
	sta zp_temp + 1
	lda z_operand_value_low_arr
	sta zp_temp + 2
	jmp z_jump_to_offset_in_zp_temp

; z_ins_print_paddr (moved to text.asm)

; 2OP instructions
z_ins_je
	jsr evaluate_all_args
	lda z_operand_value_low_arr
	cmp z_operand_value_low_arr + 1
	bne .branch_false
	lda z_operand_value_high_arr
	cmp z_operand_value_high_arr + 1
	beq .branch_true
.branch_false
	jmp make_branch_false
.branch_true
	jmp make_branch_true
z_ins_jl
	jsr evaluate_all_args
	lda z_operand_value_low_arr
	cmp z_operand_value_low_arr + 1
	lda z_operand_value_high_arr
	sbc z_operand_value_high_arr + 1
	bcc .branch_true
	jmp make_branch_false
z_ins_jg
	jsr evaluate_all_args
	lda z_operand_value_low_arr + 1
	cmp z_operand_value_low_arr
	lda z_operand_value_high_arr + 1
	sbc z_operand_value_high_arr
	bcc .branch_true
	jmp make_branch_false

; z_ins_jin (moved to objecttable.asm)
	
; z_ins_test_attr (moved to objecttable.asm)

z_ins_and
	jsr evaluate_all_args
	lda z_operand_value_low_arr
	and z_operand_value_low_arr + 1
	tax
	lda z_operand_value_high_arr
	and z_operand_value_high_arr + 1
	jmp z_store_result

; z_ins_set_attr (moved to objecttable.asm)
	
; z_ins_clear_attr (moved to objecttable.asm)
	
z_ins_store
	ldx #0
	jsr evaluate_all_args_except_x
	ldy z_operand_low_arr
	lda z_operand_value_high_arr + 1
	ldx z_operand_value_low_arr + 1
	jmp z_set_variable

; z_ins_insert_obj (moved to objecttable.asm)
	
z_ins_loadw
	jsr evaluate_all_args
	asl z_operand_value_low_arr + 1 
	rol z_operand_value_high_arr + 1
	lda z_operand_value_low_arr
	clc
	adc z_operand_value_low_arr + 1
	sta zp_temp
	lda z_operand_value_high_arr
	adc z_operand_value_high_arr + 1
	adc #>story_start
	sta zp_temp + 1
	ldy #1
	lda (zp_temp),y
	tax
	dey
	lda (zp_temp),y
	jmp z_store_result

z_ins_loadb
	jsr evaluate_all_args
	jsr calc_address_in_byte_array
	lda (zp_temp),y
	tax
	tya
	jmp z_store_result

; z_ins_get_prop (moved to objecttable.asm)
	
; z_ins_get_prop_addr (moved to objecttable.asm)

; z_ins_get_next_prop (moved to objecttable.asm)

z_ins_add
	jsr evaluate_all_args
	lda z_operand_value_low_arr
	clc
	adc z_operand_value_low_arr + 1
	tax
	lda z_operand_value_high_arr
	adc z_operand_value_high_arr + 1
	jmp z_store_result

z_ins_sub
	jsr evaluate_all_args
	lda z_operand_value_low_arr
	sec
	sbc z_operand_value_low_arr + 1
	tax
	lda z_operand_value_high_arr
	sbc z_operand_value_high_arr + 1
	jmp z_store_result

.mul_product = memory_buffer ; 5 bytes (4 for product + 1 for last bit)
.mul_inv_multiplicand = memory_buffer + 5 ; 2 bytes

z_ins_mul
	jsr evaluate_all_args
	lda #0
	ldy #16
	sta .mul_product
	sta .mul_product + 1
	sta .mul_product + 4
	lda z_operand_value_high_arr
	sta .mul_product + 2
	lda z_operand_value_low_arr
	sta .mul_product + 3
	lda z_operand_value_low_arr + 1
	eor #$ff
	clc
	adc #1
	sta .mul_inv_multiplicand + 1
	lda z_operand_value_high_arr + 1
	eor #$ff
	adc #0
	sta .mul_inv_multiplicand
	; Perform multiplication
.mul_next_iteration
	lda .mul_product + 3
	and #1
	beq .mul_bottom_is_0
	; Bottom bit is 1
	bit .mul_product + 4
	bmi .mul_do_nothing
	; Subtract
	lda .mul_product + 1
	clc
	adc .mul_inv_multiplicand + 1
	sta .mul_product + 1
	lda .mul_product
	adc .mul_inv_multiplicand
	sta .mul_product
	jmp .mul_do_nothing
.mul_bottom_is_0
	; Bottom bit is 0
	bit .mul_product + 4
	bpl .mul_do_nothing
	; Add
	lda .mul_product + 1
	clc
	adc z_operand_value_low_arr + 1
	sta .mul_product + 1
	lda .mul_product
	adc z_operand_value_high_arr + 1
	sta .mul_product
.mul_do_nothing
	clc
	bit .mul_product
	bpl +
	sec
+	ror .mul_product
	ror .mul_product + 1
	ror .mul_product + 2
	ror .mul_product + 3
	ror .mul_product + 4
	dey
	bne .mul_next_iteration
	lda .mul_product + 2
	ldx .mul_product + 3
	jmp z_store_result
	
z_ins_call_2n
	jsr evaluate_all_args
	jsr check_for_routine_0_and_store
	bne +
	rts
+	ldx z_operand_count
	dex
	ldy #0 ; Don't store result
	jmp stack_call_routine
	
; VAR instructions
	
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

z_ins_storeb
	jsr evaluate_all_args
	jsr calc_address_in_byte_array
	lda z_operand_value_low_arr + 2
	sta (zp_temp),y
	rts

; z_ins_put_prop (moved to objecttable.asm)
	
; z_ins_sread / z_ins_aread (moved to text.asm)
	
z_ins_output_stream
	jsr evaluate_all_args
	jmp streams_output_stream
}
	
	
