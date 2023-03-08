; screen-kernal.asm
; z_ins_set_colour
; s_printchar
; s_screen_width_minus_one
; s_screen_width
; mega65io
; darkmode
; bgcol
; zcolours

!macro init_screen_model {
    rts
}

fgcol
update_cursor
turn_on_cursor
turn_off_cursor
s_screen_height_minus_one
z_ins_set_colour
s_printchar
s_screen_width_minus_one
s_screen_width
darkmode
bgcol
zcolours
fgcol
s_screen_height_minus_one
    rts

; screen.asm
; z_ins_split_window
; z_ins_set_window
; z_ins_erase_window
; z_ins_erase_line
; z_ins_set_cursor
; z_ins_get_cursor
; z_ins_set_text_style
; z_ins_buffer_mode
; z_ins_print_table
; z_ins_draw_picture
; z_ins_picture_data
; z_ins_erase_picture
; z_ins_set_margins
; z_ins_move_window
; z_ins_window_size
; z_ins_window_style
; z_ins_get_wind_prop
; z_ins_scroll_window
; z_ins_pop_stack
; z_ins_read_mouse
; z_ins_mouse_window
; z_ins_push_stack
; z_ins_put_wind_prop
; z_ins_print_form
; z_ins_make_menu
; z_ins_picture_table
; printchar_flush
; printchar_buffered
; printstring_raw
; erase_window
; show_more_prompt
; clear_num_rows
; start_buffering
; toggle_darkmode
; scroll_delay
; s_delete_cursor
; cursor_character
; current_cursor_colour
; colour2k
; colour1k
; s_reset_scrolled_lines
; get_cursor
; s_scrolled_lines
; s_screen_height
; init_mega65
; init_screen_colours


z_ins_split_window
z_ins_set_window
z_ins_erase_window
z_ins_erase_line
z_ins_set_cursor
z_ins_get_cursor
z_ins_set_text_style
z_ins_buffer_mode
z_ins_print_table
z_ins_draw_picture
z_ins_picture_data
z_ins_erase_picture
z_ins_set_margins
z_ins_move_window
z_ins_window_size
z_ins_window_style
z_ins_get_wind_prop
z_ins_scroll_window
z_ins_pop_stack
z_ins_read_mouse
z_ins_mouse_window
z_ins_push_stack
z_ins_put_wind_prop
z_ins_print_form
z_ins_make_menu
z_ins_picture_table
printchar_flush
printchar_buffered
printstring_raw
erase_window
show_more_prompt
clear_num_rows
start_buffering
toggle_darkmode
s_delete_cursor
cursor_character
current_cursor_colour
colour2k
colour1k
s_reset_scrolled_lines
get_cursor
s_scrolled_lines
s_screen_height
init_mega65
init_screen_colours
    rts

