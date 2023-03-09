; screen-kernal.asm
; z_ins_set_colour
; s_printchar
; s_screen_width_minus_one
; s_screen_width
; mega65io
; darkmode
; bgcol
; zcolours

; MEGA65 registers
VIC2CTRL    = $d016
VIC3CTRL    = $d031
VIC4CTRL    = $d054
LINESTEP_LO = $d058
LINESTEP_HI = $d059
COLPTR_LO   = $d064
COLPTR_HI   = $d065
HOTREG      = $d05d
CHRCOUNT    = $d05e
SCNPTR_0    = $d060
SCNPTR_1    = $d061
SCNPTR_2    = $d062
SCNPTR_3    = $d063

init_mega65
    ; set 40MHz CPU
    lda #65
    sta 0
    ;  set default colors
    lda #$00
    sta $d020
    sta $d021
    ; enable VIC-II/VIC-III hot registers
    jsr mega65io
    ; enable full color and 16 character mode
    lda VIC4CTRL
    ora #$04 ; full color mode
    ora #$01 ; 16 bit character mode
    sta VIC4CTRL
    ; enable H640, V400
    lda VIC3CTRL
    ora #$80 ; 640 pixel width
    ora #$08 ; 400 pixel height
    sta VIC3CTRL
    ; shift one pixel right (VIC-III bug)
    lda  VIC2CTRL
    ora #$01
    sta VIC2CTRL
    ; Set colour RAM offset to 0
    lda #$00
    sta COLPTR_LO
    lda #$00
    ;lda #$10 ; move colour RAM because of stupid CBDOS himem usage
    sta COLPTR_HI
    ; set characters/line
    lda #$80
    sta CHRCOUNT
    ; set linestep (2 screen bytes = 1 character, so 2*CHRCOUNT)
    lda #$a0 
    sta LINESTEP_LO
    lda #$00
    sta LINESTEP_HI
    ; Set screen at $12000
    lda #$00
    sta SCNPTR_0
    lda #$20
    sta SCNPTR_1
    lda #$01
    sta SCNPTR_2
    lda #$00
    sta SCNPTR_3
    
    ; init screen memory
    +dma_fill $12000, 32, 4000, 2
    ; init color memory
    +dma_fill $ff80000, 0, 8000, 1

    ; Put red C in top corner
    +dma_fill $12000, $43, 1, 1
    +dma_fill $ff80000, 2, 2, 1

    ; disable VIC-II/VIC-III hot registers
    lda HOTREG
    and #$7f
    sta HOTREG

-   jmp -
    rts

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
init_screen_colours
    rts

