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

initialise
    ; read the header
    lda #$20    ; start in $2000
    ldx #$00    ; first sector to read
    ldy #$01    ; read 1 sector
    jsr readsectors

    ; read the rest
    lda #$21    ; start in $2000
    ldx #$01    ; first sector to read
    ldy #$10    ; read 1 sector
    jsr readsectors

    rts
