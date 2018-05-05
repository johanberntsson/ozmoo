; Anatomy of a stack frame:
; 
; Number of pushed bytes
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
; Stack pointer actually points to last word of current entry (POINTER TO NEXT FRAME)

!zone {

.stack_tmp !byte 0, 0, 0 

stack_init
	lda #<(stack_start - 2)
	sta stack_ptr
	lda #>(stack_start - 2)
	sta stack_ptr + 1
	rts

stack_call_routine
	; x = Number of arguments to be passed to routine
	; y = Does Z_PC point to a variable where return value should be stored (0/1)
	stx zp_temp
	sty zp_temp + 1

	; TODO: Check that there is room for this frame!
	
	; TASK: Save PC. Set new PC. Setup new stack frame.
	ldy #2
-	lda z_pc,y
	sta .stack_tmp,y
	dey
	bpl -
!ifdef Z3 {
	ldy #1
}
!ifdef Z4 {
	ldy #2
}
!ifdef Z5 {
	ldy #2
}
!ifdef Z8 {
	ldy #3
}
	lda #0
	sta z_pc
	lda z_operand_high_arr
	sta z_pc + 1
	lda z_operand_low_arr
-	asl
	rol z_pc + 1
	rol z_pc + 2
	dey
	bne -
	sta z_pc + 3
	jsr read_byte_at_z_pc_then_inc
	sta zp_temp + 2 ; Number of local vars
	
	inc zp_temp ; Increase by one to allow comparison (decrease after loop)
	inc zp_temp  + 2; Increase by one to allow comparison (decrease after loop)
		ldx #1 ; Index of first argument to be passed to routine
	ldy #2 ; Index of first byte to store local variables
	
-	cpx zp_temp + 2
	bcs .setup_of_local_vars_complete
	cpx zp_temp
	bcs .store_zero_in_local_var
	lda z_operand_value_high_arr,x
	sta (stack_ptr),y
	iny
	lda z_operand_value_low_arr,x
	sta (stack_ptr),y
	iny
	inx
	bne -
	beq .setup_of_local_vars_complete
.store_zero_in_local_var
	lda #0
	sta (stack_ptr),y
	iny
	sta (stack_ptr),y
	inx
	bne -
.setup_of_local_vars_complete
	dec zp_temp
	dec zp_temp + 2
	
	; TASK: Stor old Z_PC etc on stack
	lda zp_temp
	ldx zp_temp + 1
	beq +
	ora #%00001000
+	asl
	asl
	asl
	asl
	ora zp_temp + 2
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
	iny
	lda #0
	sta (stack_ptr),y
	iny
	sta (stack_ptr),y
	
	; TASK: Set new (higher) value of stack pointer
	dey
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
	rts

stack_push
	; Push a,x onto stack
	rts

stack_pop
	; Pop top value from stack, return in a,x
	rts

.push_byte_primitive
	ldy #0
	sta(stack_ptr),y
	inc stack_ptr
	bne +
	inc stack_ptr + 1
	ldy stack_ptr + 1
	cpy #>(stack_start + stack_size)
	bcs .overflow
+	rts
.overflow
	jsr fatalerror
	!pet "stack overflow"
}
