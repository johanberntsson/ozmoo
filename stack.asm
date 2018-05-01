!zone {
stack_init
	lda #<stack_start
	sta stack_ptr
	lda #>stack_start
	sta stack_ptr + 1
	rts

stack_push_call_state
	rts

stack_return_to_last_call_state
	rts

stack_push
	rts

stack_pop
	rts


}
