; --- ZERO PAGE --
; BASIC not much used, so many positions free to use
; memory bank control
zero_datadirection    = $00
zero_processorports   = $01
; available zero page variables (pseudo registers)
z_opcode              = $02
mempointer            = $03 ; 2 bytes
mem_temp              = $05 ; 2 bytes
z_opcode_number       = $07
stack_ptr             = $14 ; 2 bytes (08 was bad?)
parse_array           = $41 ; 2 bytes (22 was bad?)
string_array          = $43 ; 2 bytes (24 was bad?)
z_local_vars_ptr	  = $26 ; 2 bytes (16 was bad?)
zp_pc_h               = $0a
zp_pc_l               = $0b
z_opcode_opcount 	  = $0c ; 0 = 0OP, 1=1OP, 2=2OP, 3=VAR
zp_mempos             = $ae ; 2 bytes
zero_keybufferset     = $d1 ; 2 bytes (points to screen memory, start of input)
zero_keybuffer        = $d3 ; number of bytes in the current input
zp_temp               = $fb ; 4 bytes

memory_buffer         =	$02a7
memory_buffer_length  = 89

datasette_buffer_start= $033c
datasette_buffer_end  = $03fb

; --- BASIC rom routines ---
basic_printstring     = $ab1e ; write string in a/y (LO </HI >)
basic_printinteger    = $bdcd ; write integer value in a/y

; --- I/O registers ---
reg_screen_char_mode  = $d018 
reg_bordercolor       = $d020
reg_backgroundcolor   = $d021 

; --- Kernel routines ---
kernel_setcursor      = $e50c ; set cursor to x/y (row/column)
kernel_reset          = $fce2 ; cold reset of the C64
kernel_scnkey         = $ff9f ; scan the keyboard
kernel_setlfs         = $ffba ; set file parameters
kernel_setnam         = $ffbd ; set file name
kernel_open           = $ffc0 ; open a file
kernel_close          = $ffc3 ; close a file
kernel_chkin          = $ffc6 ; define file as default input
kernel_chkout         = $ffc9 ; define file as default output
kernel_clrchn         = $ffcc ; close default input/output files
kernel_readchar       = $ffcf ; read byte from default input into a
kernel_printchar      = $ffd2 ; write char in a
kernel_getchar        = $ffe4 ; get a character


; story file header constants
header_version = $0
header_flags_1 = $1
header_high_mem = $4
header_initial_pc = $6
header_dictionary = $8
header_object_table = $a
header_globals = $c
header_static_mem = $e
header_flags_2 = $10
header_abbreviations = $18
header_filelength = $1a
header_checksum = $1c
header_interpreter_number = $1e
header_interpreter_version = $1f
header_screen_height_lines = $20
header_screen_width_chars = $21
header_screen_width_units = $22
header_screen_height_units = $24
header_font_width_units = $26
header_font_height_units = $27
header_default_bg_color = $2c
header_default_fg_color = $2d
header_terminating_chars_table = $2e
header_standard_revision_number = $32
header_alphabet_table = $34
header_header_extension_table = $36


