; Anatomy of a stack frame:
; 
; Number of pushed bytes (2*n)
; Pushed word n-1
; ...
; Pushed word 0
; ZZZZZZZZ ZZZZZZZZ
; SPPPLLLL 0000EZZZ
; Local variable k-1
; ...
; Local variable 0
; 
; S = Does return address point to a a variable where return value should be stored?
; PPP = Number of parameters with which this routine was called
; LLLL = Number of local variables in this routine
; E = Execution mode (1 = interrupt, 0 = normal)
; ZZZ ZZZZZZZZ ZZZZZZZZ = Z_PC to go to when returning from this routine 
;
; Stack pointer actually points to Pushed word 0.

!zone {

; stack_tmp !byte 0, 0, 0, 0, 0
; stack_pushed_bytes !byte 0, 0
!ifdef VIEW_STACK_RECORDS {
.stack_pushed_bytes_record 	!byte 0,0
.stack_size_record		!byte 0,0
.stack_size				!byte 0,0
}


stack_init
	lda #<(stack_start)
	sta stack_ptr
	lda #>(stack_start)
	sta stack_ptr + 1
	lda #0
	sta stack_pushed_bytes
	sta stack_pushed_bytes + 1
	sta stack_has_top_value
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
+	
!ifdef VIEW_STACK_RECORDS {
	stx zp_temp + 4
	lda .stack_pushed_bytes_record + 1
	cmp stack_pushed_bytes + 1
	lda .stack_pushed_bytes_record
	sbc stack_pushed_bytes
	bcs .not_push_record
	jsr print_following_string
!pet 13,"=== Pushed bytes record: ",0 
	lda stack_pushed_bytes
	sta .stack_pushed_bytes_record
	ldx stack_pushed_bytes + 1
	stx .stack_pushed_bytes_record + 1
	jsr printinteger
	jsr newline
.not_push_record
	lda stack_ptr
	clc
	adc stack_pushed_bytes + 1
	sta .stack_size + 1
	lda stack_ptr + 1
	adc stack_pushed_bytes
	sec
	sbc #>stack_start
	sta .stack_size
	lda .stack_size_record + 1
	cmp .stack_size + 1
	lda .stack_size_record
	sbc .stack_size
	bcs .no_size_record
	jsr print_following_string
!pet 13,"### Stack size record: ",0 
	lda .stack_size
	sta .stack_size_record
	ldx .stack_size + 1
	stx .stack_size_record + 1
	jsr printinteger
	jsr newline
.no_size_record	
	ldx zp_temp + 4
}

!ifdef CHECK_ERRORS {
; push_check_room
	lda stack_ptr
	clc
	adc stack_pushed_bytes + 1
	lda stack_ptr + 1
	adc stack_pushed_bytes
	cmp #>(stack_start + stack_size)
	bcc .not_full
	jmp .stack_full
.not_full
}
	rts

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
	; a = Mode ($80 = Call read interrupt routine, 0 = Normal)
	; x = Number of arguments to be passed to routine
	; y = Does Z_PC point to a variable where return value should be stored (0/1)
	stx zp_temp
	sty zp_temp + 1
	sta stack_tmp + 4

	; TASK: Wrap up current stack frame
	lda stack_has_top_value
	beq +
	jsr stack_push_top_value
+
	lda stack_pushed_bytes
	bne .many_pushed_bytes
	; Frame has < 256 bytes pushed
	ldy stack_pushed_bytes + 1
	sta (stack_ptr),y
	tya
	iny
	sta (stack_ptr),y
	cpy #1
	beq .current_frame_done
.move_stack_ptr_to_last_word_of_frame
	lda stack_ptr
	clc
	adc stack_pushed_bytes + 1
	sta stack_ptr
	lda stack_ptr + 1
	adc stack_pushed_bytes
	sta stack_ptr + 1

.current_frame_done
	
	; TASK: Save PC. Set new PC. Setup new stack frame.
	lda z_pc
	sta stack_tmp
	lda z_pc + 1
	sta stack_tmp + 1
	lda z_pc + 2
	sta stack_tmp + 2

	lda #0
	asl z_operand_value_low_arr
	rol z_operand_value_high_arr
	rol
!ifdef Z4PLUS {
	asl z_operand_value_low_arr
	rol z_operand_value_high_arr
	rol
!ifdef Z8 {
	asl z_operand_value_low_arr
	rol z_operand_value_high_arr
	rol
}
}

!ifdef Z7 {
	pha
	lda z_operand_value_low_arr
	clc
	adc routine_offset + 2
	sta z_operand_value_low_arr
	lda z_operand_value_high_arr
	adc routine_offset + 1
	sta z_operand_value_high_arr
	pla
	adc routine_offset
}	

	ldx z_operand_value_high_arr
	ldy z_operand_value_low_arr
	
	jsr set_z_pc
	
	+read_next_byte_at_z_pc
	sta z_local_var_count
	
	lda stack_ptr
	sta z_local_vars_ptr
	lda stack_ptr + 1
	sta z_local_vars_ptr + 1

	; TASK: Setup local vars
	
	ldx #0 ; Index of first argument to be passed to routine - 1
	ldy #2 ; Index of first byte to store local variables

	; Copy parameter values to local vars
-	cpx zp_temp ; Number of args
	bcs .store_default_in_remaining_local_vars
	cpx z_local_var_count
	bcs .store_default_in_remaining_local_vars
	lda z_operand_value_high_arr + 1,x
	sta (stack_ptr),y
	iny
	lda z_operand_value_low_arr + 1,x
	sta (stack_ptr),y
	iny
	inx
	bne - ; Always branch

.store_default_in_remaining_local_vars	
	stx zp_temp + 4
!ifndef Z5PLUS {
	; Make z_pc skip over default values
	txa
	beq +
	sty stack_tmp + 3
	asl
	adc z_pc + 2 ; Carry is already clear
	tay
	lda z_pc + 1
	adc #0
	tax
	lda z_pc
	adc #0
	jsr set_z_pc
	ldy stack_tmp + 3
+	
}

; Store default values in remaining vars
	lda z_local_var_count
	sec
	sbc zp_temp + 4
	beq .setup_of_local_vars_complete
	asl
	tax ; Number of bytes to init / copy is now in x

!ifdef Z5PLUS {
	lda #0
}
-
!ifndef Z5PLUS {
	sty stack_tmp + 3
	+read_next_byte_at_z_pc ; Read first byte of initial var value
	ldy stack_tmp + 3
}
	sta (stack_ptr),y
	iny
	dex
	bne -
	
.setup_of_local_vars_complete
	
	; TASK: Store old Z_PC, number of local vars, number of arguments and store-result-bit on stack

!ifdef Z5PLUS {
	; # of arguments is only stored for Z5+
	lda zp_temp ; Arg count
	asl
	asl
	asl
	asl
	ora z_local_var_count
} else {
	lda z_local_var_count
}
	ldx zp_temp + 1 ; Store?
	beq +
	ora #%10000000
+	sta (stack_ptr),y
	iny
	lda stack_tmp + 4 ; Add call mode
	ora stack_tmp
	sta (stack_ptr),y
	iny 
	lda stack_tmp + 1
	sta (stack_ptr),y
	iny
	lda stack_tmp + 2
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
!ifdef CHECK_ERRORS {
	cmp #>(stack_start + stack_size)
	bcs .stack_full
}

!ifdef VIEW_STACK_RECORDS {
	lda stack_ptr
	sta .stack_size + 1
	lda stack_ptr + 1
	sec
	sbc #>stack_start
	sta .stack_size
	lda .stack_size_record + 1
	cmp .stack_size + 1
	lda .stack_size_record
	sbc .stack_size
	bcs .no_size_record_2
	jsr print_following_string
!pet 13,"### Stack size record: ",0 
	lda .stack_size
	sta .stack_size_record
	ldx .stack_size + 1
	stx .stack_size_record + 1
	jsr printinteger
	jsr newline
.no_size_record_2
}
	rts

!ifdef CHECK_ERRORS {
.stack_full
	lda #ERROR_STACK_FULL
	jmp fatalerror
}
	
!ifdef Z5PLUS {	
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

z_ins_catch
	; Store pointer to first byte where pushed values are stored in current frame.
	ldx stack_ptr
	lda stack_ptr + 1
	jmp z_store_result

z_ins_throw
	; Restore pointer given. Return from routine (frame).
	
	; First, restore old stack_ptr, and calculate where # of local vars is stored.
	lda z_operand_value_low_arr + 1
	sec
	sbc #6
	sta zp_temp
	lda z_operand_value_high_arr + 1
	sbc #0
	sta zp_temp + 1
	
	; Retrieve # of local vars, and set z_local_vars_ptr to correct value
	ldy #2
	lda (zp_temp),y
	and #$0f
	sta z_local_var_count
	asl
	sta zp_temp + 2 ; # of bytes used by local vars
	lda zp_temp
	sec
	sbc zp_temp + 2 ; # of bytes used by local vars
	sta z_local_vars_ptr
	lda zp_temp + 1
	sbc #0
	sta z_local_vars_ptr + 1

	; Return from the routine that contained the catch instruction
	lda z_operand_value_high_arr
	ldx z_operand_value_low_arr
;	jmp stack_return_from_routine ; Placed z_ins_throw just before stack_return_from_routine, so no jmp needed
}	

; NOTE: Must follow z_ins_throw
stack_return_from_routine

	; input: return value in a,x

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
	sta stack_tmp ; storebit, argcount, varcount
	
	; Copy PC from stack to z_pc
	iny
	lda (z_local_vars_ptr),y
	tax
	and #$07
	pha ; Top byte of z_pc
!ifdef Z4PLUS {
	txa
	and #$f8
	jsr set_z_exe_mode
}
	iny
	lda (z_local_vars_ptr),y
	tax
	iny
	lda (z_local_vars_ptr),y
	tay
	pla
	jsr set_z_pc
	
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
	sta stack_ptr
	lda z_local_vars_ptr + 1
	dey
	sbc (z_local_vars_ptr),y
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
	sta stack_tmp + 2
	lda zp_temp + 2
	sec
	sbc stack_tmp + 2
	sta z_local_vars_ptr
	lda zp_temp + 3
	sbc #0
	sta z_local_vars_ptr + 1

!ifdef Z4PLUS {	
	; Set interrupt return value, if this was a return from an interrupt
	lda z_exe_mode
	beq +
	lda zp_temp
	sta z_interrupt_return_value
	lda zp_temp + 1
	sta z_interrupt_return_value + 1
+
}

	; Store return value if calling instruction asked for it
	bit stack_tmp
	bmi +
	rts
+	
	lda zp_temp
	ldx zp_temp + 1
;	jmp z_set_variable	; Code is followed by z_store_result which will set the variable

!zone {
z_store_result
	; input: a,x hold result
	; affected: a,x,y
	pha
	+read_next_byte_at_z_pc
	tay
	pla
	jmp z_set_variable
}



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
	beq stack_pull_no_top_value
	lda stack_top_value
	ldx stack_top_value + 1
	dec stack_has_top_value
	rts
stack_pull_no_top_value
	lda stack_pushed_bytes + 1
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
	ldy z_operand_value_low_arr
	jsr z_get_variable_reference_and_value
	pla
	tax
	pla
	jsr z_set_variable_reference_to_value
	rts
	
}
