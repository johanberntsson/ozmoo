; Constants för the Commander X16 target
;

story_start_far_ram   = 0 ; NOTE: This is in banked RAM
SCREEN_HEIGHT         = 60
SCREEN_WIDTH          = 80
SCREEN_ADDRESS        = $0000
COLOUR_ADDRESS        = $0000
COLOUR_ADDRESS_DIFF   = COLOUR_ADDRESS - SCREEN_ADDRESS

;ti_variable           = $a82f; 3 bytes (in bank 0, must set $0 to 0 before access)

; Zero-page addresses which we can move
; ~ 123 bytes
z_trace_index		  = $22
z_exe_mode	  		  = $23
z_opcode              = $24
z_extended_opcode	  = $25
z_opcode_number       = $26
z_operand_count		  = $27
zp_pc_h               = $28
zp_pc_l               = $29
mem_temp              = $2a ; 2 bytes
mempointer_y          = $2c ; 1 byte
zword				  = $2d ; 6 bytes
zp_mempos             = $33 ; 2 bytes

z_operand_value_high_arr = $35 ; 8 bytes
z_operand_value_low_arr = $3d ;  8 bytes

;
; NOTE: This entire block of variables, except last byte of z_pc_mempointer
; and z_pc_mempointer_is_unsafe is included in the save/restore files
; and _have_ to be stored in a contiguous block of zero page addresses
;
	z_local_vars_ptr		= $45 ; 2 bytes
	z_local_var_count		= $47
	stack_pushed_bytes		= $48 ; 2 bytes
	stack_ptr				= $4a ; 2 bytes
	stack_top_value			= $4c ; 2 bytes
	stack_has_top_value		= $4e ;
	z_pc					= $4f ; 3 bytes (last byte shared with z_pc_mempointer)
	z_pc_mempointer			= $51 ; 2 bytes (first byte shared with z_pc), +2 bytes for MEGA65
	zp_save_start			= z_local_vars_ptr
	zp_bytes_to_save		= z_pc + 3 - z_local_vars_ptr

;
; End of contiguous zero page block
;

zchar_triplet_cnt	  = $55
packed_text			  = $56 ; 2 bytes
alphabet_offset		  = $58
escape_char			  = $59
escape_char_counter	  = $5a
abbreviation_command  = $5b

parse_array           = $5c ; 2 bytes
string_array          = $5e ; 2 bytes

z_address			  = $60 ; 3 bytes
z_address_temp		  = $63

object_tree_ptr       = $64 ; 2 bytes
object_num			  = $66 ; 2 bytes
object_temp			  = $68 ; 2 bytes

z_low_global_vars_ptr	  = $6a ; 2 bytes
z_high_global_vars_ptr	  = $6c ; 2 bytes

stack_tmp			  = $6e; ! 5 bytes
default_properties_ptr = $73 ; 2 bytes
zchars				  = $75 ; 3 bytes

s_colour 			  = $78 ; !byte 1 ; white as default

dynmem_pointer			= $79; 2 bytes
bank				= $7b; 1 byte

mempointer            = $7c ; 2 bytes

vmem_temp			  = $7e ; 2 bytes


; $a9-$d3 is for math library and Basic, can safely be used
num_rows 			  = $a9
; Screen kernal stuff. Must be kept together or update s_init in screenkernal.
s_ignore_next_linebreak = $aa ; 3 bytes
s_reverse 			  = $ad

savefile_zp_pointer   = $ae ; 2 bytes

use_reu				  = $b0


; $d4-$ff is reserved for Basic, and is free to use for an ML program
z_temp				  = $d4 ; 12 bytes

current_window		  = $e0 



is_buffered_window	  = $e1

s_stored_x			  = $e2
s_stored_y			  = $e3
s_current_screenpos_row=$e4

max_chars_on_line	  = $e5
buffer_index		  = $e6
last_break_char_buffer_pos = $e7

zp_cursorswitch       = $e8
zp_screenline         = $e9 ; 2 bytes current line (pointer to screen memory)
zp_screencolumn       = $eb ; current cursor column
zp_screenrow          = $ec ; current cursor row
zp_colourline         = $ed ; 2 bytes current line (pointer to colour memory)
cursor_row			  = $ef ; 2 bytes
cursor_column		  = $f1 ; 2 bytes

x16_z_address_bank    = $f3
x16_z_adress_pointer  = $f4 ; 2 bytes
x16_z_pc_bank         = $f6

window_start_row	  = $f7; 4 bytes
zp_temp               = $fb ; 5 bytes

first_basic_zp_address = $a9
last_basic_zp_address  = $ff




; We can use $400 - $7ff for buffers
m65_x16_checksum_quad = $400 ; 4 bytes
print_buffer		  = m65_x16_checksum_quad + 4 ; SCREEN_WIDTH + 1 bytes
print_buffer2         = print_buffer + 81 ; SCREEN_WIDTH + 1 bytes

memory_buffer         =	print_buffer2 + 81
memory_buffer_length  = 89

directory_buffer      = memory_buffer + memory_buffer_length ; 140 bytes
x16_room_for_buffers  = $800 - directory_buffer - 140

; --- I/O registers ---

; --- Kernel routines ---
; TODO: check these addresses
kernal_reset          = $fce2 ; cold reset of the X16
;kernal_delay_1ms      (custom routine in disk.asm) ; delay 1 ms
x16_kernal_kbdbuf_put = $fec3 ; Append a character to the keyboard queue
kernal_readst         = $ffb7 ; set file parameters
kernal_setlfs         = $ffba ; set file parameters
kernal_setnam         = $ffbd ; set file name
kernal_open           = $ffc0 ; open a file
kernal_close          = $ffc3 ; close a file
kernal_chkin          = $ffc6 ; define file as default input
kernal_chkout         = $ffc9 ; define file as default output
kernal_clrchn         = $ffcc ; close default input/output files
kernal_readchar       = $ffcf ; read byte from default input into a
;use streams_print_output instead of kernal_printchar
;($ffd2 only allowed for input/output in screen.asm and text.asm)
kernal_printchar      = $ffd2 ; write char in a
kernal_load           = $ffd5 ; load file
kernal_save           = $ffd8 ; save file
kernal_settime        = $ffdb ; set time of day in a/x/y
kernal_readtime       = $ffde ; get time of day in a/x/y
kernal_getchar        = $ffe4 ; get a character
