; Anatomy of a stack frame:
; 
; Number of pushed bytes + 4
; Pushed word n-1
; ...
; Pushed word 0
; ZZZZZZZZ ZZZZZZZZ
; SPPPLLLL 00000ZZZ
; Local variable k-1
; ...
; Local variable 0
; 
; S = Does return address point to a a variable where return value should be stored?
; PPP = Number of parameters with which this routine was called
; LLLL = Number of local variables in this routine
; ZZZ ZZZZZZZZ ZZZZZZZZ = Z_PC to go to when returning from this routine 
;
; Stack pointer actually points to last word of current entry (Number of pushed bytes + 4)

!zone {

.stack_tmp !byte 0, 0, 0 

stack_init
	lda #<(stack_start - 2)
	sta stack_ptr
	lda #>(stack_start - 2)
	sta stack_ptr + 1
	ldx stack_ptr
	lda stack_ptr + 1
!ifdef DEBUG {
	jsr printinteger
	jsr newline
}
	rts

stack_call_routine
	; x = Number of arguments to be passed to routine
	; y = Does Z_PC point to a variable where return value should be stored (0/1)
	stx zp_temp
	sty zp_temp + 1

	; TASK: Save PC. Set new PC. Setup new stack frame.
	ldy #2
-	lda z_pc,y
	sta .stack_tmp,y
	dey
	bpl -
!ifdef Z4PLUS {
!ifdef Z8 {
	ldy #3
} else {
	ldy #2
}
}
	lda #0
	sta z_pc
	lda z_operand_value_high_arr
	sta z_pc + 1
	lda z_operand_value_low_arr
.rol_again
	asl
	rol z_pc + 1
	rol z_pc
!ifdef Z4PLUS {
	dey
	bne .rol_again
}
	sta z_pc + 2
	jsr read_byte_at_z_pc_then_inc
	sta z_local_var_count
	
	; Check that there is room on the stack
	clc
	adc #3
	asl
	adc stack_ptr
	lda stack_ptr + 1
	adc #0
	cmp #>(stack_start + stack_size)
	bcc +
	jmp .stack_full
	
+	lda stack_ptr
	sta z_local_vars_ptr
	lda stack_ptr + 1
	sta z_local_vars_ptr + 1

	; TASK: Setup local vars
	
	ldx #0 ; Index of first argument to be passed to routine - 1
	ldy #2 ; Index of first byte to store local variables
	
-	cpx z_local_var_count
	bcs .setup_of_local_vars_complete
!ifndef Z5PLUS {
	jsr read_byte_at_z_pc_then_inc ; Read first byte of initial var value
}
	cpx zp_temp ; Number of args
	bcs .store_zero_in_local_var
!ifndef Z5PLUS {
	jsr read_byte_at_z_pc_then_inc ; Read second byte of initial var value
}
	lda z_operand_value_high_arr + 1,x
	sta (stack_ptr),y
	iny
	lda z_operand_value_low_arr + 1,x
	sta (stack_ptr),y
	iny
	inx
	bne -
	beq .setup_of_local_vars_complete
.store_zero_in_local_var
!ifdef Z5PLUS {
	lda #0
}
	sta (stack_ptr),y
	iny
!ifndef Z5PLUS {
	jsr read_byte_at_z_pc_then_inc ; Read first byte of initial var value
}
	sta (stack_ptr),y
	iny
	inx
	bne -
.setup_of_local_vars_complete
	
	; TASK: Store old Z_PC, number of local vars, number of arguments and store-result-bit on stack

	lda zp_temp
	ldx zp_temp + 1
	beq +
	ora #%00001000
+	asl
	asl
	asl
	asl
	ora z_local_var_count
	sta (stack_ptr),y
	iny
	lda .stack_tmp
	sta (stack_ptr),y
	iny
	lda .stack_tmp + 1
	sta (stack_ptr),y
	iny
	lda .stack_tmp + 2
	sta (stack_ptr),y

	; TASK: Set number of pushed bytes to 0 (+4)
	iny
	lda #0
	sta (stack_ptr),y
	iny
	lda #4
	sta (stack_ptr),y
	
	; TASK: Set new (higher) value of stack pointer
	dey
	tya
	clc
	adc stack_ptr
	sta stack_ptr
	lda stack_ptr + 1
	adc #0
	sta stack_ptr + 1

	rts

stack_return_from_routine

	; input: return value in a,x
	ldy stack_ptr + 1
	cpy #>stack_start
	bcs +
	jmp .stack_underflow

	; Save input values
+	sta zp_temp
	stx zp_temp + 1
	
	; Skip past all items pushed onto stack in this frame,
	; and 4 bytes lower to read pc and whether to store return value
	lda stack_ptr
	sec
	ldy #1
	sbc (stack_ptr),y
	sta zp_temp + 2
	lda stack_ptr + 1
	dey
	sbc (stack_ptr),y
	sta zp_temp + 3
	lda (zp_temp + 2),y
	sta .stack_tmp ; storebit, argcount, varcount
	
	; Copy PC from stack to z_pc
	iny
-	lda (zp_temp + 2),y
	sta z_pc - 1,y
	iny
	cpy #4
	bcc -
	
	; Skip past locals on stack
	lda z_local_var_count
	clc
	adc #1
	asl
	sta .stack_tmp + 1
	lda zp_temp + 2
	sec
	sbc .stack_tmp + 1
	sta stack_ptr
	lda zp_temp + 3
	sbc #0
	sta stack_ptr + 1

	; TASK: Find new locals pointer value
	; Skip past all items pushed onto stack in this frame
	lda stack_ptr
	sec
	ldy #1
	sbc (stack_ptr),y
	sta zp_temp + 2
	lda stack_ptr + 1
	dey
	sbc (stack_ptr),y
	sta zp_temp + 3
	lda (zp_temp + 2),y
	
	; Skip past locals on stack
	and #$0f
	sta z_local_var_count
	clc
	adc #1
	asl
	sta .stack_tmp + 2
	lda zp_temp + 2
	sec
	sbc .stack_tmp + 2
	sta z_local_vars_ptr
	lda zp_temp + 3
	sbc #0
	sta z_local_vars_ptr + 1

;	jsr fatalerror
;	!pet "return-debug-4!",0
	
	; Store return value if calling instruction asked for it
	bit .stack_tmp
	bpl +
	jsr read_byte_at_z_pc_then_inc
	tay
	lda zp_temp
	ldx zp_temp + 1
	jmp z_set_variable	
+	rts

stack_push
	; Push a,x onto stack
	sta zp_temp
	stx zp_temp + 1
	; Check that there is room
	lda stack_ptr
	cmp #<(stack_start + stack_size - 2)
	bne .there_is_room
	lda stack_ptr + 1
	cmp #>(stack_start + stack_size - 2)
	bne .there_is_room
.stack_full
    lda #ERROR_STACK_FULL
	jsr fatalerror
.there_is_room
	; Increase number of pushed values
	ldy #1
	lda (stack_ptr),y
	clc
	adc #2
	ldy #3
	sta (stack_ptr),y
	ldy #0
	lda (stack_ptr),y
	clc
	adc #0
	ldy #2
	sta (stack_ptr),y
	; Store value
	lda zp_temp
	ldy #0
	sta (stack_ptr),y
	lda zp_temp + 1
	iny
	sta (stack_ptr),y
	; Increase stack pointer
	inc stack_ptr
	inc stack_ptr
	bne +
	inc stack_ptr + 1
+	rts

stack_get_ref_to_top_value
	ldy #1
	lda (stack_ptr),y
	cmp #6
	bcs +
	dey
	lda (stack_ptr),y
	beq .stack_underflow
+	lda stack_ptr
	sec
	sbc #2
	tax
	lda stack_ptr + 1
	sbc #0
	rts

.stack_underflow
    lda #ERROR_STACK_EMPTY
	jsr fatalerror
	
stack_pull
	; Pull top value from stack, return in a,x

	; Check that there are > 0 values on stack
	ldy #1
	lda (stack_ptr),y
	cmp #6
	bcs .ok
	dey
	lda (stack_ptr),y
	bne .ok
.stack_empty_return_0
!ifdef DEBUG {
	jsr print_following_string
	!pet "WARNING: pull from empty stack",13,0
}
	lda #0
	tax
	rts
	
	; Decrease stack pointer by two bytes	
.ok	sec
	lda stack_ptr
	sbc #2
	sta stack_ptr
	bcs +
	lda stack_ptr + 1
	sbc #0
	sta stack_ptr + 1
	; Retrieve the top value on the stack 
+	ldy #0
	lda (stack_ptr),y
	pha
	iny
	lda (stack_ptr),y
	pha
	; Decrease the number of bytes on the stack by 2, and move the value 2 bytes down in memory
	ldy #3
	lda (stack_ptr),y
	sec
	sbc #2
	ldy #1
	sta (stack_ptr),y
	iny
	lda (stack_ptr),y
	sbc #0
	ldy #0
	sta (stack_ptr),y
	pla
	tax
	pla
	rts

z_ins_push
	lda z_operand_value_high_arr
	ldx z_operand_value_low_arr
	jmp stack_push

z_ins_pull
	jsr stack_pull
	pha
	txa
	pha
	ldx z_operand_value_low_arr
	jsr z_get_variable_reference
	stx zp_temp
	sta zp_temp + 1
	ldy #1
	pla
	sta (zp_temp),y
	pla
	dey
	sta (zp_temp),y
	rts
	
z_ins_catch
	; Store pointer to SPPPLLLL-byte in current frame.
	lda stack_ptr
	sec
	ldy #1
	sbc (stack_ptr),y
	tax
	lda stack_ptr + 1
	dey
	sbc (stack_ptr),y
	jmp z_store_result

z_ins_throw
	; Restore pointer given. Add $0004 to pointer. Place value $0004 in that position, to indicate no values have been pushed onto stack.
	lda z_operand_value_low_arr + 1
	clc
	adc #4
	sta stack_ptr
	lda z_operand_value_high_arr + 1
	adc #0
	sta stack_ptr + 1
	ldy #0
	tya
	sta (stack_ptr),y
	iny
	lda #4
	sta (stack_ptr),y
	lda z_operand_value_high_arr
	ldx z_operand_value_low_arr
	jmp stack_return_from_routine
	
z_ins_check_arg_count
	; Skip past all items pushed onto stack in this frame,
	; and 4 bytes lower to read number of arguments
	lda z_operand_value_high_arr
	bne .branch_false
	lda stack_ptr
	sec
	ldy #1
	sbc (stack_ptr),y
	sta zp_temp + 2
	lda stack_ptr + 1
	dey
	sbc (stack_ptr),y
	sta zp_temp + 3
	lda (zp_temp + 2),y
	lsr
	lsr
	lsr
	lsr
	and #7
	cmp z_operand_value_low_arr
	bcc .branch_false
	jmp make_branch_true
.branch_false
	jmp make_branch_false
	
}

