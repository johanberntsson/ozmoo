; screen update routines
; TRACE_WINDOW = 1
NEW_MORE_PROMPT = 1

.num_windows !byte 1
.num_rows !byte 0,0
.current_window !byte 0
.window_size !byte 25, 0
.cursor_position !byte 0,0
.is_buffered_window !byte 1,0
.screen_offset_hi !byte $04, $04, $04, $04, $04, $04, $04, $05, $05, $05, $05, $05, $05, $06, $06, $06, $06, $06, $06, $06, $07, $07, $07, $07, $07
.screen_offset_lo !byte $00, $28, $50, $78, $a0, $c8, $f0, $18, $40, $68, $90, $b8, $e0, $08, $30, $58, $80, $a8, $d0, $f8, $20, $48, $70, $98, $c0

init_screen_colors
    lda #$0f
    sta reg_bordercolor
    lda #$0b
    sta reg_backgroundcolor
    lda #155 ; light grey
    jsr $ffd2 ; kernel_printchar
    lda #147 ; clear screen
    jsr $ffd2 ; kernel_printchar
    rts

!ifdef Z4PLUS {
z_ins_erase_window
    +set_memory_vic2_kernal
    ; erase_window window
    lda z_operand_value_low_arr
    cmp #0
    beq .window_0
    cmp #1
    beq .window_1
    cmp #$ff ; clear screen, then; -1 unsplit, -2 keep as is
    beq .keep_split
    ldx #0 ; unsplit
    jsr .split_window
.keep_split
    lda #147 ; clear screen
    jsr $ffd2 ; kernel_printchar
    jmp .erase_window_done
.window_0
    ldx .window_size + 1
-   jsr .erase_line
    inx
    cpx #25
    bne -
    beq .erase_window_done
.window_1
    ldx #0
-   jsr .erase_line
    inx
    cpx .window_size + 1
    bne -
.erase_window_done
    +restore_default_memory
    rts

z_ins_erase_line
    +set_memory_vic2_kernal
    ; erase_line value
    ; clear current line (where the cursor is)
    sec
    jsr kernel_plot
    jsr .erase_line
    +restore_default_memory
    rts

.erase_line
    ; clear line <x> 
    ; registers: a,y
    ; note: self modifying code
    lda .screen_offset_lo,x 
    sta .erase_line_loop + 1
    lda .screen_offset_hi,x 
    sta .erase_line_loop + 2
    ldy #0
    lda #$20
.erase_line_loop
    sta $8000,y
    iny
    cpy #40
    bne .erase_line_loop
    rts

z_ins_buffer_mode 
    ; buffer_mode flag
    ldy #0
    lda z_operand_value_low_arr
    sta .is_buffered_window,y ; set window 0 (main screen) to flag
    rts
}

z_ins_split_window
    +set_memory_vic2_kernal
    ; split_window lines
!ifdef TRACE_WINDOW {
    jsr print_following_string
    !pet "split_window: ",0
    ldx z_operand_value_low_arr
    jsr printx
    jsr newline
}
    ldx z_operand_value_low_arr
    jsr .split_window
    +restore_default_memory
    rts

.split_window
    ; split if <x> > 0, unsplit if <x> = 0
    cpx #0
    bne .do_split_window
    ; unsplit
    lda #25
    sta .window_size
    lda #0
    sta .window_size + 1
    lda #1
    sta .num_windows
    rts
.do_split_window
    stx .window_size + 1
    lda #25
    sec
    sbc .window_size + 1
    sta .window_size
    lda #2
    sta .num_windows
    rts

z_ins_set_window
    +set_memory_vic2_kernal
    ;  set_window window
!ifdef TRACE_WINDOW {
    jsr print_following_string
    !pet "set_window: ",0
    ldx z_operand_value_low_arr
    jsr printx
    jsr newline
}
    lda z_operand_value_low_arr
    sta .current_window
    bne +
    ; this is the main text screen, restore cursor position
    jmp .restore_cursor
+   ; this is the status line window
    ; store cursor position so it can be restored later
    ; when set_window 0 is called
    jsr .save_cursor
    +restore_default_memory
    rts

!ifdef Z4PLUS {
z_ins_set_text_style
    +set_memory_vic2_kernal
!ifdef TRACE_WINDOW {
    jsr print_following_string
    !pet "set_text_style: ",0
    ldx z_operand_value_low_arr
    jsr printx
    jsr newline
}
    lda z_operand_value_low_arr
    bne .t0
    ; roman
    lda #146 ; reverse off
    jsr $ffd2 ; kernel_printchar
    jmp .t1
.t0 cmp #1
    bne .t1
    lda #18 ; reverse on
    jsr $ffd2 ; kernel_printchar
.t1 
    +restore_default_memory
    rts

z_ins_get_cursor
    +set_memory_vic2_kernal
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
    jsr .get_cursor ; x=row, y=column
    tya
    pha
    ldy #1
    txa ; row
    sta (string_array),y
    pla ; column
    ldy #3
    sta (string_array),y
    +restore_default_memory
    rts

z_ins_set_cursor
    +set_memory_vic2_kernal
    ; set_cursor line column
!ifdef TRACE_WINDOW {
    jsr print_following_string
    !pet "set_cursor: ",0
    ldx z_operand_value_low_arr
    jsr printx
    jsr space
    ldx z_operand_value_low_arr + 1
    jsr printx
    jsr newline
}
    ldx z_operand_value_low_arr ; line 1..
    dex ; line 0..
    ldy .current_window
    bne .top_window
    ; bottom window (add size of top window to x for correct offset)
    txa
    clc
    adc .window_size + 1
    txa
.top_window
    ldy z_operand_value_low_arr + 1 ; column
    dey
    jsr set_cursor
    +restore_default_memory
    rts
}

clear_num_rows
    lda #0
    sta .num_rows
    rts

.increase_num_rows
    ldx .current_window
    inc .num_rows,x
    lda .is_buffered_window,x
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
!ifdef NEW_MORE_PROMPT {
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
} else {
    ldx #0
-   lda .more_text,x
    beq .printchar_pressanykey
    jsr $ffd2 ; kernel_printchar
    inx
    bne -
}
    ; wait for ENTER
.printchar_pressanykey
    jsr waitforenter
!ifdef NEW_MORE_PROMPT {
    lda .more_text_char
    sta $07e5
    lda .more_text_char + 1
    sta $07e6
    lda .more_text_char + 2
    sta $07e7
} else {
    ; remove [More]
    ldx #0
-   lda .more_text,x
    beq .increase_num_rows_done
    lda #20 ; delete
    jsr $ffd2 ; kernel_printchar
    inx
    bne -
}
.increase_num_rows_done
    rts
!ifdef NEW_MORE_PROMPT {
.more_text_char !byte 0,0,0
} else {
.more_text !pet "[More]",0
}

printchar_flush
    ; flush the printchar buffer
    ldx #0
-   cpx .buffer_index
    beq +
    txa ; kernel_printchar/$ffd2 destroys x,y
    pha
    lda .buffer,x
    jsr $ffd2 ; kernel_printchar
    pla
    tax
    inx
    bne -
+   ldx #0
    stx .buffer_index
    stx .buffer_last_space
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
    ldx .current_window
    lda .is_buffered_window,x
    bne .buffered_window
    +set_memory_vic2_kernal
    lda .buffer_char
    jsr $ffd2 ; kernel_printchar
    +restore_default_memory
    jmp .printchar_done
    ; update the buffer
.buffered_window
    lda .buffer_char
    bne .not_first_space
    ; skip space if at first position
    cmp #$20
    bne .not_first_space
    jmp .printchar_done
.not_first_space
    ; add this char to the buffer
    cmp #$0d
    bne .check_space
    ; newline. Print line and reset the buffer
    +set_memory_vic2_kernal
    jsr printchar_flush
!ifdef NEW_MORE_PROMPT {
    ; more on the same line
    jsr .increase_num_rows
    lda #$0d
    jsr $ffd2 ; kernel_printchar
} else {
    ; more on the next line
    lda #$0d
    jsr $ffd2 ; kernel_printchar
    jsr .increase_num_rows
}
    +restore_default_memory
    jmp .printchar_done
.check_space
    cmp #$20
    bne .not_space
    ; update index to last space
    ldy .buffer_index
    sty .buffer_last_space
.not_space
    cmp #46 ; .
    bne .add_char
    ; use period as separator of last resort if no space found
    sty .buffer_last_space
    bne .add_char
    ldy .buffer_index
    sty .buffer_last_space
.add_char
    ldy .buffer_index
    sta .buffer,y
    inc .buffer_index
    ldy .buffer_index
    cpy #40
    bne .printchar_done
    ; print the line until last space
    +set_memory_vic2_kernal
    ldx #0
-   cpx .buffer_last_space
    beq +
    txa ; kernel_printchar/$ffd2 destroys x,y
    pha
    lda .buffer,x
    jsr $ffd2 ; kernel_printchar
    pla
    tax
    inx
    bne -
    ; move the rest of the line back to the beginning and update indices
+   inx ; skip the space
    ldy #0
-   cpx .buffer_index
    beq +
    lda .buffer,x
    sta .buffer,y
    iny
    inx
    bne -
+   sty .buffer_index
    ldy #0
    sty .buffer_last_space
!ifdef NEW_MORE_PROMPT {
    ; more on the same line
    jsr .increase_num_rows
    lda #$0d
    jsr $ffd2 ; kernel_printchar
} else {
    ; more on the next line
    lda #$0d
    jsr $ffd2 ; kernel_printchar
    jsr .increase_num_rows
}
    +restore_default_memory
.printchar_done
    pla
    tay
    pla
    tax
    rts
.buffer_char       !byte 0
.buffer_index      !byte 0
.buffer_last_space !byte 0
.buffer            !fill 41, 0

set_cursor
    ; input: y=column (0-39)
    ;        x=row (0-24)
    clc
    jmp kernel_plot

.get_cursor
    ; output: y=column (0-39)
    ;         x=row (0-24)
    sec
    jmp kernel_plot

.save_cursor
    jsr .get_cursor
    stx .cursor_position
    sty .cursor_position + 1
    rts

.restore_cursor
    ldx .cursor_position
    ldy .cursor_position + 1
    jmp set_cursor

!ifdef Z3 {
z_ins_show_status
    +set_memory_vic2_kernal
    ; show_status (hardcoded size)
    jsr draw_status_line
    +restore_default_memory
    rts

draw_status_line
    ldx #1
    jsr .split_window
    ; save z_operand* (will be destroyed by print_num)
    lda #1
    sta .current_window
    lda z_operand_value_low_arr
    pha
    lda z_operand_value_high_arr
    pha
    lda z_operand_value_low_arr + 1
    pha
    lda z_operand_value_high_arr + 1
    pha
    jsr .save_cursor
    ldx #0
    ldy #0
    jsr set_cursor
    lda #18 ; reverse on
    jsr $ffd2 ; kernel_printchar
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
    cmp #40
    beq +
    lda #$20
    jsr $ffd2 ; kernel_printchar
    jmp -
    ;
    ; score or time game?
    ;
+   lda story_start + header_flags_1
    and #$40
    bne .timegame
    ; score game
    ldx #0
    ldy #20
    jsr set_cursor
    ldy #0
-   lda .score_str,y
    beq +
    jsr $ffd2 ; kernel_printchar
    iny
    bne -
+   lda #17
    jsr z_get_low_global_variable_value
    stx z_operand_value_low_arr
    sta z_operand_value_high_arr
    jsr z_ins_print_num
    ldx #0
    ldy #30
    jsr set_cursor
    ldy #0
-   lda .moves_str,y
    beq +
    jsr $ffd2 ; kernel_printchar
    iny
    bne -
+   lda #18
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
    jsr $ffd2 ; kernel_printchar
    iny
    bne -
+   lda #17 ; hour
    jsr z_get_low_global_variable_value
    stx z_operand_value_low_arr
    sta z_operand_value_high_arr
    jsr z_ins_print_num
    lda #58 ; :
    jsr $ffd2 ; kernel_printchar
    lda #18 ; minute
    jsr z_get_low_global_variable_value
    stx z_operand_value_low_arr
    sta z_operand_value_high_arr
    jsr z_ins_print_num
.statusline_done
    lda #146 ; reverse off
    jsr $ffd2 ; kernel_printchar
    lda #0
    sta .current_window
    pla
    sta z_operand_value_high_arr + 1
    pla
    sta z_operand_value_low_arr + 1
    pla
    sta z_operand_value_high_arr
    pla
    sta z_operand_value_low_arr
    jmp .restore_cursor
.score_str !pet "Score ",0
.moves_str !pet "Moves ",0
.time_str !pet "Time ",0
}

