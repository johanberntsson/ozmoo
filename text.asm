; TODO:
; - fix offset bug in "drop all" find_word_in_dictionary
; - use dictionary terminators instead of hard-coded ones

set_z_paddress
    ; convert a/x to paddr in .addr
    ; input: a,x
    ; output: 
    ; side effects: .addr
    ; used registers: a,x
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
    ; input: 
    ; output: a,x
    ; side effects: 
    ; used registers: a,x
    ldx .addr + 2 ; low
    lda .addr + 1 ; high
    rts

read_next_byte
    ; input: 
    ; output: a
    ; side effects: .addr
    ; used registers: a,x
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
    ; side effects:
    ; used registers: a,y
    cmp #6
    bcc +
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
    ; side effects:
    ; used registers: a,x
    ldx #0
-   cmp .alphabet,x
    beq +
    inx
    cpx #26*3
    bne -
    tax
    jsr printx
    jsr fatalerror
    !pet "invalid char",0
+   txa
    clc
    adc #6
    rts

find_word_in_dictionary
    ; convert word to zchars and find it in the dictionary
    ; see: http://inform-fiction.org/zmachine/standards/z1point1/sect13.html
    ; http://inform-fiction.org/manual/html/s2.html#s2_5
    ; input: 
    ;   y = index in parse_array to store result in
    ;   parse_array = indirect address to parse_array
    ;   string_array = indirect address to string being parsed
    ;   .wordstart = index in string_array to first char of current word
    ;   .wordend = index in string_array to last char of current word
    ; output: puts address in parse_array[y] and parse_array[y+1]
    ; side effects:
    ; used registers: a,x
    ldx .wordstart
    jsr puts_x
    sty .parse_array_index ; store away the index for later
    lda #0
    sty .zword      ; clear zword buffer
    sty .zword + 1
    sty .zword + 2
    sty .zword + 3
    sty .zword + 4
    sty .zword + 5
    lda .wordstart  ; truncate the word length to dictionary size
    clc
!ifndef Z4PLUS {
    adc #6
}
!ifdef Z4PLUS {
    adc #9
}
    sta .last_char_index 
    ; get started!
    lda #1
    sta .triplet_counter ; keep track of triplets to insert extra bit
    ldy .wordstart
.encode_chars
    ldx #5
    dec .triplet_counter
    bne .shift_zchar
    lda #3
    sta .triplet_counter
    ldx #6
.shift_zchar
    asl .zword + 5
    rol .zword + 4
    rol .zword + 3
    rol .zword + 2
    rol .zword + 1
    rol .zword
    dex
    bne .shift_zchar

    lda #5 ; pad character
    cpy .wordend
    bcs +
    lda (string_array),y
    jsr convert_char_to_zchar
+   tax
!ifdef DEBUG {
    ;jsr printx ; next zchar to insert into zword
    ;pha
    ;lda #$20
    ;jsr $ffd2
    ;pla
}
    ora .zword + 5
    sta .zword + 5
    iny
    cpy .last_char_index
    bne .encode_chars
    ; done. Add stop bit to mark end of string
    lda .zword + 5
    ora #$80
    sta .zword + 5
!ifdef DEBUG {
    ; print zword (6 or 9 bytes)
    ;lda #$0d
    ;jsr $ffd2
    ;ldx .zword 
    ;jsr printx
    ;lda #44
    ;jsr $ffd2
    ;ldx .zword + 1
    ;jsr printx
    ;lda #44
    ;jsr $ffd2
    ;ldx .zword + 2
    ;jsr printx
    ;lda #44
    ;jsr $ffd2
    ;ldx .zword + 3
    ;jsr printx
    ;lda #44
    ;jsr $ffd2
    ;ldx .zword + 4
    ;jsr printx
    ;lda #44
    ;jsr $ffd2
    ;ldx .zword + 5
    ;jsr printx
    ;lda #$0d
    ;jsr $ffd2
}
    ; find entry in dictionary 
    lda #0
    sta .dict_cnt     ; loop counter is 2 bytes
    sta .dict_cnt + 1
    ldx dict_entries     ; start address of dictionary
    lda dict_entries + 1
    jsr set_z_address
!ifndef Z4PLUS {
    lda #4
}
!ifdef Z4PLUS {
    lda #6
}
    sta .zchars_per_entry
.dictionary_loop
    ; show the dictonary word
!ifdef DEBUG {
    ;lda .addr
    ;pha
    ;lda .addr + 1
    ;pha
    ;lda .addr + 2
    ;pha
    ;jsr print_addr
    ;lda #$0d
    ;jsr kernel_printchar
    ;pla 
    ;sta .addr + 2
    ;pla 
    ;sta .addr + 1
    ;pla 
    ;sta .addr
}
    ; store address to current entry
    jsr get_z_address
    sta .dictionary_address
    stx .dictionary_address + 1
    ; check if correct entry
    ldy #0
    sty .num_matching_zchars
.loop_check_entry
    jsr read_next_byte
    cmp .zword,y
    bne .zchars_differ
    inc .num_matching_zchars
.zchars_differ
    iny
    cpy .zchars_per_entry
    bne .loop_check_entry
    dey ; undo last inx in .loop_check_entry block
    cpy .num_matching_zchars
    beq .found_dict_entry ; we found the correct entry!
    ; skip the extra data bytes
    lda dict_len_entries
    sec
!ifndef Z4PLUS {
    sbc #4
}
!ifdef Z4PLUS {
    sbc #6
}
    tay
.dictionary_extra_bytes
    jsr read_next_byte
    dey
    bne .dictionary_extra_bytes
    ; increase the loop counter
    inc .dict_cnt + 1
    bne .check_high
    inc .dict_cnt
    ; counter < dict_num_entries?
.check_high
    lda dict_num_entries + 1
    cmp .dict_cnt + 1
    bne .dictionary_loop
    lda dict_num_entries
    cmp .dict_cnt
    bne .dictionary_loop
    ; no entry found
    lda #0
    sta .dictionary_address
    sta .dictionary_address + 1
.found_dict_entry
    ; store result into parse_array and exit
    ldy .parse_array_index
    lda .dictionary_address
    sta (parse_array),y
    iny
    lda .dictionary_address + 1
    sta (parse_array),y
    iny
    rts
.dict_cnt !byte 0,0
.triplet_counter !byte 0
.last_char_index !byte 0
.parse_array_index !byte 0
.dictionary_address !byte 0,0
.zword !byte 0,0,0,0,0,0
.zchars_per_entry !byte 0
.num_matching_zchars !byte 0

read_text
    ; read line from keyboard into an array (address: a/x)
    ; See also: http://inform-fiction.org/manual/html/s2.html#p54
    ; input: a,x
    ; output: string_array
    ; side effects: zero_keybuffer, zero_keybufferset
    ; used registers: a,x,y
    stx string_array ; 7c
    clc
    adc #>story_start ; 05+20 = 25
    sta string_array + 1
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
    lda (string_array),y ; max characters in array
    cmp zero_keybuffer ; compare with size of keybuffer
    bcc +
    ; maxchars >= keybuffer
    lda zero_keybuffer
    iny
    sta (string_array),y
    tay
    iny
    pla
    sta (string_array),y
    jmp .readkey
+   ; maxchars < keybuffer
    iny
    sta (string_array),y
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
    ; input: string_array should be pointing to the text array
    ; (this will be okay if called immediately after read_text)
    ; a/x should be the address of the parse array
    ; input: a,x,string_array
    ; output: parse_array
    ; side effects:
    ; used registers: a,x,y
    stx parse_array
    clc
    adc #>story_start
    sta parse_array + 1
    lda #0
    sta .numwords ; no words found yet
    lda #2
    sta .wordoffset ; where to store the next word in parse_array
    ldy #0
    lda (parse_array),y 
    sta .maxwords
    iny
    lda (string_array),y ; number of chars in text string
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
    lda (string_array),y
    cmp #$20
    bne .start_of_word
    iny
    jmp .find_word_loop
.start_of_word
    ; start of next word found (y is first character of new word)
    sty .wordstart
-   ; look for the end of the word
    lda (string_array),y
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
    jsr find_word_in_dictionary ; will update y
    ;iny
    ;iny
    lda .wordstart
    sta (parse_array),y ; start index
    iny
    lda .wordend
    sec
    sbc .wordstart
    sta (parse_array),y ; length
    ldy #1
    lda .numwords
    sta (parse_array),y ; num of words
    ; find the next word
    ldy .wordend
    lda .numwords
    cmp .maxwords
    bne  .find_word_loop
.parsing_done
    lda .numwords
    ldy #1
    sta (parse_array),y
    rts
.maxwords   !byte 0 
.numwords   !byte 0 
.wordoffset !byte 0 
.textend    !byte 0 
.wordstart  !byte 0 
.wordend    !byte 0 

read_char
    ; read a char from the keyboard
    ; input: 
    ; output: 
    ; side effects:
    ; used registers: 

print_addr
    ; print zchar-encoded text
    ; input: (.addr set with set_z_addr or set_z_paddr)
    ; output: 
    ; side effects: .addr
    ; used registers: a,x,y
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
