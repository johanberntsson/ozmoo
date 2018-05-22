; various utility functions
; - conv2dec
; - mult16
; - divide16
; - fatal error
; various debug functions

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

fatalerror
    ; prints the error, then resets the computer
    ; input: a (error code)
    ; side effects: resets the computer
!ifndef DEBUG {
    pha
	lda #%00110111
	sta zero_processorports
	ldy #>.fatal_error_string
	lda #<.fatal_error_string
    jsr basic_printstring
    pla
    tax
    lda #0
    jsr basic_printinteger
    lda #$0d
    jsr kernel_printchar
    jsr kernel_readchar   ; read keyboard
    jmp kernel_reset      ; reset
.fatal_error_string !pet "fatal error: ",0
} else {
    pha
    jsr print_following_string
    !pet "fatal error: ", 0
    pla
    cmp #ERROR_UNSUPPORTED_STREAM
    bne .f1
    jsr print_following_string
    !pet "unsupported stream#",0
    jmp .fe_reset
.f1 cmp #ERROR_INVALID_CHAR
    bne .f2
    jsr print_following_string
    !pet "invalid char",0
    jmp .fe_reset
.f2 cmp #ERROR_STREAM_NESTING_ERROR
    bne .f3
    jsr print_following_string
    !pet "stream nesting error",0
    jmp .fe_reset
.f3 cmp #ERROR_FLOPPY_READ_ERROR
    bne .f4
    jsr print_following_string
    !pet "floppy read error", 0
    jmp .fe_reset
.f4 cmp #ERROR_MEMORY_OVER_64KB
    bne .f5
    jsr print_following_string
    !pet "tried to access z-machine memory over 64kb", 0
    jmp .fe_reset
.f5 cmp #ERROR_STACK_FULL
    bne .f6
    jsr print_following_string
    !pet "stack full",0
    jmp .fe_reset
.f6 cmp #ERROR_STACK_EMPTY
    bne .f7
    jsr print_following_string
    !pet "stack empty",0
    jmp .fe_reset
.f7 cmp #ERROR_OPCODE_NOT_IMPLEMENTED
    bne .f8
    jsr print_following_string
    !pet "opcode not implemented!",0
    jmp .fe_reset
.f8 cmp #ERROR_USED_NONEXISTENT_LOCAL_VAR
    bne .f9
    jsr print_following_string
    !pet "used non-existent local var",0
    jmp .fe_reset
.f9 cmp #ERROR_BAD_PROPERTY_LENGTH
    bne .fa
    jsr print_following_string
    !pet "bad property length", 0
    jmp .fe_reset
.fa cmp #ERROR_UNSUPPORTED_STORY_VERSION
    bne .fb
    jsr print_following_string
    !pet "unsupported story version", 0
    jmp .fe_reset
.fb cmp #ERROR_OUT_OF_MEMORY
    bne .fz
    jsr print_following_string
    !pet "Out of memory", 0
    jmp .fe_reset
.fz jsr printinteger
.fe_reset
    jsr newline
    jsr print_trace
    jsr kernel_readchar   ; read keyboard
    jmp kernel_reset      ; reset

.saved_a !byte 0
.saved_x !byte 0
.saved_y !byte 0

printinteger
    ; subroutine: print integer value using Basic routine
    ; input: a,x
    ; output:
    ; used registers: a
    ; side effects:
!zone {
    pha
	lda #%00110111
	sta zero_processorports
	pla
    jsr basic_printinteger
	lda #%00110110
	sta zero_processorports
	rts
}

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
    jsr kernel_printchar
    lda .saved_a
    ldx .saved_x
    ldy .saved_y
    plp
    rts

comma
    ; subroutine: print space
    ; input: 
    ; output:
    ; used registers:
    ; side effects:
    php
    sta .saved_a
    stx .saved_x
    sty .saved_y
    lda #44
    jsr kernel_printchar
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
    jsr kernel_printchar
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

printstring
    ; input: x
    ; output:
    ; used registers:
    ; side effects:
!zone {
    pha
	lda #%00110111
	sta zero_processorports
	pla
    jsr basic_printstring
	lda #%00110110
	sta zero_processorports
	rts
}

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
    jsr kernel_printchar
    jmp -

    ; put updated return address on stack
+   lda .return_address + 2
    pha 
    lda .return_address + 1
    pha
    rts
}

print_trace
;!ifdef DEBUG {
	jsr print_following_string
	!pet 13,"last opcodes: (#, z_pc, opcode)",13,0
	lda z_trace_index
	sec
	sbc #40
	tay
	ldx #0
.print_next_op	
	jsr printx
	lda #$2c
	jsr kernel_printchar
	lda #$24
	jsr kernel_printchar
	lda z_trace_page,y
	jsr .print_byte_as_hex
	iny
	lda z_trace_page,y
	jsr .print_byte_as_hex
	iny
	lda z_trace_page,y
	jsr .print_byte_as_hex
	iny
	lda #$2c
	jsr kernel_printchar
	lda #$24
	jsr kernel_printchar
	lda z_trace_page,y
	jsr .print_byte_as_hex
	lda #$0d
	jsr kernel_printchar
	iny
	inx
	cpx #10
	bcc .print_next_op
	bcs .print_no_more_ops

.print_byte_as_hex
	stx zp_temp
	pha
	lsr
	lsr
	lsr
	lsr
	tax
	lda .hex_num,x
	jsr kernel_printchar
	pla
	and #$0f
	tax
	lda .hex_num,x
	ldx zp_temp
	jmp kernel_printchar
.hex_num
	!pet "0123456789abcdef"
.print_no_more_ops
;}	
    rts
	
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
