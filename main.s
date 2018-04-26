; C64 Program Header
    .word   basicstub
    * = $0801
basicstub
    .(
    .word   end, 1
    .byt    $9e,"2061",0
end .word   0
    .)
    jmp initialise

err .byt 0

#include "memory.s"

#define GAME_LENGTH $1a

initialise
    ; read the header
    lda #$20    ; start in $2000
    ldx #$00    ; first block to read
    ldy #$01    ; read 1 sector
    jsr readblocks

    ; check file length
    lda $201A
    ASL
    STA err
    INC err

    ; read the rest
    lda #$21    ; start in $2100
    ldx #$01    ; first block to read
    ldy err    ; read 16 sectors
    jsr readblocks

    rts
