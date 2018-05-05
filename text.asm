; message handing and decoding
;
; DragonTroll: PRINT_PADDR S030 ("The Dragon and the Troll"): 8d 03 1b

convert_paddr
    ; convert a/x to paddr in .addr
    stx .addr + 2 ; 1b
    sta .addr + 1 ; 03
    lda #$0
    sta .addr

    asl .addr+2
    rol .addr+1
    rol .addr
    asl .addr+2
    rol .addr+1
    rol .addr
    ; $031b -> $00, $0c, $6c
    rts

print_paddr
    rts

testtext
    lda #$03
    ldx #$1b
    ; $0c6c: 13 2d 28 04 26 e6
    ; $132d: 0 00100 11001 01101 = 4 25 13: (A1) Th
    ; $2804: 0 01010 00000 00100 =
    jsr convert_paddr
    jsr print_paddr
    rts

.addr !byte 0,0,0


