; screen update routines

.num_windows !byte 1
.num_rows !byte 0,0
current_window !byte 0
.window_size !byte 25, 0
.cursor_position !byte 0,0
is_buffered_window !byte 1,0

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

erase_window
    ; x = 0: delete main text window
    ;     1: delete status line
    ;    -1: clear screen and unsplit
    ;    -2: clear screen and keep split
    lda zp_screenrow
    pha
    lda z_operand_value_low_arr
    cpx #0
    beq .window_0
    cpx #1
    beq .window_1
    cpx #$ff ; clear screen, then; -1 unsplit, -2 keep as is
    bne .keep_split
	jsr clear_num_rows
    ldx #0 ; unsplit
    jsr split_window
.keep_split
	jsr clear_num_rows
    lda #147 ; clear screen
    jsr s_printchar
    jmp .end_erase
.window_0
    lda .window_size + 1
    sta zp_screenrow
-   jsr s_erase_line
    inc zp_screenrow
    lda zp_screenrow
    cmp #25
    bne -
    ; set cursor to top left
    pla
    lda .window_size + 1
    pha
    jmp .end_erase
.window_1
	lda .window_size + 1
	beq .end_erase
    lda #0
    sta zp_screenrow
-   jsr s_erase_line
    inc zp_screenrow
    lda zp_screenrow
    cmp .window_size + 1
    bne -
.end_erase
    pla
    sta zp_screenrow
    rts

!ifdef Z4PLUS {
z_ins_erase_window
    ; erase_window window
    ldx z_operand_value_low_arr
    jmp erase_window

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
    ldy #0
    lda z_operand_value_low_arr
    sta is_buffered_window,y ; set window 0 (main screen) to flag
    rts
}

z_ins_split_window
    ; split_window lines
    ldx z_operand_value_low_arr
    jmp split_window

split_window
    ; split if <x> > 0, unsplit if <x> = 0
    cpx #0
    bne .split_window
    ; unsplit
    lda #25
    sta .window_size
    lda #0
    sta .window_size + 1
    sta s_scrollstart
    lda #1
    sta .num_windows
    rts
.split_window
    stx .window_size + 1
    stx s_scrollstart
    lda #25
    sec
    sbc .window_size + 1
    sta .window_size
    lda #2
    sta .num_windows
    rts

z_ins_set_window
    ;  set_window window
    lda z_operand_value_low_arr
    sta current_window
    bne +
    ; this is the main text screen, restore cursor position
    jmp restore_cursor
+   ; this is the status line window
    ; store cursor position so it can be restored later
    ; when set_window 0 is called
    jmp save_cursor

!ifdef Z4PLUS {
z_ins_set_text_style
    lda z_operand_value_low_arr
    bne .t0
    ; roman
    lda #146 ; reverse off
    jmp s_printchar
.t0 cmp #1
    bne .t1
    lda #18 ; reverse on
    jmp s_printchar
.t1 rts

z_ins_get_cursor
    ; set_cursor array
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
    jsr get_cursor ; x=row, y=column
	inx ; In Z-machine, cursor has position 1+
	iny ; In Z-machine, cursor has position 1+
    tya
    pha
    ldy #1
    txa ; row
    sta (string_array),y
    pla ; column
    ldy #3
    sta (string_array),y
    rts

z_ins_set_cursor
    ; set_cursor line column
    ldx z_operand_value_low_arr ; line 1..
    dex ; line 0..
    txa
    ldy current_window
    bne .top_window
    ; bottom window (add size of top window to x for correct offset)
    txa
    clc
    adc .window_size + 1
    txa
.top_window
    ldy z_operand_value_low_arr + 1 ; column
    dey
    jmp set_cursor
}

clear_num_rows
    lda #0
    sta .num_rows
    rts

increase_num_rows
    ldx current_window
    inc .num_rows,x
    lda is_buffered_window,x
    bne +
    ; unbuffered windows don't insert newlines
    ;lda .num_rows
    ;cmp #24 ; make sure that we see all debug messages (if any)
    ;bcc .increase_num_rows_done
    ;bcs .show_more
    jmp .increase_num_rows_done
+   lda .num_rows
    cmp .window_size
    bcc .increase_num_rows_done
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
-   cpx .buffer_index
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
    stx .buffer_index
    stx .last_break_char_buffer_pos
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
    ldx current_window
    lda is_buffered_window,x
    bne .buffered_window
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
    ldy .buffer_index
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
    ldy .buffer_index
	cpy #40
	bcs .add_char ; Don't register break chars on last position of buffer.
    cmp #$20 ; Space
    beq .break_char
	cmp #$2d ; -
	bne .add_char
.break_char
    ; update index to last break character
    sty .last_break_char_buffer_pos
.add_char
    ldy .buffer_index
    sta print_buffer,y
    inc .buffer_index
    ldy .buffer_index
    cpy #41
    bne .printchar_done
    ; print the line until last space
	; First calculate max# of characters on line
	ldx #40
	ldy .num_rows
	iny
	cpy .window_size
	bcc +
	dex ; Max 39 chars on last line on screen.
+	stx .max_chars_on_line
	; Now find the character to break on
	ldy .last_break_char_buffer_pos
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
	ldy .max_chars_on_line
.store_break_pos
	sty .last_break_char_buffer_pos
.print_buffer
    ldx #0
-   cpx .last_break_char_buffer_pos
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
	cpx .buffer_index
	beq .after_copy_loop
    lda print_buffer,x
	cmp #$20
	bne .copy_loop
	inx
.copy_loop
	cpx .buffer_index
    beq .after_copy_loop
    lda print_buffer,x
    sta print_buffer,y
    iny
    inx
    bne .copy_loop ; Always branch
.after_copy_loop
	sty .buffer_index
    ; more on the same line
    jsr increase_num_rows
	lda .last_break_char_buffer_pos
	cmp #40
	bcs +
    lda #$0d
    jsr s_printchar
+   ldy #0
    sty .last_break_char_buffer_pos
.printchar_done
    pla
    tay
    pla
    tax
    rts
.max_chars_on_line !byte 0
.buffer_char       !byte 0
.buffer_index      !byte 0
.last_break_char_buffer_pos !byte 0
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
    stx .cursor_position
    sty .cursor_position + 1
    rts

restore_cursor
    ldx .cursor_position
    ldy .cursor_position + 1
    jmp set_cursor

!ifdef Z3 {
z_ins_show_status
    ; show_status (hardcoded size)
;    jmp draw_status_line

draw_status_line
    ldx #1
    jsr split_window
    ; save z_operand* (will be destroyed by print_num)
    lda #1
    sta current_window
    lda z_operand_value_low_arr
    pha
    lda z_operand_value_high_arr
    pha
    lda z_operand_value_low_arr + 1
    pha
    lda z_operand_value_high_arr + 1
    pha
    jsr save_cursor
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
    beq +
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
    lda #0
    sta current_window
    pla
    sta z_operand_value_high_arr + 1
    pla
    sta z_operand_value_low_arr + 1
    pla
    sta z_operand_value_high_arr
    pla
    sta z_operand_value_low_arr
    jmp restore_cursor
.score_str !pet "Score: ",0
.time_str !pet "Time ",0
}

