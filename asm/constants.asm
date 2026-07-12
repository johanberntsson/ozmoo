; C128 is in a separate constants-c128
; X16 is in a separate constants-x16
;

!ifdef TARGET_C64 {
basic_reset           = $a000
SCREEN_HEIGHT         = 25
SCREEN_WIDTH          = 40
SCREEN_ADDRESS        = $0400
COLOUR_ADDRESS        = $d800
COLOUR_ADDRESS_DIFF   = COLOUR_ADDRESS - SCREEN_ADDRESS
num_rows 			  = $a6 ; !byte 0
CURRENT_DEVICE        = $ba
;ti_variable           = $a0; 3 bytes
keyboard_buff_len     = $c6
keyboard_buff         = $277
key_repeat            = $028a
directory_buffer      = $700 ; 140 bytes, must be near end of screen RAM

use_reu				  = $9b
reu_boost_vmap_clock  = $b1
window_start_row	  = $2a; 4 bytes


; Screen kernal stuff. Must be kept together or update s_init in screenkernal.
s_ignore_next_linebreak = $b0 ; 3 bytes
s_reverse 			  = $b3 ; !byte 0

zp_temp               = $fb ; 5 bytes
savefile_zp_pointer   = $c1 ; 2 bytes
is_buffered_window	  = $c8;  !byte 1
first_banked_memory_page = $d0 ; Normally $d0 (meaning $d000-$ffff needs banking for read/write access) 
reu_filled            = $0255 ; 4 bytes
vmap_buffer_start     = $0334
vmap_buffer_end       = $0400 ; Last byte + 1. Should not be more than vmap_buffer_start + 512
}

!ifdef TARGET_PLUS4 {
basic_reset           = $8000
SCREEN_HEIGHT         = 25
SCREEN_WIDTH          = 40
SCREEN_ADDRESS        = $0c00
COLOUR_ADDRESS        = $0800
COLOUR_ADDRESS_DIFF   = $10000 + COLOUR_ADDRESS - SCREEN_ADDRESS
CURRENT_DEVICE        = $ae
;ti_variable           = $a3; 3 bytes
keyboard_buff_len     = $ef
keyboard_buff         = $527
key_repeat            = $0540
directory_buffer      = $f00 ; 140 bytes, must be near end of screen RAM


zp_temp               = $3b ; 5 bytes
;use_reu				  = $87
;window_start_row	  = $88; 4 bytes
window_start_row	  = $2a; 4 bytes

num_rows 			  = $b7 ; !byte 0

; Screen kernal stuff. Must be kept together or update s_init in screenkernal.
s_ignore_next_linebreak = $b8 ; 3 bytes
s_reverse 			  = $bb ; !byte 0

savefile_zp_pointer   = $c1 ; 2 bytes
is_buffered_window	  = $d0;  !byte 1

; first_banked_memory_page = $fc ; Normally $fc (meaning $fc00-$ffff needs banking, but that area can't be used anyway) 

fkey_string_lengths = $55f
fkey_string_area = $567

vmap_buffer_start     = $0332
vmap_buffer_end       = $03f2 ; Last byte + 1. Should not be more than vmap_buffer_start + 510
;vmap_buffer_start     = $0333
;vmap_buffer_end       = $0437 ; Last byte + 1. Should not be more than vmap_buffer_start + 510

ted_voice_2_low       = $ff0f
ted_voice_2_high      = $ff10
ted_volume            = $ff11

}

!ifdef TARGET_MEGA65 {
story_start_far_ram = 0 ; NOTE: This is in Attic RAM
basic_reset           = $a000 ; the mega65 version is always run in C64 mode
SCREEN_HEIGHT         = 25
!ifdef Z6_FCM_MODE {
; Full Colour Mode: 320x200, and a cell is two bytes in both screen and colour
; RAM, so a row is the same 80 bytes as the 80 column text screen it replaces.
SCREEN_WIDTH          = 40
CELL_BYTES            = 2
; The C64 font sits at $2d000 in the MEGA65 ROM, uppercase/graphics first and
; lowercase/uppercase second, as on the C64. Ozmoo prints mixed case, so it
; needs the second 2 KB half.
FCM_CHARSET           = $2d800
; In FCM a screen code is the cell's data address divided by 64, so the tile
; store's base code is its address / 64. Both bases below are multiples of
; $4000, so that code's low byte is zero and a tile's index simply adds in.
!ifdef Z6_PICTURES {
; Arthur draws its bordered interface as pictures, and the border, the scene
; and the status panel are all on screen at once: over a thousand tiles. Bank 1
; alone holds 1024, so the store spans banks 4 and 5, and sound and undo move
; out of the way (see SOUND_FASTRAM_BANK and UNDO_BANK below). Banks 2 and 3
; are the ROM, where FCM_CHARSET lives, so they can never be used for this.
FCM_TILE_STORE        = $40000
FCM_TILE_CODE_HI      = $10		; $40000 / 64 = $1000
PIC_MAX_TILES         = 2048	; 128 KB of banks 4 and 5, at 64 bytes a tile
} else {
; Bank 1 is untouched in a build without pictures, so the store can live there
; and leave the sound and undo buffers where every other target has them.
FCM_TILE_STORE        = $10000
FCM_TILE_CODE_HI      = 4		; $10000 / 64 = $0400
PIC_MAX_TILES         = 1024
}
} else {
SCREEN_WIDTH          = 80
CELL_BYTES            = 1
}
SCREEN_ROW_BYTES      = SCREEN_WIDTH * CELL_BYTES

; Where the sound effect being played and the undo state live. A sound effect
; is played by the audio DMA, whose stop address is only 16 bits wide, so it
; has to sit at the foot of a bank of chip RAM; undo is reached by DMA and can
; go anywhere. When the tile store takes banks 4 and 5 they both move: sound
; into bank 1, which the tile store has vacated, and undo into attic RAM, well
; clear of the pictures decompressed at $8300000.
!ifdef Z6_PICTURES {
SOUND_FASTRAM_BANK    = $01
UNDO_BANK             = $00
UNDO_ADDRESS_TOP      = $86		; attic RAM, 6 MB in
} else {
SOUND_FASTRAM_BANK    = $04
UNDO_BANK             = $05
UNDO_ADDRESS_TOP      = $00
}

!ifdef CUSTOM_FONT {
SCREEN_ADDRESS        = $1000
} else {
SCREEN_ADDRESS        = $0800
}
COLOUR_ADDRESS        = $d800
COLOUR_ADDRESS_DIFF   = COLOUR_ADDRESS - SCREEN_ADDRESS
CURRENT_DEVICE        = $ba
;ti_variable           = $a0; 3 bytes
num_rows 			  = $a6 ; !byte 0
keyboard_buff_len     = $c6
keyboard_buff         = $277
key_repeat            = $028a
!ifdef Z6_FCM_MODE {
; The screen-RAM trick below cannot work under FCM: the buffer's cells would
; need their high bytes zeroed (or they select tiles), and the colour-RAM
; hiding cannot hide that. A real buffer lives in the program instead
; (fcm_directory_buffer in screenkernal-z6.asm).
directory_buffer      = fcm_directory_buffer
} else {
directory_buffer      = SCREEN_ADDRESS + $700 ; 140 bytes, must be near end of screen RAM
}
m65_x16_checksum_quad = $255

use_reu				  = $9b
window_start_row	  = $2a; 4 bytes

; Screen kernal stuff. Must be kept together or update s_init in screenkernal.
s_ignore_next_linebreak = $b0 ; 3 bytes
s_reverse 			  = $b3 ; !byte 0

zp_temp               = $fb ; 5 bytes
savefile_zp_pointer   = $c1 ; 2 bytes
is_buffered_window	  = $c8;  !byte 1
first_banked_memory_page = $d0 ; Normally $d0 (meaning $d000-$ffff needs banking for read/write access) 
;reu_filled            = $0255 ; 4 bytes
vmap_buffer_start     = $0334
vmap_buffer_end       = $0400 ; Last byte + 1. Should not be more than vmap_buffer_start + 512

}

; --- ZERO PAGE --
; BASIC not much used, so many positions free to use
; memory bank control
zero_datadirection    = $00
zero_processorports   = $01
; available zero page variables (pseudo registers)
z_opcode              = $02
mem_temp              = $05 ; 2 bytes
z_extended_opcode	  = $07

mempointer_y          = $08 ; 1 byte
z_opcode_number       = $09
zp_pc_h               = $0a
zp_pc_l               = $0b
;z_opcode_opcount      = $0c ; 0 = 0OP, 1=1OP, 2=2OP, 3=VAR
z_operand_count		  = $0d
zword				  = $0e ; 6 bytes

zp_mempos             = $14 ; 2 bytes

z_operand_value_high_arr = $16 ; !byte 0, 0, 0, 0, 0, 0, 0, 0
z_operand_value_low_arr = $1e ;  !byte 0, 0, 0, 0, 0, 0, 0, 0

;
; NOTE: This entire block of variables, except last byte of z_pc_mempointer
; and z_pc_mempointer_is_unsafe is included in the save/restore files
; and _have_ to be stored in a contiguous block of zero page addresses
;
	; z_local_vars_ptr		= $26 ; 2 bytes
	; z_local_var_count		= $28
	; stack_pushed_bytes		= $29 ; !byte 0, 0
	; stack_ptr				= $2b ; 2 bytes
	; stack_top_value			= $2d ; 2 bytes !byte 0, 0
	; stack_has_top_value		= $2f ; !byte 0
	; z_pc					= $30 ; 3 bytes (last byte shared with z_pc_mempointer)
	; z_pc_mempointer			= $32 ; 2 bytes (first byte shared with z_pc)
	z_local_vars_ptr		= $75 ; 2 bytes
	z_local_var_count		= $77
	stack_pushed_bytes		= $78 ; !byte 0, 0
	stack_ptr				= $7a ; 2 bytes
	stack_top_value			= $7c ; 2 bytes !byte 0, 0
	stack_has_top_value		= $7e ; !byte 0
	z_pc					= $7f ; 3 bytes (last byte shared with z_pc_mempointer)
	z_pc_mempointer			= $81 ; 2 bytes (first byte shared with z_pc), +2 bytes for MEGA65
	zp_save_start			= z_local_vars_ptr
	zp_bytes_to_save		= z_pc + 3 - z_local_vars_ptr

;
; End of contiguous zero page block
;

vmap_max_entries	  = $34

zchar_triplet_cnt	  = $35
packed_text			  = $36 ; 2 bytes
alphabet_offset		  = $38
escape_char			  = $39
escape_char_counter	  = $3a
abbreviation_command  = $40

parse_array           = $41 ; 2 bytes
string_array          = $43 ; 2 bytes
;terminators_ptr       = $45 ; 2 bytes

z_address			  = $45 ; 3 bytes
z_address_temp		  = $48

object_tree_ptr       = $49 ; 2 bytes
object_num			  = $4b ; 2 bytes
object_temp			  = $4d ; 2 bytes

vmap_used_entries	  = $4f

z_low_global_vars_ptr	  = $50 ; 2 bytes
z_high_global_vars_ptr	  = $52 ; 2 bytes
z_trace_index		  = $54
z_exe_mode	  		  = $55

stack_tmp			  = $56; ! 5 bytes
default_properties_ptr = $5b ; 2 bytes
zchars				  = $5d ; 3 bytes

vmap_quick_index_match= $60
vmap_next_quick_index = $61
vmap_quick_index	  = $62 ; Must follow vmap_next_quick_index!
vmap_quick_index_length = 6 ; Says how many bytes vmap_quick_index_uses

z_temp				  = $68 ; 12 bytes

s_colour 			  = $74 ; !byte 1 ; white as default

!ifdef TARGET_MEGA65 {
dynmem_pointer			= $85; 4 bytes
;dynmem_pointer			= $26; 4 bytes
}

;mempointer            = $03 ; 2 bytes 
;mempointer            = $89 ; 2 bytes + 2 bytes for MEGA65
mempointer            = $26 ; 2 bytes + 2 bytes for MEGA65

vmem_temp			  = $92 ; 2 bytes
; alphabet_table		  = $96 ; 2 bytes


current_window		  = $d8 ; !byte 0

;is_buffered_window	  = $ab;  !byte 1


s_stored_x			  = $b4 ; !byte 0
s_stored_y			  = $b5 ; !byte 0
s_current_screenpos_row = $b6 ; !byte $ff

max_chars_on_line	  = $bd; !byte 0
buffer_index		  = $be ; !byte 0
last_break_char_buffer_pos = $bf ; !byte 0

zp_cursorswitch       = $cc
zp_screenline         = $d1 ; 2 bytes current line (pointer to screen memory)
zp_screencolumn       = $d3 ; 1 byte current cursor column
zp_screenrow          = $d6 ; 1 byte current cursor row
!ifdef Z6_FCM_MODE {
; Under Z6_FCM_MODE zp_colourline is 4 bytes: a 32-bit pointer to the row in
; colour RAM at $ff80000, because the 80-column screen's 4000 colour bytes
; outgrow the 2 KB window at $d800. The low word is the row's offset plus the
; usual +1 bias; the high word is always $0ff8. It cannot stay at $f3: the
; kernal's keyboard scan writes its decode-table pointer into $f5/$f6 on
; every IRQ, which would clobber the high word. $d9-$f2 is the kernal screen
; editor's line-link table, which Ozmoo's own screen code replaces, so that
; region is free and interrupt-safe (zp_screenline at $d1 always lived there).
zp_colourline         = $e5 ; 4 bytes (see above)
; 32-bit scratch pointers (high words also fixed at $0ff8, set in init_mega65)
; into colour RAM, for the two routines that copy colour rows and for the
; [More] prompt's colour cell, which used to be self-modified 16-bit stores.
zp_colour_src         = $d9 ; 4 bytes: colour row being read while scrolling
zp_colour_dst         = $dd ; 4 bytes: colour row being written while scrolling
zp_more_colour        = $e1 ; 4 bytes: the current window's [More] colour cell
} else {
zp_colourline         = $f3 ; 2 bytes current line (pointer to colour memory)
}
cursor_row			  = $f7 ; 2 bytes
cursor_column		  = $f9 ; 2 bytes

print_buffer		  = $100 ; SCREEN_WIDTH + 1 bytes
print_buffer2         = $200 ; SCREEN_WIDTH + 1 bytes

memory_buffer         =	$02a7
memory_buffer_length  = 89

!ifdef TARGET_PLUS4 {
charset_switchable 	  = $547
} else {
charset_switchable 	  = $291
}

; --- I/O registers ---
!ifdef TARGET_PLUS4 {
; TED reference here:
; http://mclauchlan.site.net.au/scott/C=Hacking/C-Hacking12/gfx.html
reg_screen_bitmap_mode = $ff12
reg_screen_char_mode  = $ff13
reg_bordercolour      = $ff19
reg_backgroundcolour  = $ff15 
reg_rasterline_highbit=	$ff1c
reg_rasterline        = $ff1d

rasterline_for_scroll = 6; 6 works well for PAL and NTSC

}
!ifdef TARGET_MEGA65 {
reg_rasterline        = $d012
reg_screen_char_mode  = $d018 
reg_bordercolour      = $d020
reg_backgroundcolour  = $d021 
rasterline_for_scroll = 250;
}
!ifdef TARGET_C64 {
reg_rasterline_highbit=	$d011
reg_rasterline        = $d012
reg_screen_char_mode  = $d018 
reg_bordercolour      = $d020
reg_backgroundcolour  = $d021 
rasterline_for_scroll = 56; 56 works well for PAL and NTSC
}

; --- Kernel routines ---
!ifdef TARGET_C64 {
kernal_reset          = $fce2 ; cold reset of the C64
kernal_delay_1ms      = $eeb3 ; delay 1 ms
}
!ifdef TARGET_PLUS4 {
kernal_reset          = $fff6 ; cold reset of the PLUS4
kernal_delay_1ms      = $e2dc ; delay 1 ms
}
!ifdef TARGET_MEGA65 {
kernal_reset          = $e4b8 ; Reset back to C65 mode
}
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
