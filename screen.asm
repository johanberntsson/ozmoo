; screen update routines
; - printx
; - printstring
; - fatalerror

printx
!zone {
    ; subroutine: print value stored in x register
    lda #$00
    jsr basic_printinteger
    lda #13
    jmp kernel_printchar
}

printstring
!zone {
    ; print text (implicit argument passing)
    ; usage:
    ;    jsr printstring
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
    bcc .return_address
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
!zone {
    ; print error (implicit argument passing)
    ; usage:
    ;    jsr fatalerror
    ;    !pet "message",0
    ; uses stack pointer to find start of text, 
    ; prints the error, then resets the computer

    jsr printstring
    !pet "fatal error: ", 0

    ; store the return address
    ; the address on stack is -1 before the first character
    pla  ; remove LO for return address
    tax
    pla  ; remove HI for return address
    tay
    txa
    jsr basic_printstring ; print error
    jsr kernel_readchar   ; read keyboard
    jmp kernel_reset      ; reset
}

