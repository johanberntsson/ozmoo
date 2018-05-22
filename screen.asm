; screen update routines

.current_window !byte 0
.cursor_position !byte 0,0,0

z_ins_split_window
    ; split_window lines
!ifdef DEBUG {
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
!ifdef DEBUG {
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
    lda .cursor_position
    sta zp_screenline
    lda .cursor_position + 1
    sta zp_screenline + 1
    lda .cursor_position + 2
    sta zp_screencolumn
    rts
+   ; this is the status line window
    ; store cursor position so it can be restored later
    ; when set_window 0 is called
    lda zp_screenline
    sta .cursor_position
    lda zp_screenline + 1
    sta .cursor_position + 1
    lda zp_screencolumn
    sta .cursor_position + 2
    rts

!ifdef Z4PLUS {
z_ins_set_text_style
!ifdef DEBUG {
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
!ifdef DEBUG {
    jsr print_following_string
    !pet "set_cursor: ",0
    ldx z_operand_value_low_arr
    jsr printx
    jsr space
    ldx z_operand_value_low_arr + 1
    jsr printx
    jsr newline
}
    ; for simple status lines only the column matters
    lda #$04
    sta zp_screenline + 1
    lda #00
    sta zp_screenline
    ldx z_operand_value_low_arr + 1
    dex
    stx zp_screencolumn
    rts
}
