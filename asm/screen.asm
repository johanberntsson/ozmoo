; screen update routines

!macro init_screen_model {
    lda #147 ; clear screen
    jsr s_printchar
    ldy #0
    sty current_window
    sty window_start_row + 3
!ifndef Z4PLUS {
    iny
}
    sty window_start_row + 2
    sty window_start_row + 1
    ldy s_screen_height
    sty window_start_row
    ldy #0
    sty is_buffered_window
    ldx #$ff
    jmp erase_window
}

;init_screen_colours_invisible
;	lda zcolours + BGCOL
;	bpl + ; Always branch
init_screen_colours
	jsr s_init
	; calculate the position for the more prompt
	; (self modifying code since we don't want to
	; ZP space is limited)
	lda s_screen_size + 1
	clc
	adc #>SCREEN_ADDRESS
	sta .more_access1 + 2
	sta .more_access2 + 2
	sta .more_access4 + 2
	lda s_screen_size + 1
	clc
	adc #>COLOUR_ADDRESS
!ifndef BENCHMARK {
	sta .more_access3 + 2
}
	lda s_screen_size
	sec
	sbc #1
	sta .more_access1 + 1
	sta .more_access2 + 1
!ifndef BENCHMARK {
	sta .more_access3 + 1
}
	sta .more_access4 + 1
	; colours
	lda zcolours + FGCOL
!if BORDERCOL_FINAL = 1 {
	+SetBorderColour
}
+	jsr s_set_text_colour
	lda zcolours + BGCOL
	+SetBackgroundColour
!if BORDERCOL_FINAL = 0 {
	+SetBorderColour
} else {
	!if BORDERCOL_FINAL != 1 {
		lda zcolours + BORDERCOL_FINAL
		+SetBorderColour
	}
}
!if CURSORCOL = 1 {
	lda zcolours + FGCOL
} else {
	lda zcolours + CURSORCOL
}
	sta current_cursor_colour
!ifdef Z5PLUS {
	; store default colours in header
	lda #BGCOL ; blue
	ldy #header_default_bg_colour
	jsr write_header_byte
	lda #FGCOL ; white
	ldy #header_default_fg_colour
	jsr write_header_byte
}
	lda #147 ; clear screen
	jsr s_printchar
!ifndef NODARKMODE {
	lda darkmode
	beq +
	dec darkmode
	jmp toggle_darkmode
+	
}
	rts	

!ifdef Z4PLUS {
z_ins_erase_window
	; erase_window window
	jsr printchar_flush
	ldx z_operand_value_low_arr
;    jmp erase_window ; Not needed, since erase_window follows
}
	
erase_window
	; x = 0: clear lower window
	;     1: clear upper window
	;    -1: clear screen and unsplit
	;    -2: clear screen and keep split
;	stx save_x
	lda zp_screenrow
	pha
;    lda z_operand_value_low_arr
	cpx #0
	beq .window_0
	cpx #1
	beq .window_1
	lda #0
	sta current_window
	cpx #$ff ; clear screen, then; -1 unsplit, -2 keep as is
	bne .keep_split
	jsr clear_num_rows
	ldx #0 ; unsplit
	jsr split_window
.keep_split
!ifndef Z4PLUS {
	lda #1
	bne .clear_from_a ; Always branch
} else {
	lda #0
	beq .clear_from_a ; Always branch
}
.window_0
	lda window_start_row + 1
.clear_from_a
	sta zp_screenrow
-   jsr s_erase_line
	inc zp_screenrow
	lda zp_screenrow
	cmp #25
	bcc -
	jsr clear_num_rows
	; set cursor to top left (or, if Z4, bottom left)
	pla
	ldx #0
	stx cursor_column + 1
!ifndef Z4PLUS {
	inx
}
!ifdef Z5PLUS {
	lda window_start_row + 1
} else {
	lda #24
}
	stx cursor_row + 1
	pha
	tax
	ldy #0
	clc
	jsr s_plot ; Update screen and colour pointers
	lda is_buffered_window
	beq .end_erase
	jsr start_buffering
	jmp .end_erase
.window_1
	lda window_start_row + 1
	cmp window_start_row + 2
	beq .end_erase
	lda window_start_row + 2
	sta zp_screenrow
-   jsr s_erase_line
	inc zp_screenrow
	lda zp_screenrow
	cmp window_start_row + 1
	bne -
.end_erase
	pla
	sta zp_screenrow
.return	
	rts

!ifdef Z4PLUS {
z_ins_erase_line
	; erase_line value
	; clear current line (where the cursor is)
	lda z_operand_value_low_arr
	cmp #1
	bne .return
	jmp s_erase_line_from_cursor

!ifdef Z5PLUS {
.pt_cursor = z_temp;  !byte 0,0
.pt_width = z_temp + 2 ; !byte 0
.pt_height = z_temp + 3; !byte 0
.pt_skip = z_temp + 4; !byte 0,0
.current_col = z_temp + 6; !byte 0

z_ins_print_table
	; print_table zscii-text width [height = 1] [skip]
	; ; defaults
	lda #1
	sta .pt_height
	lda #0
	sta .pt_skip
	sta .pt_skip + 1
	; Read args
	lda z_operand_value_low_arr + 1
	beq .print_table_done
	sta .pt_width
	ldy z_operand_count
	cpy #3
	bcc ++
	lda z_operand_value_low_arr + 2
	beq .print_table_done
	sta .pt_height
+   cpy #4
	bcc ++
	lda z_operand_value_low_arr + 3
	sta .pt_skip
	lda z_operand_value_high_arr + 3
	sta .pt_skip + 1
++	lda .pt_height
	cmp #1
	beq .print_table_oneline
; start printing multi-line table
	jsr printchar_flush
	jsr get_cursor ; x=row, y=column
	stx .pt_cursor
	sty .pt_cursor + 1
	lda z_operand_value_high_arr ; Start address
	ldx z_operand_value_low_arr
--	jsr set_z_address
	ldx .pt_cursor + 1
	stx .current_col
	ldy .pt_width
-	jsr read_next_byte
	ldx .current_col
	cpx s_screen_width
	bcs +
	jsr streams_print_output
+	inc .current_col
	dey
	bne -
	dec .pt_height
	beq .print_table_done
; Move cursor to start of next line to print
	inc .pt_cursor
	ldx .pt_cursor
	ldy .pt_cursor + 1
	jsr set_cursor
; Skip the number of bytes requested
	jsr get_z_address
	pha
	txa
	clc
	adc .pt_skip
	tax
	pla
	adc .pt_skip + 1
	bcc -- ; Always jump
.print_table_done	
	rts
.print_table_oneline
	lda z_operand_value_high_arr ; Start address
	ldx z_operand_value_low_arr
	jsr set_z_address
	ldy .pt_width
-	jsr read_next_byte
	jsr translate_zscii_to_petscii
	bcs + ; Illegal char
	jsr printchar_buffered
+	dey
	bne -
	rts
}

z_ins_buffer_mode 
	; buffer_mode flag
	; If buffer mode goes from 0 to 1, remember the start column
	; If buffer mode goes from 1 to 0, flush the buffer 
	
	lda z_operand_value_low_arr
	beq +
	lda #1
+	cmp is_buffered_window
	beq .buffer_mode_done
; Buffer mode changes
	sta is_buffered_window ; set lower window to buffered or unbuffered mode
	cmp #0
	bne start_buffering
	jsr printchar_flush
.buffer_mode_done
	rts

}

start_buffering
	lda current_window
	beq + ; If lower window (0) is selected, we will get cursor pos
	ldy cursor_column
	jmp ++
+	jsr get_cursor
++	sty first_buffered_column
	sty buffer_index
	ldy #0
	sty last_break_char_buffer_pos
	rts

!ifndef Z4PLUS {
.max_lines = 24
} else {
.max_lines = 25
}

z_ins_split_window
	; split_window lines
	ldx z_operand_value_low_arr
;    jmp split_window ; Not needed since split_window follows

split_window
!ifdef SMOOTHSCROLL {
	jsr wait_smoothscroll
}
	; split if <x> > 0, unsplit if <x> = 0
	cpx #0
	bne .split_window
	; unsplit
	ldx window_start_row + 2
	stx window_start_row + 1
	rts
.split_window
	cpx #.max_lines
	bcc +
	ldx #.max_lines
+	txa
	clc
	adc window_start_row + 2
	sta window_start_row + 1
!ifndef Z4PLUS {
	ldx #1
	jsr erase_window
}	
	lda current_window
	beq .ensure_cursor_in_window
	; Window 1 was already selected => Reset cursor if outside window
	jsr get_cursor
	cpx window_start_row + 1
	bcs .reset_cursor
.do_nothing
	rts
.ensure_cursor_in_window
	jsr get_cursor
	cpx window_start_row + 1
	bcs .do_nothing
	ldx window_start_row + 1
	jmp set_cursor

z_ins_set_window
	;  set_window window
	lda z_operand_value_low_arr
	bne select_upper_window
	; Selecting lower window
select_lower_window
	ldx current_window
	beq .do_nothing
	jsr save_cursor
	lda #0
	sta current_window
	; this is the main text screen, restore cursor position
	jmp restore_cursor
select_upper_window
	; this is the status line window
	; store cursor position so it can be restored later
	; when set_window 0 is called
	ldx current_window
	bne .reset_cursor ; Upper window was already selected
	jsr save_cursor
	ldx #1
	stx current_window
.reset_cursor
!ifndef Z4PLUS { ; Since Z3 has a separate statusline 
	ldx #1
} else {
	ldx #0
}
	ldy #0
	jmp set_cursor

!ifdef Z4PLUS {
z_ins_set_text_style
	lda z_operand_value_low_arr
	bne .t0
	; roman
	lda #146 ; reverse off
	jmp s_printchar
.t0 cmp #1
	bne .do_nothing
	lda #18 ; reverse on
	jmp s_printchar

z_ins_get_cursor
	; get_cursor array
	ldx z_operand_value_low_arr
	; stx string_array
	lda z_operand_value_high_arr
	jsr set_z_address
	ldx current_window
	beq + ; We are in lower window, jump to read last cursor pos in upper window
	jsr get_cursor ; x=row, y=column	
-	inx ; In Z-machine, cursor has position 1+
	iny ; In Z-machine, cursor has position 1+
	lda #0
	jsr write_next_byte
	txa
	jsr write_next_byte
	lda #0
	jsr write_next_byte
	tya
	jmp write_next_byte
+	ldx cursor_row + 1
	ldy cursor_column + 1
	jmp -	


z_ins_set_cursor
	; set_cursor line column
	ldy current_window
	beq .do_nothing_2
	ldx z_operand_value_low_arr ; line 1..
	dex ; line 0..
	ldy z_operand_value_low_arr + 1 ; column
	dey
	jmp set_cursor
}

clear_num_rows
	lda #0
	sta num_rows
.do_nothing_2
	rts

!ifdef TARGET_C128 {
vdc_set_more_char_address
    lda #$cf ; low
    ldy #$07 ; high
    jmp VDCSetAddress

vdc_set_more_colour_address
    lda #$cf ; low
    ldy #$0f ; high
    jmp VDCSetAddress

vdc_show_more
	; character
	jsr vdc_set_more_char_address
	ldx #VDC_DATA
	jsr VDCReadReg
	sta .more_text_char
	jsr vdc_set_more_char_address
	lda #128 + $2a ; screen code for reversed "*"
	ldx #VDC_DATA
	jsr VDCWriteReg
	; colour
	jsr vdc_set_more_colour_address
	ldy s_colour
	lda vdc_vic_colours,y
	ldx #VDC_DATA
	jmp VDCWriteReg

vdc_hide_more
	jsr vdc_set_more_char_address
	lda .more_text_char
	ldx #VDC_DATA
	jmp VDCWriteReg
}

increase_num_rows
	lda current_window
	bne .increase_num_rows_done ; Upper window is never buffered
	inc num_rows
	lda is_buffered_window
	beq .increase_num_rows_done
	lda window_start_row
	sec
	sbc window_start_row + 1
	sbc #1
	cmp num_rows
	bcs .increase_num_rows_done
show_more_prompt
	; time to show [More]
	jsr clear_num_rows

!ifdef TARGET_C128 {
    bit COLS_40_80
    bpl +
    ; 80 columns
	jsr vdc_show_more
	jmp .alternate_colours
    ; 40 columns
+
}
.more_access1
	lda SCREEN_ADDRESS + (SCREEN_WIDTH*SCREEN_HEIGHT-1) 
	sta .more_text_char
	lda #128 + $2a ; screen code for reversed "*"
.more_access2
	sta SCREEN_ADDRESS + (SCREEN_WIDTH*SCREEN_HEIGHT-1) 

	; wait for ENTER
.alternate_colours
!ifndef BENCHMARK {
--	ldx s_colour
!ifdef TARGET_PLUS4 {
	lda plus4_vic_colours,x
	tax
}
	iny
	tya
	and #1
	beq +
	ldx reg_backgroundcolour
+
!ifdef TARGET_MEGA65 {
	jsr colour2k
}
!ifdef TARGET_C128 {
    bit COLS_40_80
    bmi .check_for_keypress
    ; Only show more prompt in C128 VIC-II screen
}
.more_access3
	stx COLOUR_ADDRESS + (SCREEN_WIDTH*SCREEN_HEIGHT-1)
!ifdef TARGET_MEGA65 {
	jsr colour1k
}
.check_for_keypress
	ldx #40
---	lda ti_variable + 2 ; $a2
-	cmp ti_variable + 2 ; $a2
	beq -
	jsr getchar_and_maybe_toggle_darkmode
	cmp #0
	bne +
	dex
	bne ---
	beq -- ; Always branch
+
}
!ifdef TARGET_C128 {
    bit COLS_40_80
    bpl +
    ; 80 columns
	jsr vdc_hide_more
	jmp .increase_num_rows_done
    ; 40 columns
+
}
	lda .more_text_char
.more_access4
	sta SCREEN_ADDRESS + (SCREEN_WIDTH*SCREEN_HEIGHT -1)
.increase_num_rows_done
	rts

.more_text_char !byte 0

printchar_flush
	; flush the printchar buffer
	ldx current_window
	stx z_temp + 11
	jsr select_lower_window
	lda s_reverse
	pha

	ldx first_buffered_column
	cpx buffer_index
	bcs +

	ldx buffer_index
	dex
	stx last_break_char_buffer_pos
	jsr print_line_from_buffer
	
	ldx buffer_index
	dex
	lda print_buffer2,x
	sta s_reverse
	lda print_buffer,x
	jsr s_printchar

	; ldx first_buffered_column
; -   cpx buffer_index
	; bcs +
	; lda print_buffer2,x
	; sta s_reverse
	; lda print_buffer,x
	; jsr s_printchar
	; inx
	; bne -

+	pla
	sta s_reverse
	jsr start_buffering
	ldx z_temp + 11
	beq .increase_num_rows_done
	jsr save_cursor
	lda #1
	sta current_window
	; We have re-selected the upper window, restore cursor position
	jmp restore_cursor

print_line_from_buffer
	; Prints the text from first_buffered_column to last_break_char_buffer_pos
!ifdef TARGET_C128 {
	bit COLS_40_80
	bmi +
	jmp .printline40

+	lda zp_screenline + 1
	sec
	sbc #$04 ; adjust from $0400 (VIC-II) to $0000 (VDC)
	tay
	lda zp_screenline
	clc
	adc zp_screencolumn
	bcc +
	iny
+	jsr VDCSetAddress
	ldy #VDC_DATA
	sty VDC_ADDR_REG

	ldx first_buffered_column
-   cpx last_break_char_buffer_pos
	bcs .done_print_80
	lda print_buffer,x
	jsr convert_petscii_to_screencode
	ora print_buffer2,x
--	bit     VDC_ADDR_REG
	bpl --
	sta VDC_DATA_REG
	inx
	bne - ; Always branch

.done_print_80	

	lda last_break_char_buffer_pos
	sec
	sbc first_buffered_column

!ifdef COLOURFUL_LOWER_WIN {

	pha ; Char count

	; ; Fill relevant portion of colour RAM (start at offset $1800) with the game's foreground colour
	lda zp_colourline + 1
	sec
	sbc #$d0 ; adjust from $d800 (VIC-II) to $0800 (VDC)
	tay
	lda zp_colourline
	clc
	adc zp_screencolumn
	bcc +
	iny
+	jsr VDCSetAddress

	ldx s_colour
	lda vdc_vic_colours,x
	ora #$80 ; Bit 7 = charset, bit 0-4 = fg colour
	ldx #VDC_DATA
	jsr VDCWriteReg
	; We have written default fg colour to the first position in colour RAM. Now fill the rest positions.
	lda #0 ; Set to Fill mode ; Not needed, we have 0 in A
	ldx #VDC_VSCROLL
	jsr VDCWriteReg
	ldx #VDC_COUNT
	pla
	pha
	sec
	sbc #1
	jsr VDCWriteReg
	pla
	
.dont_colour_80	
}
	clc
	adc zp_screencolumn
	sta zp_screencolumn

	jmp +++ ; Always branch
	
.printline40
}

!ifdef TARGET_MEGA65 {
	jsr colour2k	
}
	ldy first_buffered_column
-   cpy last_break_char_buffer_pos
	bcs ++
	lda print_buffer,y
	jsr convert_petscii_to_screencode
	ora print_buffer2,y
	sta (zp_screenline),y
!ifdef COLOURFUL_LOWER_WIN {
!ifdef TARGET_PLUS4 {
	ldx s_colour
	lda plus4_vic_colours,x
} else {
	lda s_colour
}
	sta (zp_colourline),y
}
	iny
	bne - ; Always branch

++	

!ifdef TARGET_MEGA65 {
	jsr colour1k
}
	lda last_break_char_buffer_pos
	sec
	sbc first_buffered_column
	clc
	adc zp_screencolumn
	sta zp_screencolumn

+++
	rts

printchar_buffered
	; a is PETSCII character to print
	sta .buffer_char
	; need to save x,y
	txa
	pha
	tya
	pha
	; is this a buffered window?
	lda current_window
	bne .is_not_buffered
	lda is_buffered_window
	bne .buffered_window
.is_not_buffered
	lda .buffer_char
	jsr s_printchar
	jmp .printchar_done
	; update the buffer
.buffered_window
	lda .buffer_char
	; add this char to the buffer
	cmp #$0d
	bne .check_break_char
	jsr printchar_flush
	; more on the same line
	jsr increase_num_rows
	lda #$0d
	jsr s_printchar
	jsr start_buffering
	jmp .printchar_done
.check_break_char
	ldy buffer_index
	cpy s_screen_width
	bcs .add_char ; Don't register break chars on last position of buffer.
	cmp #$20 ; Space
	beq .break_char
	cmp #$2d ; -
	bne .add_char
.break_char
	; update index to last break character
	sty last_break_char_buffer_pos
.add_char
;	ldy buffer_index ; TODO: REMOVE!
	sta print_buffer,y
	lda s_reverse
	sta print_buffer2,y
	iny
	sty buffer_index
	cpy s_screen_width_plus_one ; #SCREEN_WIDTH+1
	beq +
	jmp .printchar_done
+
	; print the line until last space
	; First calculate max# of characters on line
	ldx s_screen_width
	lda window_start_row
	sec
	sbc window_start_row + 1
	sbc #2
	cmp num_rows
	bcs +
	dex ; Max 39 chars on last line on screen.
+	stx max_chars_on_line
	; Check if we have a "perfect space" - a space after 40 characters
	lda print_buffer,x
	cmp #$20
	beq .print_40_2 ; Print all in buffer, regardless of which column buffering started in
	; Now find the character to break on
	ldy last_break_char_buffer_pos
	beq .print_40 ; If there are no break characters on the line, print all 40 characters
	; Check if the break character is a space
	lda print_buffer,y
	cmp #$20
	beq .print_buffer
	iny
	bne .store_break_pos ; Always branch
.print_40
	; If we can't find a place to break, and buffered output started in column > 0, print a line break and move the text in the buffer to the next line.
	ldx first_buffered_column
	beq .print_40_2
	jmp .move_remaining_chars_to_buffer_start
.print_40_2	
	ldy max_chars_on_line
.store_break_pos
	sty last_break_char_buffer_pos
.print_buffer
	lda s_reverse
	pha

	dec last_break_char_buffer_pos ; Print last character using normal print routine, to avoid trouble

	jsr print_line_from_buffer

	ldx last_break_char_buffer_pos
	inc last_break_char_buffer_pos ; Restore old value, since we decreased it by one before

	; Print last character
	lda print_buffer2,x
	sta s_reverse
	lda print_buffer,x
	jsr s_printchar
	inx

	pla
	sta s_reverse

.move_remaining_chars_to_buffer_start
	; Skip initial spaces, move the rest of the line back to the beginning and update indices
	ldy #0
	cpx buffer_index
	beq .after_copy_loop
	lda print_buffer,x
	cmp #$20
	bne .copy_loop
	inx
.copy_loop
	cpx buffer_index
	beq .after_copy_loop
	lda print_buffer,x
	sta print_buffer,y
	lda print_buffer2,x
	sta print_buffer2,y
	iny
	inx
	bne .copy_loop ; Always branch
.after_copy_loop
	sty buffer_index
	lda #0
	sta first_buffered_column
	; more on the same line
	jsr increase_num_rows
	lda last_break_char_buffer_pos
	cmp s_screen_width
	bcs +
	lda #$0d
	jsr s_printchar
+   ldy #0
	sty last_break_char_buffer_pos
.printchar_done
	pla
	tay
	pla
	tax
	rts
.buffer_char       !byte 0
; print_buffer            !fill 41, 0
.save_x			   !byte 0
.save_y			   !byte 0
first_buffered_column !byte 0

clear_screen_raw
	lda #147
	jsr s_printchar
	rts

printstring_raw
; Parameters: Address in a,x to 0-terminated string
	stx .read_byte + 1
	sta .read_byte + 2
	ldx #0
.read_byte
	lda $8000,x
	beq +
	jsr s_printchar
	inx
	bne .read_byte
+	rts
	

save_cursor
	jsr get_cursor
	tya
	ldy current_window
	stx cursor_row,y
	sta cursor_column,y
	rts

restore_cursor
	ldy current_window
	ldx cursor_row,y
	lda cursor_column,y
	tay
;	jmp set_cursor

set_cursor
	; input: y=column (0-39)
	;        x=row (0-24)
	clc
	jmp s_plot

get_cursor
	; output: y=column (0-39)
	;         x=row (0-24)
	sec
	jmp s_plot

!ifndef Z4PLUS {

!ifdef TARGET_MEGA65 {
sl_score_pos !byte 54
sl_moves_pos !byte 67
sl_time_pos !byte 64
} else {
sl_score_pos !byte 25
!ifdef TARGET_C128 {
sl_moves_pos !byte 0 ; A signal that "Moves:" should not be printed
}
sl_time_pos !byte 25
}

z_ins_show_status
	; show_status (hardcoded size)
;    jmp draw_status_line

draw_status_line
	lda current_window
	pha
	jsr save_cursor
	lda #2
	sta current_window
	ldx #0
	ldy #0
	jsr set_cursor
	lda #18 ; reverse on
	jsr s_printchar
	ldx darkmode
	ldy statuslinecol,x 
	lda zcolours,y
	jsr s_set_text_colour
	;
	; Room name
	; 
	; name of the object whose number is in the first global variable
	lda #16
	jsr z_get_low_global_variable_value
	jsr print_obj
	;
	; fill the rest of the line with spaces
	;
-   lda zp_screencolumn
	cmp s_screen_width
	bcs +
	lda #$20
	jsr s_printchar
	jmp -
	;
	; score or time game?
	;
+   
!ifdef Z3 {
	ldy #header_flags_1
	jsr read_header_word
	and #$02
	beq +
	jmp .timegame
+
}
	; score game
	lda z_operand_value_low_arr
	pha
	lda z_operand_value_high_arr
	pha
	lda z_operand_value_low_arr + 1
	pha
	lda z_operand_value_high_arr + 1
	pha
	ldx #0
	ldy sl_score_pos
	jsr set_cursor
	ldy #0
-   lda .score_str,y
	beq +
	jsr s_printchar
	iny
	bne -
+   lda #17
	jsr z_get_low_global_variable_value
	stx z_operand_value_low_arr
	sta z_operand_value_high_arr
	jsr z_ins_print_num
!ifdef SUPPORT_80COL {
	ldy sl_moves_pos
	bne +
	lda #47
	jsr s_printchar
	jmp ++	
+	ldx #0
	jsr set_cursor
	ldy #0
-   lda .turns_str,y
	beq ++
	jsr s_printchar
	iny
	bne - ; Always branch
++
} else {
	lda #47
	jsr s_printchar
}
	lda #18
	jsr z_get_low_global_variable_value
	stx z_operand_value_low_arr
	sta z_operand_value_high_arr
	jsr z_ins_print_num
	pla
	sta z_operand_value_high_arr + 1
	pla
	sta z_operand_value_low_arr + 1
	pla
	sta z_operand_value_high_arr
	pla
	sta z_operand_value_low_arr
	jmp .statusline_done

!ifdef Z3 {
.time_str !pet "Time: ",0
.ampm_str !pet " AM",0

.print_clock_number
	sty z_temp + 11
	txa
	ldy #0
-	cmp #10
	bcc .print_tens
	sbc #10 ; C is already set
	iny
	bne - ; Always branch
.print_tens
	tax
	tya
	bne +
	lda z_temp + 11
	bne ++
+	ora #$30
++	jsr s_printchar
	txa
	ora #$30
	jmp s_printchar

.timegame
	; time game
	ldx #0
	ldy sl_time_pos
	jsr set_cursor
	lda #>.time_str
	ldx #<.time_str
	jsr printstring_raw
; Print hours
	lda #65 + 32
	sta .ampm_str + 1
	lda #17 ; hour
	jsr z_get_low_global_variable_value
; Change AM to PM if hour >= 12
	cpx #12
	bcc +
	lda #80 + 32
	sta .ampm_str + 1
+	cpx #0
	bne +
	ldx #12
; Subtract 12 from hours if hours >= 13, so 15 becomes 3 etc
+	cpx #13
	bcc +
	txa
	sbc #12
	tax
+	ldy #$20 ; " " before if < 10
	jsr .print_clock_number
	lda #58 ; :
	jsr s_printchar
; Print minutes
	lda #18 ; minute
	jsr z_get_low_global_variable_value
	ldy #$30 ; "0" before if < 10
	jsr .print_clock_number
; Print AM/PM
	lda #>.ampm_str
	ldx #<.ampm_str
	jsr printstring_raw
}
.statusline_done
	ldx darkmode
	ldy fgcol,x 
	lda zcolours,y
	jsr s_set_text_colour
	lda #146 ; reverse off
	jsr s_printchar
	pla
	sta current_window
	jmp restore_cursor


.score_str !pet "Score: ",0
!ifdef SUPPORT_80COL {
.turns_str !pet "Moves: ",0
}
}

