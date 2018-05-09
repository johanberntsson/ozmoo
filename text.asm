; message handing and decoding
;
; DragonTroll: PRINT_PADDR S030 ("The Dragon and the Troll"): 8d 03 1b

set_z_paddress
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

set_z_address
    stx .addr + 2
    sta .addr + 1
    lda #$0
    sta .addr
    rts

get_z_address
    ldx .addr + 2 ; low
    lda .addr + 1 ; high
    rts

read_next_byte
    ; destroys x,a: y untouched
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
.next_byte_state !byte 0

convert_zchar_to_char
    ; input: a=zchar
    ; output: a=char
    ; used registers: a,y
    cmp #6
    bcc +
    ; print zchar
    sec
    sbc #6
    clc
    adc .alphabet_offset
    tay
    lda .alphabet,y
+   rts

convert_char_to_zchar
    ; input: a=char
    ; output: a=zchar
    ; used registers: a,x
    ldx #26*3
-   cmp .alphabet,x
    beq +
    dex
    bne -
    jsr fatalerror
    !pet "invalid char",0
+   txa
    clc
    adc #6
    rts

convert_string_to_dictionary
    ldy #0
    sty .zword
    sty .zword + 1
-   ldx #5
--  asl .zword + 1
    rol .zword
    dex
    bne --
    lda .textbuffer,y
    jsr convert_char_to_zchar
    tax
    ora .zword + 1
    sta .zword + 1
!ifdef DEBUG { 
    lda #$0d
    jsr $ffd2
    jsr printx
    lda #$20
    jsr $ffd2
    ldx .zword + 1
    jsr printx
    lda #$0d
    jsr $ffd2
}
    iny
    cpy #3
    bne -
    ldx .zword
    jsr printx
    lda #44
    jsr $ffd2
    ldx .zword + 1
    jsr printx
    lda #$0d
    jsr $ffd2
    rts
.zword !byte 0,0
.textbuffer !pet "drop     "

lookup_dictionary
    ; find a word in the dictionary
    ; see: http://inform-fiction.org/zmachine/standards/z1point1/sect13.html
    ; http://inform-fiction.org/manual/html/s2.html#s2_5


read_text
    ; read line from keyboard into an array (address: a/x)
    ; See also: http://inform-fiction.org/manual/html/s2.html#p54
    stx mempointer ; 7c
    clc
    adc #>story_start ; 05+20 = 25
    sta mempointer + 1
    ; turn on blinking cursor
    lda #0
    sta $cc
.readkey
    jsr kernel_getchar
    cmp #$00
    beq .readkey
    cmp #$0d
    beq .read_text_done
    cmp #20
    bne +
    ; allow delete if buffer > 0
    ldy zero_keybuffer
    cpy #0
    beq .readkey
+   ; disallow cursor keys etc
    cmp #14
    beq .readkey ; big/small
    cmp #19
    beq .readkey ; home
    cmp #145
    beq .readkey ; cursor up
    cmp #17
    beq .readkey ; cursor down
    cmp #157
    beq .readkey ; cursor left
    cmp #29
    beq .readkey ; cursor right
    ; print the allowed char and store in the array
    jsr kernel_printchar
    pha
    ldy #0
    lda (mempointer),y ; max characters in array
    cmp zero_keybuffer ; compare with size of keybuffer
    bcc +
    ; maxchars >= keybuffer
    lda zero_keybuffer
    iny
    sta (mempointer),y
    tay
    iny
    pla
    sta (mempointer),y
    jmp .readkey
+   ; maxchars < keybuffer
    iny
    sta (mempointer),y
    pla ; don't save this (out of bounds)
    jmp .readkey
.read_text_done
    ; turn off blinking cursor
    lda #$ff
    sta $cc
    ; hide cursor if still visible
    ldy zero_keybuffer
    lda (zero_keybufferset),y
    and #$7f
    sta (zero_keybufferset),y
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
    ; skip initial space
    cpy .textend
    beq .start_of_word
    bcs .parsing_done
    lda (mempointer),y
    cmp #$20
    bne .start_of_word
    iny
    jmp .find_word_loop
.start_of_word
    ; start of next word found (y is first character of new word)
    sty .wordstart
-   ; look for the end of the word
    lda (mempointer),y
    cmp #$20
    beq .space_found
    cmp #44 ; comma
    beq .terminator_found
    cpy .textend
    bcs .word_found
    iny
    jmp -
.terminator_found
    cpy .wordstart
    beq .word_found
.space_found
    dey
.word_found
    ; word found. Look it up in the dictionary
    inc .numwords
    iny
    sty .wordend ; .wordend is the last character of the word + 1
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
    sec
    sbc .wordstart
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

print_addr
    lda #0
    sta .alphabet_offset
    jsr read_next_byte
    sta .packedtext
    jsr read_next_byte
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
    jsr convert_zchar_to_char
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
    jmp .next_zchar
.l4 ; normal char
    jsr kernel_printchar
    ; change back to A0
    lda #0
    sta .alphabet_offset
.next_zchar
    dex
    bpl --

    lda .packedtext + 1
    beq print_addr
    rts

testtext
    jmp convert_string_to_dictionary

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
    jsr tokenise_text
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
.alphabet ; 26 * 3
    !pet "abcdefghijklmnopqrstuvwxyz"
    !pet "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    !pet " ",13,"0123456789.,!?_#'",34, "/\-:()"
