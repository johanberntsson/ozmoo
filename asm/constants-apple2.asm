; Constants for the Apple II target
;
; --- screen -----------------------------------------------------------------
; 24 rows, not 25: the reference for text comparisons is `dfrotz -h 24 -w 40`.
; The rows of the text page are interleaved - row base = $400 + (row & 7) * $80
; + (row >> 3) * $28 - so SCREEN_ADDRESS is only the base of the table, never
; a row stride; screenkernal.asm's Apple II branch reaches a row through a
; lookup table.
SCREEN_HEIGHT         = 24
SCREEN_WIDTH          = 40
SCREEN_ADDRESS        = $0400

COLOUR_ADDRESS        = $d000
COLOUR_ADDRESS_DIFF   = COLOUR_ADDRESS - SCREEN_ADDRESS

; A screen byte's top two bits are its video mode: 
; - $00-$3f inverse, 
; - $40-$7f flashing
; - $80-$ff normal. So a blank cell is $a0, not $20, and the cursor is
SPACE_SCREENCODE      = $a0

; --- hardware ---------------------------------------------------------------
KEYBOARD              = $C000   ; bit 7 = a key is waiting, bits 0-6 = ASCII
KEYBOARD_STROBE       = $C010   ; any access clears the strobe
SPEAKER               = $C030   ; a click per access
TXTCLR                = $C050   ; these four put the screen in 40 column text,
TXTSET                = $C051   ; page 1, no mixed graphics
MIXCLR                = $C052
LOWSCR                = $C054
HIRESOFF              = $C056

; The boot chain at $0800, which stays resident. Ozmoo reaches a sector through
; the jump at A2_READ_SECTOR (or A2_WRITE_SECTOR) after filling in the track,
; sector and address below it; see the header of asm/apple2-rwts.asm, which owns
; these addresses.
A2_READ_SECTOR        = $0804
A2_TRACK              = $0807
A2_SECTOR             = $0808
A2_DEST               = $0809   ; high byte of the buffer address...
A2_DEST_LO            = $080A   ; ...and its low byte
A2_WRITE_SECTOR       = $080B   ; write one sector, same three parameters
A2_WRITE_PROTECT      = $080E   ; nonzero if the last write was refused by the
                                ; drive rather than failing to verify
A2_LAST_TRACK         = $080F   ; the track and sector of the last address
A2_LAST_SECTOR        = $0810   ; field the drive decoded. After a read that
                                ; failed, these two against the ones asked for
                                ; say whether the head was in the wrong place
                                ; or the bits under it would not decode

; --- zero page --------------------------------------------------------------
; Laid out like the X16's, which is the most recent map written from scratch
; rather than inherited from the C64's KERNAL gaps.
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
	z_pc_mempointer			= $51 ; 2 bytes (first byte shared with z_pc)
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

s_colour 			  = $78 ; the byte is kept, but nothing renders it

mempointer            = $7c ; 2 bytes
vmem_temp			  = $7e ; 2 bytes

vmap_max_entries	  = $80
vmap_used_entries	  = $81
vmap_quick_index_match= $82
vmap_next_quick_index = $83
vmap_quick_index	  = $84 ; Must follow vmap_next_quick_index!
vmap_quick_index_length = 6 ; Says how many bytes vmap_quick_index uses

z_temp				  = $8a ; 12 bytes

num_rows 			  = $96
; Screen kernal stuff. Must be kept together or update s_init in screenkernal.
!ifndef Z6 {
s_ignore_next_linebreak = $97 ; 3 bytes
}
s_reverse 			  = $9a

savefile_zp_pointer   = $9b ; 2 bytes
current_window		  = $9d
is_buffered_window	  = $9e

s_stored_x			  = $9f
s_stored_y			  = $a0
s_current_screenpos_row = $a1

max_chars_on_line	  = $a2
buffer_index		  = $a3
last_break_char_buffer_pos = $a4

zp_cursorswitch       = $a5
zp_screenline         = $a6 ; 2 bytes current line (pointer to screen memory)
zp_screencolumn       = $a8 ; current cursor column
zp_screenrow          = $a9 ; current cursor row
zp_colourline         = $aa ; 2 bytes, and it points at colour_dump on this
                            ; target, because there is no colour memory
cursor_row			  = $ac ; 2 bytes

window_start_row	  = $ae ; 4 bytes

zp_temp               = $b2 ; 5 bytes

; The software clock and the entropy counter the keyboard shim keeps
; (asm/apple2-kernal.asm). There is no timer and no readable vertical blank on
; this machine, so the jiffy count is made by the input loop counting its own
; passes; a2_entropy is free running and sampled when a key is pressed.
a2_jiffy              = $b7 ; 3 bytes, as RDTIM's a/x/y
a2_jiffy_sub          = $ba ; 2 bytes: polls left until the next jiffy, which
                            ; is more than 256, so this is a word
a2_entropy            = $bc ; 2 bytes

; --- buffers ----------------------------------------------------------------
; $0100-$01ff is the 6502 stack, which print_buffer shares with it exactly as
; it does on the C64; $0300-$03ff is the vmem page table.
print_buffer		  = $0100 ; SCREEN_WIDTH + 1 bytes
print_buffer2         = $0200 ; SCREEN_WIDTH + 1 bytes
memory_buffer         = $02a7
memory_buffer_length  = 89

vmap_buffer_start     = $0300
vmap_buffer_end       = $0400 ; Last byte + 1

; --- what the Apple II does not have ----------------------------------------
; Nothing is banked on a 48K II+, so no page ever needs banking in or out.
first_banked_memory_page = $c0
