; This file should be used for the C128 target
;
; We use VIC-II 40 columns for now and worry about 80 columns later
; see also: http://cbm.ko2000.nu/manuals/anthology/p124.jpg
;
SCREEN_HEIGHT         = 25
SCREEN_WIDTH          = 40 
SCREEN_ADDRESS        = $0400
COLOUR_ADDRESS        = $d800
COLOUR_ADDRESS_DIFF   = COLOUR_ADDRESS - SCREEN_ADDRESS
CURRENT_DEVICE        = $ba

; --- ZERO PAGE --
; available zero page variables (pseudo registers)
z_opcode              !byte 0 ; = $02
mempointer            = $03 ; 2 bytes
mem_temp              !byte 0,0 ; = $05 ; 2 bytes
z_extended_opcode	  !byte 0 ;= $07

z_opcode_number       !byte 0; = $09
zp_pc_h               !byte 0; = $0a
zp_pc_l               !byte 0; = $0b
z_opcode_opcount      !byte 0; = $0c ; 0 = 0OP, 1=1OP, 2=2OP, 3=VAR
z_operand_count		  !byte 0; = $0d
zword				  !byte 0; = $0e ; 6 bytes

zp_mempos             = $14 ; 2 bytes

z_operand_value_high_arr !byte 0, 0, 0, 0, 0, 0, 0, 0 ; = $16
z_operand_value_low_arr  !byte 0, 0, 0, 0, 0, 0, 0, 0 ; = $1e

; NOTE: This entire block, except last byte of z_pc_mempointer and z_pc_mempointer_is_unsafe is saved!
z_local_vars_ptr      = $26 ; 2 bytes
z_local_var_count	  !byte 0 ;= $28
stack_pushed_bytes	  !byte 0, 0 ;= $29 ; !byte 0, 0
stack_ptr             = $2b ; 2 bytes
stack_top_value 	  !byte 0, 0 ;= $2d ; 2 bytes !byte 0, 0
stack_has_top_value   !byte 0 ;= $2f ; !byte 0
z_pc				  = $30 ; 3 bytes (last byte shared with z_pc_mempointer)
z_pc_mempointer		  = $32 ; 2 bytes (first byte shared with z_pc)
; z_pc_mempointer_is_unsafe = $34

zp_save_start = z_local_vars_ptr
zp_bytes_to_save = z_pc + 3 - z_local_vars_ptr


vmap_max_entries	  !byte 0 ; = $34

zchar_triplet_cnt	  !byte 0 ; = $35
packed_text			  !byte 0, 0 ; = $36 ; 2 bytes
alphabet_offset		  !byte 0 ;= $38
escape_char			  !byte 0 ;= $39
escape_char_counter	  !byte 0 ;= $3a
abbreviation_command  !byte 0 ;= $40

parse_array           = $41 ; 2 bytes
string_array          = $43 ; 2 bytes

z_address			  !byte 0, 0, 0 ; = $45 ; 3 bytes
z_address_temp		  !byte 0 ; = $48

object_tree_ptr       = $49 ; 2 bytes
object_num			  !byte 0, 0 ; = $4b ; 2 bytes
object_temp			  !byte 0, 0 ;= $4d ; 2 bytes

vmap_used_entries	  !byte 0; = $4f

z_low_global_vars_ptr	  = $50 ; 2 bytes
z_high_global_vars_ptr	  = $52 ; 2 bytes
z_trace_index		  !byte 0 ; = $54
z_exe_mode	  		  !byte 0 ; = $55

stack_tmp			  !byte 0,0,0,0,0 ; = $56; ! 5 bytes
default_properties_ptr = $5b ; 2 bytes
zchars				  !byte 0, 0, 0 ; = $5d ; 3 bytes

vmap_quick_index_match !byte 0 ; = $60
vmap_next_quick_index !byte 0 ; = $61
vmap_quick_index	  !byte 0, 0, 0, 0, 0, 0 ; = $62 ; Must follow vmap_next_quick_index!
vmap_quick_index_length = 6 ; Says how many bytes vmap_quick_index_uses

z_temp				  = $68 ; 12 bytes

s_colour 			  !byte 0 ; = $74 ; !byte 1 ; white as default

vmem_temp			  !byte 0, 0 ; = $92 ; 2 bytes
alphabet_table		  = $96 ; 2 bytes

use_reu				  !byte 0 ; = $9b

window_start_row	  !byte 0, 0, 0, 0 ; = $9c; 4 bytes

num_rows			  !byte 0 ; = $a6 ; !byte 0
current_window		  !byte 0 ; = $a7 ; !byte 0

is_buffered_window	  !byte 0 ; = $ab;  !byte 1

; Screen kernal stuff. Must be kept together or update s_init in screenkernal.
s_ignore_next_linebreak !byte 0, 0, 0 ; = $b0 ; 3 bytes
s_reverse 			  !byte 0, 0, 0 ; = $b3 ; !byte 0

s_stored_x			  !byte 0 ; = $b4 ; !byte 0
s_stored_y			  !byte 0 ; = $b5 ; !byte 0
s_current_screenpos_row !byte 0 ; = $b6 ; !byte $ff

max_chars_on_line	  !byte 0 ; = $bd; !byte 0
buffer_index		  !byte 0 ; = $be ; !byte 0
last_break_char_buffer_pos !byte 0 ; = $bf ; !byte 0

zp_cursorswitch       !byte 0 ; = $f0 ; 1 byte
zp_screenline         = $f1 ; 2 bytes current line (pointer to screen memory)
zp_screencolumn       = $f3 ; 1 byte current cursor column
zp_screenrow          = $f4 ; 1 byte current cursor row
zp_colourline         = $f5 ; 2 bytes current line (pointer to colour memory)
cursor_row			  = $f7 ; 2 bytes
zp_temp               = $f9 ; 5 bytes (is $fa bad because of kernal bug?)
cursor_column		  !byte 0, 0 ; = $fe ; 2 bytes ;

print_buffer		  = $0c00 ; SCREEN_WIDTH + 1 bytes
print_buffer2         = $0d00 ; SCREEN_WIDTH + 1 bytes

memory_buffer         =	$0e00
memory_buffer_length  = 89

first_banked_memory_page = $d0 ; Normally $d0 (meaning $d000-$ffff needs banking for read/write access) 

charset_switchable 	  = $291

datasette_buffer_start= $0b00 
datasette_buffer_end  = $0bff

; --- I/O registers ---
reg_screen_char_mode  = $0a2c
reg_bordercolour      = $d020
reg_backgroundcolour  = $d021 

; --- Kernel routines ---
kernal_delay_1ms      = $eeb3 ; delay 1 ms
kernal_reset          = $fce2 ; cold reset of the C128
kernal_setbnk         = $ff68 ; set bank for I/O
kernal_setlfs         = $ffba ; set file parameters
kernal_setnam         = $ffbd ; set file name
kernal_open           = $ffc0 ; open a file
kernal_close          = $ffc3 ; close a file
kernal_chkin          = $ffc6 ; define file as default input
kernal_clrchn         = $ffcc ; close default input/output files
kernal_readchar       = $ffcf ; read byte from default input into a
;use streams_print_output instead of kernal_printchar
;($ffd2 only allowed for input/output in screen.asm and text.asm)
kernal_printchar      = $ffd2 ; write char in a
kernal_load           = $ffd5 ; load file
kernal_save           = $ffd8 ; save file
kernal_readtime       = $ffde ; get time of day in a/x/y
kernal_getchar        = $ffe4 ; get a character
;NOTUSED kernal_setcursor      = $e50c ; set cursor to x/y (row/column)
;NOTUSED kernal_scnkey         = $ff9f ; scan the keyboard
;NOTUSED kernal_chkout         = $ffc9 ; define file as default output
;NOTUSED kernal_plot           = $fff0 ; set (c=1)/get (c=0) cursor: x=row, y=column

