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
	ldx stack_ptr
	lda stack_ptr + 1
	jsr printinteger
	lda #$0d
	jsr kernel_printchar
	rts

stack_call_routine
	; x = Number of arguments to be passed to routine
	; y = Does Z_PC point to a variable where return value should be stored (0/1)
	stx zp_temp
	sty zp_temp + 1

;	jsr print_following_string
;	!pet "incoming z_pc",0
;	ldx z_pc + 2
;	lda z_pc + 1
;	jsr printinteger
;	lda #$0d
;	jsr kernel_printchar

	
;	ldx stack_ptr
;	lda stack_ptr + 1
;	jsr printinteger
;	lda #$0d
;	jsr kernel_printchar
	
	
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
	rol z_pc
	dey
	bne -
	sta z_pc + 2
	jsr read_byte_at_z_pc_then_inc
	sta z_local_var_count
	cmp #0
	beq +
	lda stack_ptr
	sta z_local_vars_ptr
	lda stack_ptr + 1
	sta z_local_vars_ptr + 1
+	

	; TASK: Setup local vars
	
	ldx #0 ; Index of first argument to be passed to routine - 1
	ldy #2 ; Index of first byte to store local variables
	
-	cpx z_local_var_count
	bcs .setup_of_local_vars_complete
	cpx zp_temp ; Number of args
	bcs .store_zero_in_local_var
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
	lda #0
	sta (stack_ptr),y
	iny
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
	iny
	lda #0
	sta (stack_ptr),y
	iny
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

;	jsr print_following_string
;	!pet "hello stack",0
;	ldx stack_ptr
;	lda stack_ptr + 1
;	jsr printinteger
;	lda #$0d
;	jsr kernel_printchar
	
	
	rts

stack_return_from_routine
	rts

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
	jsr fatalerror
	!pet "stack full",0
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
	
stack_pull
	; Pull top value from stack, return in a,x

	; Check that there are > 0 values on stack
	ldy #1
	lda (stack_ptr),y
	bne .ok
	dey
	lda (stack_ptr),y
	bne .ok
	jsr fatalerror
	!pet "stack empty",0

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

;.push_byte_primitive
;	ldy #0
;	sta (stack_ptr),y
;	inc stack_ptr
;	bne +
;	inc stack_ptr + 1
;	ldy stack_ptr + 1
;	cpy #>(stack_start + stack_size)
;	bcs .overflow
;+	rts
;.overflow
;	jsr fatalerror
;	!pet "stack overflow"
}
