; Mouse support for the MEGA65 full colour screen (Z6_FCM_MODE).
;
; The Z-machine mouse model is in z-spec 10.3: a game sets bit 5 of Flags 2 to
; ask for a mouse, the interpreter clears it if it cannot offer one, a click is
; delivered as input character 254 and its position is written into the header
; extension table (and read back with read_mouse in v6). The pointer is sprite
; 0, moved in software: the MEGA65 has no hardware that ties a sprite to the
; mouse, its KERNAL does it in an interrupt, and so do we — once per input poll.
;
; The 1351/Amiga mouse on control port 1 is read straight from the MEGA65's own
; pot registers ($d620/$d621), which need no SID/CIA multiplexing, and its
; button from the port 1 fire line. The pot is a 6-bit counter that wraps, so we
; track the signed change between polls and accumulate a pixel position.

!ifdef Z6_FCM_MODE {

MOUSE_POTX      = $d620		; port 1 pot X / Y, MEGA65 direct-read registers
MOUSE_POTY      = $d621
MOUSE_BUTTON    = $dc01		; port 1: bit 4 clear = left button down
SPRITE_ENABLE   = $d015
SPRITE0_X       = $d000
SPRITE0_Y       = $d001
SPRITE_XMSB     = $d010
SPRITE0_COLOUR  = $d027
SPRPTRADR       = $d06c		; 24-bit address of the sprite pointer list

; The sprite's top-left is the click point (the hot spot), so a screen pixel
; (px, py) puts the sprite at VIC coordinates px + 24, py + 50.
MOUSE_X_OFFSET  = 24
MOUSE_Y_OFFSET  = 50
MOUSE_X_MAX     = 319
MOUSE_Y_MAX     = 199

mouse_px        !byte 160, 0	; pointer pixel position, X is 0..319 (two bytes)
mouse_py        !byte 100		; Y is 0..199
mouse_prev_potx !byte 0			; the pot readings the last poll, to difference
mouse_prev_poty !byte 0
mouse_button    !byte 0			; 1 while the button is held
mouse_clicked   !byte 0			; set on the press edge, cleared when consumed
mouse_cell_x    !byte 1			; current pointer position in 1-based cells
mouse_cell_y    !byte 1
mouse_click_x   !byte 1			; cell the last click landed in
mouse_click_y   !byte 1
mouse_window    !byte $ff		; window the mouse is confined to, $ff = free
mouse_active    !byte 0			; 1 once a game asks for the mouse (Flags 2 bit 5)
.mouse_temp     !byte 0
.mouse_ext      !byte 0, 0		; address of the header extension table

mouse_init
	; Point the sprite hardware at our arrow, colour it, and show it. The FCM
	; screen setup never touches the sprite registers, so this survives.
	jsr mega65io
	lda #<.mouse_sprite_ptrs
	sta SPRPTRADR
	lda #>.mouse_sprite_ptrs
	sta SPRPTRADR + 1
	lda #$80				; pointer list is in bank 0; bit 7 = 16-bit pointers
	sta SPRPTRADR + 2
	lda #2					; red
	sta SPRITE0_COLOUR
	; seed the pot history so the first poll reports no movement
	lda MOUSE_POTX
	lsr
	and #$3f
	sta mouse_prev_potx
	lda MOUSE_POTY
	lsr
	and #$3f
	sta mouse_prev_poty
	jmp .mouse_place_sprite

mouse_enable
	; The game asked for the mouse (Flags 2 bit 5): mark it active and show the
	; pointer. Called from z_init, once the header has been read.
	lda #1
	sta mouse_active
	jsr mega65io
	lda SPRITE_ENABLE
	ora #1					; sprite 0 on
	sta SPRITE_ENABLE
	rts

mouse_poll
	; Read the mouse, move the pointer, and note a fresh click. Returns with the
	; press-edge flag in mouse_clicked (also A: 0 = nothing, 1 = a click).
	lda #0
	sta mouse_clicked		; only a press this poll sets it again
	jsr mega65io

	; --- X: pot bits 1..6 are a wrapping 6-bit counter ---
	lda MOUSE_POTX
	lsr
	and #$3f
	sta .mouse_temp
	sec
	sbc mouse_prev_potx		; raw change, -63..63
	jsr .mouse_signed6		; fold to a signed -32..31 pixel delta in A
	ldx .mouse_temp
	stx mouse_prev_potx
	jsr .mouse_add_x		; move mouse_px by the signed delta, clamped

	; --- Y: pot counts the opposite way to the screen ---
	lda MOUSE_POTY
	lsr
	and #$3f
	sta .mouse_temp
	sec
	sbc mouse_prev_poty
	jsr .mouse_signed6
	eor #$ff				; negate: up on the desk is up the screen
	clc
	adc #1
	ldx .mouse_temp
	stx mouse_prev_poty
	jsr .mouse_add_y

	jsr .mouse_place_sprite
	jsr .mouse_update_cells

	; --- button, with press-edge detection ---
	lda MOUSE_BUTTON
	and #$10				; bit 4 = fire; clear means pressed
	bne .mouse_up
	lda mouse_button		; held now — was it held before?
	bne .mouse_done			; yes: not a new click
	lda #1
	sta mouse_button
	jsr .mouse_register_click
	lda mouse_clicked
	rts
.mouse_up
	lda #0
	sta mouse_button
.mouse_done
	lda mouse_clicked
	rts

mouse_write_header_coords
	; Put the click cell into words 1 and 2 of the header extension table, if the
	; game supplied a table of at least two words (z-spec 10.3.2). Coordinates
	; are in the screen's units, which for Ozmoo are 1-based character cells.
	ldy #header_header_extension_table
	jsr read_header_word	; a = high, x = low of the table's byte address
	sta .mouse_ext + 1
	stx .mouse_ext
	ora .mouse_ext			; a 0 address means the game gave no table
	beq .mwhc_done
	lda .mouse_ext + 1		; word 0 is the number of words in the table
	ldx .mouse_ext
	jsr set_z_address
	jsr read_next_byte		; length high byte
	bne .mwhc_write			; >= 256 words, certainly enough
	jsr read_next_byte		; length low byte
	cmp #2
	bcc .mwhc_done
.mwhc_write
	lda .mouse_ext			; point at word 1 (table + 2) and write x then y
	clc
	adc #2
	tax
	lda .mouse_ext + 1
	adc #0
	jsr set_z_address
	lda #0
	jsr write_next_byte		; word 1 high
	lda mouse_click_x
	jsr write_next_byte		; word 1 low = x
	lda #0
	jsr write_next_byte		; word 2 high
	lda mouse_click_y
	jsr write_next_byte		; word 2 low = y
.mwhc_done
	rts

.mouse_register_click
	; A press landed. If the mouse is confined to a window and the pointer is
	; outside it, the spec says ignore the click (10.3.4).
	lda mouse_window
	cmp #$ff
	beq +
	tay
	; row within [window_y, window_y + window_y_size) ? cells are 1-based
	lda mouse_cell_y
	sec
	sbc #1					; 0-based row
	cmp window_y,y
	bcc .mouse_click_out
	sec
	sbc window_y,y
	cmp window_y_size,y
	bcs .mouse_click_out
	lda mouse_cell_x
	sec
	sbc #1
	cmp window_x,y
	bcc .mouse_click_out
	sec
	sbc window_x,y
	cmp window_x_size,y
	bcs .mouse_click_out
+	lda mouse_cell_x		; remember where the click landed
	sta mouse_click_x
	lda mouse_cell_y
	sta mouse_click_y
	lda #1
	sta mouse_clicked
.mouse_click_out
	rts

.mouse_signed6
	; A holds cur - prev in -63..63; return the wrapped signed delta -32..31.
	clc
	adc #$20
	and #$3f
	sec
	sbc #$20
	rts

.mouse_add_x
	; add the signed byte in A to the 16-bit mouse_px, clamped to 0..MOUSE_X_MAX
	tay						; keep the delta
	clc
	adc mouse_px
	sta mouse_px
	tya
	and #$80				; sign-extend the delta into the high byte
	beq +
	lda #$ff
+	adc mouse_px + 1
	sta mouse_px + 1
	; result is -32..350; its high byte is $ff, 0 or 1
	bmi .mouse_x_zero		; negative -> 0
	beq .mouse_x_ok			; 0..255 -> in range
	cmp #>MOUSE_X_MAX		; high >= 1
	bne .mouse_x_max		; > 1 -> above 319
	lda mouse_px
	cmp #<MOUSE_X_MAX + 1
	bcc .mouse_x_ok
.mouse_x_max
	lda #<MOUSE_X_MAX
	sta mouse_px
	lda #>MOUSE_X_MAX
	sta mouse_px + 1
.mouse_x_ok
	rts
.mouse_x_zero
	lda #0
	sta mouse_px
	sta mouse_px + 1
	rts

.mouse_add_y
	; add the signed byte in A to mouse_py (0..199), clamped. The result is
	; -32..230, so its sign-extended high byte is $ff (negative) or 0.
	tay
	clc
	adc mouse_py
	pha						; low byte of the result; carry preserved by pha
	tya
	and #$80
	beq +
	lda #$ff
+	adc #0					; high byte = sign extension + carry
	bne .mouse_y_zero		; $ff -> below 0
	pla						; 0..230
	cmp #MOUSE_Y_MAX + 1
	bcc +
	lda #MOUSE_Y_MAX
+	sta mouse_py
	rts
.mouse_y_zero
	pla
	lda #0
	sta mouse_py
	rts

.mouse_place_sprite
	jsr mega65io
	; X = px + 24, which can exceed 255, so maintain the MSB in $d010 bit 0
	lda mouse_px
	clc
	adc #MOUSE_X_OFFSET
	sta SPRITE0_X
	lda mouse_px + 1
	adc #0
	lsr						; bit 0 of the high byte -> carry
	lda SPRITE_XMSB
	and #$fe
	adc #0					; carry (the 9th X bit) into bit 0
	sta SPRITE_XMSB
	lda mouse_py
	clc
	adc #MOUSE_Y_OFFSET
	sta SPRITE0_Y
	rts

.mouse_update_cells
	; cell = pixel / 8, then 1-based
	lda mouse_px + 1		; px / 8 for a 0..319 value
	lsr
	lda mouse_px
	ror
	lsr
	lsr						; A = px / 8 (0..39)
	clc
	adc #1
	sta mouse_cell_x
	lda mouse_py
	lsr
	lsr
	lsr						; py / 8 (0..24)
	clc
	adc #1
	sta mouse_cell_y
	rts

; A 24x21 monochrome arrow, hot spot at the top-left corner. 63 bytes of data,
; padded to a 64-byte boundary so the 16-bit sprite pointer (address / 64) is
; exact.
!align 63, 0
.mouse_sprite_data
	!byte %10000000, %00000000, %00000000
	!byte %11000000, %00000000, %00000000
	!byte %11100000, %00000000, %00000000
	!byte %11110000, %00000000, %00000000
	!byte %11111000, %00000000, %00000000
	!byte %11111100, %00000000, %00000000
	!byte %11111110, %00000000, %00000000
	!byte %11111111, %00000000, %00000000
	!byte %11111111, %10000000, %00000000
	!byte %11111111, %11000000, %00000000
	!byte %11111100, %00000000, %00000000
	!byte %11101100, %00000000, %00000000
	!byte %11001110, %00000000, %00000000
	!byte %10001110, %00000000, %00000000
	!byte %00000111, %00000000, %00000000
	!byte %00000111, %00000000, %00000000
	!byte %00000011, %10000000, %00000000
	!byte %00000011, %10000000, %00000000
	!byte %00000001, %00000000, %00000000
	!byte %00000000, %00000000, %00000000
	!byte %00000000, %00000000, %00000000
	!byte 0

.mouse_sprite_ptrs
	!word .mouse_sprite_data / 64	; sprite 0 points at the arrow
	!fill 14, 0						; sprites 1..7 unused

}
