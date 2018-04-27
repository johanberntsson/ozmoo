!source "basic-boot.asm"

+start_at $0900

    jmp .initialise

err !byte 0

!source "memory.asm"

.initialise
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

    ldx err
    LDA #$00
    JSR $BDCD      ; write counter

    ; read the rest
    lda #$21    ; start in $2100
    ldx #$01    ; first block to read
    ldy err    ; read 16 sectors
    ;jsr readblocks

    rts
