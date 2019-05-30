; screen update routines

init_screen_colours_invisible
	ldx zcolours + BGCOL
    lda colours,x ; Load control character to switch to background colour
	bne +
init_screen_colours
    jsr s_init
	ldx zcolours + FGCOL
!ifdef BORDER_LIKE_FG {
	stx reg_bordercolour
}
    lda colours,x ; Load control character to switch to background colour
+	jsr s_printchar
    lda zcolours + BGCOL
    sta reg_backgroundcolour
!ifdef BORDER_LIKE_BG {
	sta reg_bordercolour
} else {
!ifndef BORDER_LIKE_FG {
	lda zcolours + BORDERCOL
	sta reg_bordercolour
}
}
!ifdef Z5PLUS {
    ; store default colours in header
    lda #BGCOL ; blue
    sta story_start + header_default_bg_colour
    lda #FGCOL ; white
    sta story_start + header_default_fg_colour
}
    lda #147 ; clear screen
    jmp s_printchar

!ifdef Z4PLUS {
z_ins_erase_window
    ; erase_window window
    ldx z_operand_value_low_arr
;    jmp erase_window ; Not needed, since erase_window follows
}
	
erase_window
    ; x = 0: clear lower window
    ;     1: clear upper window
    ;    -1: clear screen and unsplit
    ;    -2: clear screen and keep split
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
!ifdef Z3 {
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
    bne -
	jsr clear_num_rows
    ; set cursor to top left (or, if Z4, bottom left)
    pla
	ldx #0
	stx cursor_column + 1
!ifdef Z3 {
	inx
}
!ifdef Z4 {
    lda #24
} else {
    lda window_start_row + 1
}
	stx cursor_row + 1
    pha
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
    rts

!ifdef Z4PLUS {
z_ins_erase_line
    ; erase_line value
    ; clear current line (where the cursor is)
    jmp s_erase_line

!ifdef Z5PLUS {
.pt_cursor = z_temp;  !byte 0,0
.pt_width = z_temp + 2 ; !byte 0
.pt_height = z_temp + 3; !byte 0
.pt_skip = z_temp + 4; !byte 0
.current_col = z_temp + 5; !byte 0

z_ins_print_table
    ; print_table zscii-text width [height = 1] [skip]
    ; ; defaults
    lda #1
    sta .pt_height
    lda #0
    sta .pt_skip
	; Read args
    lda z_operand_value_low_arr + 1
    sta .pt_width
    ldy z_operand_count
    cpy #3
    bcc +
    lda z_operand_value_low_arr + 2
    sta .pt_height
+   cpy #4
    bcc +
    lda z_operand_value_low_arr + 3
    sta .pt_skip
+   ; start printing
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
	cpx #40
	bcs +
	jsr streams_print_output
+	inc .current_col
	dey
	bne -
	dec .pt_height
	beq ++
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
	adc #0
	bcc -- ; Always jump 
++	rts
}

z_ins_buffer_mode 
    ; buffer_mode flag
    jsr printchar_flush
    lda z_operand_value_low_arr
    sta is_buffered_window ; set lower window to buffered mode
    rts
}

!ifdef Z3 {
.max_lines = 24
} else {
.max_lines = 25
}

z_ins_split_window
    ; split_window lines
    ldx z_operand_value_low_arr
;    jmp split_window ; Not needed since split_window follows

split_window
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
!ifdef Z3 {
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
	bne .selecting_upper_window
	; Selecting lower window
	ldx current_window
	beq .do_nothing
	jsr save_cursor
	lda #0
    sta current_window
    ; this is the main text screen, restore cursor position
    jmp restore_cursor
.selecting_upper_window
	; this is the status line window
    ; store cursor position so it can be restored later
    ; when set_window 0 is called
	ldx current_window
	bne .reset_cursor ; Upper window was already selected
    jsr save_cursor
	ldx #1
	stx current_window
.reset_cursor
!ifdef Z3 { ; Since Z3 has a separate statusline 
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
    stx string_array
    lda z_operand_value_high_arr
    clc
    adc #>story_start
    sta string_array + 1
    lda #0
    ldy #0
    sta (string_array),y
    ldy #2
    sta (string_array),y
	ldx current_window
	beq + ; We are in lower window, jump to read last cursor pos in upper window
    jsr get_cursor ; x=row, y=column	
-	inx ; In Z-machine, cursor has position 1+
	iny ; In Z-machine, cursor has position 1+
    tya
    pha
    ldy #1
    txa ; row
    sta (string_array),y
    pla ; column
    ldy #3
    sta (string_array),y
.do_nothing_2
    rts
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
    rts

increase_num_rows
    lda current_window
	bne .not_buffered
    inc num_rows
    lda is_buffered_window
    bne +
.not_buffered
    ; unbuffered windows don't insert newlines
    ;lda num_rows
    ;cmp #24 ; make sure that we see all debug messages (if any)
    ;bcc .increase_num_rows_done
    ;bcs .show_more
    jmp .increase_num_rows_done
; TODO: Check comparison for off-by-1-error
+   lda window_start_row
	sec
	sbc window_start_row + 1
	sbc #1
	cmp num_rows
	bcs .increase_num_rows_done
	; lda num_rows
    ; cmp window_size
    ; bcc .increase_num_rows_done
.show_more
    ; time to show [More]
    jsr clear_num_rows
    ; print [More]
    lda $07e5 
    sta .more_text_char
    lda $07e6 
    sta .more_text_char + 1
    lda $07e7 
    sta .more_text_char + 2
    ;lda #190 ; screen code for reversed >
    lda #174 ; screen code for reversed .
    sta $07e5
    sta $07e6
    sta $07e7
    ; wait for ENTER
.printchar_pressanykey
!ifndef BENCHMARK {
-   jsr kernal_getchar
    beq -
}
    lda .more_text_char
    sta $07e5
    lda .more_text_char + 1
    sta $07e6
    lda .more_text_char + 2
    sta $07e7
.increase_num_rows_done
    rts
.more_text_char !byte 0,0,0

printchar_flush
    ; flush the printchar buffer
    ldx #0
-   cpx buffer_index
    beq +
    txa ; kernal_printchar destroys x,y
    pha
    lda print_buffer,x
    jsr s_printchar
    pla
    tax
    inx
    bne -
+   ldx #0
    stx buffer_index
    stx last_break_char_buffer_pos
    rts

printchar_buffered
    ; a is character to print
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
    ; newline. Print line and reset the buffer
    ldy buffer_index
	cpy #40
	bne +
	; This newline occurs just after 40 characters of text, meaning it should not be printed.
    jsr printchar_flush
;	jsr increase_num_rows ; Not sure if this should be called
	jmp .printchar_done
+	jsr printchar_flush
    ; more on the same line
    jsr increase_num_rows
    lda #$0d
    jsr s_printchar
    jmp .printchar_done
.check_break_char
    ldy buffer_index
	cpy #40
	bcs .add_char ; Don't register break chars on last position of buffer.
    cmp #$20 ; Space
    beq .break_char
	cmp #$2d ; -
	bne .add_char
.break_char
    ; update index to last break character
    sty last_break_char_buffer_pos
.add_char
    ldy buffer_index
    sta print_buffer,y
    inc buffer_index
    ldy buffer_index
    cpy #41
    bne .printchar_done
    ; print the line until last space
	; First calculate max# of characters on line
	ldx #40
; TODO: Check comparison for off-by-1-error
	lda window_start_row
	sec
	sbc window_start_row + 1
	sbc #2
	cmp num_rows
	bcs +
	; ldy num_rows 
	; iny
	; cpy window_size
	; bcc +
	dex ; Max 39 chars on last line on screen.
+	stx max_chars_on_line
	; Now find the character to break on
	ldy last_break_char_buffer_pos
	beq .print_40 ; If there are no break characters on the line, print all 40 characters
	; Check if we have a "perfect space" - a space after 40 characters
	lda print_buffer,x
	cmp #$20
	beq .print_40
	; Check if the break character is a space
	lda print_buffer,y
	cmp #$20
	beq .print_buffer
	iny
	bne .store_break_pos ; Always branch
.print_40
	ldy max_chars_on_line
.store_break_pos
	sty last_break_char_buffer_pos
.print_buffer
    ldx #0
-   cpx last_break_char_buffer_pos
    beq +
    txa ; kernal_printchar destroys x,y
    pha
    lda print_buffer,x
    jsr s_printchar
    pla
    tax
    inx
    bne - ; Always branch
    ; Skip initial spaces, move the rest of the line back to the beginning and update indices
+   ldy #0
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
    iny
    inx
    bne .copy_loop ; Always branch
.after_copy_loop
	sty buffer_index
    ; more on the same line
    jsr increase_num_rows
	lda last_break_char_buffer_pos
	cmp #40
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

clear_screen_raw
	lda #147
	jsr s_printchar
	rts

printchar_raw
	php
	stx .save_x
	sty .save_y
	jsr s_printchar
	ldy .save_y
	ldx .save_x
	plp
	rts

printstring_raw
; Parameters: Address in a,x to 0-terminated string
	stx .read_byte + 1
	sta .read_byte + 2
	ldx #0
.read_byte
	lda $8000,x
	beq +
	jsr printchar_raw
	inx
	bne .read_byte
+	rts
	
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
    jmp set_cursor

!ifdef Z3 {

z_ins_show_status
    ; show_status (hardcoded size)
;    jmp draw_status_line

draw_status_line
	; lda s_first_line
	; pha
	; lda s_last_line_plus_1
	; pha
	; lda #0
	; sta s_first_line
	; lda #1
	; sta s_last_line_plus_1
	lda current_window
	pha
    ; ldx #1
    ; jsr split_window
    ; lda #1
    ; sta current_window
    ; save z_operand* (will be destroyed by print_num)
    lda z_operand_value_low_arr
    pha
    lda z_operand_value_high_arr
    pha
    lda z_operand_value_low_arr + 1
    pha
    lda z_operand_value_high_arr + 1
    pha
    jsr save_cursor
	lda #2
	sta current_window
    ldx #0
    ldy #0
    jsr set_cursor
    lda #18 ; reverse on
    jsr s_printchar
	ldx zcolours + STATCOL
	lda colours,x
	jsr s_printchar
    ;
    ; Room name
    ; 
    ; name of the object whose number is in the first global variable
    lda #16
    jsr z_get_low_global_variable_value
    jsr print_obj
    ;jsr print_addr
    ;
    ; fill the rest of the line with spaces
    ;
-   lda zp_screencolumn
;    beq +
	cmp #40
	bcs +
    lda #$20
    jsr s_printchar
    jmp -
    ;
    ; score or time game?
    ;
+   lda story_start + header_flags_1
    and #$40
    bne .timegame
    ; score game
    ldx #0
    ldy #25
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
    lda #47
    jsr s_printchar
    lda #18
    jsr z_get_low_global_variable_value
    stx z_operand_value_low_arr
    sta z_operand_value_high_arr
    jsr z_ins_print_num
    jmp .statusline_done
.timegame
    ; time game
    ldx #0
    ldy #20
    jsr set_cursor
    ldy #0
-   lda .time_str,y
    beq +
    jsr s_printchar
	iny
    bne -
+   lda #17 ; hour
    jsr z_get_low_global_variable_value
    stx z_operand_value_low_arr
    sta z_operand_value_high_arr
    jsr z_ins_print_num
    lda #58 ; :
    jsr s_printchar
    lda #18 ; minute
    jsr z_get_low_global_variable_value
    stx z_operand_value_low_arr
    sta z_operand_value_high_arr
    jsr z_ins_print_num
.statusline_done
	ldx zcolours + FGCOL
	lda colours,x
	jsr s_printchar
    lda #146 ; reverse off
    jsr s_printchar
    ; lda #0
    ; sta current_window
    pla
    sta z_operand_value_high_arr + 1
    pla
    sta z_operand_value_low_arr + 1
    pla
    sta z_operand_value_high_arr
    pla
    sta z_operand_value_low_arr
	pla
	sta current_window
	; pla
	; sta s_last_line_plus_1
	; pla
	; sta s_first_line
    jmp restore_cursor
.score_str !pet "Score: ",0
.time_str !pet "Time ",0
}

