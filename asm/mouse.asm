; Mouse support: the MEGA65 full colour screen (Z6_FCM_MODE) and the X16's
; pictures screen (TARGET_X16 + Z6_PICTURES), both selected by Z6_MOUSE.
;
; The Z-machine mouse model is in z-spec 10.3: a game sets bit 5 of Flags 2 to
; ask for a mouse, the interpreter clears it if it cannot offer one, a click is
; delivered as input character 254 and its position is written into the header
; extension table (10.3.2), read back with read_mouse in v6 (10.3.3), and the
; mouse may be confined to one window, whereupon clicks outside it are ignored
; (10.3.4). All of that is common to both machines and lives here; only reading
; the hardware and moving the pointer differ, which is .mouse_read.
;
; MEGA65: the 1351/Amiga mouse on control port 2 is read straight from the
; MEGA65's own pot registers ($d620/$d621), which need no SID/CIA multiplexing,
; and its button from the port 2 fire line ($dc00 bit 4). Port 2 is the clean
; joystick port; port 1's lines are shared with the keyboard matrix, so its fire
; bit ($dc01 bit 4) reads keyboard row 4 too and can't tell a click from a
; keypress. The pot is a 6-bit counter that wraps, so we track the signed change
; between polls and accumulate a pixel position. The pointer is sprite 0, moved
; in software: the MEGA65 has no hardware that ties a sprite to the mouse, its
; KERNAL does it in an interrupt, and so do we — once per input poll.
;
; X16: the KERNAL owns the PS/2 mouse. mouse_config ($ff68) turns the pointer on
; and gives it its bounds in 8-pixel units, mouse_get ($ff6b) returns the
; position and the button mask, and the KERNAL's own interrupt handler scans the
; mouse and moves the pointer sprite (VERA sprite 0, its image at VRAM $13000,
; clear of the tile store and the layer 0 map). So .mouse_read there is a single
; KERNAL call, and there is no sprite of ours to place.

!ifdef Z6_MOUSE {

!ifdef TARGET_X16 {
; The pictures screen is 640x200 logical pixels (80x25 cells): mouse_config
; takes those bounds in 8-pixel units, and mouse_get then reports a position in
; the same space as the sprite, which the KERNAL positions for us.
MOUSE_X_MAX     = SCREEN_WIDTH * 8 - 1
MOUSE_Y_MAX     = SCREEN_HEIGHT * 8 - 1
} else {
MOUSE_POTX      = $d620		; port 2 pot X / Y, MEGA65 direct-read registers
MOUSE_POTY      = $d621
MOUSE_BUTTON    = $dc00		; port 2: bit 4 clear = left button down
; A joystick in control port 1 is an alternative to the mouse (either, or both,
; moves the pointer and clicks). Port 1 is $dc01, whose lines are shared with the
; keyboard matrix, so it is read with the columns deselected (JOY_COLUMNS in
; $dc00) - a held key would otherwise look like a direction or a click. Bits, all
; active low: 0 up, 1 down, 2 left, 3 right, 4 fire.
JOY_PORT1       = $dc01
JOY_COLUMNS     = $dc00		; keyboard column select; $ff = none, for a clean read
JOY_UP          = %00000001
JOY_DOWN        = %00000010
JOY_LEFT        = %00000100
JOY_RIGHT       = %00001000
JOY_FIRE        = %00010000
JOY_DIRS        = %00001111
JOY_STEP        = 6			; pixels the pointer moves per jiffy while a way is held
JOY_STEP_NEG    = 256 - JOY_STEP
SPRITE_ENABLE   = $d015
SPRITE0_X       = $d000
SPRITE0_Y       = $d001
SPRITE_XMSB     = $d010
SPRITE0_COLOUR  = $d027
SPRPTRADR       = $d06c		; 24-bit address of the sprite pointer list

; The sprite's top-left is the click point (the hot spot), so a screen pixel
; (px, py) puts the sprite at VIC coordinates px + 24, py + 50 -- except that
; on the H640 screen a sprite X unit covers two physical pixels, so the
; pointer's 0..639 position halves into sprite coordinates.
MOUSE_X_OFFSET  = 24
MOUSE_Y_OFFSET  = 50
!ifdef Z6_FCM_40 {
MOUSE_X_MAX     = 319
} else {
MOUSE_X_MAX     = 639
}
MOUSE_Y_MAX     = 199
}

; pointer pixel position, starting mid-screen; X is 0..MOUSE_X_MAX (two bytes)
mouse_px        !byte <((MOUSE_X_MAX + 1) / 2), >((MOUSE_X_MAX + 1) / 2)
mouse_py        !byte (MOUSE_Y_MAX + 1) / 2		; Y is 0..MOUSE_Y_MAX
mouse_button    !byte 0			; the buttons held now, one bit each (0 = none)
mouse_clicked   !byte 0			; set on the press edge, cleared when consumed
mouse_cell_x    !byte 1			; current pointer position in 1-based cells
mouse_cell_y    !byte 1
mouse_click_x   !byte 1			; cell the last click landed in
mouse_click_y   !byte 1
mouse_window    !byte $ff		; window the mouse is confined to, $ff = free
mouse_active    !byte 0			; 1 once a game asks for the mouse (Flags 2 bit 5)
.mouse_temp     !byte 0
.mouse_ext      !byte 0, 0		; address of the header extension table
.mouse_save_x   !byte 0			; caller's registers, kept across a poll
.mouse_save_y   !byte 0

mouse_poll
	; Read the mouse, move the pointer, and note a fresh click. Returns with the
	; press-edge flag in mouse_clicked (also A: 0 = nothing, 1 = a click), and
	; with x and y as the caller left them.
	stx .mouse_save_x
	sty .mouse_save_y
	jsr .mouse_poll_body
	ldx .mouse_save_x
	ldy .mouse_save_y
	lda mouse_clicked		; reload, so z reflects the result and not the ldy
	rts

.mouse_poll_body
	lda #0
	sta mouse_clicked		; only a press this poll sets it again
	jsr .mouse_read			; a = the buttons held now, one bit each
	pha
	jsr .mouse_update_cells
	pla

	; --- press-edge detection: a button going down is a click ---
	cmp #0
	beq .mouse_up
	ldx mouse_button		; held now — was anything held before?
	sta mouse_button
	bne .mouse_done			; yes: not a new press
	jsr .mouse_register_click
	lda mouse_clicked
	rts
.mouse_up
	sta mouse_button
.mouse_done
	lda mouse_clicked
	rts

mouse_write_header_coords
	; Put the click cell into words 1 and 2 of the header extension table, if the
	; game supplied a table of at least two words (z-spec 10.3.2). Coordinates
	; are in the screen's units, which for Ozmoo are 1-based character cells.
	;
	; z_address IS SAVED ACROSS THIS, and must be. The click that gets here often
	; arrives at a [MORE] prompt, and a [MORE] prompt happens in the middle of a
	; print: print_addr keeps its position in the string in z_address, and
	; set_z_address / read_next_byte / write_next_byte below are the very
	; routines it walks the string with. Without this the print resumed from the
	; header extension table and the game spat decoded garbage all over the
	; screen - clicking to dismiss [MORE] did that on both graphics targets,
	; while pressing a key (which touches none of this) was fine. print_addr's
	; own abbreviation path saves the same bytes for the same reason.
	lda z_address
	pha
	lda z_address + 1
	pha
	lda z_address + 2
	pha
	jsr .mwhc_body
	pla
	sta z_address + 2
	pla
	sta z_address + 1
	pla
	sta z_address
!ifdef TARGET_X16 {
	jsr x16_bank_z_address	; the banked-RAM pointer is derived from z_address
}
	rts

.mwhc_body
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
!ifdef Z6_PIXEL_UNITS {
	; the click cell reported in units, like every other coordinate. The cell
	; is all this layer tracks, so it is the cell's corner rather than the
	; exact pixel; the games only ask which cell was clicked.
	lda mouse_click_x
	sec
	sbc #1					; the stored cell is 1-based
	jsr cells_to_units_x	; a = low, x = high
	clc
	adc #1
	sta .mwhc_col
	txa
	adc #0
	jsr write_next_byte		; word 1 high
	lda .mwhc_col
	jsr write_next_byte		; word 1 low = x
	lda #0
	jsr write_next_byte		; word 2 high
	lda mouse_click_y
	sec
	sbc #1
	jsr cells_to_units_y
	clc
	adc #1
	jsr write_next_byte		; word 2 low = y
} else {
	lda #0
	jsr write_next_byte		; word 1 high
	lda mouse_click_x
	jsr write_next_byte		; word 1 low = x
	lda #0
	jsr write_next_byte		; word 2 high
	lda mouse_click_y
	jsr write_next_byte		; word 2 low = y
}
.mwhc_done
	rts

!ifdef Z6_PIXEL_UNITS {
.mwhc_col !byte 0	; the click column while it is scaled into units
}

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

.mouse_update_cells
	; cell = pixel / 8, then 1-based
	lda mouse_px + 1		; px / 8; the high byte carries up to two bits
	sta .mouse_temp			; when the position runs to 639
	lda mouse_px
	lsr .mouse_temp
	ror
	lsr .mouse_temp
	ror
	lsr .mouse_temp
	ror						; A = px / 8 (0..SCREEN_WIDTH-1)
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

!ifdef TARGET_X16 {

mouse_init
	; Nothing to do before the game asks: the KERNAL owns the pointer, and
	; turning it on early would leave an arrow on the splash screen.
	rts

mouse_enable
	; The game asked for the mouse (Flags 2 bit 5): tell the KERNAL to show its
	; pointer and to bound it to our screen, in 8-pixel units. Called from
	; z_init, once the header has been read.
	lda #1
	sta mouse_active
	ldx #SCREEN_WIDTH
	ldy #SCREEN_HEIGHT
	lda #1					; 1 = show the default pointer
	jsr kernal_mouse_config
	; the pointer is a sprite, so the sprite layer has to be on
	stz VERA_ctrl
	lda VERA_dc_video
	ora #$40
	sta VERA_dc_video
	rts

mouse_disable
	; The quit path: hide the pointer again (which also puts the SMC back to
	; sending key codes only), so BASIC comes up without an arrow on it.
	lda #0
	sta mouse_active
	ldx #0
	ldy #0
	jsr kernal_mouse_config
	rts

.mouse_read
	; The KERNAL scanned the mouse in its interrupt handler and moved the
	; pointer sprite; mouse_get just reads the state back. It fills four
	; zero page bytes from .x -- we use the KERNAL API registers r0 and r1,
	; which the interrupt handler saves and restores around its own use --
	; and returns the button mask in a (bit 0 left, 1 right, 2 middle) and
	; the scroll wheel movement in x, which we have no use for.
	ldx #x16_r0
	jsr kernal_mouse_get
	pha
	lda x16_r0
	sta mouse_px
	lda x16_r0 + 1
	sta mouse_px + 1
	lda x16_r1				; y never exceeds MOUSE_Y_MAX, so one byte of it
	sta mouse_py
	pla
	rts

} else {

mouse_prev_potx !byte 0			; the pot readings the last poll, to difference
mouse_prev_poty !byte 0
.joy_bits       !byte $ff		; the joystick bits read this poll ($ff = idle)
.joy_last_jiffy !byte 0			; the jiffy the pointer last stepped for the joystick
.joy_was_held   !byte 0			; nonzero if the joystick was held the previous poll,
								; so one more keyboard flush catches a late phantom key

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

.mouse_read
	; Difference the pots into a pixel position, move the sprite there, and
	; return the button state (1 = the button is down) in a.
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

	; --- a joystick in control port 1 moves the pointer too ---
	jsr .mouse_read_joy
	jsr .mouse_place_sprite

	; the button is down if either the mouse's (port 2 fire) or the joystick's
	; (port 1 fire, in .joy_bits) is pressed
	lda MOUSE_BUTTON
	and #$10				; bit 4 = fire; clear means pressed
	beq .mouse_btn_down
	lda .joy_bits
	and #JOY_FIRE
	beq .mouse_btn_down
	lda #0					; neither: up
	rts
.mouse_btn_down
	lda #1
	rts

.read_joy_bits
	; A = the joystick's bits ($dc01, active low: 0 up 1 down 2 left 3 right
	; 4 fire). $dc00 selects keyboard columns, so deselect them all around the
	; read - with a column live, a held key on that column would read as a
	; direction or a click - and keep interrupts off so the keyboard scan cannot
	; reselect one between the two writes. NOTE this cleans OUR read only; the
	; KERNAL's own scan still sees the joystick and turns it into phantom keys,
	; which getchar_and_maybe_toggle_darkmode discards (see mouse_joystick_held).
	php
	sei
	lda JOY_COLUMNS
	pha
	lda #$ff
	sta JOY_COLUMNS
	lda JOY_PORT1
	tax
	pla
	sta JOY_COLUMNS
	plp
	txa
	rts

mouse_joystick_held
	; A/z: nonzero if any direction or fire is held (0 = idle). getchar uses this
	; to drop the phantom keys the KERNAL scan makes from the joystick.
	jsr .read_joy_bits
	eor #$ff				; active low -> a set bit now means "held"
	and #(JOY_DIRS | JOY_FIRE)
	rts

.mouse_read_joy
	; Read the joystick and step the pointer once per jiffy for each direction
	; held. Leaves the raw bits (fire included) in .joy_bits for the button test.
	jsr .read_joy_bits
	sta .joy_bits

	and #JOY_DIRS
	cmp #JOY_DIRS
	beq .mrj_done			; no direction held (all bits set)

	; rate-limit to one step per jiffy, so the speed does not depend on how fast
	; the input-wait loop polls (kernal_readtime returns the jiffy low byte in a)
	jsr kernal_readtime
	cmp .joy_last_jiffy
	beq .mrj_done
	sta .joy_last_jiffy

	lda .joy_bits
	and #JOY_LEFT
	bne +
	lda #JOY_STEP_NEG
	jsr .mouse_add_x
+	lda .joy_bits
	and #JOY_RIGHT
	bne +
	lda #JOY_STEP
	jsr .mouse_add_x
+	lda .joy_bits
	and #JOY_UP
	bne +
	lda #JOY_STEP_NEG
	jsr .mouse_add_y
+	lda .joy_bits
	and #JOY_DOWN
	bne +
	lda #JOY_STEP
	jsr .mouse_add_y
+
.mrj_done
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
	; result is -32..MOUSE_X_MAX+31; its high byte is $ff, or 0..>MOUSE_X_MAX
	bmi .mouse_x_zero		; negative -> 0
	beq .mouse_x_ok			; 0..255 -> in range
	cmp #>MOUSE_X_MAX
	bcc .mouse_x_ok			; a smaller high byte -> in range
	bne .mouse_x_max		; a bigger one -> past the edge
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
!ifdef Z6_FCM_40 {
	lda mouse_px + 1
	sta .mouse_temp
	lda mouse_px
} else {
	; a sprite X unit is two physical pixels on the H640 screen (the sprite
	; coordinate space does not change with H640), so halve the position
	lda mouse_px + 1
	lsr
	sta .mouse_temp
	lda mouse_px
	ror
}
	clc
	adc #MOUSE_X_OFFSET
	sta SPRITE0_X
	lda .mouse_temp
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

} ; TARGET_X16 / MEGA65

}
