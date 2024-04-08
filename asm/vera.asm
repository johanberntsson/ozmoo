; Support routines for VERA access on the X16
; https://github.com/X16Community/x16-docs/blob/master/VERA%20Programmer%27s%20Reference.md
;
; Standard text: video memory starts at $b000,
; and each character is specified by a (screencode,colour) tuple.
;
; Each line has up to 128 characters even if only 80 is shown as
; default, so the first character in the second line is at $b100
; $b000, $b002, $b004 ...
; $b100, $b102, $b104 ...
; ...
;


VERA_addr_low		= $9f20
VERA_addr_high		= $9f21
VERA_addr_bank		= $9f22
VERA_data0			= $9f23
VERA_data1			= $9f24
VERA_ctrl			= $9f25
VERA_ien			= $9f26
VERA_scanline_l		= $9f28
VERA_dc_video		= $9f29
VERA_dc_hscale		= $9f2a
VERA_dc_vscale		= $9f2b
VERA_dc_border		= $9f2c
VERA_L1_config		= $9f34
VERA_L1_mapbase		= $9f35
VERA_L1_tilebase	= $9f36

;VRAM_layer1_map   = $1B000
;VRAM_layer0_map   = $00000
;VRAM_lowerchars   = $0B000
;VRAM_lower_rev    = VRAM_lowerchars + 128*8
;VRAM_petscii      = $1F000
;VRAM_palette      = $1FA00

