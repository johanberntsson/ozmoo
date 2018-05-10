; screen update routines

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

puts_array 
    ; subroutine: print zcode array
    ; input:
    ; output:
    ; used registers:
    ; side effects:
!zone {
    ; TODO: implements me
    rts
}


printx
    ; subroutine: print value stored in x register
    ; input: x
    ; output:
    ; used registers:
    ; side effects:
!zone {
    php
    pha
    txa
    pha
    tya
    pha
    lda #$00
    jsr printinteger
    pla
    tay
    pla
    tax
    pla
    plp
    rts
}

puts_x
!zone {
    ; subroutine: print value stored in x register + newline
    ; input: x
    ; output:
    ; used registers:
    ; side effects:
    php
    pha
    txa
    pha
    tya
    pha
    lda #$00
    jsr printinteger
    lda #13
    jsr kernel_printchar
    pla
    tay
    pla
    tax
    pla
    plp
    rts
}

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
    jsr kernel_readchar   ; read keyboard
    jmp kernel_reset      ; reset
}

