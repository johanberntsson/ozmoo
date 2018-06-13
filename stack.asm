; Anatomy of a stack frame:
; 
; Number of pushed bytes (2*n)
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

.stack_tmp !byte 0, 0, 0, 0
stack_pushed_bytes !byte 0, 0

stack_init
	lda #<(stack_start)
	sta stack_ptr
	lda #>(stack_start)
	sta stack_ptr + 1
	lda #0
	sta stack_pushed_bytes
	sta stack_pushed_bytes + 1
	sta stack_has_top_value
	; tay
; -	sta stack_start,y
	; iny
	; cpy #4
	; bcc -

; !ifdef DEBUG {
	; ldx stack_ptr
	; lda stack_ptr + 1
	; jsr printinteger
	; jsr newline
; }
	rts

	
stack_push_top_value
	; prerequisites: Caller must check that stack_has_top_value > 0
	; uses: a,y
	; Note: Does not change stack_has_top_value! Caller must do this as needed.
+	lda stack_ptr
	clc
	adc stack_pushed_bytes + 1
	sta zp_temp + 2
	lda stack_ptr + 1
	adc stack_pushed_bytes
	sta zp_temp + 3
	ldy #0
	lda stack_top_value
	sta (zp_temp + 2),y
	iny
	lda stack_top_value + 1
	sta (zp_temp + 2),y
	inc stack_pushed_bytes + 1	
	inc stack_pushed_bytes + 1
	bne .top_done
	inc stack_pushed_bytes
.top_done
+	lda stack_pushed_bytes
	cmp #>(stack_start + stack_size - 256)
	bcs .push_check_room
-	rts
.push_check_room
	lda stack_ptr
	clc
	adc stack_pushed_bytes + 1
	lda stack_ptr + 1
	adc stack_pushed_bytes
	cmp #>(stack_start + stack_size)
	bcc -
	jmp .stack_full

; This is used by stack_call_routine	
.many_pushed_bytes
	lda stack_ptr
	clc
	adc stack_pushed_bytes + 1
	sta zp_temp + 2
	lda stack_ptr + 1
	adc stack_pushed_bytes
	sta zp_temp + 3
	ldy #0
	lda stack_pushed_bytes
	sta (zp_temp + 2),y
	iny
	lda stack_pushed_bytes + 1
	sta (zp_temp + 2),y
	jmp .move_stack_ptr_to_last_word_of_frame

stack_call_routine
	; x = Number of arguments to be passed to routine
	; y = Does Z_PC point to a variable where return value should be stored (0/1)
	stx zp_temp
	sty zp_temp + 1

	; TASK: Wrap up current stack frame
	lda stack_has_top_value
	beq +
	jsr stack_push_top_value
+
;	lda stack_ptr + 1
;	cmp #>stack_start
;	bcc .current_frame_done ; There is no current frame, so no need to close it either
	lda stack_pushed_bytes
	bne .many_pushed_bytes
	; Frame has < 256 bytes pushed
	ldy stack_pushed_bytes + 1
	beq .no_pushed_bytes
	sta (stack_ptr),y
	tya
	iny
	sta (stack_ptr),y
.move_stack_ptr_to_last_word_of_frame
	lda stack_ptr
	clc
	adc stack_pushed_bytes + 1
	sta stack_ptr
	lda stack_ptr + 1
	adc stack_pushed_bytes
	sta stack_ptr + 1
	bne .current_frame_done ; Always branch
.no_pushed_bytes
	sta (stack_ptr),y
	tya
	iny
	sta (stack_ptr),y
.current_frame_done
	
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
	
	; Check if we changed page
	lda .stack_tmp + 1
	cmp z_pc + 1
	bne +
	lda .stack_tmp
	cmp z_pc
	beq ++
+	inc z_pc_mempointer_is_unsafe
++
	
	+read_next_byte_at_z_pc
;	jsr read_byte_at_z_pc_then_inc
	sta z_local_var_count
	
	lda stack_ptr
	sta z_local_vars_ptr
	lda stack_ptr + 1
	sta z_local_vars_ptr + 1

	; TASK: Setup local vars
	
	ldx #0 ; Index of first argument to be passed to routine - 1
	ldy #2 ; Index of first byte to store local variables
	
-	cpx z_local_var_count
	bcs .setup_of_local_vars_complete
!ifndef Z5PLUS {
	sty .stack_tmp + 3
	+read_next_byte_at_z_pc
	ldy .stack_tmp + 3
;	jsr read_byte_at_z_pc_then_inc ; Read first byte of initial var value
}
	cpx zp_temp ; Number of args
	bcs .store_zero_in_local_var
!ifndef Z5PLUS {
	sty .stack_tmp + 3
	+read_next_byte_at_z_pc
	ldy .stack_tmp + 3
;	jsr read_byte_at_z_pc_then_inc ; Read second byte of initial var value
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
	sty .stack_tmp + 3
	+read_next_byte_at_z_pc
	ldy .stack_tmp + 3
;	jsr read_byte_at_z_pc_then_inc ; Read first byte of initial var value
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

	; TASK: Set number of pushed bytes to 0
	lda #0
	sta stack_has_top_value
	sta stack_pushed_bytes
	sta stack_pushed_bytes + 1
	
	; TASK: Set new (higher) value of stack pointer
	iny
	tya
	clc
	adc stack_ptr
	sta stack_ptr
	lda stack_ptr + 1
	adc #0
	sta stack_ptr + 1
	cmp #>(stack_start + stack_size)
	bcs .stack_full
	
	rts

.stack_full
    lda #ERROR_STACK_FULL
	jmp fatalerror
	
stack_return_from_routine

	; input: return value in a,x
	; ldy stack_ptr + 1
	; cpy #>stack_start
	; bcs +
	; jmp .stack_underflow

	; Save input values
+	sta zp_temp
	stx zp_temp + 1
	
	; Read pc to return to and whether to store return value in this frame
	ldy z_local_var_count
	iny
	tya
	asl
	tay
	lda (z_local_vars_ptr),y
	sta .stack_tmp ; storebit, argcount, varcount
	
	; Copy PC from stack to z_pc
	iny
	ldx #0
-	lda z_pc,x
	sta .stack_tmp + 1,x
	lda (z_local_vars_ptr),y
	sta z_pc,x
	iny
	inx
	cpx #3
	bcc -

	; Check if we changed page
	lda .stack_tmp + 2
	cmp z_pc + 1
	bne +
	lda .stack_tmp + 1
	cmp z_pc
	beq ++
+	inc z_pc_mempointer_is_unsafe
++
	
	; TASK: Set stack_pushed_bytes to new value
	ldy #0
	sty stack_has_top_value
	lda (z_local_vars_ptr),y
	sta stack_pushed_bytes
	iny
	lda (z_local_vars_ptr),y
	sta stack_pushed_bytes + 1
	
	; TASK: Find new locals pointer value
	; Skip past all items pushed onto stack in this frame
	
	; First, set stack_ptr correctly
	lda z_local_vars_ptr
	sec
;	ldy #1 ; Not needed, has right value already
	sbc (z_local_vars_ptr),y
	tax
	lda z_local_vars_ptr + 1
	dey
	sbc (z_local_vars_ptr),y
	tay

	txa
	sbc #0 ; Carry should always be set after last operation
	sta stack_ptr
	tya
	sbc #0
	sta stack_ptr + 1
	
	; Find # of locals
	lda stack_ptr
	sbc #4 ; Carry should always be set after last operation
	sta zp_temp + 2
	lda stack_ptr + 1
	sbc #0
	sta zp_temp + 3
	ldy #0
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
	
	; Store return value if calling instruction asked for it
	bit .stack_tmp
	bpl +
	+read_next_byte_at_z_pc
;	jsr read_byte_at_z_pc_then_inc
	tay
	lda zp_temp
	ldx zp_temp + 1
	jmp z_set_variable	
+	
	; lda #ERROR_READ_ABOVE_STATMEM
	; jmp fatalerror

	rts

stack_push
	; Push a,x onto stack
	ldy stack_has_top_value
	bne +
	sta stack_top_value
	stx stack_top_value + 1
	inc stack_has_top_value
	rts
+	sta zp_temp
	jsr stack_push_top_value
	lda zp_temp
	sta stack_top_value
	stx stack_top_value + 1
	rts
	
stack_get_ref_to_top_value
	ldy stack_has_top_value
	beq +
	lda #>stack_top_value
	ldx #<stack_top_value
	rts
+
!ifdef DEBUG {	
	ldx stack_pushed_bytes + 1
	beq .stack_underflow
}
	clc
	lda stack_pushed_bytes + 1
	adc stack_ptr
	tax
	lda stack_pushed_bytes
	adc stack_ptr + 1
	tay
	txa
	sec
	sbc #2
	tax
	tya
	sbc #0
	rts

!ifdef DEBUG {	
.stack_underflow
    lda #ERROR_STACK_EMPTY
	jmp fatalerror
}

stack_pull
	; Pull top value from stack, return in a,x
	ldy stack_has_top_value
	beq +
	lda stack_top_value
	ldx stack_top_value + 1
	dec stack_has_top_value
	rts
+	lda stack_pushed_bytes + 1
	beq .stack_empty_return_0
	; Decrease # of bytes on stack
	sec
	sbc #2
	sta stack_pushed_bytes + 1
	tax
	lda stack_pushed_bytes
	sbc #0
	sta stack_pushed_bytes
	tay
	; Calculate address of top value
	txa
	clc
	adc stack_ptr
	sta zp_temp
	tya
	adc stack_ptr + 1
	sta zp_temp + 1
	; Load value and return
	ldy #1
	lda (zp_temp),y
	tax
	dey
	lda (zp_temp),y
	rts

.stack_empty_return_0
!ifdef DEBUG {
	jsr print_following_string
	!pet "WARNING: pull from empty stack",13,0
}
	lda #0
	tax
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

!ifdef Z5PLUS {	
z_ins_catch
	; Store pointer to first byte where pushed values are stored in current frame.
	ldx stack_ptr
	lda stack_ptr + 1
	; lda stack_ptr
	; sec
	; ldy #1
	; sbc (stack_ptr),y
	; tax
	; lda stack_ptr + 1
	; dey
	; sbc (stack_ptr),y
	jmp z_store_result

z_ins_throw
	; Restore pointer given. Return from routine (frame).
	lda z_operand_value_low_arr + 1
	sta stack_ptr
	lda z_operand_value_high_arr + 1
	sta stack_ptr + 1
	lda z_operand_value_high_arr
	ldx z_operand_value_low_arr
	jmp stack_return_from_routine
	
z_ins_check_arg_count
	; Read number of arguments provided to this routine
	lda z_operand_value_high_arr
	bne .branch_false
	ldy z_local_var_count
	iny
	tya
	asl
	tay
	lda (z_local_vars_ptr),y
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
	
}

