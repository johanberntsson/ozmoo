; screen update routines
; TRACE_WINDOW = 1

.current_window !byte 0
.cursor_position !byte 0,0

set_cursor
    ; input: y=column (0-39)
    ;        x=row (0-24)
    clc
    jmp kernel_plot

save_cursor
    sec
    jsr kernel_plot
    stx .cursor_position
    sty .cursor_position + 1
    rts

restore_cursor
    ldx .cursor_position
    ldy .cursor_position + 1
    jmp set_cursor


!ifdef Z3 {
draw_status_line
    jsr save_cursor
    ldx #0
    ldy #0
    jsr set_cursor
    lda #18 ; reverse on
    jsr kernel_printchar
    ;
    ; Room name
    ; 
    ; name of the object whose number is in the first global variable
    ldy #0
    lda z_global_vars_start,y ; 22
    sta object_tree_ptr 
    iny 
    ldx z_global_vars_start,y ; 54
    stx object_tree_ptr + 1
    ldy #8
    lda (object_tree_ptr),y ; low byte
    tax
    dey
    lda (object_tree_ptr),y ; high byte
    jsr set_z_address
    jsr read_next_byte ; length of object short name
    jsr print_addr
    ;
    ; fill the rest of the line with spaces
    ;
-   lda zp_screencolumn
    cmp #40
    beq +
    lda #$20
    jsr kernel_printchar
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
    jsr kernel_printchar
    iny
    bne -
+   ldy #30
    jsr set_cursor
    ldy #0
-   lda .moves_str,y
    beq +
    jsr kernel_printchar
    iny
    bne -
+   jmp .statusline_done
.timegame
    ; time game
    ldx #0
    ldy #20
    jsr set_cursor
    ldy #0
-   lda .time_str,y
    beq +
    jsr kernel_printchar
    iny
    bne -
+
.statusline_done
    lda #146 ; reverse off
    jsr kernel_printchar
    jmp restore_cursor
}
.score_str !pet "Score: ",0
.moves_str !pet "Moves: ",0
.time_str !pet "Time: ",0

z_ins_split_window
    ; split_window lines
!ifdef TRACE_WINDOW {
    jsr print_following_string
    !pet "split_window: ",0
    ldx z_operand_value_low_arr
    jsr printx
    jsr newline
}
    ; TODO: find out how to protect top lines from scrolling
    rts

z_ins_set_window
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
    jmp restore_cursor
+   ; this is the status line window
    ; store cursor position so it can be restored later
    ; when set_window 0 is called
    jmp save_cursor

!ifdef Z4PLUS {
z_ins_set_text_style
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
    jmp kernel_printchar
.t0 cmp #1
    bne .t1
    lda #18 ; reverse on
    jmp kernel_printchar
.t1 rts

z_ins_set_cursor
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
    ldx z_operand_value_low_arr
    ldy z_operand_value_low_arr + 1
    dex
    dey
    jmp set_cursor
}
