.addr !byte 0,0,0
.next_byte_state !byte 0

set_z_address
    stx .addr + 2
    sta .addr + 1
    lda #$0
    sta .addr
    rts

dec_z_address
    pha
    dec .addr + 2
    lda .addr + 2
    cmp #$ff
    bne +
    dec .addr + 1
    lda .addr + 1
    cmp #$ff
    bne +
    dec .addr
+   pla
    rts

set_z_himem_address
    stx .addr + 2
    sta .addr + 1
    sty .addr
    rts

skip_bytes_z_address
    ; skip <a> bytes
    clc
    adc .addr + 2
    sta .addr + 2
    lda .addr + 1
    adc #0
    sta .addr + 1
    lda .addr
    adc #0
    sta .addr
    rts

!ifdef DEBUG {
print_z_address
    ldx .addr + 2 ; low
    jsr space
    jsr printx
    ldx .addr + 1 ; high
    jsr printx
    jmp newline
}

get_z_address
    ; input: 
    ; output: a,x
    ; side effects: 
    ; used registers: a,x
    ldx .addr + 2 ; low
    lda .addr + 1 ; high
    rts

get_z_himem_address
    ldx .addr + 2
    lda .addr + 1
    ldy .addr
    rts

read_next_byte
    ; input: 
    ; output: a
    ; side effects: .addr
    ; used registers: a,x,y
    sty .next_byte_state
    lda .addr
    ldx .addr + 1
    ldy .addr + 2
    jsr read_byte_at_z_address
    inc .addr + 2
    bne +
    inc .addr + 1
    bne +
    inc .addr
+   ldy .next_byte_state
    rts

set_z_paddress
    ; convert a/x to paddr in .addr
    ; input: a,x
    ; output: 
    ; side effects: .addr
    ; used registers: a,x
    ; example: $031b -> $00, $0c, $6c (Z5)
    stx .addr + 2
    sta .addr + 1
    lda #$0
    sta .addr
!ifdef Z4 {
    ldx #2
}
!ifdef Z5 {
    ldx #2
}
!ifdef Z8 {
    ldx #3
}
-   asl .addr+2
    rol .addr+1
    rol .addr
!ifndef Z3 {
    dex
    bne -
}
    rts

