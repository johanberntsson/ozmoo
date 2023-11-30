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
VERA_dc_video		= $9f29
VERA_dc_hscale		= $9f2a
VERA_dc_vscale		= $9f2b
VERA_L1_config		= $9f34
VERA_L1_mapbase		= $9f35
VERA_L1_tilebase	= $9f36

;VRAM_layer1_map   = $1B000
;VRAM_layer0_map   = $00000
;VRAM_lowerchars   = $0B000
;VRAM_lower_rev    = VRAM_lowerchars + 128*8
;VRAM_petscii      = $1F000
;VRAM_palette      = $1FA00

VERAInit
    lda #0
    sta VERA_ctrl	    ; Select primary VRAM address
    lda #$01	        ; VPOKE 1st argument (The 0x01 in this is the 1 bank)
    sta VERA_addr_high	; Set primary address bank to 1, stride to 2
    rts

VERATest
    lda #0
    sta VERA_ctrl	    ; Select primary VRAM address
    lda #$01	        ; VPOKE 1st argument (The 0x01 in this is the 1 bank)
    sta VERA_addr_high	; Set primary address bank to 1, stride to 2

    ; VPOKE 1,$b000,2
    ; VPOKE 1,$b001,1
    ; The following is the same as the 2 above VPOKE statements
    lda #0		        ; VPOKE 2nd argument
    sta VERA_addr_low	; Set Primary address low byte to 0
    lda #$b0	        ; Not using the high byte, just want to stay on <0,0>
    sta VERA_addr_high	; Set primary address high byte to 0
    lda #2		        ; VPOKE 3rd argument (set the character to "B")
    sta VERA_data0	    ; Writing $73 to primary address ($01:$b000)

    ; Set the color to white
    lda #1		        ; VPOKE 2nd argument (next byte over)
    sta VERA_addr_low	; Next byte over
    lda #1		        ; VPOKE 3rd argument (white color code)
    sta VERA_data0	    ; Write the color
    rts

