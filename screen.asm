; screen update routines

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
	

fatalerror
    ; print error (implicit argument passing)
    ; input: 
    ; output:
    ; used registers: a,x,y
    ; side effects: resets the computer
!zone {
    ; usage:
    ;    jsr fatalerror
    ;    !pet "message",0
    ; uses stack pointer to find start of text, 
    ; prints the error, then resets the computer

    jsr print_following_string
    !pet "fatal error: ", 0

    ; store the return address
    ; the address on stack is -1 before the first character
    pla  ; remove LO for return address
    tax
    pla  ; remove HI for return address
    tay
    txa
    jsr printstring ; print error

    jsr print_trace
	
    jsr kernel_readchar   ; read keyboard
    jmp kernel_reset      ; reset
}

