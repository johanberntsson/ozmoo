; This file should be used for the C128 target
;
; ZP allocation: http://cbm.ko2000.nu/manuals/anthology/p124.jpg

basic_reset           = $4000

SCREEN_HEIGHT         = 25
SCREEN_WIDTH          = 40 ; default, adjusted if needed in s_init
SCREEN_ADDRESS        = $0400
COLOUR_ADDRESS        = $d800
COLOUR_ADDRESS_DIFF   = COLOUR_ADDRESS - SCREEN_ADDRESS
CURRENT_DEVICE        = $ba
COLS_40_80            = $d7
keyboard_buff_len     = $d0
keyboard_buff         = $34a
key_repeat            = $0a22

; --- ZERO PAGE -- ; available zero page variables (pseudo registers)
mempointer_y          = $08 ; !byte 0 ### OK C128

; NOTE: This entire block, except last byte of z_pc_mempointer and z_pc_mempointer_is_unsafe is saved!
z_local_vars_ptr      = $09 ; 2 bytes ### OK C128
z_local_var_count     = $0b ;         ### OK C128
stack_pushed_bytes	  = $0c ; 2 bytes ### OK C128
stack_ptr             = $0e ; 2 bytes ### OK C128
stack_top_value 	  = $10 ; 2 bytes ### OK C128
stack_has_top_value   = $12 ; !byte 0 ### OK C128
z_pc				  = $13 ; 3 bytes (last byte shared with z_pc_mempointer) ### OK C128
z_pc_mempointer		  = $15 ; 2 bytes (first byte shared with z_pc) ### OK C128

;z_local_vars_ptr      = $26 ; 2 bytes
;z_local_var_count     = $28
;stack_pushed_bytes	  = $29 ; !byte 0, 0
;stack_ptr             = $2b ; 2 bytes
;stack_top_value 	  = $2d ; 2 bytes !byte 0, 0
;stack_has_top_value   = $2f ; !byte 0
;z_pc				  = $30 ; 3 bytes (last byte shared with z_pc_mempointer)
;z_pc_mempointer		  = $32 ; 2 bytes (first byte shared with z_pc)
; z_pc_mempointer_is_unsafe = $34

zp_save_start = z_local_vars_ptr
zp_bytes_to_save = z_pc + 3 - z_local_vars_ptr


mempointer            = $17 ; 2 bytes ### OK C128
savefile_zp_pointer   = $19 ; 2 bytes ### OK C128
zp_mempos             = $1b ; 2 bytes ### OK C128

z_operand_value_high_arr = $1d ; $1d-$24 !byte 0, 0, 0, 0, 0, 0, 0, 0 ; ### OK C128
z_operand_value_low_arr  = $25 ; $25-$2c !byte 0, 0, 0, 0, 0, 0, 0, 0 ; ### OK C128

mem_temp                 = $37 ; 2 bytes ### OK C128

zp_pc_h                  = $3b ; ### OK C128
zp_pc_l                  = $3c ; ### OK C128

s_stored_x               = $3f ; ### OK C128
s_stored_y               = $40 ; ### OK C128

parse_array           = $41 ; 2 bytes ### OK C128
string_array          = $43 ; 2 bytes ### OK C128

ti_variable           = $a0; 3 bytes ### OK C128

object_tree_ptr       = $45 ; 2 bytes ### OK C128
object_num			  = $47 ; 2 bytes ### OK C128
object_temp			  = $49 ; 2 bytes ### OK C128

z_low_global_vars_ptr = $4b ; 2 bytes ### OK C128
z_high_global_vars_ptr= $4d ; 2 bytes ### OK C128

default_properties_ptr= $4f ; 2 bytes ### OK C128

stack_tmp			  = $51 ; 5 bytes ### OK C128

zchars				  = $56 ; 3 bytes ### OK C128

z_trace_index		  = $59 ;  ### OK C128
z_exe_mode	  		  = $5a ;  ### OK C128

s_colour              = $5b ;  ### OK C128

vmem_temp             = $5c ;  2 bytes ### OK C128

use_reu	              = $5e ;  ### OK C128



z_temp				  = $61 ; 12 bytes $61-$6c ### OK C128 but problems if user enters monitor!
; alphabet_table		  = $6d ; 2 bytes ### OK C128

zchar_triplet_cnt     = $6f ; ### OK C128
packed_text           = $70 ; 2 bytes ### OK C128
alphabet_offset       = $72 ; ### OK C128
escape_char			  = $73 ; ### OK C128
escape_char_counter	  = $74 ; ### OK C128
abbreviation_command  = $75 ; ### OK C128

z_opcode              = $77 ; ### OK C128
z_extended_opcode     = $78 ; ### OK C128
z_opcode_number       = $79 ; ### OK C128
;z_opcode_opcount      = $7b ; ### OK C128
z_operand_count       = $7c ; ### OK C128

vmap_max_entries      = $80 ; ### OK C128 Was $92

zp_cursorswitch       = $81 ; ### OK C128

zword                 = $83 ; ### OK C128  6 bytes : $83-$88


vmap_next_quick_index = $89 ; ### OK C128
vmap_quick_index      = $8a ; ### OK C128	6 bytes; $8a-8f ; Must follow vmap_next_quick_index!

vmap_quick_index_length = 6 ; Says how many bytes vmap_quick_index_uses

; $92 is bad
vmap_used_entries     = $96 ; ### OK C128
vmap_quick_index_match= $97 ; ### OK C128

cursor_row            = $9b ; 2 bytes ### OK C128
cursor_column         = $a6 ; 2 bytes ### OK C128


window_start_row      = $a8 ; 4 bytes ### OK C128

num_rows              = $b0 ; ### OK C128
current_window 	      = $b1 ; ### OK C128

is_buffered_window    = $b2 ; ### OK C128

; Screen kernal stuff. Must be kept together or update s_init in screenkernal.
s_ignore_next_linebreak=$b3 ; 3 bytes ### OK C128
s_reverse             = $b6 ; ### OK C128

s_current_screenpos_row=$be ; ### OK C128 ; !byte $ff

max_chars_on_line      = $c5 ; ### OK C128

z_address			   = $c8 ; 3 bytes ### OK C128
z_address_temp		   = $cb ; ### OK C128

;reu_boost_pointer      = $e6 ; 2 bytes
reu_boost_vmap_clock   = $e6

zp_screenline          = $f1 ; 2 bytes current line (pointer to screen memory)
zp_screencolumn        = $f3 ; 1 byte current cursor column
zp_screenrow           = $f4 ; 1 byte current cursor row
zp_colourline          = $f5 ; 2 bytes current line (pointer to colour memory)

charset_switchable     = $f7

zp_temp                = $f8 ; 5 bytes (is $fa bad because of kernal bug?)

buffer_index           = $fd ; ### OK C128
last_break_char_buffer_pos=$fe ; ### OK C128

copy_page_c128         = $380 ; Uses ~30 bytes


; C128 terp can use a maximum of 109 KB of RAM for dynmem + vmem in z3 mode
; (This is when story_start is $4e00), less in z4+, so vmap buffer should be 
; big enough to hold 2*109 = 218 entries, using 436 = $1b4 bytes.
; Important: Interpreter breaks if area given is larger than $01fe
vmap_buffer_start     = $0801
vmap_buffer_end       = $09b4 ; last usable byte + 1

reu_filled            = $09fc ; 4 bytes

memory_buffer         =	$0a05
memory_buffer_length  = 23

vmem_cache_start      = $0b00
vmem_cache_size = $1000 - vmem_cache_start
vmem_cache_count = vmem_cache_size / 256

fkey_string_lengths   = $1000
fkey_string_area      = $100a

;c128_function_key_string_lengths = $1000 ; 10 bytes holding length of strings for F1, F2 etc
print_buffer		  = $100a + 10 ; SCREEN_WIDTH + 1 bytes
print_buffer2         = print_buffer + 81 ; SCREEN_WIDTH + 1 bytes


first_banked_memory_page = $c0 ; Normally $d0 (meaning $d000-$ffff needs banking for read/write access) 

story_start_far_ram = $1000 + (STACK_PAGES + 2 -  (STACK_PAGES & 1))  * $100 ; NOTE: This is in bank 1

; --- I/O registers ---
reg_screen_char_mode  = $0a2c
reg_rasterline_highbit=	$d011
reg_rasterline        = $d012
reg_bordercolour      = $d020
reg_backgroundcolour  = $d021 
reg_2mhz			  = $d030
rasterline_for_scroll = 56; 56 works well for PAL and NTSC

; --- MMU config ---
c128_mmu_pcra         = $d501
c128_mmu_pcrb         = $d502
c128_mmu_pcrc         = $d503
c128_mmu_pcrd         = $d504

c128_mmu_ram_cfg      = $d506

c128_mmu_cfg          = $ff00
c128_mmu_load_pcra    = $ff01
c128_mmu_load_pcrb    = $ff02
c128_mmu_load_pcrc    = $ff03
c128_mmu_load_pcrd    = $ff04

; --- Kernel routines ---
kernal_delay_1ms      = $eeb3 ; delay 1 ms
kernal_reset          = $ff3d ; cold reset of the C128
kernal_jswapper       = $ff5f ; set bank for I/O
kernal_setbnk         = $ff68 ; set bank for I/O
kernal_readst         = $ffb7 ; set file parameters
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

