; Routines to handle output streams and input streams

!zone streams {
streams_stack
	!fill 32, 0
streams_stack_items	
	!byte 0
streams_buffering
	!byte 1,1
streams_output_selected	
	!byte 0, 0, 0, 0
	
streams_init
	lda #0
	sta streams_stack_items
	sta streams_output_selected + 1
	sta streams_output_selected + 2
	sta streams_output_selected + 3
	lda #1
	sta streams_buffering
	sta streams_buffering + 1
	sta streams_output_selected
	rts
	
streams_print_output
	jmp kernel_printchar

streams_output_stream
	rts
}