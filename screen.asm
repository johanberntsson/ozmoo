; screen update routines
; TRACE_WINDOW = 1

current_text_style !byte 0 ; always 0 (roman) for Z3

.current_window !byte 0
.cursor_position !byte 0,0,0
.cursor_offset_l !byte $00,$28,$50,$78,$a0,$c8,$f0,$18,$40,$68,$90,$b8,$e0,$08,$30,$58,$80,$a8,$d0,$f8,$20,$48,$70,$98,$c0
.cursor_offset_h !byte $04,$04,$04,$04,$04,$04,$04,$05,$05,$05,$05,$05,$05,$06,$06,$06,$06,$06,$06,$06,$07,$07,$07,$07,$07

draw_status_line
    jsr save_cursor
    ldx #0
    ldy #0
    jsr set_cursor
    lda #18 ; reverse on
    jsr kernel_printchar
    ; name of the object whose number is in the first global variable
    ldy #0
    lda z_global_vars_start,y ; 22
    sta object_tree_ptr 
    iny 
    ldx z_global_vars_start,y ; 54
    stx object_tree_ptr + 1
!ifndef Z4PLUS {
    ldy #8
}
!ifdef Z4PLUS {
    ldy #13
}
    lda (object_tree_ptr),y ; low byte
    tax
    dey
    lda (object_tree_ptr),y ; high byte
    jsr set_z_address
    jsr read_next_byte ; length of object short name
    jsr print_addr

-   lda zp_screencolumn
    cmp #40
    beq +
    lda #$20
    jsr kernel_printchar
    jmp -
+   lda #146 ; reverse off
    jsr kernel_printchar
    jmp restore_cursor

set_cursor
    ; input: x=column (0-39)
    ;        y=line(0-24)
    stx zp_screencolumn
    lda .cursor_offset_l,y
    sta zp_screenline
    lda .cursor_offset_h,y
    sta zp_screenline + 1
    rts

save_cursor
    lda zp_screenline
    sta .cursor_position
    lda zp_screenline + 1
    sta .cursor_position + 1
    lda zp_screencolumn
    sta .cursor_position + 2
    rts

restore_cursor
    lda .cursor_position
    sta zp_screenline
    lda .cursor_position + 1
    sta zp_screenline + 1
    lda .cursor_position + 2
    sta zp_screencolumn
    rts



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
    sta current_text_style
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
    ldy z_operand_value_low_arr
    ldx z_operand_value_low_arr + 1
    dex
    dey
    jmp set_cursor
}
