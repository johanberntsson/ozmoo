; text opcodes

;TRACE_READTEXT = 1
;TRACE_TOKENISE = 1
;TRACE_SHOW_DICT_ENTRIES = 1
;TRACE_PRINT_ARRAYS = 1
;TRACE_HISTORY = 1
.text_tmp	!byte 0
.current_character !byte 0
.petscii_char_read = zp_temp
!ifdef USE_INPUTCOL {
input_colour_active !byte 0
}

!ifndef Z5PLUS {
!ifdef UNDO {
undo_possible   !byte 0
undo_requested  !byte 0
undo_msg        !pet "(Turn undone)",13,13,">",0 
}
}

; only ENTER + cursor + F1-F8 possible on a C64
num_terminating_characters !byte 1
terminating_characters !byte $0d
!ifdef Z5PLUS {	
	!byte $81,$82,$83,$84,$85,$86,$87,$88,$89,$8a,$8b,$8c

parse_terminating_characters
	; read terminating characters list ($2e)
	; must be one of function keys 129-154, 252-254.
	; 129-132: cursor u/d/l/r
	; 133-144: F1-F12 (only F1-F8 on C64)
	; 145-154: keypad 0-9 (not on C64 of course)
	; 252 menu click (V6) (not C64)
	; 253 double click (V6) (not C64)
	; 254 single click (not C64)
	; 255 means any function key
	ldy #header_terminating_chars_table
	jsr read_header_word
	cpx #0
	bne +
	cmp #0
	bne +
	rts
+   jsr set_z_address
	; read terminator
	ldy #1
-   jsr read_next_byte
	cmp #$ff
	bne +
	; all function keys (already the default)
	lda #$0d ; 13 keys in total (enter+cursor+F1-F8)
	sta num_terminating_characters
	rts
+   cmp #$8d ; F8=8c. Any higher values are not accepted in C64 mode
	bpl +
	sta terminating_characters,y
	iny 
+   cmp #$00
	bne -
	sty num_terminating_characters
	rts
}

!ifdef BENCHMARK {
benchmark_commands
; !pet "turn statue w:turn it e:turn it n:n:open door:",255,0
!pet 255,"turn statue w:turn it e:turn it n:n:open door:n:turn flashlight on:n:examine model:press green:g:g:press black:g:press white:g:press green:g:g:press black:press blue:press green:g:g:g:press red:g:g:take ring:e:e:take yellow card:s:take slide:put it in slide projector:turn slide projector on:focus slide projector:take film:examine film projector:remove cap:drop it:put film in film projector:turn film projector on:examine screen:n:w:w:s:e:e:examine piano:open lid:take violet card:play tomorrow:push piano n:d:s:take dirty pillar:n:u:push piano s:g:d:n:take meter:s:u:drop pillar:w:w:w:drop ring:drop meter:e:drop yellow and violet:n:drop letter and photo:s:w:enter fireplace:take brick and drop it:u:u:u:e:d:take penguin:u:w:d:d:d:take indigo card:e:drop penguin:e:drop indigo:w:examine red statue:examine white statue:examine blue statue:e:e:move painting:take green card:examine safe:turn dial right 3:turn dial left 7:turn dial right 5:open safe:take grater:w:drop green:w:drop grater:e:open closet:enter closet:pull third peg:open door:n:examine newel:turn newel:e:take sack:open window:open sack:take finch:drop sack:w:w:s:move mat:take red card:n:e:s:pull second peg:open door:n:drop red:w:drop finch:e:enter closet:take bucket:n:n:unlock patio door:open door:n:take orange card:e:n:n:examine cannon:fill bucket with water:e:s:w:s:s:enter closet:hang bucket on third peg:n:u:open closet:s:wait:wait:open door:n:open panel:open trunk:take hydrant:d:d:w:drop hydrant:e:take all:n:w:w:d:open door:s:take blue card:n:turn computer on:examine it:put red in slot:put yellow in slot:put orange in slot:put green in slot:put blue in slot:put indigo in slot:put violet in slot:examine display:u:take matchbox:open it:take match:drop matchbox:e:e:n:e:n:n:take cannon ball:put it in cannon:light match:light fuse:open compartment:take mask:e:s:w:s:s:w:drop mask:e:s:open mailbox:take yellowed piece of paper:take card:examine card:drop card:n:n:w:take thin:e:n:n:nw:take shovel:ne:n:put thin on yellowed:n:w:n:w:n:w:s:w:w:n:w:s:e:s:e:n:e:s:w:n:w:s:w:n:w:s:w:n:e:n:e:n:e:e:n:e:s:e:e:s:e:n:e:n:e:s:w:s:w:s:e:n:w:s:dig ground with shovel:take stamp:n:e:s:w:n:e:n:e:n:w:s:w:s:w:n:w:w:n:w:s:w:w:s:w:s:w:s:e:n:e:s:e:n:e:s:e:n:w:s:w:n:w:n:e:s:e:e:n:e:s:e:s:e:s:w:s:e:s:s:w:drop stamp:e:drop all except flashlight:w:take red statuette:e:u:open door:enter closet:take skis:n:d:n:n:e:n:n:n:drop flashlight:s:e:e:wear skis:n:take match:light red statue:put wax on match:take skis off:swim:s:d:d:w:u:u:n:n:u:light match:light red statue:lift left end of plank:pull chain:burn rope:stand on right end of plank:wait:blow statue out:drop skis:drop statue:take ladder and flashlight:d:hang ladder on hooks:examine safe:turn dial left 4:turn dial right 5:turn dial left 7:open safe:take film:u:s:e:s:w:s:s:w:drop film:call 576-3190:n:w:d:take toupee:take peg and note:read note:u:e:e:s:u:s:put peg in hole:get gun:shoot herman:get sword:kill herman with sword:get shears:kill herman with shears:untie hildegarde:",255,0
benchmark_read_char
	lda benchmark_commands
	beq +++
	inc benchmark_read_char + 1
	bne +
	inc benchmark_read_char + 2
+	cmp #255
	beq ++
	sta .petscii_char_read
	jsr translate_petscii_to_zscii
+++	rts
++	jsr dollar
	lda ti_variable
	jsr print_byte_as_hex
	lda ti_variable + 1
	jsr print_byte_as_hex
	lda ti_variable + 2
	jsr print_byte_as_hex
	jsr space
	jsr printchar_flush
	lda #13
	rts
}
	
z_ins_print_char
	; lda #0
	; sta alphabet_offset
	; sta escape_char_counter
	; sta abbreviation_command
	lda z_operand_value_low_arr
;	jsr invert_case
;	jsr translate_zscii_to_petscii
	jmp streams_print_output
	
z_ins_new_line
	lda #13
	jmp streams_print_output

!ifdef Z4PLUS {	
z_ins_read_char
	; read_char 1 [time routine] -> (result)
	; ignore argument 0 (always 1)
	; ldy z_operand_value_low_arr
	; optional time routine arguments
	jsr printchar_flush
	; clear [More] counter
	jsr clear_num_rows
	jsr turn_on_cursor
	ldy #0
	tya
	sty .read_text_time
	sty .read_text_time + 1
	ldy z_operand_count
	cpy #3
	bne .read_char_loop
	ldy z_operand_value_high_arr + 1
	sty .read_text_time
	ldy z_operand_value_low_arr + 1
	sty .read_text_time + 1
	ldy z_operand_value_high_arr + 2
	sty .read_text_routine
	ldy z_operand_value_low_arr + 2
	sty .read_text_routine + 1
!ifdef USE_BLINKING_CURSOR {
	jsr init_cursor_timer
}
	jsr init_read_text_timer
.read_char_loop
	jsr read_char
	cmp #0
	beq .read_char_loop ; timer routine returned false
	pha
	jsr turn_off_cursor
	jsr start_buffering
	pla
	cmp #1
	bne +
	lda #0 ; time routine returned true, and read_char should return 0
+   tax
	lda #0
	jmp z_store_result
}
	
!ifdef Z5PLUS {	
z_ins_tokenise_text
	; tokenise text parse dictionary flag
	; setup string_array
	ldx z_operand_value_low_arr
	lda z_operand_value_high_arr
	stx string_array
!ifndef COMPLEX_MEMORY {
	clc
	adc #>story_start
}
	sta string_array + 1
	; setup user dictionary, if supplied
	lda z_operand_count
	cmp #3
	bcc .no_user_dictionary
	ldx z_operand_value_low_arr + 2
	txa
	ora z_operand_value_high_arr + 2
	beq .no_user_dictionary

	; user dictionary

	lda z_operand_value_high_arr + 2 ; X is already set
	jsr parse_user_dictionary
	jmp .tokenise_main
	
.no_user_dictionary
	; Setup default dictionary
	lda dict_is_default
	bne +
	jsr parse_default_dictionary
+

.tokenise_main
	; setup parse_array and flag
	ldy #0
	lda z_operand_count
	cmp #4
	bcc .flag_set
	ldy z_operand_value_low_arr + 3
.flag_set	
	ldx z_operand_value_low_arr + 1
	lda z_operand_value_high_arr + 1
	jmp tokenise_text

z_ins_encode_text
	; encode_text zscii-text length from coded-text
	; setup string_array
	ldx z_operand_value_low_arr
	lda z_operand_value_high_arr
	stx string_array
!ifndef COMPLEX_MEMORY {
	clc
	adc #>story_start
}
	sta string_array + 1
	; setup length (seems okay to ignore)
	; ldx z_operand_value_low_arr + 1
	; setup from
	ldx z_operand_value_low_arr + 2
	stx .wordstart
	; do the deed
	jsr encode_text
	; save result
	ldx z_operand_value_low_arr + 3
	lda z_operand_value_high_arr + 3
	stx string_array
!ifndef COMPLEX_MEMORY {
	clc
	adc #>story_start
}
	sta string_array + 1
	ldy #0
-   lda zword,y
	+macro_string_array_write_byte
;	sta (string_array),y
	iny
	cpy #6
	bne -
	rts
}

z_ins_print_addr 
	ldx z_operand_value_low_arr
	lda z_operand_value_high_arr
	jsr set_z_address
	jmp print_addr

z_ins_print_paddr
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
	stx zp_temp
	tax
	tya
	ldy zp_temp
	jmp set_z_pc

z_ins_print_ret
	jsr z_ins_print
	lda #$0d
	jsr streams_print_output
	lda #0
	ldx #1
	jmp stack_return_from_routine


!ifdef USE_INPUTCOL {
activate_inputcol
!ifdef Z4 {
	lda #0
	sta input_colour_active
	cpx #3
	bcs .dont_colour_input ; time and routine are set
}
; Set inputcolour
	ldx darkmode
	ldy inputcol,x
	lda zcolours,y
	jsr s_set_text_colour
	lda #$ff
	sta input_colour_active
.dont_colour_input
	rts
}


; ============================= New unified read instruction
z_ins_read
	; z3: sread text parse
	; z4: sread text parse time routine
	; z5: aread text parse time routine -> (result)
	jsr printchar_flush

!ifndef Z5PLUS {
!ifdef UNDO {
	lda undo_state_available
	sta undo_possible
}
}

!ifndef Z4PLUS {
	; Z1 - Z3 should redraw the status line before input
	jsr draw_status_line
}
!ifdef Z4PLUS {
	; arguments that need to be copied to their own locations because there *may* be a timed interrupt call
	ldx z_operand_count
	stx .read_text_operand_count
	ldy z_operand_value_low_arr + 1
	sty .read_parse_buffer
	ldy z_operand_value_high_arr + 1
	sty .read_parse_buffer + 1
	lda #0
	tay
	cpx #3
	bcc + ; time and routine are omitted
	ldy z_operand_value_high_arr + 3
	sty .read_text_routine
	ldy z_operand_value_low_arr + 3
	sty .read_text_routine + 1
	lda z_operand_value_high_arr + 2
	ldy z_operand_value_low_arr + 2
+	sta .read_text_time
	sty .read_text_time + 1
}



!ifdef USE_INPUTCOL {
	; x = 3 means the routine does not turn on input colour
	jsr activate_inputcol
}

	; Read input
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
	jsr colon
	ldx string_array
	lda string_array+1
	jsr printx
	jsr space
	jsr printa
!ifdef Z5PLUS {
	jsr colon
	lda .read_text_return_value
	jsr printa
}
	jsr newline
	ldy #0
-	+macro_string_array_read_byte
;	lda (string_array),y
	jsr printa
	jsr space
	iny
	cpy #10
	bne -
	jsr newline
}
!ifdef Z5PLUS {
	; parse it as well? In Z5, this can be avoided by setting parse to 0
	ldx .read_text_operand_count
	cpx #2
	bcc .read_done
	lda .read_parse_buffer
	ora .read_parse_buffer + 1
	beq .read_done

	; Setup default dictionary
	lda dict_is_default
	bne +
	jsr parse_default_dictionary
+
}

!ifndef Z4PLUS {
	lda z_operand_value_high_arr + 1
	ldx z_operand_value_low_arr + 1
} else {
	lda .read_parse_buffer + 1
	ldx .read_parse_buffer
}
	ldy #0
	jsr tokenise_text
!ifdef TRACE_TOKENISE {
	ldy #0
-	+macro_parse_array_read_byte
	jsr printa
	jsr space
	iny
	cpy #10
	bne -
	jsr newline
}
.read_done
	jsr start_buffering
	; debug - print parsearray
!ifdef TRACE_PRINT_ARRAYS {
	ldy #0
-	+macro_string_array_read_byte
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
-	+macro_parse_array_read_byte
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
!ifdef DEBUG {
!ifdef PREOPT {
	jsr print_following_string
	!raw "[preopt mode. type xxx to exit early.]",13,0
!ifdef Z5PLUS {
	ldy #2
} else {
	ldy #1
}
.check_next_preopt_exit_char
	+macro_string_array_read_byte
	cmp #$78
	bne .not_preopt_exit
	iny
!ifdef Z5PLUS {
	cpy #5
} else {
	cpy #4
}
	bne .check_next_preopt_exit_char
; Exit PREOPT mode
	ldx #1
	jmp print_optimized_vm_map
.not_preopt_exit	
}	
}
!ifdef Z5PLUS {
	lda #0
	ldx .read_text_return_value
	jmp z_store_result
} else {


!ifdef USE_INPUTCOL {
; Restore normal text colour
	lda #0
	sta input_colour_active
	ldx darkmode
	ldy fgcol,x
	lda zcolours,y
	jsr s_set_text_colour
}

!ifdef UNDO {
	lda undo_requested
	beq ++
	dec undo_requested
	jsr do_restore_undo
	lda #>undo_msg
	ldx #<undo_msg
	jsr printstring_raw
	jmp +++
++	
	; Save undo state, where z_pc points to where this read instruction starts
	ldx #2
-	lda z_pc,x
	pha
	lda z_pc_before_instruction,x
	sta z_pc,x
	dex
	bpl -
	jsr do_save_undo
	pla
	sta z_pc
	pla
	sta z_pc + 1
	pla
	sta z_pc + 2
	
+++	lda #0
	sta undo_possible ; Set to not possible whenever we exit the read instruction
}
	rts
}
; ============================= End of new unified read instruction

!ifdef Z5PLUS {
z_ins_check_unicode
	lda #0
	tax
	jmp z_store_result
	
z_ins_print_unicode
	lda #$28 ; (
	jsr streams_print_output
	lda #$23 ; #
	jsr streams_print_output
	jsr print_num_unsigned
	lda #$29 ; )
	jmp streams_print_output
}
	
convert_zchar_to_char
	; input: a=zchar
	; output: a=char
	; side effects:
	; used registers: a,y
	cmp #$20
	beq +++
	cmp #6
	bcc +++
	sec
	sbc #6
	clc
	adc alphabet_offset
	tay
	lda z_alphabet_table,y
+++	rts

translate_petscii_to_zscii
	ldx #character_translation_table_in_end - character_translation_table_in - 1
-	cmp character_translation_table_in,x
	bcc .no_match
	beq .translation_match
	dex
	bpl -
.no_match	
	cmp #$41
	bcc .case_conversion_done
	cmp #$5b
	bcs .not_lower_case
	; Lower case. $41 -> $61
	ora #$20
	bcc .case_conversion_done ; Always branch
.not_lower_case
	cmp #$c1
	bcc .case_conversion_done
	cmp #$db
	bcs .case_conversion_done
	; Upper case. $c1 -> $41
	and #$7f
.case_conversion_done
	rts
.translation_match
	lda character_translation_table_in_end,x
	rts

	
convert_char_to_zchar
	; input: a=char
	; output: store zchars in z_temp,x. Increase x. Exit if x >= ZCHARS_PER_ENTRY
	; side effects:
	; used registers: a,x
	; NOTE: This routine can't convert space (code 0) or newline (code 7 in A2) properly, but there's no need to either.
	sty zp_temp + 4
	ldy #0
-   cmp z_alphabet_table,y
	beq .found_char_in_alphabet
	iny
	cpy #26*3
	bne -
	; Char is not in alphabet
	pha
	lda #5
	sta z_temp,x
	inx
	lda #6
	sta z_temp,x
	inx
	pla
	pha
	lsr
	lsr
	lsr
	lsr
	lsr
	sta z_temp,x
	pla
	and #%00011111
	inx
	bne .store_last_char ; Always branch
	
.found_char_in_alphabet
	cpy #26
	bcc .found_in_a0
!ifndef Z3PLUS {
	lda #2 ; Shift up to A1
} else {
	lda #4 ; Shift to A1
}
	cpy #26*2
	bcc .found_in_a1
!ifndef Z3PLUS {
	lda #3 ; Shift down to A2
} else {
	lda #5 ; Shift to A2
}
.found_in_a1
	sta z_temp,x
	inx
	tya
	sec
-	sbc #26
	cmp #26
	bcs -
	tay
.found_in_a0
	tya
	clc
	adc #6
.store_last_char	
	sta z_temp,x
	inx
.convert_return
	ldy zp_temp + 4
	rts

.first_word = z_temp ;	!byte 0,0
.last_word = z_temp + 2 ; 	!byte 0,0
.median_word = z_temp + 4	; !byte 0,0
.final_word = zp_temp;  	!byte 0	
	
.is_word_found = zp_temp + 1 ; !byte 0
.triplet_counter = zp_temp + 2; !byte 0
.last_char_index		!byte 0
.parse_array_index 		!byte 0
.dictionary_address = zp_temp + 3 ;  !byte 0,0
; .zword !byte 0,0,0,0,0,0
	
	
!ifdef Z4PLUS {
	ZCHARS_PER_ENTRY = 9
} else {
	ZCHARS_PER_ENTRY = 6
}
ZCHAR_BYTES_PER_ENTRY = ZCHARS_PER_ENTRY * 2 / 3
ZWORD_OFFSET = 6 - ZCHAR_BYTES_PER_ENTRY

encode_text
	; input .wordstart
	; registers: a,x,y
	; side effects: .last_char_index, .triplet_counter, zword
	ldy .wordstart ; Pointer to current character
	ldx #0 ; Next position in z_temp
-	+macro_string_array_read_byte
;	lda (string_array),y
	jsr convert_char_to_zchar
	cpx #ZCHARS_PER_ENTRY
	bcs .done_converting_to_zchars
	iny
	cpy .wordend
	bcc -
	; Pad rest of word
	lda #5 ; Pad character
-	sta z_temp,x
	inx
	cpx #ZCHARS_PER_ENTRY
	bcc -
.done_converting_to_zchars
	ldx #0 ; x = start of current triplet 
	ldy #0 ; Pointer to next character in buffer
-	lda z_temp,y
	sta zword + ZWORD_OFFSET,x
	iny
	lda z_temp,y
	asl
	asl
	asl
	asl
	rol zword + ZWORD_OFFSET,x
	asl
	rol zword + ZWORD_OFFSET,x
	iny
	ora z_temp,y
	sta zword + ZWORD_OFFSET + 1,x
	iny
	inx
	inx
	cpx #(2 * (ZCHARS_PER_ENTRY / 3))
	bcc -
	lda zword + 4
	ora #$80
	sta zword + 4
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
	lda #1
	sta .is_word_found ; assume success until proven otherwise
	jsr encode_text
!ifdef TRACE_TOKENISE {
	; print zword (6 or 9 bytes)
	jsr newline
	ldx zword 
	jsr printx
	jsr comma
	ldx zword + 1
	jsr printx
	jsr comma
	ldx zword + 2
	jsr printx
	jsr comma
	ldx zword + 3
	jsr printx
	jsr comma
	ldx zword + 4
	jsr printx
	jsr comma
	ldx zword + 5
	jsr printx
	jsr newline
}
	; find entry in dictionary, using binary search
	; Step 1: Set start and end of dictionary
	lda #0
	sta .final_word
	sta .first_word
	sta .first_word + 1
	lda dict_num_entries + 1 ; This is stored High-endian
	tax
	ora dict_num_entries ; This is stored High-endian
	bne +
	jmp .no_entry_found
+	txa
	sec
	sbc #1
	sta .last_word
	lda dict_num_entries
	sbc #0
	sta .last_word + 1
!ifdef Z5PLUS {
	lda dict_ordered
	bne .loop_check_next_entry
	jmp .find_word_in_unordered_dictionary
}		
	; Step 2: Calculate the median word
.loop_check_next_entry
	lda .last_word
	cmp .first_word
	bne .more_than_one_word
	ldx .last_word + 1
	cpx .first_word + 1
	bne .more_than_one_word
; This is the last possible word that can match
	dec .final_word ; Signal that this is the last possible word
.more_than_one_word
	sec
	sbc .first_word
	tax
	lda .last_word + 1
	sbc .first_word + 1
	lsr
	tay
	txa
	ror
	clc
	adc .first_word
	sta .median_word
	sta multiplier
	tya
	adc .first_word + 1
	sta .median_word + 1
	sta multiplier + 1
	
	; Step 3: Set the address of the median word
	lda dict_len_entries
	jsr mult8
	lda product
	clc
	adc dict_entries
	tax
	lda product + 1
	adc dict_entries + 1
	sta .dictionary_address
	stx .dictionary_address + 1
	jsr set_z_address

	; show the dictonary word
!ifdef TRACE_SHOW_DICT_ENTRIES {
	jsr dollar
	lda .dictionary_address
	jsr print_byte_as_hex
	lda .dictionary_address + 1
	jsr print_byte_as_hex
	jsr space

	lda z_address + 1
	pha
	lda z_address + 2
	pha
	jsr print_addr
	pla 
	sta z_address + 2
	pla 
	sta z_address + 1
}

	; check if correct entry
	ldy #0
.loop_check_entry
	jsr read_next_byte
!ifdef Z4PLUS {
	cmp zword,y
} else {
	cmp zword + 2,y
}
	bne .zchars_differ
	iny
	cpy #ZCHAR_BYTES_PER_ENTRY
	bne .loop_check_entry
	beq .found_dict_entry ; Always branch
.zchars_differ
	php
	lda .final_word
	beq .not_final_word
	plp
	bne .no_entry_found ; Always branch
.not_final_word
	plp
	bcs .larger_than_sought_word
; The median word is smaller than the sought word
!ifdef TRACE_SHOW_DICT_ENTRIES {
	lda #60
	jsr streams_print_output
	jsr newline
}
	lda .median_word
	clc
	adc #1
	sta .first_word
	lda .median_word + 1
	adc #0
	sta .first_word + 1
	jmp .loop_check_next_entry ; Always branch
.larger_than_sought_word
; The median word is larger than the sought word
!ifdef TRACE_SHOW_DICT_ENTRIES {
	lda #62
	jsr streams_print_output
	jsr newline
}
	lda .median_word
	cmp .first_word
	bne .median_is_not_first
	ldy .median_word + 1
	cpy .first_word + 1
	beq .no_entry_found
.median_is_not_first
	sec
	sbc #1
	sta .last_word
	lda .median_word + 1
	sbc #0
	sta .last_word + 1
	jmp .loop_check_next_entry ; Always branch

	
; no entry found
.no_entry_found
!ifdef TRACE_SHOW_DICT_ENTRIES {
	lda #60
	jsr streams_print_output
	lda #62
	jsr streams_print_output
	jsr newline
}
	lda #0
	sta .dictionary_address
	sta .dictionary_address + 1
	sta .is_word_found
	lda .ignore_unknown_words
	beq .store_find_result
	ldy .parse_array_index
	iny
	iny
	rts

; After adding an rts above, the following code can't be reached anyway.	
;!ifdef TRACE_SHOW_DICT_ENTRIES {
;	beq .store_find_result ; Only needed if TRACE_SHOW_DICT_ENTRIES is set
;}
.found_dict_entry
	; store result into parse_array and exit
!ifdef TRACE_SHOW_DICT_ENTRIES {
	lda #61
	jsr streams_print_output
	jsr newline
}
.store_find_result
	ldy .parse_array_index
	lda .dictionary_address
	+macro_parse_array_write_byte
;	sta (parse_array),y
	iny
	lda .dictionary_address + 1
	+macro_parse_array_write_byte
;	sta (parse_array),y
	iny
	rts

!ifdef Z5PLUS {
.find_word_in_unordered_dictionary
; In the end, jump to either .found_dict_entry or .no_entry_found
	ldx dict_entries
	stx .dictionary_address + 1 ; Stored with high-byte first!
	lda dict_entries + 1
	sta .dictionary_address ; Stored with high-byte first!
.unordered_check_next_word
	jsr set_z_address

	; check if correct entry
	ldy #0
.unordered_loop_check_entry
	jsr read_next_byte
	cmp zword,y ; Correct for z4+, and this code is only built for z5+
	bne .unordered_not_a_match
	iny
	cpy #ZCHAR_BYTES_PER_ENTRY
	bne .unordered_loop_check_entry
	beq .found_dict_entry ; Always branch
	
	
.unordered_not_a_match	
	inc .first_word
	bne +
	inc .first_word + 1
+	lda .last_word
	cmp .first_word
	lda .last_word + 1
	sbc .first_word + 1
	bcc + ; No more words to check
	lda .dictionary_address + 1
	clc
	adc dict_len_entries
	tax
	sta .dictionary_address + 1
	lda .dictionary_address
	adc #0
	sta .dictionary_address
	bcc .unordered_check_next_word ; Always branch

+	bcs .no_entry_found ; Always branch
} ; End of !ifdef Z5PLUS

!ifdef USE_BLINKING_CURSOR {
update_cursor_timer
	; calculate when the next cursor update occurs
!ifdef SMOOTHSCROLL {
	jsr wait_smoothscroll
}
	jsr kernal_readtime  ; read current time (in jiffys)
	clc
	adc #USE_BLINKING_CURSOR
	sta .cursor_jiffy + 2
	txa
	adc #0
	sta .cursor_jiffy + 1
	tya
	adc #0
	sta .cursor_jiffy
	rts
}

!ifdef Z4PLUS {
init_read_text_timer
	lda .read_text_time
	ora .read_text_time + 1
	bne +
	rts ; no timer
+   ; calculate timer interval in jiffys (1/60 second, regardless of TV standard)
	lda #0
	sta z_temp ; Top byte of result
	lda .read_text_time ; High byte
	sta z_temp + 1 ; Middle byte of result
	lda .read_text_time + 1 ; Low byte
	; Multiply by 2
	asl
	rol z_temp + 1
	rol z_temp
	; Add starting value
	clc
	adc .read_text_time + 1
	pha
	lda z_temp + 1
	adc .read_text_time
	sta .read_text_time_jiffy + 1
	lda z_temp
	adc #0
	sta .read_text_time_jiffy
	; Multiply by 2
	pla
	asl
	sta .read_text_time_jiffy + 2
	rol .read_text_time_jiffy + 1
	rol .read_text_time_jiffy
	; lda .read_text_time
	; sta multiplier + 1
	; lda .read_text_time + 1
	; sta multiplier
	; lda #0
	; sta multiplicand + 1
	; lda #6
	; sta multiplicand ; t*6 to get jiffies
	; jsr mult16
	; lda product
	; sta .read_text_time_jiffy + 2
	; lda product + 1
	; sta .read_text_time_jiffy + 1
	; lda product + 2
	; sta .read_text_time_jiffy
update_read_text_timer
	; prepare time for next routine call (current time + time_jiffy)
!ifdef SMOOTHSCROLL {
	jsr wait_smoothscroll
}
	jsr kernal_readtime  ; read current time (in jiffys)
	clc
	adc .read_text_time_jiffy + 2
	sta .read_text_jiffy + 2
	txa
	adc .read_text_time_jiffy + 1
	sta .read_text_jiffy + 1
	tya
	adc .read_text_time_jiffy
	sta .read_text_jiffy
	rts
}

getchar_and_maybe_toggle_darkmode
	stx .getchar_save_x
!ifdef SMOOTHSCROLL {
	jsr wait_smoothscroll
}
	jsr kernal_getchar
!ifndef NODARKMODE {
 	cmp #133 ; Charcode for F1
	bne +
	jsr toggle_darkmode
	jmp .did_something
+	
}
!ifdef SMOOTHSCROLL {
!ifdef TARGET_C128 { ; Smooth scroll not available on 80 col C128
	bit COLS_40_80
	bmi +
}
	cmp #18 ; Ctrl-9
	bne +
	bit smoothscrolling
	bmi .did_something
	ldx #0
	stx scroll_delay
	jsr toggle_smoothscroll
	jmp .did_something
+
}
!ifdef SCROLLBACK {
	cmp #135 ; F5
	bne +
	ldx scrollback_supported
	beq +
	jsr launch_scrollback
	jmp .did_something
+	
}
	ldx #8
-	cmp .scroll_delay_keys,x
	beq .is_scroll_delay_key
	dex
	bpl -
	bmi +
.is_scroll_delay_key
	lda scroll_delay_values,x
	sta scroll_delay
!ifdef SMOOTHSCROLL {
	bit smoothscrolling
	bpl .did_something
	jsr toggle_smoothscroll
}
	jmp .did_something
+
	cmp #11 ; Ctrl-K for key repeating
	bne +
	; Toggle key repeat (People using fast emulators want to turn it off)
	lda #64
	bit key_repeat
	bvc ++
	lda #0
++	sta key_repeat
	jmp .did_something
+

!ifndef Z5PLUS {
!ifdef UNDO {
	cmp #21 ; Ctrl-U for Undo
	bne +
	ldx undo_possible
	beq +
	stx undo_requested
	dec undo_possible
	jmp .did_something
+	
}
}

	cmp #4 ; Ctrl-D to forget device# for saves
	bne .did_nothing
	; Forget device# for saves
	dec ask_for_save_device ; Normally 0. Even if we decrease 100 times, we still get the same effect
	; Fall through to .did_something
	
.did_something
	ldx #2
	jsr play_beep
	lda #0
.did_nothing
	ldx .getchar_save_x
	rts

!ifdef SMOOTHSCROLL {
scroll_delay !byte 0
} else {
scroll_delay !byte 1 ; Start in fastest flicker-free + tear-free scroll speed
}

.scroll_delay_keys !byte 146, 144, 5, 28, 159, 156, 30, 31, 158 ; Ctrl-0, 1, 2, 3
!ifdef TARGET_MEGA65 {
scroll_delay_values !byte 0, 1, 2, 3, 4, 5, 6, 7, 9 ; Ctrl-0, 1, 2, 3
} else {
scroll_delay_values !byte 0, 1, 2, 3, 4, 5, 6, 7, 8 ; Ctrl-0, 1, 2, 3
}
.getchar_save_x !byte 0



read_char
	; return: 0,1: return value of routine (false, true)
	;         any other number: char value
!ifdef BENCHMARK {
	jsr benchmark_read_char
	cmp #0
	beq +
	cmp #58 ; colon
	bne ++
	lda #13
++	rts
+
}

!ifdef USE_BLINKING_CURSOR {
	; check if time for to update the blinking cursor
	; http://www.6502.org/tutorials/compare_beyond.html#2.2
!ifdef SMOOTHSCROLL {
	jsr wait_smoothscroll
}
	jsr kernal_readtime   ; read start time (in jiffys) in a,x,y (low to high)
	cmp .cursor_jiffy + 2
	txa
	sbc .cursor_jiffy + 1
	tya
	sbc .cursor_jiffy
	bcc .no_cursor_blink
	; blink the cursor
	;
	; set up next time out
	jsr update_cursor_timer
	; cursor on/off depending on if s_cursormode is even/odd
	lda #CURSORCHAR ; cursor on
	sta cursor_character
	jsr update_cursor
	inc s_cursormode
	lda s_cursormode
	and #$01
	beq .no_cursor_blink
	lda #$20 ; blank space, cursor off
	sta cursor_character
	jsr update_cursor
.no_cursor_blink
}
	
!ifdef Z4PLUS {
    ; check if we have a sound callback to run
!ifdef SOUND {
    ; check if needed to run the @sound_effect routine argument
    lda trigger_sound_routine
    beq .no_sound_trigger
    lda #0
    sta trigger_sound_routine
    ; run the routine without arguments
    ; the routine address is in sound_arg_routine
    ; we are not interested in the return value
    lda sound_arg_routine  + 1
    sta z_operand_value_high_arr
    ldx sound_arg_routine  
    stx z_operand_value_low_arr
    lda #z_exe_mode_return_from_read_interrupt
    ldx #0
    ldy #0
    jsr stack_call_routine
    ; let the interrupt routine start
    jsr z_execute
.no_sound_trigger
}
	; check if time for routine call
	; http://www.6502.org/tutorials/compare_beyond.html#2.2
	lda .read_text_time
	ora .read_text_time + 1
	beq .no_timer
!ifdef SMOOTHSCROLL {
	jsr wait_smoothscroll
}
	jsr kernal_readtime   ; read start time (in jiffys) in a,x,y (low to high)
	cmp .read_text_jiffy + 2
	txa
	sbc .read_text_jiffy + 1
	tya
	sbc .read_text_jiffy
	bcc .no_timer
.call_routine	
	; current time >= .read_text_jiffy. Time to call routine
	jsr turn_off_cursor

	lda .read_text_routine
	sta z_operand_value_high_arr
	ldx .read_text_routine + 1
	stx z_operand_value_low_arr
	lda #z_exe_mode_return_from_read_interrupt
	ldx #0
	ldy #0
	jsr stack_call_routine
	; let the interrupt routine start, so we need to rts.
	jsr z_execute

	jsr printchar_flush

	jsr turn_on_cursor
	; Interrupt routine has been executed, with value in word
	; z_interrupt_return_value
	; set up next time out
	jsr update_read_text_timer
	; just return the value: 0 or 1 (true or false)
	lda z_interrupt_return_value
	ora z_interrupt_return_value + 1
	beq +
	lda #1
+	rts
}
.no_timer
	jsr getchar_and_maybe_toggle_darkmode

!ifndef Z5PLUS {
!ifdef UNDO {
	ldy undo_requested
	beq ++
	lda #13 ; Pretend the user pressed Enter, to get out of routine
++
}
}

	cmp #$00
	bne +
	jmp read_char
+	sta .petscii_char_read
	jmp translate_petscii_to_zscii

!ifdef USE_BLINKING_CURSOR {
init_cursor_timer
reset_cursor_blink
	; resets the cursor timer and blink mode
	; effectively puts the cursor back on the screen for another timer duration
	lda #$00
	sta .cursor_jiffy
	sta .cursor_jiffy + 1
	sta .cursor_jiffy + 2
	lda #$01
	sta s_cursormode
	rts
}

read_text
	; read line from keyboard into an array (address: a/x)
	; See also: http://inform-fiction.org/manual/html/s2.html#p54
	; input: a,x, .read_text_time (Z4PLUS), .read_text_routine (Z4PLUS)
	; output: string_array, .read_text_return_value (Z5PLUS)
	; side effects: zp_screencolumn, zp_screenline, .read_text_jiffy
	; used registers: a,x,y
	stx string_array
!ifndef COMPLEX_MEMORY {
	clc
	adc #>story_start
}
	sta string_array + 1
	jsr printchar_flush
!ifdef SCROLLBACK {
	lda read_text_level
	bne +
	; Entering top level read_text call - pause copying to scrollback buffer
	jsr s_reset_scrolled_lines
	lda zp_screenrow
	sta read_text_screenrow_start
+	inc read_text_level
}	
	; clear [More] counter
	jsr clear_num_rows
!ifdef USE_BLINKING_CURSOR {
	jsr init_cursor_timer
}
!ifdef Z4PLUS {
	; check timer usage
	jsr init_read_text_timer
}
!ifdef USE_HISTORY {
	jsr enable_history_keys
}
	ldy #0
	+macro_string_array_read_byte
;	lda (string_array),y
!ifdef Z5PLUS {
	tax
	inx
	stx .read_text_char_limit
} else {
	sta .read_text_char_limit
}
	; store start column
	iny
!ifdef Z5PLUS {
	+macro_string_array_read_byte
	clc
	adc #1
;
} else {
	lda #0
	+macro_string_array_write_byte
	tya
}
	sta .read_text_column
	; turn on blinking cursor
	jsr turn_on_cursor
.readkey
	jsr get_cursor ; x=row, y=column
	stx .read_text_cursor
	sty .read_text_cursor + 1
	jsr read_char
!ifdef Z4PLUS {
	cmp #0
	bne .timer_didnt_return_false

; ########## Start of code for handling that timer routine returned false

	; timer routine returned false
	; did the routine draw something on the screen?
	jsr get_cursor ; x=row, y=column
	cpy .read_text_cursor + 1
	beq .readkey
	; text changed, redraw input line
	jsr turn_off_cursor
	jsr clear_num_rows
!ifdef Z5PLUS {
	ldy #1
	+macro_string_array_read_byte
	tax
.p0 cpx #0
	beq .p1
	iny
	+macro_string_array_read_byte
	jsr translate_zscii_to_petscii
!ifdef DEBUG {
	bcc .could_convert
	cmp #0
	beq .done_printing_this_char
	jsr print_bad_zscii_code
	jmp .done_printing_this_char
.could_convert
} else {
	bcs .done_printing_this_char
}
	jsr s_printchar
.done_printing_this_char
	dex
	jmp .p0
.p1   
} else { ; not Z5PLUS
	ldy #1
.p0	+macro_string_array_read_byte
	cmp #0
	beq .p1
	jsr translate_zscii_to_petscii
!ifdef DEBUG {
	bcc .could_convert
	cmp #0
	beq .done_printing_this_char
	jsr print_bad_zscii_code
	jmp .done_printing_this_char
.could_convert
} else {
	bcs .done_printing_this_char
}
	jsr s_printchar
.done_printing_this_char
	iny
	jmp .p0
.p1
} ; not Z5PLUS
	jsr turn_on_cursor
	jmp .readkey
	
; ########## End of code for handling that timer routine returned false	
	
.timer_didnt_return_false
	cmp #1
	bne +
	; timer routine returned true
	; clear input and return 
	ldy #1
	lda #0
	+macro_string_array_write_byte
	jmp .read_text_done ; a should hold 0 to return 0 here
	; check terminating characters
+   
} ; Z4PLUS


	ldy #0
-   cmp terminating_characters,y
	bne .cont_check
	jmp .read_text_done
.cont_check
	iny
	cpy num_terminating_characters
	bne -
+   cmp #8 ; delete key
	bne +
	; allow delete if anything in the buffer
	ldy .read_text_column
	cpy #2
	bcc .readkey
	dey
	sty .read_text_column
	dey ; the length of the text
	jsr turn_off_cursor
	lda .petscii_char_read
	jsr s_printchar ; print the delete char
	jsr turn_on_cursor
!ifdef Z5PLUS {
	tya ; y is still the length of the text
	ldy #1
	+macro_string_array_write_byte
}
	jmp .readkey ; don't store in the array
+   ; disallow cursor keys etc
	cmp #32
	bcs ++
	jmp .readkey
++	cmp #128 ; < 128 is delete, newline, and standard ascii keys
	bcc .char_is_ok
!ifdef USE_HISTORY {
	; cursor: 129,130,131,132 = up,down,left,right
	cmp #131
	bcs +
	jmp handle_history 
+
}
	cmp #155 ; start of extra characters
	bcs +
	jmp .readkey
+	cmp #252 ; end of extra characters
	bcc .char_is_ok
	jmp .readkey	
	; print the allowed char and store in the array
.char_is_ok
	ldx .read_text_column ; compare with size of keybuffer
	cpx .read_text_char_limit
	bcc +
	jmp .readkey
+	; keybuffer < maxchars
	pha
	txa
!ifdef Z5PLUS {
	ldy #1
	+macro_string_array_write_byte
}
	tay
!ifdef Z5PLUS {
	iny
}
	lda .petscii_char_read
	jsr s_printchar
	jsr update_cursor
	pla
!ifdef character_downcase_table {	
	bpl +
	ldx #character_downcase_table_end - character_downcase_table - 1
-	cmp character_downcase_table,x
	bcc +
	beq .match_in_downcase_table
	dex
	bpl -
	bmi + ; Always branch
.match_in_downcase_table
	lda character_downcase_table_end,x
	bne .dont_invert_case ; Always branch
+
}
	; convert to lower case
	cmp #$41
	bcc .dont_invert_case
	cmp #$5b
	bcs .dont_invert_case
	ora #$20

.dont_invert_case
	+macro_string_array_write_byte
	inc .read_text_column	
!ifndef Z5PLUS {
	iny
	lda #0
	+macro_string_array_write_byte
}
	jmp .readkey
.read_text_done
	pha ; the terminating character, usually newline
!ifdef Z5PLUS {
	sta .read_text_return_value
}
!ifdef SCROLLBACK {
	dec read_text_level
	bne .dont_copy_to_scrollback

	; Copy any lines on screen that haven't been copied to scrollback buffer yet (but not current line)
	lda zp_screenrow
	sec
	sbc	read_text_screenrow_start
	clc
	adc s_scrolled_lines
	beq .dont_copy_to_scrollback ; 0 lines to copy
	bmi .dont_copy_to_scrollback ; Unreasonable result
	cmp s_screen_height_minus_one
	bcs .dont_copy_to_scrollback ; Unreasonable result

	; Copy A lines above current to scrollback buffer
	
	; Make zp_screenline point to first line
	tax
	pha
-	lda zp_screenline
	sec
	sbc s_screen_width
	sta zp_screenline
	bcs +
	dec zp_screenline + 1
+	dex
	bne -

	; Copy a line to scrollback buffer
-	jsr copy_line_to_scrollback
	; Move zp_screenline pointer one line ahead
	lda zp_screenline
	clc
	adc s_screen_width
	sta zp_screenline
	bcc +
	inc zp_screenline + 1
	; Decrease the counter for number lines to print
+	pla
	sec
	sbc #1
	beq .dont_copy_to_scrollback ; We're done
	pha
	bne - ; Always branch
.dont_copy_to_scrollback
}

	; turn off blinking cursor
	jsr turn_off_cursor
!ifndef Z5PLUS {
	; Store terminating 0, in case characters were deleted at the end.
	ldy .read_text_column ; compare with size of keybuffer
	lda #0
	+macro_string_array_write_byte
}	
!ifdef USE_HISTORY {
	jsr add_line_to_history
}
	pla ; the terminating character, usually newline
	beq +
	jsr s_printchar; print terminating char unless 0 (0 indicates timer abort)
+   rts

!ifdef USE_HISTORY {
	; MAIN DATASTRUCTURE:
	; history_start        history_end
	; ond0........first0sec
	;             ^.history_first
	;     ^.history_last
	;             ^.history_current (used when selecting)
	;
	; use the space between history_start and history_end, but
	; not more than 255 bytes so that history_start,x addressing works

.dec_history_current
	; move backwards to the previous entry
	; x = (x - 1) % history_size
	dex
	cpx #$ff
	bne +
	ldx #history_lastpos
+	rts

handle_history
	; reacts to history command keys
	; input: 
	;  - a is current key (either 129 for cursor up, or 130 for cursor down)
	; output: 
	; side effects: 
	;  - string_array
	;  - .read_text_column
	; used registers: a,x
	;
	ldy .history_disabled
	bne .handle_history_done
	cmp #129
	bne .history_cursor_down
	; cursor up
	; check if already at the oldest entry
	ldx .history_current
	cpx .history_first
	beq .handle_history_done
	; move backwards to the previous entry
	jsr .dec_history_current ; move to 0 in the previous string
-	txa ; save x value in y before calling .dec_history_current
	tay
	; check if at start of oldest entry
	cpx .history_first
	beq +
	jsr .dec_history_current ; move to prev char
	lda history_start,x ; check if at start of the new entry
!ifdef TRACE_HISTORY {
	jsr printx
	jsr space
	jsr printa
	jsr colon
}
	bne -
	tya
	tax
+	stx .history_current
!ifdef TRACE_HISTORY {
	jsr printx
	jsr newline
}
	jsr get_input_from_history
	jmp .readkey
.history_cursor_down
	; cursor down
	; check if already at the newest entry
	ldx .history_current
	cpx .history_last
	beq .handle_history_done
	; move forwards to a newer entry
	; x = (x + 1) % history_size
-	lda history_start,x
	inx
	cpx #history_size 
	bcc +
	ldx #0
+	cmp #0
	bne -
	stx .history_current
	jsr get_input_from_history
.handle_history_done
	jmp .readkey

get_input_from_history
	; copies data from history to input
	; input: 
	;  - history_current
	; output: 
	; side effects: 
	;  - string_array
	;  - .read_text_column
	; used registers: 

	; remove any old input first
	ldx .read_text_column
-	cpx #1
	beq +
	lda #$14 ; delete character
	jsr s_printchar
	dex
	bne -
+	; update string_array and write characters
!ifdef Z5PLUS {
	ldy #2 ; start from position 2
} else {
	ldy #1 ; start from position 1 (z3)
}
	ldx .history_current
-	lda history_start,x
	+macro_string_array_write_byte
	beq ++
	; convert back to petscii
	jsr translate_zscii_to_petscii
	jsr s_printchar
	iny
	; x = (x + 1) % history_size
	inx
	cpx #history_size 
	bcc -
	ldx #0
	beq - ; unconditional jump
++  ; store string length
!ifdef Z5PLUS {
	dey
	sty .read_text_column
	dey
	tya
	ldy #1
	+macro_string_array_write_byte
} else {
	sty .read_text_column
}
	jmp turn_on_cursor

disable_history_keys
	; disable cursor up/down for history
	; input: -
	; output: -
	; side effects: -
	; used registers: -
	pha
	lda #1
	bne + ; unconditional jump for code sharing with enable_history_keys
enable_history_keys
	; enable cursor up/down for history if there is any history stored
	; input: -
	; output: -
	; side effects: -
	; used registers: -
	pha
	lda .history_first
	cmp .history_last
	beq ++
	; something was stored, so proceed and enable it.
	lda .history_last
	sta .history_current
	lda #0
+	sta .history_disabled
++	pla
	rts

add_line_to_history
	; copy the current input to history, if there is space
	; input: 
	; - string_array
	; output:
	; side effects:
	; used registers: a,x,y
	ldx .read_text_column
	cpx #1 ; skip if the line is empty
	beq ++ 
	cpx #history_size ; skip if the line larger than the history buffer
	bcs ++
	; there is space
	pha
	ldy #0
	ldx .history_last
-	iny
!ifdef Z5PLUS {
	iny ; since text in string_array,y+2
}
	+macro_string_array_read_byte
	sta history_start,x
!ifdef Z5PLUS {
	dey ; only one dey since we want to y++ before cpy
}
	; x = (x + 1) % history_size
	inx
	cpx #history_size 
	bcc +
	ldx #0
+	; check if we are overwriting the oldest entry
	cpx .history_first
	bne +
	; drop the oldest entry
	txa
	pha
--	lda history_start,x
	pha
	lda #0 ; null the oldest entry as we skip forwards
	sta history_start,x
	; x = (x + 1) % history_size
	inx
	cpx #history_size 
	bcc +++
	ldx #0
+++	pla ; check if we found the 0 at the end of the string
	bne --
	stx .history_first
	pla
	tax
+	cpy .read_text_column
	bne -
	stx .history_last
	lda #0
	dex
	cpx #$ff
	bne +
	ldx #history_lastpos
+	sta history_start,x
	pla
++  ; done
!ifdef TRACE_HISTORY {
	ldx #history_size
	jsr printx
	jsr space
	ldx .history_first
	jsr printx
	jsr space
	ldx .history_last
	jsr printx
	jsr newline
}
	rts

.history_current !byte 0  ; the current entry (when selecting with up/down)
.history_first !byte 0    ; offset to the first (oldest) entry
.history_last !byte 0     ; offset to the end of the last (newest) entry
.history_disabled !byte 1 ; 0 means disabled, otherwise enabled
}

.read_parse_buffer !byte 0,0
.read_text_cursor !byte 0,0
.read_text_column !byte 0
.read_text_char_limit !byte 0
.read_text_operand_count !byte 0
!ifdef Z4PLUS {
.read_text_time !byte 0,0 ; update interval in 1/10 seconds
.read_text_time_jiffy !byte 0,0,0 ; update interval in jiffys
.read_text_jiffy !byte 0,0,0  ; current time
.read_text_routine !byte 0,0 ; called with .read_text_time intervals
}
!ifdef Z5PLUS {
.read_text_return_value !byte 0 ; return value
}
!ifdef USE_BLINKING_CURSOR {
.cursor_jiffy !byte 0,0,0  ; next cursor update time
}
!ifdef SCROLLBACK {
read_text_level !byte 0 ; Depth of read_text calls ( > 1 only if an interrupt routine calls read_text.)
read_text_screenrow_start !byte 0
}

tokenise_text
	; divide read_line input into words and look up them in the dictionary
	; input: string_array should be pointing to the text array
	; (this will be okay if called immediately after read_text)
	; a/x should be the address of the parse array
	; input: - string_array
	;        - x,a: address of parse_array
	;        - y: flag (1 = don't add unknown words to parse_array)
	; output: parse_array
	; side effects:
	; used registers: a,x,y
	sty .ignore_unknown_words
	stx parse_array
!ifndef COMPLEX_MEMORY {
	clc
	adc #>story_start
}
	sta parse_array + 1
	lda #2
	sta .wordoffset ; where to store the next word in parse_array
	ldy #0
	sty .numwords ; no words found yet
	+macro_parse_array_read_byte
	sta .maxwords
!ifdef Z5PLUS {
	iny
	+macro_string_array_read_byte
	tax
	inx
	stx .textend
	iny ; sets y to 2 = start position in text
} else {
-   iny
	+macro_string_array_read_byte
	cmp #0
	bne -
	dey
	sty .textend
	ldy #1 ; start position in text
}
	; look over text and find each word
.find_word_loop
	; skip initial space
	cpy .textend
	beq +
	bcs .parsing_done
+	+macro_string_array_read_byte
	cmp #$20
	bne .start_of_word
	iny
	bne .find_word_loop ; Always branch
.start_of_word
	; start of next word found (y is first character of new word)
	sty .wordstart
-   ; look for the end of the word
	+macro_string_array_read_byte
	cmp #$20
	beq .space_found
	; check for terminators
	ldx num_terminators
--  cmp terminators - 1,x
	beq .terminator_found
	dex
	bne --
	; check if end of string
	cpy .textend
	bcs .word_found
	iny
	bne - ; Always branch
.terminator_found
	cpy .wordstart
	beq .word_found
.space_found
	dey
.word_found
	; word found. Look it up in the dictionary
	iny
	sty .wordend ; .wordend is the last character of the word + 1
	; update parse_array
	lda .wordoffset
	tay
	clc
	adc #4
	sta .wordoffset
	jsr find_word_in_dictionary ; will update y
	inc .numwords
	lda .is_word_found
	bne .store_word_in_parse_array
	lda .ignore_unknown_words
	bne .find_next_word ; word unknown, and we shouldn't store unknown words
.store_word_in_parse_array
	lda .wordend
	sec
	sbc .wordstart
	+macro_parse_array_write_byte
	iny
	lda .wordstart
	+macro_parse_array_write_byte
	; find the next word
.find_next_word
	ldy .wordend
	lda .numwords
	cmp .maxwords
	bne  .find_word_loop
.parsing_done
	ldy #1
	lda .numwords
	+macro_parse_array_write_byte
	rts
.maxwords   !byte 0 
.numwords   !byte 0 
.wordoffset !byte 0 
.textend    !byte 0 
.wordstart  !byte 0 
.wordend    !byte 0 
.ignore_unknown_words !byte 0 

get_next_zchar
	; returns the next zchar in a
	; side effects: z_address
	; used registers: a,x,y
	ldx zchar_triplet_cnt
	cpx #2
	bne .just_read
	; extract 3 zchars (5 bits each)
	; stop bit remains in packed_text + 1
	jsr read_next_byte
	sta packed_text
	jsr read_next_byte
	sta packed_text + 1
	and #$1f
	sta zchars
	lda packed_text
	lsr
	ror packed_text + 1
	lsr
	ror packed_text + 1
	and #$1f
	sta zchars + 2
	lda packed_text + 1
	lsr
	lsr
	lsr
	sta zchars + 1	
	ldx #0
	bit packed_text
	bpl +
	inx
+	stx packed_text + 1	
	ldx zchar_triplet_cnt
.just_read
	lda zchars,x
	dex
	bpl +

init_get_zchar
	; Setup for reading zchars from packed string
	; side effects: -
	; used registers: x
	ldx #2
+	stx zchar_triplet_cnt
	rts
	
	
; .zchar_triplet_cnt !byte 0

was_last_zchar
	; only call after a get_next_zchar
	; returns a=0 if current zchar is the last zchar, else > 0
	lda zchar_triplet_cnt ; 0 - 2
	cmp #2
	bne +
	lda packed_text + 1
	eor #1
+   rts

get_abbreviation_offset
	; abbreviation is 32(abbreviation_command-1)+a
	sta .current_zchar
	dey
	tya
	asl
	asl
	asl
	asl
	asl
	clc
	adc .current_zchar
	asl ; byte -> word 
	tay
	rts
.current_zchar !byte 0

!ifndef Z3PLUS {
perm_alphabet_offset !byte 0
}

print_addr
	; print zchar-encoded text
	; input: (z_address set with set_z_addr or set_z_paddr)
	; output: 
	; side effects: z_address
	; used registers: a,x,y
	lda #0
!ifndef Z3PLUS {
	sta perm_alphabet_offset
}
	sta alphabet_offset
	sta escape_char_counter
	sta abbreviation_command
	jsr init_get_zchar
.print_chars_loop
	jsr get_next_zchar
!ifndef Z1 {
	ldy abbreviation_command
	beq .l0
	; handle abbreviation
	jsr get_abbreviation_offset
	; need to store state before calling print_addr recursively
	txa
	pha
	lda z_address
	pha
	lda z_address + 1
	pha
	lda z_address + 2
	pha
	lda zchars
	pha
	lda zchars + 1
	pha
	lda zchars + 2
	pha
	lda packed_text
	pha
	lda packed_text + 1
	pha
	lda zchar_triplet_cnt
	pha
!ifndef Z3PLUS {
	lda perm_alphabet_offset
	pha
}
	tya
	pha
	ldy #header_abbreviations
	jsr read_header_word
	jsr set_z_address
	pla
	tay
	jsr skip_bytes_z_address
	jsr read_next_byte ; 0
	pha
	jsr read_next_byte ; 33
	tax
	pla
	jsr set_z_address
	; abbreviation index is word, *2 for bytes
	asl z_address + 2
	rol z_address + 1 
	rol z_address 
	; print the abbreviation
	jsr print_addr
	; restore state
!ifndef Z3PLUS {
	pla
	sta perm_alphabet_offset
}
	pla 
	sta zchar_triplet_cnt
	pla
	sta packed_text + 1
	pla
	sta packed_text
	pla
	sta zchars + 2
	pla
	sta zchars + 1
	pla
	sta zchars
	pla
	sta z_address + 2
	pla
	sta z_address + 1
	pla
	sta z_address
	pla
	tax
	lda #0
	sta alphabet_offset
	jmp .next_zchar
} ; End of abbreviation call, for Z2+
.l0 ldy escape_char_counter
	beq .l0a
	; handle the two characters that make up an escaped character
	ldy #5
-   asl escape_char
	dey
	bne -
	ora escape_char
	sta escape_char
	dec escape_char_counter
	beq +
	jmp .next_zchar
+   lda escape_char
;	jsr translate_zscii_to_petscii
	jsr streams_print_output
	jmp .next_zchar
.l0a 
	; If alphabet A2, special treatment for code 6 and 7!
	ldy alphabet_offset
	cpy #52
	bne .not_A2
; newline?
	cmp #7
!ifndef Z1 {
	bne .l0b
	lda #13
	jmp .print_normal_char ; Always jump
.l0b 
}
	; Direct jump for all normal chars in A2
	bcs .l6
	; escape char?
	cmp #6
	bne .l1
	lda #2
	sta escape_char_counter
	lda #0
	sta escape_char
	beq .reset_alphabet ; Always branch
.not_A2
	cmp #6
	bcs .l6
.l1 ; Space?
	cmp #0
	bne .l2
	; space
	lda #$20
	bne .print_normal_char ; Always jump
.l2 
!ifdef Z1 {
	cmp #1
	bne +
	; newline
	lda #$0d
	bne .print_normal_char
+
}
!ifdef Z2 {
	cmp #1
	beq .abbreviation
}
!ifndef Z3PLUS {
	; Handle shift codes for z1 & z2
	cmp #2
	bne .z1shift3
	; Code 2, shift up temporarily
	lda perm_alphabet_offset
	clc
	adc #26
	cmp #53
	bcc .sta_alpha_and_jump
	lda #0
	beq .sta_alpha_and_jump ; Always branch
.z1shift3
	cmp #3
	bne .z1shift4
	; Code 3, shift down temporarily
	lda perm_alphabet_offset
	sec
	sbc #26
	bpl .sta_alpha_and_jump
	lda #52
.sta_alpha_and_jump
	sta alphabet_offset
	jmp .next_zchar
.z1shift4
	cmp #4
	bne .z1shift5
	; Code 4, shift up permanently
	lda perm_alphabet_offset
	clc
	adc #26
	cmp #53
	bcc .sta_perm_alpha_and_jump ; Always branch
	lda #0
.sta_perm_alpha_and_jump
	sta perm_alphabet_offset
	sta alphabet_offset
	jmp .next_zchar
.z1shift5
	; Code 5, shift down permanently
	lda perm_alphabet_offset
	sec
	sbc #26
	bpl .sta_perm_alpha_and_jump
	lda #52
	bne .sta_perm_alpha_and_jump ; Always branch
}
!ifdef Z3PLUS {	
	cmp #4
	bcc .abbreviation
	bne .l3
	; change to A1
	lda #26
	sta alphabet_offset
	jmp .next_zchar
.l3 ; This can only be #5: Change to A2
	; change to A2
	lda #52
	sta alphabet_offset
	jmp .next_zchar
}
.l5 ; abbreviation command?
.abbreviation
	sta abbreviation_command ; 1, 2 or 3
	jmp .next_zchar
.l6 ; normal char
	jsr convert_zchar_to_char
.print_normal_char
	jsr streams_print_output
.reset_alphabet
!ifndef Z3PLUS {
	; Change back to permanent alphabet
	lda perm_alphabet_offset
} else {
	; change back to A0
	lda #0
}
	sta alphabet_offset
.next_zchar
	jsr was_last_zchar
	beq +
	jmp .print_chars_loop
+   rts


; .escape_char !byte 0
; .escape_char_counter !byte 0
; .abbreviation_command !byte 0

; .zchars !byte 0,0,0
; .packedtext !byte 0,0
; .alphabet_offset !byte 0
z_alphabet_table ; 26 * 3
	!raw "abcdefghijklmnopqrstuvwxyz"
	!raw "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
!ifdef Z1 {
	!raw 32,"0123456789.,!?_#'",34,47,92,"<-:()"
} else {
	!raw 32,13,"0123456789.,!?_#'",34,47,92,"-:()"
}

