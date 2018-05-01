!zone {
stack_init
	lda #<stack_start
	sta stack_ptr
	lda #>stack_start
	sta stack_ptr + 1
	rts

stack_enter_routine
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
