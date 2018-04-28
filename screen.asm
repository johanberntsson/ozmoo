; screen update routines
; - printx
; - printstring

printx
    ; subroutine: print value stored in x register
    LDA #$00
    JSR basic_printinteger
    LDA #13
    JMP kernel_printchar

printstring
    ; print text (implicit argument passing)
    ; usage:
    ;    jsr .print2
    ;    !text "message",0
    ; uses stack pointer to find start of text, then
    ; updates the stack so that execution continues
    ; directly after the end of the text

    ; store the return address
    ; return address start -1 before the first character
    PLA  ; remove LO for return address
    STA .return_address + 1; 13
    PLA  ; remove HI for return address
    STA .return_address + 2; 09

    ; print the string
-   INC .return_address + 1
    BCC .return_address
    INC .return_address + 2
.return_address
    LDA $0000 ; self-modifying code (aaarg! but oh, so efficent)
    BEQ +
    JSR kernel_printchar
    JMP -

    ; put updated return address on stack
+   LDA .return_address + 2
    PHA 
    LDA .return_address + 1
    PHA
    RTS


