!zone {
stack_init
	lda #<stack_start
	sta stack_ptr
	lda #>stack_start
	sta stack_ptr + 1
	rts

stack_call_routine
	; x = argument number of routine start address
	stx zp_temp + 2
	
	; TASK: Set return address in current frame
	
	; Subtask 1: Get a pointer to last word on stack (pointer to Localcount / z_pc_high)
	lda stack_ptr
	sec
	sbc #2
	sta zp_temp
	lda stack_ptr + 1
	sbc #0
	sta zp_temp + 1
	
	; Subtask 2: Copy value of pointer to Localcount / z_pc_high
	ldy #0
	lda (zp_temp),y
	sta mem_temp
	iny
	lda (zp_temp),y
	sta mem_temp + 1
	
	; Subtask 3: Copy z_pc_instruction to stack
;	lda z_pc_instruction
	lda z_pc
	sta (mem_temp),y
	iny
;	lda z_pc_instruction + 1
	lda z_pc + 1
	sta (mem_temp),y
	iny
;	lda z_pc_instruction + 2
	lda z_pc + 2
	sta (mem_temp),y
	
	; TASK: Create new stack frame
	
	; Subtask 1: Unpack z address to be called
	
	lda #0
	ldx zp_temp + 2
	sta zp_temp
	lda z_operand_high_arr,x
	sta zp_temp + 1
	lda z_operand_low_arr,x
	asl
	rol zp_temp + 1
	rol zp_temp
!ifdef Z4PLUS {
	asl
	rol zp_temp + 1
	rol zp_temp
}
	sta zp_temp + 2

	; Setup local variables
	tay
	ldx zp_temp + 1
	lda zp_temp
;	jsr 

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
