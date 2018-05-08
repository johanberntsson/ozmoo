; message handing and decoding
;
; DragonTroll: PRINT_PADDR S030 ("The Dragon and the Troll"): 8d 03 1b

convert_from_paddr
    ; convert a/x to paddr in .addr
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

    ; $031b -> $00, $0c, $6c
    rts

read_text_byte
    lda .addr
    ldx .addr + 1
    ldy .addr + 2
    jsr read_byte_at_z_address
    inc .addr + 2
    bne +
    inc .addr + 1
    bne +
    inc .addr
+   rts

read_text
    ; read line from keyboard into an array (address: a/x)
    ; See also: http://inform-fiction.org/manual/html/s2.html#p54
    stx mempointer ; 7c
    clc
    adc #>story_start ; 05+20 = 25
    sta mempointer + 1
    ldy #0
    lda (mempointer),y
    tax
    iny
    iny
.read_loop
    ;sty mem_temp
    ;stx mem_temp + 1
    ;jsr kernel_getchar ; will destroy x and y
    ; TODO: delete can move cursor past first point, and give strange results
    jsr kernel_readchar
    ;ldy mem_temp
    ;ldx mem_temp + 1
    cmp #13
    beq .read_done  ; quit if newline
    cmp #20
    bne + 
    ; handle delete key
    cpy #2
    beq .read_loop
    dey
    jmp .read_loop
+   cpx #0
    beq .read_loop ; don't add if full
    ; valid character?
    cmp #$20
    beq .valid_char
    ; convert to lower case
    cmp #97
    bcc .valid_char
    sec
    sbc #32
.valid_char
    sta (mempointer), y ; add char
    iny
    dex
    jmp .read_loop
.read_done
    tya     ; stored the number of characters read
    sec
    sbc #2 ; skip byte 0, 1 (input starts at byte 2)
    ldy #1
    sta (mempointer), y
    rts

parse_text
    ; another attemps at parsing the text (see tokenise below)
    rts


tokenise_text
    ; divide read_line input into words and look up them in the dictionary
    ; input: mempointer should be pointing to the text array
    ; (this will be okay if called immediately after read_text)
    ; a/x should be the address of the parse array
    stx mem_temp ; a7
    clc
    adc #>story_start ; 05+20 = 25
    sta mem_temp + 1

    lda #0
    sta .numwords ; no words found yet
    lda #2
    sta .wordoffset ; where to store the next word in parse_array
    ldy #0
    lda (mem_temp),y 
    sta .maxwords
    iny
    lda (mempointer),y ; number of chars in text string
    clc
    adc #1
    sta .textend
    ; look over text and find each word
    ldy #2 ; start position in text
.find_word_loop
-   ; skip initial space
    cpy .textend
    bcs .parsing_done
    lda (mempointer),y
    cmp #$20
    bne .start_of_word
    iny
    jmp -
    ; start of next word found
.start_of_word
    sty .wordstart
-   ; look for the end of the word
    lda (mempointer),y
    cmp #$20
    beq .word_found
    cpy .textend
    bcs .word_found
    iny
    jmp -
.word_found
    ; word found. Look it up in the dictionary
    sty .wordend
    inc .numwords
    ; update parse_array
    lda .wordoffset
    tay
    clc
    adc #4
    sta .wordoffset
    iny
    iny
    lda .wordstart
    sta (mem_temp),y ; start index
    iny
    lda .wordend
    ;sec
    ;sbc .wordstart
    sta (mem_temp),y ; length
    ldy #1
    lda .numwords
    sta (mem_temp),y ; num of words
    ; find the next word
    ldy .wordend
    lda .numwords
    cmp .maxwords
    bne  .find_word_loop
.parsing_done
    lda .numwords
    ldy #1
    sta (mem_temp),y
    rts
.maxwords   !byte 0 
.numwords   !byte 0 
.wordoffset !byte 0 
.textend    !byte 0 
.wordstart  !byte 0 
.wordend    !byte 0 

read_char
    ; read a char from the keyboard

tokenize_text
    ; break output from read_text into workds and find their addresses
    ; in the dictionary. The result is stored in parse_buffer

print_addr
    jsr read_text_byte
    sta .packedtext
    jsr read_text_byte
    sta .packedtext + 1

    ; extract 3 zchars (5 bits each)
    ldx #0
.extract_loop
    lda .packedtext + 1
    and #$1f
    sta .zchars,x

    ldy #5
-   lsr .packedtext
    ror .packedtext+1
    dey
    bne -
    inx
    cpx #3
    bne .extract_loop

    ; print the three chars
    ldx #2
--  lda .zchars,x
    cmp #6
    bcc .l1
    ; print zchar
    sec
    sbc #6
    clc
    adc .alphabet_offset
    tay
    lda .alphabet,y
    jsr kernel_printchar
    ; change back to A0
    lda #0
    sta .alphabet_offset
    jmp .next_zchar
.l1 cmp #0
    bne .l2
    ; space
    lda #$20
    jsr kernel_printchar
    jmp .next_zchar
.l2 cmp #4
    bne .l3
    ; change to A1
    lda #26
    sta .alphabet_offset
    jmp .next_zchar
.l3 cmp #5
    bne .l4
    ; change to A2
    lda #52
    sta .alphabet_offset
.l4
.next_zchar
    dex
    bpl --

    lda .packedtext + 1
    beq print_addr
    rts

testtext
    ; init the array (normally done by the story file)
    ldy #20
    lda #0
-   sta $257c,y
    sta $25a7,y
    dey
    bne -
    lda #20
    sta $257c
    lda #0     ; 0=overwrite, 1=append to previous input
    sta $257d
    lda #$05
    ldx #$7c
    jsr read_text
    lda #$0d
    jsr kernel_printchar
    ldy #0
-   lda $257c,y
    tax
    jsr printx
    lda #$20
    jsr kernel_printchar
    iny
    cpy #12
    bne -
    ; parser
    lda #6 ; max 6 words
    sta $25a7
    lda #$05
    ldx #$a7
    jsr parse_text
    lda #$0d
    jsr kernel_printchar
    ldy #0
-   lda $25a7,y
    tax
    jsr printx
    lda #$20
    jsr kernel_printchar
    iny
    cpy #16
    bne -
    rts

.addr !byte 0,0,0
.zchars !byte 0,0,0
.packedtext !byte 0,0
.alphabet_offset !byte 0
.alphabet
    !pet "abcdefghijklmnopqrstuvwxyz"
    !pet "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    !pet " ",13,"0123456789.,!?_#'",34, "/\-:()"
