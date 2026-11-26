; Constants for a future Neo6502 target.
;
; Bootstrap phase note:
; - This file intentionally keeps a C64-like layout so we can thread
;   TARGET_NEO6502 through the build without changing interpreter core logic.
; - Morpheus firmware mappings (I/O, timing, file API, reset) will replace
;   the compatibility placeholders below in follow-up steps.
;

; ---- temporary machine/layout assumptions (bootstrap only) ----
basic_reset           = $a000
; NeoBasic lives at $0800 and its image ends at $497c. A full quit therefore
; reloads BASIC through the firmware API and jumps to $0800. The wait loop must
; be above the BASIC image: small builds pad to $4980, while larger Z4+ builds
; place it immediately after the interpreter and move the story start up.
neo_basic_cold_start  = $0800
neo_basic_image_end   = $4980
SCREEN_HEIGHT         = 30
SCREEN_WIDTH          = 53
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
; z6 indexes this by current_window (0-7), so three bytes are not enough and
; the overrun lands on s_reverse below. screenkernal-z6.asm defines its own
; eight-byte array instead; this zero page is free in a z6 build.
!ifndef Z6 {
s_ignore_next_linebreak = $b0 ; 3 bytes
}
s_reverse 			  = $b3 ; !byte 0

zp_temp               = $fb ; 5 bytes
savefile_zp_pointer   = $c1 ; 2 bytes
is_buffered_window	  = $c8;  !byte 1
first_banked_memory_page = $d0 ; Placeholder bootstrap value
reu_filled            = $0255 ; 4 bytes
vmap_buffer_start     = $0334
vmap_buffer_end       = $0400 ; Last byte + 1. Should not be more than vmap_buffer_start + 512

; Neo VMEM map area is intentionally constrained to the C64-compatible safe
; low-memory window below screen RAM. vmem.asm derives:
;   vmap_max_size = (vmap_buffer_end - vmap_buffer_start) / 2
; so this window must be even-sized and <= 512 bytes.
neo_vmap_buffer_bytes = vmap_buffer_end - vmap_buffer_start
!if (neo_vmap_buffer_bytes & 1) <> 0 {
	!error "Neo vmap buffer must be even-sized (two bytes per VMEM entry)"
}
!if neo_vmap_buffer_bytes > 512 {
	!error "Neo vmap buffer exceeds 512-byte VMEM map limit"
}


; --- I/O registers (bootstrap placeholders) ---
reg_rasterline_highbit=	$d011
reg_rasterline        = $d012
reg_screen_char_mode  = $d018
reg_bordercolour      = $d020
reg_backgroundcolour  = $d021
rasterline_for_scroll = 56

; --- Neo6502 Morpheus API constants ---
; Synced against:
; - paulscottrobson/neo6502-firmware, examples/assembly/neo6502.asm.inc
; - https://www.neo6502.com/reference/api-listing/
;
; NOTE: neo6502.asm.inc currently uses ca65-style literals (e.g. #$01) and is
; not directly ACME-compatible, so keep this ACME-native mirror in sync.
neo_api_command       = $ff00
neo_api_function      = $ff01
neo_api_error         = $ff02
neo_api_status        = $ff03
neo_api_param0        = $ff04
neo_api_param1        = $ff05
neo_api_param2        = $ff06
neo_api_param3        = $ff07
neo_api_param4        = $ff08
neo_api_param5        = $ff09

neo_vector_readline   = $ffeb
neo_vector_readchar   = $ffee
neo_vector_writechar  = $fff1
neo_vector_waitmsg    = $fff4
neo_vector_sendmsg    = $fff7

neo_api_group_system  = $01
neo_api_group_console = $02
neo_api_group_fileio  = $03

neo_api_fn_timer      = $01
neo_api_fn_load_basic = $03
neo_api_fn_reset      = $07

neo_api_fn_read_char  = $01
neo_api_fn_console_status = $02
neo_api_fn_read_line  = $03
neo_api_fn_define_char = $05
neo_api_fn_write_char = $06
neo_api_fn_set_cursor_pos = $07
neo_api_fn_screen_size = $09
neo_api_fn_insert_line = $0a
neo_api_fn_delete_line = $0b
neo_api_fn_clear_screen = $0c
neo_api_fn_cursor_pos = $0d
neo_api_fn_clear_region = $0e
neo_api_fn_set_text_color = $0f

; Neo console palette indices and the control codes that select them. CONWrite
; treats $80+n as foreground and $90+n as background, without moving the cursor.
; -neo-fg/-neo-bg override the defaults at build time (see make.rb).
neo_console_fg_default = 7
neo_console_bg_default = 4
!ifndef NEO_FGCOL {
	NEO_FGCOL = neo_console_fg_default
}
!ifndef NEO_BGCOL {
	NEO_BGCOL = neo_console_bg_default
}
neo_console_fg       = NEO_FGCOL
neo_console_bg       = NEO_BGCOL
neo_console_fg_code  = $80
neo_console_bg_code  = $90

; CONInitialise/NeoBasic default console palette: white on black. Quit must
; restore this before reloading BASIC, otherwise BASIC draws its banner and
; prompts over the game's background colour.
neo_basic_console_fg  = 7
neo_basic_console_bg  = 0

neo_api_fn_load_file  = $02
neo_api_fn_store_file = $03
neo_api_fn_file_open  = $04
neo_api_fn_file_close = $05
neo_api_fn_file_seek  = $06
neo_api_fn_file_tell  = $07
neo_api_fn_file_read  = $08
neo_api_fn_file_write = $09
neo_api_fn_file_size  = $0a
neo_api_fn_file_delete= $0d
neo_api_fn_file_stat   = $10

neo_api_file_mode_read              = $00
neo_api_file_mode_write             = $01
neo_api_file_mode_readwrite         = $02
neo_api_file_mode_readwrite_create  = $03

neo_api_error_ok   = $00
; TODO(neo6502): Confirm canonical EOF error code for API_ERROR via docs/runtime
; probing. Current adapter behavior expects $02 for EOF.
neo_api_error_eof  = $02
neo_api_error_no_file= $11

; --- Neo6502 Morpheus adapter bindings ---
; Route KERNAL entrypoints used by Ozmoo through local adapter routines.
kernal_reset          = neo_kernal_reset
kernal_delay_1ms      = neo_kernal_delay_1ms
kernal_readst         = neo_kernal_readst
kernal_setlfs         = neo_kernal_setlfs
kernal_setnam         = neo_kernal_setnam
kernal_open           = neo_kernal_open
kernal_close          = neo_kernal_close
kernal_chkin          = neo_kernal_chkin
kernal_chkout         = neo_kernal_chkout
kernal_clrchn         = neo_kernal_clrchn
kernal_readchar       = neo_kernal_readchar
kernal_printchar      = neo_kernal_printchar
kernal_load           = neo_kernal_load
kernal_save           = neo_kernal_save
kernal_settime        = neo_kernal_settime
kernal_readtime       = neo_kernal_readtime
kernal_getchar        = neo_kernal_getchar

; Pull in the shared constants, zero-page layout and common vectors.
!source "constants.asm"
