; various utility functions
; - conv2dec
; - mult16
; - divide16
; - fatalerror
; - enable_interrupts
; - disable_interrupts
; - set_memory_normal
; - set_memory_all_ram
; - set_memory_no_basic
; various debug functions

; zero_processorports: ...<d000><e000><a000> on/off
!macro set_memory_all_ram {
    ; Don't forget to disable interrupts first!
    pha
    lda #%00110000 
    sta zero_processorports
    pla
}

!macro set_memory_no_basic {
    pha
    lda #%00110110
    sta zero_processorports
    pla
}

!macro set_memory_normal {
    pha
    lda #%00110111
    sta zero_processorports
    pla
}

; to be expanded to disable NMI IRQs later if needed
!macro disable_interrupts {
    sei 
}

!macro enable_interrupts {
    cli
}

!macro read_next_byte_at_z_pc {
	ldy z_pc_mempointer_is_unsafe
	beq +
	jsr get_page_at_z_pc	
+	lda (z_pc_mempointer),y
	inc z_pc_mempointer ; Also increases z_pc
	bne ++
	jsr inc_z_pc_page
++	
}

ERROR_UNSUPPORTED_STREAM = 1
ERROR_INVALID_CHAR = 2
ERROR_STREAM_NESTING_ERROR = 3
ERROR_FLOPPY_READ_ERROR = 4
ERROR_MEMORY_OVER_64KB = 5
ERROR_STACK_FULL = 6
ERROR_STACK_EMPTY = 7
ERROR_OPCODE_NOT_IMPLEMENTED = 8
ERROR_USED_NONEXISTENT_LOCAL_VAR = 9
ERROR_BAD_PROPERTY_LENGTH = 10
ERROR_UNSUPPORTED_STORY_VERSION = 11
ERROR_OUT_OF_MEMORY = 12
ERROR_WRITE_ABOVE_DYNMEM = 13
ERROR_READ_ABOVE_STATMEM = 14
ERROR_TOO_MANY_TERMINATORS = 15

!ifdef DEBUG {
.error_unsupported_stream !pet "unsupported stream#",0
.error_invalid_char !pet "invalid char",0
.error_stream_nesting_error !pet "stream nesting error",0
.error_floppy_read_error !pet "floppy read error", 0
.error_memory_over_64kb !pet "tried to access z-machine memory over 64kb", 0
.error_stack_full !pet "stack full",0
.error_stack_empty !pet "stack empty",0
.error_opcode_not_implemented !pet "opcode not implemented!",0
.error_used_nonexistent_local_var !pet "used non-existent local var",0
.error_bad_property_length !pet "bad property length", 0
.error_unsupported_story_version !pet "unsupported story version", 0
.error_out_of_memory !pet "out of memory", 0
.error_write_above_dynmem !pet "tried to write to non-dynamic memory", 0
.error_read_above_statmem !pet "tried to read from himem", 0
.error_too_many_terminators !pet "too many terminators", 0

.error_message_high_arr
    !byte >.error_unsupported_stream
    !byte >.error_invalid_char
    !byte >.error_stream_nesting_error
    !byte >.error_floppy_read_error
    !byte >.error_memory_over_64kb
    !byte >.error_stack_full
    !byte >.error_stack_empty
    !byte >.error_opcode_not_implemented
    !byte >.error_used_nonexistent_local_var
    !byte >.error_bad_property_length
    !byte >.error_unsupported_story_version
    !byte >.error_out_of_memory
    !byte >.error_write_above_dynmem
    !byte >.error_read_above_statmem
    !byte >.error_too_many_terminators

.error_message_low_arr
    !byte <.error_unsupported_stream
    !byte <.error_invalid_char
    !byte <.error_stream_nesting_error
    !byte <.error_floppy_read_error
    !byte <.error_memory_over_64kb
    !byte <.error_stack_full
    !byte <.error_stack_empty
    !byte <.error_opcode_not_implemented
    !byte <.error_used_nonexistent_local_var
    !byte <.error_bad_property_length
    !byte <.error_unsupported_story_version
    !byte <.error_out_of_memory
    !byte <.error_write_above_dynmem
    !byte <.error_read_above_statmem
    !byte <.error_too_many_terminators
}

fatalerror
    ; prints the error, then resets the computer
    ; input: a (error code)
    ; side effects: resets the computer
!ifndef DEBUG {
    pha
    +set_memory_normal
    ldy #>.fatal_error_string
	lda #<.fatal_error_string
	jsr printstring
    pla
    tax
    lda #0
    jsr printinteger
    lda #$0d
    jsr streams_print_output
    jsr printchar_flush
    jsr kernel_readchar   ; read keyboard
    jmp kernel_reset      ; reset
.fatal_error_string !pet "fatal error: ",0
} else {
    pha
    jsr print_following_string
    !pet "fatal error ", 0
    pla
    tax
    dex
    jsr printa
    jsr colon
    jsr space
    lda .error_message_high_arr,x
    tay
    lda .error_message_low_arr,x
    jsr printstring
    jsr newline
    jsr print_trace
    jsr printchar_flush
    jsr kernel_readchar   ; read keyboard
    jmp kernel_reset      ; reset

.saved_a !byte 0
.saved_x !byte 0
.saved_y !byte 0

space
    ; subroutine: print space
    ; input: 
    ; output:
    ; used registers:
    ; side effects:
    php
    sta .saved_a
    stx .saved_x
    sty .saved_y
    lda #$20
    jsr streams_print_output
    lda .saved_a
    ldx .saved_x
    ldy .saved_y
    plp
    rts

comma
    ; subroutine: print comma
    ; input: 
    ; output:
    ; used registers:
    ; side effects:
    php
    sta .saved_a
    stx .saved_x
    sty .saved_y
    lda #44
    jsr streams_print_output
    lda .saved_a
    ldx .saved_x
    ldy .saved_y
    plp
    rts

dollar
    ; subroutine: print dollar
    ; input: 
    ; output:
    ; used registers:
    ; side effects:
    php
    sta .saved_a
    stx .saved_x
    sty .saved_y
    lda #36
    jsr streams_print_output
    lda .saved_a
    ldx .saved_x
    ldy .saved_y
    plp
    rts

colon
    ; subroutine: print colon
    ; input: 
    ; output:
    ; used registers:
    ; side effects:
    php
    sta .saved_a
    stx .saved_x
    sty .saved_y
    lda #58
    jsr streams_print_output
    lda .saved_a
    ldx .saved_x
    ldy .saved_y
    plp
    rts

arrow
    ; subroutine: print ->
    ; input: 
    ; output:
    ; used registers:
    ; side effects:
    php
    sta .saved_a
    stx .saved_x
    sty .saved_y
    lda #$2d
    jsr streams_print_output
    lda #$3e
    jsr streams_print_output
    lda .saved_a
    ldx .saved_x
    ldy .saved_y
    plp
    rts


newline
    ; subroutine: print newline
    ; input: 
    ; output:
    ; used registers:
    ; side effects:
    php
    sta .saved_a
    stx .saved_x
    sty .saved_y
    lda #$0d
    jsr streams_print_output
    lda .saved_a
    ldx .saved_x
    ldy .saved_y
    plp
    rts

printx
    ; subroutine: print value stored in x register
    ; input: x
    ; output:
    ; used registers:
    ; side effects:
    php
    sta .saved_a
    stx .saved_x
    sty .saved_y
    lda #$00
    jsr printinteger
    lda .saved_a
    ldx .saved_x
    ldy .saved_y
    plp
    rts

printy
    ; subroutine: print value stored in y register
    ; input: y
    ; output:
    ; used registers:
    ; side effects:
    php
    sta .saved_a
    stx .saved_x
    sty .saved_y
    tya
    tax
    lda #$00
    jsr printinteger
    lda .saved_a
    ldx .saved_x
    ldy .saved_y
    plp
    rts

printa
    ; subroutine: print value stored in a register
    ; input: a
    ; output:
    ; used registers:
    ; side effects:
    php
    sta .saved_a
    stx .saved_x
    sty .saved_y
    tax
    lda #$00
    jsr printinteger
    lda .saved_a
    ldx .saved_x
    ldy .saved_y
    plp
    rts

pause
    ; subroutine: print newline
    ; input: 
    ; output:
    ; used registers:
    ; side effects:
    php
    sta .saved_a
    stx .saved_x
    sty .saved_y
    jsr print_following_string
	!pet "[Intentional pause. Press ENTER.]",13,0
    jsr print_trace
    jsr printchar_flush
    jsr kernel_readchar   ; read keyboard
    lda .saved_a
    ldx .saved_x
    ldy .saved_y
    plp
    rts

print_following_string
    ; print text (implicit argument passing)
    ; input: 
    ; output:
    ; used registers: a
    ; side effects:
!zone {
    ; usage:
    ;    jsr print_following_string
    ;    !pet "message",0
    ; uses stack pointer to find start of text, then
    ; updates the stack so that execution continues
    ; directly after the end of the text

    ; store the return address
    ; the address on stack is -1 before the first character
    pla  ; remove LO for return address
    sta .return_address + 1
    pla  ; remove HI for return address
    sta .return_address + 2

    ; print the string
-   inc .return_address + 1
    bne .return_address
    inc .return_address + 2
.return_address
    lda $0000 ; self-modifying code (aaarg! but oh, so efficent)
    beq +
    jsr streams_print_output
    jmp -

    ; put updated return address on stack
+   lda .return_address + 2
    pha 
    lda .return_address + 1
    pha
    rts
}

print_trace
!ifdef TRACE {
    jsr newline
	jsr print_following_string
	!pet "last opcodes: (#, z_pc, opcode)",0
    jsr newline
	lda z_trace_index
	tay
	and #%11
	cmp #%11
	bne +
	jsr print_following_string
	!pet "last opcode not stored (shown as $ee)",13,0
	lda #$ee
	sta z_trace_page,y
	iny
+	tya
	sec
	sbc #40
	tay
	ldx #0
.print_next_op	
	jsr printx
	jsr comma
	jsr dollar
	lda z_trace_page,y
	jsr print_byte_as_hex
	iny
	lda z_trace_page,y
	jsr print_byte_as_hex
	iny
	lda z_trace_page,y
	jsr print_byte_as_hex
	iny
	jsr comma
	jsr dollar
	lda z_trace_page,y
	jsr print_byte_as_hex
	jsr newline
	iny
	inx
	cpx #10
	bcc .print_next_op
	bcs .print_no_more_ops
} else {
	rts ; If TRACE is not enabled, there is no trace info to print
}

print_byte_as_hex
	stx .saved_x
	pha
	lsr
	lsr
	lsr
	lsr
	tax
	lda .hex_num,x
	jsr streams_print_output
	pla
	pha
	and #$0f
	tax
	lda .hex_num,x
	ldx .saved_x
	jsr streams_print_output
	pla
	rts
.hex_num
	!pet "0123456789abcdef"
.print_no_more_ops
    rts
	
}

printinteger
    ; subroutine: print 16 bit integer value
    ; input: a,x (x = low, a = high);
    ; output:
    ; used registers: a, x, y
    ; side effects:
!zone {
	pha
	ldy #1
-	lda z_operand_value_high_arr,y
	sta .temp,y
	lda z_operand_value_low_arr,y
	sta .temp + 2,y
	dey
	bpl -
	pla
	sta z_operand_value_high_arr
	stx z_operand_value_low_arr
	jsr print_num_unsigned
	ldy #1
-	lda .temp,y
	sta z_operand_value_high_arr,y
	lda .temp + 2,y
	sta z_operand_value_low_arr,y
	dey
	bpl -
	rts
.temp
	!byte 0,0,0,0
}

printstring
    ; input: a,y (lo/hi)
    ; output:
    ; used registers:
    ; side effects:
!zone {
    sta .loop+1
    sty .loop+2
    ldy #0
.loop
    lda $8000,y
    beq +
    jsr streams_print_output
    iny
    bne .loop
+   rts
}

conv2dec
    ; convert a to decimal in x,a
    ; for example a=#$0f -> x='1', a='5'
    ldx #$30 ; store '0' in x
-   cmp #10
    bcc +    ; a < 10
    inx
    sec
    sbc #10
    jmp -
+   adc #$30
    rts

mult16
    ;16-bit multiply with 32-bit product
    ;http://codebase64.org/doku.php?id=base:16bit_multiplication_32-bit_product
    lda #$00
    sta product+2 ; clear upper bits of product
    sta product+3 
    ldx #$10 ; set binary count to 16 
shift_r
    lsr multiplier+1 ; divide multiplier by 2 
    ror multiplier
    bcc rotate_r 
    lda product+2 ; get upper half of product and add multiplicand
    clc
    adc multiplicand
    sta product+2
    lda product+3 
    adc multiplicand+1
rotate_r
    ror ; rotate partial product 
    sta product+3 
    ror product+2
    ror product+1 
    ror product 
    dex
    bne shift_r 
    rts
multiplier
divisor
	!byte 0, 0
multiplicand
dividend
division_result
	!byte 0, 0
product
remainder 
	!byte 0 ,0 ,0 ,0

; divisor = $58     ;$59 used for hi-byte
; dividend = $fb	  ;$fc used for hi-byte
; remainder = $fd	  ;$fe used for hi-byte
; result = dividend ;save memory by reusing divident to store the result

!zone {
divide16	
	lda #0	        ;preset remainder to 0
	sta remainder
	sta remainder + 1
	ldx #16	        ;repeat for each bit: ...
.divloop
	asl dividend	;dividend lb & hb*2, msb -> Carry
	rol dividend + 1	
	rol remainder	;remainder lb & hb * 2 + msb from carry
	rol remainder + 1
	lda remainder
	sec
	sbc divisor	;substract divisor to see if it fits in
	tay	        ;lb result -> Y, for we may need it later
	lda remainder + 1
	sbc divisor+1
	bcc .skip	;if carry=0 then divisor didn't fit in yet

	sta remainder + 1	;else save subtraction result as new remainder,
	sty remainder
	inc division_result	;and INCrement result cause divisor fit in 1 times
.skip
	dex
	bne .divloop
	rts
}
; screen update routines
