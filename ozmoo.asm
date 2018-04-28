; Define DEBUG for additional runtime printouts
DEBUG = 1

; where to story data
mem_start = $2000

; story file header constants
header_version = $1a
header_filelength = $1a

; basic program (10 SYS2061)
!source "basic-boot.asm"
    +start_at $080d
    jmp .initialize

; global variables
err !byte 0
; include other assembly files
!source "memory.asm"

; ---- to be moved into a debug or screen library later on ----
.print2
    ; trying message passing with implicit argument(s)
    ; usage:
    ;    jsr .print2
    ;    !text "message",0
    ; is supposed to use stack pointer to print the message until 0,
    ; then update the stack so that RTS return to next instruction
    ; after the text
    ;
    PLA     ; remove LO for return address
    STA .return_address + 1;
    PLA     ; remove HI for return address
    STA .return_address;

-   LDA .return_address
    INC .return_address + 1
    BNE +
    INC .return_address
+   JSR print_char
    BNE -

    LDA .return_address
    PHA 
    LDA .return_address + 1
    PHA
    RTS

.return_address !word $0000

.printstring
    ;jsr .print2
    ;!pet "hello:",0

    ; subroutine: print string
    lda #<.msg
    ldy #>.msg
    jmp print_string

.msg !pet "total blocks: ",0

.printx
    ; subroutine: print value stored in x register
    LDA #$00
    JSR print_integer
    LDA #13
    JMP print_char

; ----- the main routine ----

.initialize
    ; read the header
    lda #>mem_start ; first free memory block
    ldx #$00    ; first block to read from floppy
    ldy #$01    ; read 1 block
    jsr readblocks

    ; check file length (need to be doubled)
    lda mem_start + header_filelength
    ASL          ; *2
    STA err      ; store length

!ifdef DEBUG {
    ; show how many blocks to read (exluding header)
    jsr .printstring
    ldx err
    jsr .printx
}
    ; read the rest
    ldx #>mem_start ; first free memory block
    inx        ; skip header
    txa
    ldx #$01    ; first block to read from floppy
    ldy err    ; read <header_filelength> blocks
    jsr readblocks
    rts
