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
VERA_isr			= $9f27
VERA_scanline_l		= $9f28
VERA_dc_video		= $9f29
VERA_dc_hscale		= $9f2a
VERA_dc_vscale		= $9f2b
VERA_dc_border		= $9f2c
VERA_L0_config		= $9f2d
VERA_L0_mapbase		= $9f2e
VERA_L0_tilebase	= $9f2f
VERA_L1_config		= $9f34
VERA_L1_mapbase		= $9f35
VERA_L1_tilebase	= $9f36

; The PCM audio FIFO (sound-x16.asm). Plain registers, not multiplexed by
; VERA_ctrl's DCSEL and unrelated to the data ports, so touching them cannot
; disturb the screen code's "port 0 selected, stride 1" invariant.
; audio_ctrl  write: bit7 reset FIFO, bit6 (with bit7) loop, bit5 16-bit,
;                    bit4 stereo, bits3-0 volume
;             read:  bit7 FIFO full, bit6 FIFO empty
; audio_rate  0-128; the sample rate is rate * 25 MHz / 512 / 128 = rate * 381.47 Hz
; audio_data  write-only FIFO port, one sample byte per write, SIGNED 8-bit
VERA_audio_ctrl		= $9f3b
VERA_audio_rate		= $9f3c
VERA_audio_data		= $9f3d

;VRAM_layer1_map   = $1B000
;VRAM_layer0_map   = $00000
;VRAM_lowerchars   = $0B000
;VRAM_lower_rev    = VRAM_lowerchars + 128*8
;VRAM_petscii      = $1F000
;VRAM_palette      = $1FA00

