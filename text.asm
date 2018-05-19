; text opcodes

;TRACE_READTEXT = 1
;TRACE_TOKENISE = 1
;TRACE_SHOW_DICT_ENTRIES = 1

z_ins_print_addr 
    jsr evaluate_all_args
    ldx z_operand_value_low_arr
	lda z_operand_value_high_arr
	jsr set_z_address
	jmp print_addr

z_ins_print_paddr
    jsr evaluate_all_args
    ; Packed address is now in (z_operand_value_high_arr, z_operand_value_low_arr)
    lda z_operand_value_high_arr
    ldx z_operand_value_low_arr
    jsr set_z_paddress
    jmp print_addr

z_ins_print 
    ldy z_pc
    lda z_pc + 1
    ldx z_pc + 2
    jsr set_z_himem_address
    jsr print_addr
    jsr get_z_himem_address
    sty z_pc
    sta z_pc + 1
    stx z_pc + 2
    rts

z_ins_print_ret
    jsr z_ins_print
    lda #$0d
    jsr streams_print_output
    lda #0
    ldx #1
    jmp stack_return_from_routine

!ifndef Z5PLUS {

z_ins_sread
	; sread text parse (Z1-Z3)
	; sread text parse time routine (Z4)
    jsr evaluate_all_args
    ; read input
    ldx z_operand_value_low_arr
    lda z_operand_value_high_arr
    jsr read_text
!ifdef TRACE_READTEXT {
    jsr print_following_string
    !pet "read_text ",0
    ldx z_operand_value_low_arr
    lda z_operand_value_high_arr
    jsr printx
    jsr space
    jsr printa
    jsr newline
    ldy #0
-   lda (string_array),y
    jsr printa
    jsr space
    iny
    cpy #14
    bne -
    jsr newline
}
    ; parse it as well?
    ldx z_operand_count
    cpx #2
    bcc .sread_done
    lda z_operand_value_high_arr + 1
    ldx z_operand_value_low_arr + 1
!ifdef TRACE_TOKENISE {
    jsr print_following_string
    !pet "tokenise_text ",0
    ldx z_operand_value_low_arr + 1
    lda z_operand_value_high_arr + 1
    jsr printx
    jsr space
    jsr printa
    jsr newline
}
    jsr tokenise_text
!ifdef TRACE_TOKENISE {
    ldy #0
-   lda (parse_array),y
    jsr printa
    jsr space
    iny
    cpy #10
    bne -
    jsr newline
}
.sread_done
    rts

} else {	

z_ins_aread
    ; aread text parse time routine -> (result)
    jsr evaluate_all_args
    ; read input
    lda z_operand_value_high_arr
    ldx z_operand_value_low_arr
    jsr read_text
!ifdef TRACE_READTEXT {
    jsr print_following_string
    !pet "read_text ",0
    ldx z_operand_value_low_arr
    lda z_operand_value_high_arr
    jsr printx
    jsr space
    jsr printa
    jsr newline
    ldy #0
-   lda (string_array),y
    jsr printa
    jsr space
    iny
    cpy #10
    bne -
    jsr newline
}
    ; parse it as well?
    ldx z_operand_count
    cpx #2
    bcc .aread_done
    lda z_operand_value_high_arr + 1
    ldx z_operand_value_low_arr + 1
!ifdef TRACE_TOKENISE {
    jsr print_following_string
    !pet "tokenise_text ",0
    ldx z_operand_value_low_arr + 1
    lda z_operand_value_high_arr + 1
    jsr printx
    jsr space
    jsr printa
    jsr newline
}
    jsr tokenise_text
!ifdef TRACE_TOKENISE {
    ldy #0
-   lda (parse_array),y
    jsr printa
    jsr space
    iny
    cpy #10
    bne -
    jsr newline
}
.aread_done
    ; debug - print parsearray
!ifdef DEBUG {
    ldy #0
-   lda (string_array),y
    tax
    jsr printx
    lda #$20
    jsr streams_print_output
    iny
    cpy #12
    bne -
    lda #$0d
    jsr streams_print_output
    ldy #0
-   lda (parse_array),y
    tax
    jsr printx
    lda #$20
    jsr streams_print_output
    iny
    cpy #16
    bne -
    lda #$0d
    jsr streams_print_output
}
    lda #0
    ldx #13
	jmp z_store_result
}

z_ins_print_char
	jsr evaluate_all_args
    ldx z_operand_value_low_arr
	jmp streams_print_output
	
z_ins_new_line
	lda #13
	jmp streams_print_output
	
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

set_z_address
    stx .addr + 2
    sta .addr + 1
    lda #$0
    sta .addr
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
    lda .addr + 1
    lda .addr
    adc #0
    lda .addr
    rts

!ifdef DEBUG {
print_z_address
    ldx .addr + 2 ; low
    lda #$20
    jsr $ffd2
    jsr printx
    ldx .addr + 1 ; high
    jsr printx
    lda #$0d
    jmp $ffd2
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
    sty .parse_array_index ; store away the index for later
    lda #0
    sta .zword      ; clear zword buffer
    sta .zword + 1
    sta .zword + 2
    sta .zword + 3
    sta .zword + 4
    sta .zword + 5
    lda .wordstart  ; truncate the word length to dictionary size
    clc
!ifdef Z4PLUS {
    adc #9
} else {
    adc #6
}
    sta .last_char_index 
    ; get started!
    lda #1
    sta .triplet_counter ; keep track of triplets to insert extra bit
    ldy .wordstart
.encode_chars
    ldx #5 ; shift 5 times to make place for the next zchar
    dec .triplet_counter
    bne .shift_zchar
    lda #3
    sta .triplet_counter
    ldx #6 ; no, make that 6 times (to fill up 3 zchars in 2 bytes)
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
!ifdef TRACE_TOKENISE {
    jsr printx ; next zchar to insert into zword
    jsr space
}
    ora .zword + 5
    sta .zword + 5
    iny
    cpy .last_char_index
    bne .encode_chars
    ; done. Add stop bit to mark end of string
    lda .zword + 4
    ora #$80
    sta .zword + 4
!ifdef TRACE_TOKENISE {
    ; print zword (6 or 9 bytes)
    jsr newline
    ldx .zword 
    jsr printx
    lda #44
    jsr $ffd2
    ldx .zword + 1
    jsr printx
    lda #44
    jsr $ffd2
    ldx .zword + 2
    jsr printx
    lda #44
    jsr $ffd2
    ldx .zword + 3
    jsr printx
    lda #44
    jsr $ffd2
    ldx .zword + 4
    jsr printx
    lda #44
    jsr $ffd2
    ldx .zword + 5
    jsr printx
    jsr newline
}
    ; find entry in dictionary 
    lda #0
    sta .dict_cnt     ; loop counter is 2 bytes
    sta .dict_cnt + 1
    ldx dict_entries     ; start address of dictionary
    lda dict_entries + 1
    jsr set_z_address
!ifdef Z4PLUS {
    lda #6
} else {
    lda #4
}
    sta .zchars_per_entry
.dictionary_loop
    ; show the dictonary word
!ifdef TRACE_SHOW_DICT_ENTRIES {
    lda .addr
    pha
    lda .addr + 1
    pha
    lda .addr + 2
    pha
    jsr print_addr
    jsr space
    pla 
    sta .addr + 2
    pla 
    sta .addr + 1
    pla 
    sta .addr
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
!ifdef TRACE_SHOW_DICT_ENTRIES {
    jsr printa
    jsr space
}
!ifdef Z4PLUS {
    cmp .zword,y
} else {
    cmp .zword + 2,y
}
    bne .zchars_differ
    inc .num_matching_zchars
.zchars_differ
    iny
    cpy .zchars_per_entry
    bne .loop_check_entry
!ifdef TRACE_SHOW_DICT_ENTRIES {
    jsr printy
    jsr space
    lda .num_matching_zchars
    jsr printa
    jsr newline
}
    cpy .num_matching_zchars
    beq .found_dict_entry ; we found the correct entry!
    ; skip the extra data bytes
    lda dict_len_entries
    sec
!ifdef Z4PLUS {
    sbc #6
} else {
    sbc #4
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
johanword
.zword !byte 0,0,0,0,0,0
.zchars_per_entry !byte 0
.num_matching_zchars !byte 0

read_text
    ; read line from keyboard into an array (address: a/x)
    ; See also: http://inform-fiction.org/manual/html/s2.html#p54
    ; input: a,x
    ; output: string_array
    ; side effects: zp_screencolumn, zp_screenline
    ; used registers: a,x,y
    stx string_array ; 7c
    clc
    adc #>story_start ; 05+20 = 25
    sta string_array + 1
    ; turn on blinking cursor
    lda #0
    sta zp_cursorswitch
    lda zp_screencolumn
    sta .read_text_startcolumn
!ifdef Z5PLUS {
    ldy #1
    lda (string_array),y
} else {
    lda #0
}
    sta .read_text_offset
.readkey
    jsr kernel_getchar
    cmp #$00
    beq .readkey
    cmp #$0d
    beq .read_text_done
    cmp #20
    bne +
    ; allow delete if anything in the buffer
    ldy zp_screencolumn
    cpy .read_text_startcolumn
    beq .readkey
    jsr kernel_printchar ; print the delete char
    jmp .readkey ; don't store in the array
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
    lda zp_screencolumn ; compare with size of keybuffer
    sec
    sbc .read_text_startcolumn
!ifdef Z5PLUS {
    clc
    adc .read_text_offset
}
    ldy #0
    cmp (string_array),y ; max characters in array
    bcs +
    ; keybuffer < maxchars
!ifdef Z5PLUS {
    iny
    sta (string_array),y ; number of characters in the array
}
    tay
!ifdef Z5PLUS {
    iny
}
    pla
    ; convert to lower case
    and #$7f
    sta (string_array),y ; store new character in the array
!ifndef Z5PLUS {
    iny
    lda #0
    sta (string_array),y ; store 0 after last char
}
    jmp .readkey
+   ; keybuffer >= maxchars
!ifdef Z5PLUS {
    lda (string_array),y ; max characters in array
    sec
    sbc #1
    iny
    sta (string_array),y ; number of characters in the array (max - 1)
}
    pla ; don't save this character (out of bounds)
    jmp .readkey
.read_text_done
    ; turn off blinking cursor
    lda #$ff
    sta zp_cursorswitch
    ; hide cursor if still visible
    ldy zp_screencolumn
    lda (zp_screenline),y
    and #$7f
    sta (zp_screenline),y
    lda #$0d
    jsr kernel_printchar
    rts
.read_text_offset !byte 0
.read_text_startcolumn !byte 0

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
!ifdef Z5PLUS {
    iny
    lda (string_array),y ; number of chars in text string
    clc
    adc #1
    sta .textend
    ldy #2 ; start position in text
} else {
-   iny
    lda (string_array),y
    bne -
    dey
    sty .textend
    ldy #1 ; start position in text
}
    ; look over text and find each word
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
    ; check for terminators
    tax
    tya
    pha     ; we need to reuse y, so save it on the stack
    txa
    ldy #0
--  cmp (terminators_ptr),y
    beq .terminator_found
    iny
    cpy num_terminators
    bne --
    pla
    tay ; restore y from the stack
    ; check if end of string
    cpy .textend
    bcs .word_found
    iny
    jmp -
.terminator_found
    pla
    tay ; restore y from the stack
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
    lda .wordend
    sec
    sbc .wordstart
    sta (parse_array),y ; length
    iny
    lda .wordstart
    sta (parse_array),y ; start index
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
    sta .escape_char_counter
.read_triplet_loop
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
    ldy .escape_char_counter
    beq .l1
    ldy #5
-   asl .escape_char
    dey
    bne -
    ora .escape_char
    sta .escape_char
    dec .escape_char_counter
    beq +
    jmp .next_zchar
+   lda .escape_char
    jsr streams_print_output
    jmp .next_zchar
.l1 cmp #0
    bne .l2
    ; space
    lda #$20
    jsr streams_print_output
    lda #0
    sta .alphabet_offset
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
.l4 ; escape char?
    cmp #6
    bne .l5
    ldy .alphabet_offset
    cpy #52
    bne .l5
    lda #0
    sta .escape_char
    lda #2
    sta .escape_char_counter
    jmp .next_zchar
.l5 ; normal char
    jsr convert_zchar_to_char
    jsr streams_print_output
    ; change back to A0
    lda #0
    sta .alphabet_offset
.next_zchar
    dex
    bpl --
    lda .packedtext + 1
    bne +
    jmp .read_triplet_loop
+   rts
.escape_char !byte 0
.escape_char_counter !byte 0

!ifdef DEBUG {
testtext
    ldx #$1b
    lda #$03
    jsr set_z_paddress
    jmp print_addr

testparser
    lda #63
    jsr $ffd2
    lda #$20
    jsr $ffd2
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
    lda #44
    sta $257e
    sta $257f
    sta $2560
    lda #$05
    ldx #$7c
    jsr read_text
    lda #$0d
    jsr streams_print_output
    ldy #0
-   lda $257c,y
    tax
    jsr printx
    lda #$20
    jsr streams_print_output
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
    jsr streams_print_output
    ldy #0
-   lda $25a7,y
    tax
    jsr printx
    lda #$20
    jsr streams_print_output
    iny
    cpy #16
    bne -
    rts
}

.addr !byte 0,0,0
.zchars !byte 0,0,0
.packedtext !byte 0,0
.alphabet_offset !byte 0
.alphabet ; 26 * 3
    !pet "abcdefghijklmnopqrstuvwxyz"
    !pet "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    !pet " ",13,"0123456789.,!?_#'",34, "/\-:()"
