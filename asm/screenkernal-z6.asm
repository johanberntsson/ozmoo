; Z6 version of screenkernal.asm (used when the Z6 window model is active).

; A screen cell is two bytes under FCM. Ozmoo writes the character into the
; even one; the odd one selects a full colour tile when it is non-zero, so
; every character written over a picture has to put it back to zero.
!ifdef Z6_FCM_MODE {
!macro clear_cell_high_byte {
	iny
	lda #0
	sta (zp_screenline),y
	dey
}
; Colour RAM is CPU-visible only 2 KB at a time through $d800, which the
; 80-column screen's 4000 colour bytes outgrow. Under FCM zp_colourline is
; therefore a 32-bit pointer into colour RAM at $ff80000 (see constants.asm)
; and every colour access goes through it -- no colour2k/colour1k. The store
; takes the colour in a and the byte index in y, like the old
; sta (zp_colourline),y it replaces. Clobbers z.
!macro sta_colour_ram {
	phy
	plz
	sta [zp_colourline],z
}
} else {
!macro clear_cell_high_byte {
}
}

; Kept as close to screenkernal.asm as possible; differences:
; - window_start_row replaced by the window_y array (window_y,w = top row of window w)
; - no bounds/overflow checks in .normal_char, and no auto-expansion of window 1
;   (in z6, window positions and sizes are controlled by the game)
;
; replacement for these C64 kernal routines and their variables:
; printchar $ffd2
; plot      $fff0
; zp_cursorswitch $cc
; zp_screenline $d1-$d2
; zp_screencolumn $d3
; zp_screenrow $d6
; zp_colourline $f3-$f4
;
; needed to be able to customize the text scrolling to
; not include status lines, especially big ones used in
; Border Zone, and Nord and Bert.
;
; usage: first call s_init, then replace
; $ffd2 with s_printchar and so on.
; s_scrollstart is set to the number of top lines to keep when scrolling

!zone screenkernal {

!ifdef TARGET_X16 {
colour_petscii !byte 144,5,28,159,156,30,31,158,129,149,150,151,152,153,154,155
}
zcolours	!byte $ff,$ff ; current/default colour
			!byte 0,2,5,7  ; black, red, green, yellow
			!byte 6,4,3,1  ; blue, magenta, cyan, white
			!byte $ff,$ff,$ff,$ff,$ff,$ff ; Colour 10-15 are unused
			!byte 8,9,10,11,12,13,14,15 ; Colour 16-23 are C64 colours 8-15
darkmode	!byte 0
bgcol		!byte BGCOL, BGCOLDM
fgcol		!byte FGCOL, FGCOLDM
bordercol	!byte BORDERCOL_FINAL, BORDERCOLDM_FINAL
!ifdef USE_INPUTCOL {
inputcol	!byte INPUTCOL, INPUTCOLDM
}
!ifndef Z4PLUS {
statuslinecol !byte STATCOL, STATCOLDM
}
cursorcol !byte CURSORCOL, CURSORCOLDM
current_cursor_colour !byte CURSORCOL
cursor_character !byte CURSORCHAR

!ifdef TARGET_PLUS4 {
plus4_vic_colours
	;     PLUS4  VIC-II
	!byte $00   ; black
	!byte $71   ; white
	!byte $32   ; red
	!byte $63   ; cyan
	!byte $44   ; purple
	!byte $65   ; green
	!byte $26   ; blue
	!byte $77   ; yellow
	!byte $48   ; orange
	!byte $39   ; brown 
	!byte $62   ; light red
	!byte $31   ; dark grey
	!byte $51   ; grey
	!byte $75   ; light green
	!byte $56   ; light blue
	!byte $61   ; light grey
}

!ifdef TARGET_X16 {
!source "vera.asm"

.stored_x_or_y !byte 0
.vera_background !byte 0
vera_composite_colour !byte 0

.convert_screenline_y_to_vera_address
    ; convert screenline,y to address in VERA
	tya
	asl
	sta VERA_addr_low
	lda zp_screenline + 1
	adc #$b0 ; Carry is already clear after ASL
	sta VERA_addr_high
    rts

.s_scroll_vera
	; Scroll the current window's rectangle up one line and erase the window's
	; new last line, the VERA equivalent of .s_scroll. Leaves zp_screenrow on
	; that last line. The rows and the blanking are the same window-local ones
	; the scroll_window opcode uses, so only .vera_copy_row is VERA-specific.
	; (This used to scroll the whole screen from window 0's top line down,
	; which smeared every window that did not reach the bottom of the screen.)
	jsr .calc_window_rect
!ifdef SCROLLBACK {
	inc s_scrolled_lines
}
	jsr .vera_scroll_delay
	jsr .sw_up_one ; copies the window's rows up, blanks its new last line
!ifdef Z6_PICTURES {
	jsr pic_scroll_win_up ; and the pictures behind it, on layer 0
}
	ldy .win_left
	sty zp_screencolumn
	rts

.vera_scroll_delay
	; Slow the scroll down by as much as scroll_delay asks, then land on the
	; same scanline every time so a scrolling window does not tear.
	ldx scroll_delay
	beq .done_delaying_vera
	dex
	beq ++
-	txa
	pha
	jsr wait_an_interval
	pla
	tax
	dex
	bne -
++
-	ldx VERA_scanline_l
	cpx #<450
	bne -
	lda VERA_ien
	and #$40 ; bit 8 of the scanline: 450 is past the bottom of the text screen
	beq -
.done_delaying_vera
	rts

.vera_copy_row
	; Copy the window's columns from row .sw_src to row .sw_dst. A cell is a
	; character byte and a colour byte, and a VERA text row is 256 bytes, so a
	; cell sits at $1b000 + row * 256 + column * 2: the row is the address high
	; byte and the column never carries into it. Port 0 reads and port 1 writes,
	; both stepping by one; port 0 is left selected with the stride the rest of
	; the screen code expects of it.
	lda .win_right_excl
	sec
	sbc .win_left
	beq + ; a window with no columns has nothing to copy
	tax
	lda #1
	sta VERA_ctrl ; port 1: the destination row
	lda #$11 ; stride 1, and bit 16 of the address (the text map is at $1b000)
	sta VERA_addr_bank
	lda .sw_dst
	clc
	adc #$b0
	sta VERA_addr_high
	lda .win_left
	asl ; two bytes a cell
	sta VERA_addr_low
	stz VERA_ctrl ; port 0: the source row, and the port everything else uses
	lda #$11
	sta VERA_addr_bank
	lda .sw_src
	clc
	adc #$b0
	sta VERA_addr_high
	lda .win_left
	asl
	sta VERA_addr_low
-	lda VERA_data0 ; the character
	sta VERA_data1
	lda VERA_data0 ; and its colour
	sta VERA_data1
	dex
	bne -
+	rts

VERASetBorderColour
	stz VERA_ctrl
	sta VERA_dc_border
    rts

!ifdef Z6_PICTURES {
vera_gfx_init
	; Set the pictures screen up: halve VSCALE so the 80x60 text mode becomes
	; 80x30 fat rows, crop the display to 25 of them with VSTOP (640x200
	; effective - the MEGA65 80-column geometry), move the kernal charset out
	; of VRAM bank 0 (which becomes the tile store), and put layer 0 behind
	; the text as a 64x32 map of 16x8-pixel 4bpp tiles, all transparent.
	stz VERA_ctrl			; port 0, DCSEL 0
	lda #64
	sta VERA_dc_vscale
	lda #2					; DCSEL 1: HSTART/HSTOP/VSTART/VSTOP
	sta VERA_ctrl
	lda #200				; VSTOP is in physical lines / 2: 400 lines shown
	sta VERA_dc_border		; $9f2c is VSTOP when DCSEL = 1
	stz VERA_ctrl

	; Copy the 2 KB charset from wherever the kernal keeps it to VRAM_CHARSET,
	; reading with port 0 and writing with port 1, then repoint layer 1 at the
	; copy. The tilebase register holds address bits 16-11 in its top six
	; bits: bit 7 is address bit 16, and (reg & $7c) << 1 is the address's
	; high byte.
	lda VERA_L1_tilebase
	pha						; keep the tile size bits for later
	and #$80
	asl						; carry = address bit 16, a = 0
	lda #$10				; stride 1
	adc #0					; plus address bit 16
	sta VERA_addr_bank
	pla
	pha
	and #$7c
	asl
	sta VERA_addr_high
	stz VERA_addr_low
	lda #1					; port 1: the destination, $11000
	sta VERA_ctrl
	lda #$11				; stride 1, address bit 16 set
	sta VERA_addr_bank
	lda #>(VRAM_CHARSET & $ffff)
	sta VERA_addr_high
	stz VERA_addr_low
	stz VERA_ctrl
	ldx #8					; 8 pages = 2 KB
	ldy #0
-	lda VERA_data0
	sta VERA_data1
	iny
	bne -
	dex
	bne -
	pla
	and #$03				; keep the 8x8 tile size
	ora #((VRAM_CHARSET >> 11) << 2) & $fc
	sta VERA_L1_tilebase

	; Layer 0: 64x32 map at VRAM_L0_MAP, 16x8 tiles at VRAM_PIC_TILES, 4bpp
	lda #$12				; map height 32, width 64, tile mode, 4bpp
	sta VERA_L0_config
	lda #(VRAM_L0_MAP >> 9)
	sta VERA_L0_mapbase
	lda #$01				; tile base 0, tile height 8, tile width 16
	sta VERA_L0_tilebase

	; Zero tile 0 (the transparent tile) and the whole map, port 0, stride 1
	lda #$10
	sta VERA_addr_bank
	stz VERA_addr_high
	stz VERA_addr_low
	ldy #64
	lda #0
-	sta VERA_data0
	dey
	bne -
	lda #$11				; the map is in bank 1
	sta VERA_addr_bank
	lda #>(VRAM_L0_MAP & $ffff)
	sta VERA_addr_high
	stz VERA_addr_low
	ldx #16					; 16 pages = 4 KB
	ldy #0
	lda #0
-	sta VERA_data0
	iny
	bne -
	dex
	bne -

	; leave port 0 selected with stride 1, as the screen code expects
	lda #$11
	sta VERA_addr_bank

	stz VERA_ctrl			; enable layer 0 (DC_VIDEO bit 4)
	lda VERA_dc_video
	ora #$10
	sta VERA_dc_video
	rts

vera_gfx_restore
	; The quit path: put the composer and layer 1 back the way the kernal
	; left them, so BASIC comes up readable after the reset.
	stz VERA_ctrl
	lda #128
	sta VERA_dc_vscale
	lda #2
	sta VERA_ctrl
	lda #240				; VSTOP back to 480 lines
	sta VERA_dc_border
	stz VERA_ctrl
	lda VERA_dc_video		; layer 0 off
	and #$ef
	sta VERA_dc_video
	; The kernal's charset copy at VRAM_CHARSET is intact, and BASIC keeps
	; using it through our L1 tilebase, so it does not need moving back.
	rts
} ; Z6_PICTURES

VERASetBackgroundColour
	pha
    asl
    asl
    asl
    asl
    sta .vera_background
	ora s_colour
	sta vera_composite_colour
	pla
    rts

VERASetForegroundColour
    sta s_colour
	ora .vera_background
	sta vera_composite_colour
    lda s_colour
    rts

VERAPrintChar
	; a = character, y = column
	pha
	sty .stored_x_or_y
    jsr .convert_screenline_y_to_vera_address
    ; write character
    pla
    sta VERA_data0
	ldy vera_composite_colour
	sty VERA_data0
    ; restore y
	ldy .stored_x_or_y
    rts

; VERAPrintColour
	; pha
	; sty .stored_x_or_y
    ; jsr .convert_screenline_y_to_vera_address
    ; ; increase to colour address
    ; inc VERA_addr_low
    ; bne +
    ; inc VERA_addr_high
    ; ; write colour
; +   pla
    ; ora vera_background
    ; sta VERA_data0
    ; ; restore y
	; ldy .stored_x_or_y
    ; rts

; VERAPrintColourAfterChar
	; ; a = colour
    ; ora .vera_background
    ; sta VERA_data0
    ; rts
}

!ifdef TARGET_C128 {
!source "vdc.asm"

.stored_a !byte 0
.stored_x_or_y !byte 0

; Mapping between VIC-II and VDC colours
; VDC:
; 00 = dark black
; 01 = light black (dark gray)
; 02 = dark blue
; 03 = light blue
; 04 = dark green
; 05 = light green
; 06 = dark cyan
; 07 = light cyan
; 08 = dark red
; 09 = light red
; 10 = dark purple
; 11 = light purple
; 12 = dark yellow (brown/orange)
; 13 = light yellow
; 14 = dark white (light gray)
; 15 = light white
vdc_vic_colours = $ce5c ; The official conversion table in ROM
	; ;     VDC    VIC-II
	; !byte 0    ; black
	; !byte 15   ; white
	; !byte 8    ; red
	; !byte 7    ; cyan
	; !byte 10   ; purple
	; !byte 4    ; green
	; !byte 3    ; blue
	; !byte 13   ; yellow
	; !byte 12   ; orange
	; !byte 12   ; brown 
	; !byte 9    ; light red
	; !byte 1    ; dark grey
	; !byte 14   ; grey
	; !byte 5    ; light green
	; !byte 3    ; light blue
	; !byte 14   ; light grey

C128SetBackgroundColour
	stx .stored_x_or_y
	bit COLS_40_80
	bpl +
	; 80 columns mode selected
	sta .stored_a
	tax
	lda vdc_vic_colours,x
	ldx #VDC_COLORS
	jsr VDCWriteReg
	lda .stored_a
	jmp ++
+	sta reg_backgroundcolour
++	ldx .stored_x_or_y
	rts

C128SetBorderColour
	stx .stored_x_or_y
	bit COLS_40_80
	bmi + ; no border in VDC, only use background
	; 40 column mode
	sta reg_bordercolour
+	ldx .stored_x_or_y
	rts

VDCGetChar
	; 80 columns, use VDC screen
	sty .stored_x_or_y
	lda zp_screenline + 1
	sec
	sbc #$04 ; adjust from $0400 (VIC-II) to $0000 (VDC)
	tay
	lda zp_screenline
	clc
	adc .stored_x_or_y
	bcc +
	iny
+	jsr VDCSetAddress
	ldy .stored_x_or_y
	ldx #VDC_DATA
	jmp VDCReadReg

VDCPrintChar
	; 80 columns, use VDC screen
	sty .stored_x_or_y
	pha
	lda zp_screenline + 1
	sec
	sbc #$04 ; adjust from $0400 (VIC-II) to $0000 (VDC)
	tay
	lda zp_screenline
	clc
	adc .stored_x_or_y
	bcc +
	iny
+	jsr VDCSetAddress
	pla
	ldy .stored_x_or_y
	ldx #VDC_DATA
	jmp VDCWriteReg

VDCPrintColour
	; 80 columns, use VDC screen
	sty .stored_x_or_y
	; adjust color from VIC-II to VDC format
	tax
	lda vdc_vic_colours,x
	ora #$80 ; lower-case
	pha
	lda zp_colourline + 1
	sec
	sbc #$d0 ; adjust from $d800 (VIC-II) to $0800 (VDC)
	tay
	lda zp_colourline
	clc
	adc .stored_x_or_y
	bcc +
	iny
+	jsr VDCSetAddress
	pla
	ldy .stored_x_or_y
	ldx #VDC_DATA
	jmp VDCWriteReg
}

!ifdef TARGET_MEGA65 {

init_mega65
	; MEGA65 IO enable
	jsr mega65io
	; set 40MHz CPU
	lda #65
	sta 0
!ifdef Z6_FCM_MODE {
!ifdef Z6_FCM_40 {
	; 320x200: H640 off, V400 off, and ATTR (bit 5) off, which is what selects
	; 8 bit colour. Bit 6 (fast CPU) stays on.
	lda #$40
	sta $d031
	lda #$c8
	sta $D016
} else {
	; 640x200: H640 on (bit 7) so 80 8-pixel text cells fit a row, V400 off,
	; ATTR (bit 5) off. Bit 6 (fast CPU) stays on.
	lda #$c0
	sta $d031
	lda #$c8 + 1 ; as on the 80-column text screen: +1 loses one pixel on the left
	sta $D016
}
} else {
	; set 80-column mode
	lda #$c0
	sta $d031
	lda #$c8 + 1 ; +1 loses one pixel on the left, +2 loses one pixel on the right. Leftmost pixel usually empty.
	sta $D016
}
	; Set the colour RAM offset. Under FCM the screen's colour cells sit at
	; FCM_COLOUR_OFFSET, past the CBDOS workspace that owns the top of colour
	; RAM's first 2 KB (see constants.asm); elsewhere at 0.
!ifdef Z6_FCM_MODE {
	lda #<FCM_COLOUR_OFFSET
	sta $d064
	lda #>FCM_COLOUR_OFFSET
	sta $d065
} else {
	lda #0
	sta $d064
	sta $d065
}
	; set screen at $0800
	;lda #$26
	;sta $d018
	; disable VIC-II/VIC-III hot registers
	lda $d05d
	and #$7f
	sta $d05d
!ifdef Z6_FCM_MODE {
	; 16 bit character codes (CHR16), and full colour for codes >= 256
	; (FCLRHI). FCLRLO stays off, so codes < 256 are ordinary 8 byte glyphs
	; fetched from CHARPTR, which is what all the text uses.
	lda $d054
	and #%11111010
	ora #%00000101
	sta $d054
	lda #SCREEN_WIDTH
	sta $d05e ; CHRCOUNT: cells per row
	lda #<SCREEN_ROW_BYTES
	sta $d058 ; LINESTEP: two bytes per cell
	lda #>SCREEN_ROW_BYTES
	sta $d059
	lda #<SCREEN_ADDRESS
	sta $d060 ; SCNPTR
	lda #>SCREEN_ADDRESS
	sta $d061
	lda #0
	sta $d062
	sta $d063
	lda #<FCM_CHARSET
	sta $d068 ; CHARPTR
	lda #>FCM_CHARSET
	sta $d069
	lda #^FCM_CHARSET
	sta $d06a

	; The colour RAM pointers' high words never change: colour RAM is at
	; $ff80000, and the offsets in the low words stay under 16 bits.
	lda #$f8
	sta zp_colourline + 2
	sta zp_colour_src + 2
	sta zp_colour_dst + 2
	sta zp_more_colour + 2
	lda #$0f
	sta zp_colourline + 3
	sta zp_colour_src + 3
	sta zp_colour_dst + 3
	sta zp_more_colour + 3

	; Every cell is two bytes. Ozmoo only ever writes the character (the even
	; byte of a screen cell) and the colour (the odd byte of a colour cell), so
	; the other two must start at zero and stay there. The colour RAM is
	; cleared through the 32-bit pointer; the screen through a plain one.
	lda #0
	sta zp_screenline
	sta zp_colourline
	lda #>FCM_COLOUR_OFFSET
	sta zp_colourline + 1
	lda #>SCREEN_ADDRESS
	sta zp_screenline + 1
	ldx #(SCREEN_ROW_BYTES * SCREEN_HEIGHT + $ff) >> 8 ; whole pages
	ldy #0
	ldz #0
	tya
-	sta (zp_screenline),y
	sta [zp_colourline],z
	iny
	inz
	bne -
	inc zp_screenline + 1
	inc zp_colourline + 1
	dex
	bne -
	; leave the low word pointing at row 0 again, bias included
	lda #1
	sta zp_colourline
	lda #>FCM_COLOUR_OFFSET
	sta zp_colourline + 1
}
	rts
	
colour2k
	; start mapping 2nd KB of colour RAM to $DC00-$DFFF
	sei
	pha
	jsr mega65io
	lda #$01
	sta $d030
	pla
	rts

colour1k
	; stop mapping 2nd KB of colour RAM to $DC00-$DFFF
	pha
	jsr mega65io
	lda #$00
	sta $d030
	pla
	cli
	rts
}

s_screen_width !byte 0
s_screen_height !byte 0
s_screen_width_plus_one !byte 0
s_screen_width_minus_one !byte 0
s_screen_height_minus_one !byte 0
s_screen_size !byte 0, 0

!ifdef Z6_FCM_MODE {
; The other targets borrow the tail of screen RAM for the disk directory and
; hide it by drawing it in the background colour. An FCM cell's high byte
; would make the borrowed cells show tiles, so the buffer is real memory here
; (constants.asm points directory_buffer at it).
fcm_directory_buffer !fill 140
}
!ifdef TARGET_X16 {
s_x16_screen_mode	!byte 0
}

!ifdef Z6_ECM_MODE {
; Extended Color Mode (ECM): the VIC-II takes the top two bits of each screen
; code as an index into four background colour registers ($d021-$d024), so
; each z6 window can have its own background colour. The price is that only
; the first 64 characters of the charset are available: text is lowercase
; only (uppercase screen codes are masked down to lowercase) and reverse
; video is lost.
reg_screenctrl = $d011 ; bit 6 turns Extended Color Mode on

ecm_bits        !byte 0 ; screen code bits for the current window's background
ecm_bg_colours  !byte 0, 0, 0, 0 ; the colours in $d021-$d024
ecm_bg_used     !byte 1 ; number of background registers handed out
window_bg_index !byte 0, 0, 0, 0, 0, 0, 0, 0 ; background register per window
.ecm_bits_table !byte $00, $40, $80, $c0

ecm_init
	; Turn on Extended Color Mode. Every window starts out using background
	; register 0, which holds the background colour the rest of Ozmoo sets.
	lda reg_screenctrl
	ora #%01000000
	sta reg_screenctrl
	lda #0
	sta ecm_bits
	sta ecm_bg_colours
	ldx #7
-	sta window_bg_index,x
	dex
	bpl -
	lda #1
	sta ecm_bg_used
	rts

ecm_set_bits_for_window
	; x = window. Preserves nothing.
	lda window_bg_index,x
	tax
	lda .ecm_bits_table,x
	sta ecm_bits
	rts

ecm_update_bits
	ldx current_window
	jmp ecm_set_bits_for_window

ecm_set_window_bg
	; a = C64 colour, x = window. Give the window a background register
	; showing that colour, reusing one that already holds it if possible.
	stx .ecm_window
	; Ozmoo writes background register 0 directly (initial colours, dark
	; mode), so read back what it holds before looking for a match.
	pha
	lda reg_backgroundcolour
	and #$0f
	sta ecm_bg_colours
	pla
	ldy #0
-	cmp ecm_bg_colours,y
	beq .ecm_found ; this register already shows the colour
	iny
	cpy ecm_bg_used
	bcc -
	; the colour isn't on screen yet: use the next free background
	; register, or, if all four are taken, overwrite the last one
	cpy #4
	bcc +
	ldy #3
+	sta ecm_bg_colours,y
	; write the colour to $d021 + register number
	pha
	tya
	tax
	pla
	sta reg_backgroundcolour,x
	cpy ecm_bg_used
	bcc .ecm_found
	iny
	sty ecm_bg_used
	dey
.ecm_found
	; remember which register the window uses
	ldx .ecm_window
	tya
	sta window_bg_index,x
	cpx current_window
	bne +
	jmp ecm_update_bits
+	rts

.ecm_window !byte 0
}

convert_petscii_to_screencode
   ; convert from pet ascii to screen code
	cmp #$40
	bcc ++    ; no change if numbers or special chars
	cmp #$60
	bcs +
	and #%00111111
	rts
+   cmp #$80
	bcs +
	and #%11011111
	rts
+	cmp #$c0
	bcs +
	eor #%11000000
+	and #%01111111
++ 	rts

s_init
	; set up screen_width and screen_width_minus_one
!ifdef TARGET_C128 {
	lda #40
	bit COLS_40_80
	bpl +
	; 80 columns mode selected
	lda #80
+
} else ifdef TARGET_X16 {
	sec
	jsr $ff5f
	sta s_x16_screen_mode
!ifdef Z6_PICTURES {
	; The pictures screen is not a kernal mode: vera_gfx_init reshapes the
	; 80x60 text mode into 80x25 fat rows with a tile layer behind it.
	jsr vera_gfx_init
	ldx #SCREEN_WIDTH
	ldy #SCREEN_HEIGHT
}
	txa
} else {
	lda #SCREEN_WIDTH
}
	sta s_screen_width
	sta s_screen_width_plus_one
	sta s_screen_width_minus_one
	inc s_screen_width_plus_one
	dec s_screen_width_minus_one

	; set up screen_height and screen_width_minus_one
!ifdef TARGET_X16 {
	tya
} else {
	lda #SCREEN_HEIGHT
}
	sta s_screen_height
	sta s_screen_height_minus_one
	dec s_screen_height_minus_one

	; calculate total screen size
	lda #0
	sta multiplier + 1
	lda s_screen_width
	sta multiplier
	lda s_screen_height
	jsr mult8
	lda product
	sta s_screen_size;
	lda product + 1
	sta s_screen_size + 1;

	; init cursor
	lda #$ff
	sta s_current_screenpos_row ; force recalculation first time
	lda #0
	sta zp_screencolumn
	sta zp_screenrow
	; Set to 0: s_ignore_next_linebreak, s_reverse
	ldx #3
-	sta s_ignore_next_linebreak,x
	dex
	bpl -
	rts

s_plot
	; y=column (0-(SCREEN_WIDTH-1))
	; x=row (0- (SCREEN_HEIGHT-1))
	bcc .set_cursor_pos
	; get_cursor
	ldx zp_screenrow
	ldy zp_screencolumn
	rts
.set_cursor_pos
+	cpx s_screen_height
	bcc +
	ldx s_screen_height_minus_one
+	stx zp_screenrow
	sty zp_screencolumn
	jmp .update_screenpos

s_set_text_colour
!ifdef TARGET_X16 {
	jmp VERASetForegroundColour
} else {
	sta s_colour
	rts
}

; The game swapped its foreground and background around (Arthur does it for
; every parser message, boxing the text like its status line): no target has
; per-window hardware backgrounds, but a swapped pair is exactly what the
; reversed glyphs draw -- the field in the glyph colour, the text in the
; screen background -- so while this is $80 everything prints reversed and
; the glyph colour is the requested background. Cleared when set_colour puts
; the background back. (ECM has no reversed glyphs; it never sets this.)
s_colour_swap	!byte 0
s_bg_zcolour	!byte 0	; the screen background as a z-colour number

s_delete_cursor
!ifdef TARGET_MEGA65 {
!ifndef Z6_FCM_MODE {
	jsr colour2k
}
}
!ifdef Z6_FCM_MODE {
	lda zp_screencolumn ; a cell is two bytes wide
	asl
	tay
}
	lda #$20 ; blank space
!ifdef Z6_ECM_MODE {
	ora ecm_bits ; keep the window's background colour
} else {
	ora s_colour_swap ; swapped colours erase to a field of the glyph colour
}
!ifdef TARGET_C128 {
	bit COLS_40_80
	bpl +
	jmp VDCPrintChar
+
}
!ifdef TARGET_X16 {
	jmp VERAPrintChar
} else {
!ifndef Z6_FCM_MODE {
	ldy zp_screencolumn
}
	sta (zp_screenline),y
	+clear_cell_high_byte
!ifdef TARGET_PLUS4 {
	ldx s_colour
	lda plus4_vic_colours,x
} else {
	lda s_colour
}
!ifdef Z6_FCM_MODE {
	+sta_colour_ram
} else {
	sta (zp_colourline),y
!ifdef TARGET_MEGA65 {
	jsr colour1k
}
}
	rts
}

s_printchar
	; replacement for CHROUT ($ffd2)
	; input: A = byte to write (PETASCII)
	; output: -
	; used registers: -
	stx s_stored_x
	sty s_stored_y

	ldx window_y
	cpx s_screen_height
	bcc +
	ldx current_window
	bne +
	; There is no free line to print on, return with carry set
	ldx s_stored_x
	rts
+
	; Fastlane for the most common characters
	cmp #$20
	bcc +
	cmp #$80
	bcc ++ ; .normal_char
	cmp #$a0
	bcc + ; bcs .normal_char
++	jmp .normal_char
+	
	cmp #$0d
	bne +
	; newline
	jmp .perform_newline
+
	cmp #20
	bne +
	; delete
	ldy zp_screencolumn
	jsr s_delete_cursor
	dec zp_screencolumn ; move back
	ldx current_window
	jsr s_window_left_edge
	ldy zp_screencolumn
	bmi .del_outside    ; went past column 0
	cmp zp_screencolumn
	beq .del_inside     ; on the left margin
	bcc .del_inside     ; still inside the window
.del_outside
	ldy current_window
	lda zp_screenrow
	cmp window_y,y
	bcc .del_left_edge  ; above window top (shouldn't happen): stay at left edge
	beq .del_left_edge  ; on the window's top row: stay at left edge
	dec zp_screenrow
	jsr s_window_right_edge
	sec
	sbc #1              ; rightmost column before the right margin
	sta zp_screencolumn
	jmp .del_inside
.del_left_edge
	jsr s_window_left_edge
	sta zp_screencolumn
.del_inside
	jsr .update_screenpos
!ifdef Z6_FCM_MODE {
	lda zp_screencolumn ; a cell is two bytes wide
	asl
	tay
} else {
	ldy zp_screencolumn
}
	lda #$20
!ifdef Z6_ECM_MODE {
	ora ecm_bits ; keep the window's background colour
}
!ifdef TARGET_C128 {
	bit COLS_40_80
	bmi .col80_1
	; 40 columns, use VIC-II screen
	sta (zp_screenline),y
	+clear_cell_high_byte
	lda s_colour
	sta (zp_colourline),y
	jmp .col80_1_end
.col80_1
	jsr VDCPrintChar
.col80_1_end
} else ifdef TARGET_X16 {
    jsr VERAPrintChar
} else {
	sta (zp_screenline),y
	+clear_cell_high_byte
!ifdef Z6_FCM_MODE {
	lda s_colour
	+sta_colour_ram
} else {
	!ifdef TARGET_MEGA65 {
		jsr colour2k
	}
	lda s_colour
	sta (zp_colourline),y
	!ifdef TARGET_MEGA65 {
		jsr colour1k
	}
}
}
	jmp .printchar_end
+   cmp #$93 
	bne +
	; clr (clear screen)
	lda #0
	sta zp_screencolumn
	sta zp_screenrow
	jsr s_erase_window
	jmp .printchar_end
+   cmp #$12 ; 18
	bne +
	; reverse on
	ldx #$80
	stx s_reverse
	jmp .printchar_end
+   cmp #$92 ; 146
	beq +
	jmp .printchar_end
	; reverse off
+   ldx #0
	stx s_reverse
	bne .normal_char
	jmp .printchar_end ; Always jump
	
.normal_char
	; Reset ignore next linebreak setting
	ldx current_window
	ldy s_ignore_next_linebreak,x
	bpl .resume_printing_normal_char
	inc s_ignore_next_linebreak,x
.resume_printing_normal_char
	jsr convert_petscii_to_screencode
!ifdef Z6_ECM_MODE {
	and #$3f ; only 64 characters, and the top bits select the background
	ora ecm_bits
} else {
	ora s_reverse
	ora s_colour_swap ; swapped colours render as reverse video
}
	pha
	jsr .update_screenpos
!ifdef Z6_FCM_MODE {
	lda zp_screencolumn ; a cell is two bytes wide
	asl
	tay
	pla
} else {
	pla
	ldy zp_screencolumn
}
!ifdef TARGET_C128 {
	bit COLS_40_80
	bmi .col80_2
	; 40 columns, use VIC-II screen
	sta (zp_screenline),y
	+clear_cell_high_byte
	lda s_colour
	sta (zp_colourline),y
	jmp .col80_2_end
.col80_2
	jsr VDCPrintChar
	lda s_colour
	jsr VDCPrintColour
.col80_2_end
} else ifdef TARGET_X16 {
	jsr VERAPrintChar
	; lda s_colour
	; jsr VERAPrintColourAfterChar
} else {
	sta (zp_screenline),y
	+clear_cell_high_byte
!ifdef Z6_FCM_MODE {
	lda s_colour
	+sta_colour_ram
} else {
	!ifdef TARGET_MEGA65 {
		jsr colour2k
	}
!ifdef TARGET_PLUS4 {
	ldx s_colour
	lda plus4_vic_colours,x
} else {
	lda s_colour
}
	sta (zp_colourline),y
	!ifdef TARGET_MEGA65 {
		jsr colour1k
	}
}
}
	; y is a byte offset under FCM, so step the column itself and reload
	inc zp_screencolumn
	ldy zp_screencolumn
	ldx current_window
	; wrap when the cursor passes the right margin of the current window
	jsr s_window_right_edge
	cpy .window_edge
	bcc .printchar_end
	lda window_attributes,x
	and #WIN_WRAPPING
	bne +
	; wrapping disabled: park the cursor on the window's last column
	ldy .window_edge
	dey
	sty zp_screencolumn
	jmp .printchar_end
+	dec s_ignore_next_linebreak,x ; Goes from 0 to $ff
!ifdef SCROLLBACK {
	cpx #0
	bne +
	jsr copy_line_to_scrollback
+
}
	jmp .wrap_to_next_line
.printchar_end
	ldx s_stored_x
	ldy s_stored_y
	rts

.perform_newline
	; newline/enter/return
	; Check ignore next linebreak setting
	ldx current_window
	ldy s_ignore_next_linebreak,x
	bpl +
	inc s_ignore_next_linebreak,x
	jmp .printchar_end
+	
!ifdef SCROLLBACK {
	; Copy to scrollback buffer, if we're in lower window
	ldx current_window
	bne +
	jsr copy_line_to_scrollback
+
}
	; fall through into .wrap_to_next_line

.wrap_to_next_line
	; Move the cursor to the start of the next line in the current window,
	; scrolling or clamping at the window's bottom edge
	inc zp_screenrow
	ldx current_window
	; bottom edge (exclusive) = min(window_y + window_y_size, s_screen_height)
	lda window_y,x
	clc
	adc window_y_size,x
	cmp s_screen_height
	bcc +
	lda s_screen_height
+	sta .window_edge
	lda zp_screenrow
	cmp .window_edge
	bcc .wrap_move_to_left_edge ; still inside the window
	; the cursor has passed the bottom edge of the window
	lda window_attributes,x
	and #WIN_SCROLLING
	beq .clamp_to_bottom
	; scroll (.s_scroll* also erases the window's new last line and
	; leaves zp_screenrow on it)
!ifdef TARGET_C128 {
	bit COLS_40_80
	bmi .col80_4
	; 40 columns, use VIC-II screen
	jsr .s_scroll
	jmp .wrap_move_to_left_edge
.col80_4
	jsr .s_scroll_vdc
	jmp .wrap_move_to_left_edge
} else ifdef TARGET_X16 {
	jsr .s_scroll_vera
	jmp .wrap_move_to_left_edge
} else {
	jsr .s_scroll
	jmp .wrap_move_to_left_edge
}
.clamp_to_bottom
	dec zp_screenrow
.wrap_move_to_left_edge
	ldx current_window
	jsr s_window_left_edge
	sta zp_screencolumn
	jsr .update_screenpos
	jmp .printchar_end

s_window_left_edge
	; x = window. Return its left margin's column in a, and in .window_edge.
	lda window_x,x
	clc
	adc window_left_margin,x
	sta .window_edge
	rts

s_window_right_edge
	; x = window. Return the first column past its right margin in a, and in
	; .window_edge. A margin wider than the window leaves no room at all.
	lda window_x,x
	clc
	adc window_x_size,x
	sec
	sbc window_right_margin,x
	bcs +
	lda window_x,x
+	sta .window_edge
	rts

.window_edge !byte 0

s_erase_window
	lda #0
	sta zp_screenrow
-   jsr s_erase_line
	inc zp_screenrow
	lda zp_screenrow
	cmp s_screen_height
	bne -
	lda #0
	sta zp_screenrow
	sta zp_screencolumn
	rts

.update_screenpos
	; set screenpos (current line) using row
	ldx zp_screenrow
	cpx s_current_screenpos_row
	beq .same_row
	; need to recalculate zp_screenline
	stx s_current_screenpos_row
!ifdef TARGET_X16 {
    txa
	sta zp_screenline + 1
	sta zp_colourline + 1
    lda #0
	sta zp_screenline
	sta zp_colourline
} else ifdef TARGET_MEGA65 {
	; calculate zp_screenline = zp_current_screenpos_row * SCREEN_ROW_BYTES
	; Use MEGA65's hardware multiplier
	jsr mega65io
	stx $d770
	lda #0
	sta $d771
	sta $d772
	sta $d773
	sta $d775
	sta $d776
	sta $d777
	lda #SCREEN_ROW_BYTES ; 80, whether that is 80 cells or 40 two-byte cells
	sta $d774
	;
	; add screen offsets
	;
!ifdef Z6_FCM_MODE {
	; The row's offset is the same in screen RAM (from SCREEN_ADDRESS) and in
	; colour RAM (from $ff80000 + FCM_COLOUR_OFFSET, where the 32-bit
	; zp_colourline points -- the offset keeps the screen off the CBDOS bytes).
	; The colour of a cell is its odd byte, the character its even one:
	; biasing the colour pointer by one lets both be written with the same
	; index. A row offset's low byte is a multiple of 32, so it never carries.
	lda $d778
	sta zp_screenline
	sta zp_colourline
	inc zp_colourline
	lda $d779
	and #$0f ; row offsets run to $0f00 on the 80-column screen
	clc
	adc #>FCM_COLOUR_OFFSET
	sta zp_colourline+1
	sec
	sbc #>FCM_COLOUR_OFFSET ; back to the bare row offset for the screen line
	clc
	adc #>SCREEN_ADDRESS
	sta zp_screenline+1
} else {
	lda $d778
	sta zp_screenline
	sta zp_colourline
	lda $d779
	and #$07
	clc
	adc #>SCREEN_ADDRESS ; add screen start ($0400 for C64)
	sta zp_screenline+1
	clc
	adc #>COLOUR_ADDRESS_DIFF ; add colour start ($d800 for C64)
	sta zp_colourline+1
}
} else {
	; calculate zp_screenline = zp_current_screenpos_row * s_screen_width
	stx product + 1
	txa
	asl ; 2x
	asl ; 4x
	adc product + 1 ; 5x
	asl ; 10x
	asl
	ldx #0
	stx product + 1
	rol product + 1 ; 20x
	asl
	rol product + 1 ; 40x
!ifdef TARGET_C128 {
	bit COLS_40_80
	bpl ++
	asl
	rol product + 1 ; 80x
++
}
	sta zp_screenline
	sta zp_colourline
	lda product + 1
	;
	; add screen offsets
	;
	adc #>SCREEN_ADDRESS ; add screen start ($0400 for C64)
	sta zp_screenline +1
	adc #>COLOUR_ADDRESS_DIFF ; add colour start ($d800 for C64)
	sta zp_colourline + 1
}
.same_row
	rts

!ifdef TARGET_C128 {
.s_scroll_vdc
	; Scroll the current window's rectangle up one line and erase the window's
	; new last line, the VDC equivalent of .s_scroll. Leaves zp_screenrow on
	; that last line. The rows and the blanking are the same window-local ones
	; the scroll_window opcode uses, so only the row copy (.vdc_copy_row) is
	; VDC-specific. (This used to scroll the whole screen from window 0's top
	; line down to the bottom of the screen, which smeared every window that
	; did not reach it, and it only ran at all once the cursor had passed the
	; bottom of the *screen* rather than of the window.)
	jsr .calc_window_rect
!ifdef SCROLLBACK {
	inc s_scrolled_lines
}
	ldx scroll_delay
	beq .done_delaying_vdc
-	txa
	pha
	jsr wait_an_interval
	pla
	tax
	dex
	bne -
.done_delaying_vdc
	jsr .sw_up_one ; copies the window's rows up, blanks its new last line
	ldy .win_left
	sty zp_screencolumn
	rts

.vdc_copy_row
	; Copy the window's columns from row .sw_src to row .sw_dst. The VDC's
	; screen is not in the CPU's address space, but the chip has a blitter:
	; with the copy bit of the vertical scroll register set, writing the byte
	; count to VDC_COUNT copies that many bytes from the copy source address
	; to the current address. So a row is one register write, rather than 80
	; read/write round trips through the data port.
	lda .win_right_excl
	sec
	sbc .win_left
	beq +  ; a window with no columns has nothing to copy
	sta .vdc_count ; a count of 0 would mean 256 bytes, hence the check above
	ldx #VDC_VSCROLL
	jsr VDCReadReg
	ora #$80 ; the blitter copies rather than fills
	jsr VDCWriteReg
	lda #$00 ; the characters, at $0000
	jsr .vdc_copy_block
!ifdef COLOURFUL_LOWER_WIN {
	lda #$08 ; and their attributes, at $0800
	jsr .vdc_copy_block
}
+	rts

.vdc_copy_block
	; a = the high byte of the VDC region's base: $00 for the characters,
	; $08 for the attributes.
	sta .vdc_base
	lda .sw_src
	jsr .vdc_row_addr
	jsr VDCSetCopySourceAddress
	lda .sw_dst
	jsr .vdc_row_addr
	jsr VDCSetAddress
	lda .vdc_count
	ldx #VDC_COUNT
	jmp VDCWriteReg ; writing the count is what runs the copy

.vdc_row_addr
	; a = row. Return the VDC address of the window's first column on that row
	; in a (low) and y (high): base + row * screen width + left column.
	sta .vdc_row
	lda s_screen_width
	sta multiplier
	lda #0
	sta multiplier + 1
	lda .vdc_row
	jsr mult8
	lda product
	clc
	adc .win_left
	tax
	lda product + 1
	adc .vdc_base
	tay
	txa
	rts

.vdc_count !byte 0
.vdc_base  !byte 0
.vdc_row   !byte 0
}

!ifdef SCROLLBACK {
s_reset_scrolled_lines
	pha
	lda #0
	sta s_scrolled_lines
	pla
	rts

s_scrolled_lines !byte 0
}

.s_scroll
	; Scroll the current window's rectangle up one line and erase the
	; window's new last line. Leaves zp_screenrow on that last line.
	jsr .calc_window_rect
!ifdef SCROLLBACK {
	inc s_scrolled_lines
}
	ldx .win_top ; the window's first line is the first line to overwrite
	inx
	stx zp_screenrow
	jsr .update_screenpos
	lda zp_screenline
	sta .scroll_load_screen + 1
	lda zp_screenline + 1
	sta .scroll_load_screen + 2
!ifdef COLOURFUL_LOWER_WIN {
!ifdef Z6_FCM_MODE {
	lda zp_colourline
	sta zp_colour_src
	lda zp_colourline + 1
	sta zp_colour_src + 1
} else {
	lda zp_colourline
	sta .scroll_load_colour + 1
	lda zp_colourline + 1
	sta .scroll_load_colour + 2
}
}
	dec zp_screenrow
	jsr .update_screenpos
	lda zp_screenline
	sta .scroll_store_screen + 1
	lda zp_screenline + 1
	sta .scroll_store_screen + 2
!ifdef COLOURFUL_LOWER_WIN {
!ifdef Z6_FCM_MODE {
	lda zp_colourline
	sta zp_colour_dst
	lda zp_colourline + 1
	sta zp_colour_dst + 1
} else {
	lda zp_colourline
	sta .scroll_store_colour + 1
	lda zp_colourline + 1
	sta .scroll_store_colour + 2
}
}
!ifdef SMOOTHSCROLL {
	lda smoothscrolling
	beq +
	jsr smoothscroll
+
}

!ifndef TARGET_X16 {
; ----------- Delay for slower scrolling

	ldx scroll_delay
	beq .done_delaying
!ifdef TARGET_MEGA65 {
	clc ; Carry is expected to be clear when entering the following loop
	lda #rasterline_for_scroll
} else {
	lda .win_top ; how many top lines to protect
	asl
	asl
	asl ; Multiplied by 8 (There are 8 raster lines per row)
	adc #rasterline_for_scroll
}
	sei
--
	cmp reg_rasterline
	bne --
!ifndef TARGET_MEGA65 {
!ifdef TARGET_PLUS4 {
	pha
	lda reg_rasterline_highbit
	lsr
	pla
	bcs --
} else {
	bit reg_rasterline_highbit
	bmi --
}
}
	adc #0 ; Carry is always set, so this adds 1
;	lda #rasterline_for_scroll + 1
-	cmp reg_rasterline
	bne -
	sbc #1 ; Carry is set, so this subtracts 1
	dex
	bne --
	cli
.done_delaying
}
!ifdef TARGET_MEGA65 {
!ifndef Z6_FCM_MODE {
	jsr colour2k
}
}

	; number of lines to move up = .win_bottom - .win_top
	lda .win_bottom
	sec
	sbc .win_top
	tax
	beq .done_scrolling
	clc
;	sei
-
!ifdef Z6_FCM_MODE {
	lda .win_left ; two bytes per cell
	asl
	tay
} else {
	ldy .win_left
}
--
.scroll_load_screen
	lda $8000,y ; This address is modified above
.scroll_store_screen
	sta $8000,y ; This address is modified above
!ifdef COLOURFUL_LOWER_WIN {
!ifdef Z6_FCM_MODE {
	phy
	plz
	lda [zp_colour_src],z
	sta [zp_colour_dst],z
} else {
.scroll_load_colour
	lda $8000,y ; This address is modified above
.scroll_store_colour
	sta $8000,y ; This address is modified above
}
}
	iny
!ifdef Z6_FCM_MODE {
	cpy .win_right_excl_bytes
} else {
	cpy .win_right_excl
}
	bcc --
	clc ; the compare above leaves carry set
	dex
	beq .done_scrolling
!ifdef Z6_FCM_MODE {
	; Step all four row pointers. The screen ones are self-modified absolute
	; addresses; the colour ones are the 32-bit zero page pointers, whose
	; low bytes differ from the screen ones by the +1 bias, so each is
	; stepped on its own. Carry is clear here and after every + below.
	lda .scroll_store_screen + 1
	adc #SCREEN_ROW_BYTES ; a row is 40 cells of two bytes
	sta .scroll_store_screen + 1
	bcc +
	clc
	inc .scroll_store_screen + 2
+
	lda zp_colour_dst
	adc #SCREEN_ROW_BYTES
	sta zp_colour_dst
	bcc +
	clc
	inc zp_colour_dst + 1
+
	lda .scroll_load_screen + 1
	adc #SCREEN_ROW_BYTES
	sta .scroll_load_screen + 1
	bcc +
	clc
	inc .scroll_load_screen + 2
+
	lda zp_colour_src
	adc #SCREEN_ROW_BYTES
	sta zp_colour_src
	bcc -
	clc
	inc zp_colour_src + 1
	bne - ; Always branch
} else {
	lda .scroll_store_screen + 1
;	clc
	adc s_screen_width
	sta .scroll_store_screen + 1
!ifdef COLOURFUL_LOWER_WIN {
	sta .scroll_store_colour + 1
}
	bcc +
	clc
	inc .scroll_store_screen + 2
!ifdef COLOURFUL_LOWER_WIN {
	inc .scroll_store_colour + 2
}
+
	lda .scroll_load_screen + 1
	adc s_screen_width
	sta .scroll_load_screen + 1
!ifdef COLOURFUL_LOWER_WIN {
	sta .scroll_load_colour + 1
}
	bcc -
	clc
	inc .scroll_load_screen + 2
!ifdef COLOURFUL_LOWER_WIN {
	inc .scroll_load_colour + 2
}
	bne - ; Always branch
}

.done_scrolling
;	cli
;	dec reg_backgroundcolour
;	inc reg_backgroundcolour

!ifdef TARGET_MEGA65 {
!ifndef Z6_FCM_MODE {
	jsr colour1k
}
}
!ifdef SMOOTHSCROLL {
	+done_smoothscroll
}
	; erase the window's new last line (only the window's columns)
	lda .win_bottom
	sta zp_screenrow
	lda #$ff
	sta s_current_screenpos_row ; force recalculation
	jsr .update_screenpos
	ldy .win_left
	sty zp_screencolumn
	; s_delete_cursor clobbers y, and under FCM it leaves a byte offset in it
-	jsr s_delete_cursor ; writes a space at the current column
	inc zp_screencolumn
	ldy zp_screencolumn
	cpy .win_right_excl
	bcc -
	ldy .win_left
	sty zp_screencolumn
	rts

.calc_window_rect
	; work out the current window's rectangle on screen, clamped to it
	; .win_left/.win_top are inclusive, .win_right_excl is exclusive,
	; .win_bottom is the window's last line
	ldx current_window
.calc_window_rect_x
	; same, for the window in x. x is preserved.
	lda window_x,x
	sta .win_left
	clc
	adc window_x_size,x
	cmp s_screen_width
	bcc +
	lda s_screen_width
+	sta .win_right_excl
!ifdef Z6_FCM_MODE {
	asl
	sta .win_right_excl_bytes ; two bytes per cell
}
	lda window_y,x
	sta .win_top
	clc
	adc window_y_size,x
	cmp s_screen_height
	bcc +
	lda s_screen_height
+	sec
	sbc #1
	sta .win_bottom
	rts

.win_left       !byte 0
.win_right_excl !byte 0
!ifdef Z6_FCM_MODE {
.win_right_excl_bytes !byte 0
}
.win_top        !byte 0
.win_bottom     !byte 0

s_scroll_window
	; Scroll a window's rectangle by whole lines, blanking the lines that are
	; scrolled into view. This serves the scroll_window opcode, which has
	; nothing to do with the window's scrolling attribute, nor with the
	; scrolling that happens when text reaches a window's bottom edge. It is
	; therefore free of the scroll delay, smooth scrolling and scrollback that
	; .s_scroll has to care about.
	; input: x = window, a = number of lines, carry set to scroll down
	stx .sw_window
	sta .sw_count
	lda #0
	rol ; the direction was passed in the carry
	sta .sw_downwards
	lda .sw_count
	beq .sw_return
	jsr .calc_window_rect_x
	; Scrolling a window by its own height blanks it, and scrolling it by
	; more than that cannot blank it any further, so clamp the count. That
	; also keeps the row counters inside the window.
	lda .win_bottom
	sec
	sbc .win_top
	clc
	adc #1 ; the window's height in lines
	cmp .sw_count
	bcs +
	sta .sw_count
+
!ifdef Z6_ECM_MODE {
	; blank in the scrolled window's background colour, not the current one
	ldx .sw_window
	jsr ecm_set_bits_for_window
}
-	lda .sw_downwards
	beq +
	jsr .sw_down_one
	jmp ++
+	jsr .sw_up_one
++	dec .sw_count
	bne -
!ifdef Z6_ECM_MODE {
	jsr ecm_update_bits
}
.sw_return
	rts

.sw_up_one
	; every line takes the contents of the one below it; the last goes blank
	lda .win_top
	sta .sw_dst
	clc
	adc #1
	sta .sw_src
-	lda .sw_dst
	cmp .win_bottom
	beq +
	jsr .sw_copy_row
	inc .sw_src
	inc .sw_dst
	jmp -
+	lda .win_bottom
	jmp .sw_blank_row

.sw_down_one
	; every line takes the contents of the one above it; the first goes blank
	lda .win_bottom
	sta .sw_dst
	sec
	sbc #1
	sta .sw_src
-	lda .sw_dst
	cmp .win_top
	beq +
	jsr .sw_copy_row
	dec .sw_src
	dec .sw_dst
	jmp -
+	lda .win_top
	jmp .sw_blank_row

.sw_copy_row
	; copy the window's columns from row .sw_src to row .sw_dst
!ifdef TARGET_X16 {
	jmp .vera_copy_row ; the VERA screen is not in the CPU's address space
} else {
!ifdef TARGET_C128 {
	bit COLS_40_80
	bpl + ; 40 columns: the VIC-II screen, which the CPU can address
	jmp .vdc_copy_row ; 80 columns: the VDC's, which it cannot
+
}
	lda .sw_src
	jsr .sw_point_at_row
	lda zp_screenline
	sta .sw_load_screen + 1
	lda zp_screenline + 1
	sta .sw_load_screen + 2
!ifdef COLOURFUL_LOWER_WIN {
!ifdef Z6_FCM_MODE {
	lda zp_colourline
	sta zp_colour_src
	lda zp_colourline + 1
	sta zp_colour_src + 1
} else {
	lda zp_colourline
	sta .sw_load_colour + 1
	lda zp_colourline + 1
	sta .sw_load_colour + 2
}
}
	lda .sw_dst
	jsr .sw_point_at_row
	lda zp_screenline
	sta .sw_store_screen + 1
	lda zp_screenline + 1
	sta .sw_store_screen + 2
!ifdef COLOURFUL_LOWER_WIN {
!ifdef Z6_FCM_MODE {
	lda zp_colourline
	sta zp_colour_dst
	lda zp_colourline + 1
	sta zp_colour_dst + 1
} else {
	lda zp_colourline
	sta .sw_store_colour + 1
	lda zp_colourline + 1
	sta .sw_store_colour + 2
}
}
!ifdef TARGET_MEGA65 {
!ifndef Z6_FCM_MODE {
	jsr colour2k
}
}
!ifdef Z6_FCM_MODE {
	; two bytes per cell, so copy the window's columns byte by byte. The colour
	; pointer is biased by one, so its last byte is the flags byte of the first
	; cell past the window, which is zero and is copied onto itself.
	lda .win_left
	asl
	tay
} else {
	ldy .win_left
}
-
.sw_load_screen
	lda $8000,y ; these addresses are modified above
.sw_store_screen
	sta $8000,y
!ifdef COLOURFUL_LOWER_WIN {
!ifdef Z6_FCM_MODE {
	phy
	plz
	lda [zp_colour_src],z
	sta [zp_colour_dst],z
} else {
.sw_load_colour
	lda $8000,y
.sw_store_colour
	sta $8000,y
}
}
	iny
!ifdef Z6_FCM_MODE {
	cpy .win_right_excl_bytes
} else {
	cpy .win_right_excl
}
	bcc -
!ifdef TARGET_MEGA65 {
!ifndef Z6_FCM_MODE {
	jsr colour1k
}
}
	rts
} ; not TARGET_X16

.sw_blank_row
	; a = row. Blank the window's columns on it.
	jsr .sw_point_at_row
	ldy .win_left
	sty zp_screencolumn
	; s_delete_cursor clobbers y, and under FCM it leaves a byte offset in it
-	jsr s_delete_cursor ; writes a space at the current column
	inc zp_screencolumn
	ldy zp_screencolumn
	cpy .win_right_excl
	bcc -
	rts

.sw_point_at_row
	; a = row. Point zp_screenline/zp_colourline at it.
	sta zp_screenrow
	lda #$ff
	sta s_current_screenpos_row ; force .update_screenpos to recalculate
	jmp .update_screenpos

.sw_window    !byte 0
.sw_count     !byte 0
.sw_downwards !byte 0
.sw_src       !byte 0
.sw_dst       !byte 0

s_erase_line
	; registers: a,x,y
	lda zp_screenrow
	cmp s_screen_height
	bcc +
	rts ; Illegal row, just ignore
+	lda #0
	sta zp_screencolumn
	jsr .update_screenpos
	ldy #0
.erase_line_from_any_col	
!ifdef TARGET_C128 {
	bit COLS_40_80
	bmi .col80_5
	; 40 columns, use VIC-II screen
	lda #$20
	ora s_colour_swap ; swapped colours erase to a field of the glyph colour
	tax
-	cpy s_screen_width
	bcs .done_erasing
	txa
	sta (zp_screenline),y
	+clear_cell_high_byte
	lda s_colour
	sta (zp_colourline),y
	iny
	bne - ; Always branch
	jmp .done_erasing	
.col80_5
	; erase line in VDC
	tya
	clc 
	adc zp_screenline
	pha
	lda zp_screenline + 1
	adc #$00
	sec
	sbc #$04
	sta .stored_a
	ldx #VDC_DATA_HI
	jsr VDCWriteReg
	pla
	pha
	ldx #VDC_DATA_LO
	jsr VDCWriteReg
	lda #$20
	ora s_colour_swap ; swapped colours erase to a field of the glyph colour

	ldx #VDC_DATA
	jsr VDCWriteReg
	; We have written a space character to the first position
	; Now fill the rest of the line.
	lda #0 ; Set to Fill mode
	ldx #VDC_VSCROLL
	jsr VDCWriteReg
	sty .stored_x_or_y
	lda #79
	sec
	sbc .stored_x_or_y
	beq +
	ldx #VDC_COUNT
	jsr VDCWriteReg
+

	lda .stored_a
	clc
	adc #$08 ; Colour RAM starts at $0800, while screen RAM starts at $0000
	ldx #VDC_DATA_HI
	jsr VDCWriteReg
	pla
	ldx #VDC_DATA_LO
	jsr VDCWriteReg

	ldx s_colour
	lda vdc_vic_colours,x
	ora #$80 ; lower-case
	ldx #VDC_DATA
	jsr VDCWriteReg
	; We have written the first byte to colour memory
	; Now fill the rest of the line.
	lda #0 ; Set to Fill mode
	ldx #VDC_VSCROLL
	jsr VDCWriteReg
	sty .stored_x_or_y
	lda #79
	sec
	sbc .stored_x_or_y
	beq +
	ldx #VDC_COUNT
	jsr VDCWriteReg
+


	; tya
	; pha
; -	cpy s_screen_width
	; bcs +
	; lda #$20
	; jsr VDCPrintChar
	; iny
	; bne -
	; also reset attributes/colours
;+	pla
;	tay

; -	cpy s_screen_width
	; bcs .done_erasing
	; lda s_colour
	; jsr VDCPrintColour
	; iny
	; bne -
} else {

; set colour
!ifdef TARGET_MEGA65 {
!ifndef Z6_FCM_MODE {
	jsr colour2k
}
}
!ifdef TARGET_X16 {
	jsr .convert_screenline_y_to_vera_address
}
!ifdef Z6_FCM_MODE {
	; y arrives as a column; erase from there to the end of the row, two bytes
	; a cell. The colour pointer is biased by one, so the same index does both.
	tya
	asl
	tay
-	cpy #SCREEN_ROW_BYTES
} else {
-	cpy s_screen_width
}
	bcs .done_erasing
	; set character
	lda #$20
!ifdef Z6_ECM_MODE {
	ora ecm_bits ; keep the window's background colour
} else {
	ora s_colour_swap ; swapped colours erase to a field of the glyph colour
}
!ifdef TARGET_X16 {
    sta VERA_data0
} else {
	sta (zp_screenline),y
	+clear_cell_high_byte
}
!ifdef TARGET_PLUS4 {
	ldx s_colour
	lda plus4_vic_colours,x
} else {
	lda s_colour
}
!ifdef TARGET_X16 {
	ora .vera_background
    sta VERA_data0
} else {
!ifdef Z6_FCM_MODE {
	+sta_colour_ram
} else {
	sta (zp_colourline),y
}
}
	iny
!ifdef Z6_FCM_MODE {
	iny ; two bytes per cell
}
	bne -
}
.done_erasing
!ifdef TARGET_MEGA65 {
!ifndef Z6_FCM_MODE {
	jsr colour1k
}
}

 	rts
s_erase_line_from_cursor
	jsr .update_screenpos
	ldy zp_screencolumn
	jmp .erase_line_from_any_col

s_cursorswitch !byte 0
cursor_hidden !byte 0 ; v6 set_cursor -1/-2: the game asked for no cursor
!ifdef USE_BLINKING_CURSOR {
s_cursormode !byte 0
}
turn_on_cursor
!ifdef USE_BLINKING_CURSOR {
    jsr reset_cursor_blink
    lda #CURSORCHAR
    sta cursor_character
}
    lda #1
    sta s_cursorswitch
    bne update_cursor ; always branch

turn_off_cursor
    lda #0
    sta s_cursorswitch

update_cursor
	; when the game has hidden the cursor, neither draw it nor "delete" it:
	; the delete writes a space, which would eat the character under the
	; cursor parking spot (Shogun parks it on the selected menu item)
	lda cursor_hidden
	beq +
	rts
+
    sty object_temp
	jsr .update_screenpos
    ldy zp_screencolumn
	bmi .skip_cursor_update
	cpy s_screen_width
	bcs .skip_cursor_update
    lda s_cursorswitch
    bne +++
    ; no cursor
    jsr s_delete_cursor
    ldy object_temp
    rts
+++ ; cursor
!ifdef TARGET_C128 {
	bit COLS_40_80
	bpl +
    ; 80 columns
    lda cursor_character
    jsr VDCPrintChar
    lda current_cursor_colour
    jsr VDCPrintColour
    jmp .vdc_printed_char_and_colour
+   ; 40 columns
} else ifdef TARGET_X16 {
	lda s_colour
	pha
	lda current_cursor_colour
	and #15
	jsr VERASetForegroundColour
	lda cursor_character
	jsr VERAPrintChar
	pla
	jsr VERASetForegroundColour
	; lda current_cursor_colour
	; jsr VERAPrintColourAfterChar
}
!ifndef TARGET_X16 {
!ifdef Z6_FCM_MODE {
    lda zp_screencolumn ; a cell is two bytes wide
    asl
    tay
}
    lda cursor_character
    sta (zp_screenline),y
    +clear_cell_high_byte
    lda current_cursor_colour
!ifdef TARGET_PLUS4 {
    stx object_temp + 1
    tax
    lda plus4_vic_colours,x
    ldx object_temp + 1
}
!ifdef Z6_FCM_MODE {
    +sta_colour_ram
} else {
!ifdef TARGET_MEGA65 {
    jsr colour2k
}
    sta (zp_colourline),y
!ifdef TARGET_MEGA65 {
    jsr colour1k
}
}
}

.vdc_printed_char_and_colour

.skip_cursor_update
    ldy object_temp
    rts

write_default_colours_to_header
	; On exit:
	; a = fg colour (2-9)
	; x = darkmode
	; y = destroyed
	ldx darkmode
	lda bgcol,x
	ldy #header_default_bg_colour
	jsr write_header_byte
	lda fgcol,x
	ldy #header_default_fg_colour
	jmp write_header_byte

!ifndef NODARKMODE {

.new_bg 		= z_temp + 5 ; New background colour, adapted to target platform
.new_fg_c64		= z_temp + 6 ; New foreground colour, as C64 colour
.new_fg			= z_temp + 7 ; New foreground colour, adapted to target platform
.new_input		= z_temp + 8 ; New input colour, adapted to target platform
.old_input		= z_temp + 9 ; Old input colour, adapted to target platform
.colour_ram_pointer = z_temp + 10 ; (2 bytes) Pointer into colour RAM

toggle_darkmode

!ifdef TARGET_X16 {
	ldy #0
	sty zp_screenline + 1
	jsr .convert_screenline_y_to_vera_address
	lda #0
	sta VERA_ctrl
}

!ifdef Z5PLUS {
	; We will need the old fg colour later, to check which characters have the default colour
	ldx darkmode ; previous darkmode value (0 or 1)
	ldy fgcol,x
	lda zcolours,y
!ifdef TARGET_C128 {
	bit COLS_40_80
	bpl +
	; 80 columns mode selected
	tay
	lda vdc_vic_colours,y
+
}
!ifdef TARGET_PLUS4 {
	tay
	lda plus4_vic_colours,y
}
	sta .old_input ; old fg colour TODO - was +9, but comment says old fg?
} else { ; This is z3 or z4
!ifdef USE_INPUTCOL {

	; We will need the old input colour later, to check which characters are input text
	ldx darkmode ; previous darkmode value (0 or 1)
	ldy inputcol,x
	lda zcolours,y
!ifdef TARGET_C128 {
	bit COLS_40_80
	bpl +
	; 80 columns mode selected
	tay
	lda vdc_vic_colours,y
+
}
!ifdef TARGET_PLUS4 {
	tay
	lda plus4_vic_colours,y
}
	sta .old_input ; old input colour

	; If the mode we switch *from* has inputcol = fgcol, make sure inputcol is never matched
	lda inputcol,x
	cmp fgcol,x
	bne +
	inc .old_input
+
} ; USE_INPUTCOL

} ; else (not Z5PLUS)


; Toggle darkmode
	lda darkmode
	eor #1
	sta darkmode
	tax
	
!ifdef USE_INPUTCOL {
	ldy inputcol,x
	lda zcolours,y
!ifdef TARGET_C128 {
	bit COLS_40_80
	bpl +
	; 80 columns mode selected
	tay
	lda vdc_vic_colours,y
+
}
!ifdef TARGET_PLUS4 {
	tay
	lda plus4_vic_colours,y
}
	sta .new_input ; new input colour

} ; USE_INPUTCOL	
	
; Write colours to header
	jsr write_default_colours_to_header	
	
; Set fgcolour
;	ldy fgcol,x
	; ldy #header_default_fg_colour
	; jsr write_header_byte
	tay
	lda zcolours,y
	sta .new_fg_c64 ; New foreground colour, as C64 colour 
	jsr s_set_text_colour
!ifdef TARGET_C128 {
	bit COLS_40_80
	bpl +
	; 80 columns mode selected
	tay
	lda vdc_vic_colours,y
+
}
!ifdef TARGET_PLUS4 {
	tay
	lda plus4_vic_colours,y
}
	sta .new_fg ; New foreground colour, transformed for target platform
!ifdef TARGET_MEGA65 {
!ifndef Z6_FCM_MODE {
	jsr colour2k
}
}
; Set cursor colour
	ldy cursorcol,x
	lda .new_fg_c64
	cpy #1
	beq +
	lda zcolours,y
+	sta current_cursor_colour
; Set bgcolour
	ldy bgcol,x
	; ldy #header_default_bg_colour
	; jsr write_header_byte
	; tay
	lda zcolours,y
!ifdef Z5PLUS {
	; We will need the new bg colour later, to check which characters would become invisible if left unchanged
	sta .new_bg ; new background colour
}
	+SetBackgroundColour
; Set border colour 
	ldy bordercol,x
!ifdef BORDER_MAY_FOLLOW_BG {
	beq .store_bordercol
}
!ifdef BORDER_MAY_FOLLOW_FG {
	cpy #1
	bne +
	ldy fgcol,x
+	
}
	lda zcolours,y
.store_bordercol
	+SetBorderColour

	; update colour memory with new colours
!ifndef Z4PLUS {

; For Z3: Set statusline colour
	ldy statuslinecol,x
	lda zcolours,y
!ifdef TARGET_X16 {
	ora .vera_background
} else ifdef TARGET_C128 {
	bit COLS_40_80
	bpl +
	; 80 columns mode selected
	tay
	lda vdc_vic_colours,y
+
}
!ifdef TARGET_PLUS4 {
	tay
	lda plus4_vic_colours,y
}
	ldy s_screen_width_minus_one
-
!ifdef TARGET_X16 {
	ldx VERA_data0 ; Go past character
	sta VERA_data0
;	jsr VERAPrintColourAfterChar
} else ifdef TARGET_C128 {
	bit COLS_40_80
	bmi +
	sta COLOUR_ADDRESS,y
	jmp ++
+
	; 80 columns mode selected
	sty s_stored_y
	pha
	ldy #$08
	lda s_stored_y
	jsr VDCSetAddress
	pla
	ora #$80 ; lower-case
	ldx #VDC_DATA
	jsr VDCWriteReg
	ldy s_stored_y
++
} else {
	sta COLOUR_ADDRESS,y
}
	dey
	bpl -
}

; ---------- CHANGE COLOURS IN MAIN WINDOW (both for Z4+)

!ifdef TARGET_X16 {
	lda s_screen_height_minus_one
	sta zp_screenline + 1
--	ldy #0
	jsr .convert_screenline_y_to_vera_address
-	lda VERA_data0 ; Skip character data
	lda VERA_data0 ; Get colour data
;	sta z_temp + 5 ; Temporary storage
	and #$0f
!ifdef USE_INPUTCOL {
	cmp .old_input ; Old input colour
	bne +
	lda .new_input ; New input colour
	jmp ++
+
	; cmp .old_fg
	; beq +++
	; cmp .new_bg ; New background colour
	; bne ++
; +++
}
	lda .new_fg
++	dec VERA_addr_low
	ora .vera_background
	sta VERA_data0
;	jsr VERAPrintColourAfterChar
	iny
	cpy s_screen_width
	bcc -
	dec zp_screenline + 1
	lda zp_screenline + 1
!ifdef Z4PLUS {
	bpl --
} else {
	bne --
}
} else ifdef Z6_FCM_MODE {
	; A colour cell is two bytes and only the odd one holds a colour -- the
	; even one is VIC-IV attributes and must stay zero -- so sweep the rows
	; through the 32-bit pointer two bytes at a time. This file is only built
	; for z6, so the Z5PLUS comparison logic below is always the one used.
	; zp_colourline is borrowed as the sweep pointer; the forced
	; recalculation at the end puts it back.
	lda #0
	sta zp_colourline
	lda #>FCM_COLOUR_OFFSET
	sta zp_colourline + 1
	ldx #SCREEN_HEIGHT
.tdm_row
	ldz #1 ; the colour byte of the row's first cell
.tdm_cell
	lda [zp_colourline],z
	and #$0f
	cmp .old_input
	beq .tdm_change
	cmp .new_bg ; New background colour
	bne .tdm_dont_change
.tdm_change
	lda .new_fg
	sta [zp_colourline],z
.tdm_dont_change
	inz
	inz
	cpz #SCREEN_ROW_BYTES + 1
	bcc .tdm_cell
	; on to the next row
	lda zp_colourline
	clc
	adc #SCREEN_ROW_BYTES
	sta zp_colourline
	bcc +
	inc zp_colourline + 1
+	dex
	bne .tdm_row
	; zp_colourline no longer matches the cached cursor row
	lda #$ff
	sta s_current_screenpos_row
} else {
	;; Work out how many pages of colour RAM to examine
	ldx s_screen_size + 1
	inx
	ldy #>COLOUR_ADDRESS
	sty .colour_ram_pointer + 1
	ldy #0
	sty .colour_ram_pointer
!ifndef Z4PLUS {
	ldy s_screen_width ; Since we have coloured the statusline separately, skip it now
}
!ifndef Z5PLUS {
;	ldy #0 ; But y is already 0, so we skip this
	lda .new_fg ; For Z3 and Z4 we can just load this value before the loop  
}
.compare
!ifdef TARGET_C128 {
	lda .new_fg  ; too much work to read old colour from VDC
	bit COLS_40_80
	bmi .toggle_80
} ; else {
!ifdef Z5PLUS {
	lda (.colour_ram_pointer),y
!ifndef TARGET_PLUS4 {
	and #$0f
}
	cmp .old_input
	beq .change
	cmp .new_bg ; New background colour
	bne .dont_change
.change	
	lda .new_fg
}

!ifdef USE_INPUTCOL {
	lda (.colour_ram_pointer),y
!ifndef TARGET_PLUS4 {
	and #$0f
}
	cmp .old_input
	bne .change
	lda .new_input
	bne + ; Always branch
.change	
	lda .new_fg
+
}

.toggle_80

; }
!ifdef TARGET_C128 {
	pha
	bit COLS_40_80
	bmi +
	pla
	sta (.colour_ram_pointer),y
	jmp ++
+
	; 80 columns mode selected
	stx s_stored_x
	sty s_stored_y
	lda .colour_ram_pointer + 1
	sec
	sbc #$d0 ; adjust from $d800 (VIC-II) to $0800 (VDC)
	tay
	lda .colour_ram_pointer
	clc
	adc s_stored_y
	bcc +
	iny
+	jsr VDCSetAddress
	pla
	ora #$80 ; lower-case
	ldy s_stored_y
	ldx #VDC_DATA
	jsr VDCWriteReg
	ldx s_stored_x
++
} else {
	sta (.colour_ram_pointer),y
}
.dont_change
	iny
	bne .compare
	inc .colour_ram_pointer + 1
	dex
	bne .compare
!ifdef TARGET_MEGA65 {
	jsr colour1k
}
} ; Not TARGET_X16

!ifdef USE_INPUTCOL {
	; Switch to the new input colour, if input colour is active (we could be at a MORE prompt or in a timed input)
	lda input_colour_active
	beq +
	jsr activate_inputcol
	ldx darkmode
+
}

!ifdef TARGET_X16 {
	ldy zp_screenrow
	sty zp_screenline + 1
}
	jmp update_cursor
} ; ifndef NODARKMODE

!ifdef Z5PLUS {

!ifdef Z6 {
s_track_colours
	; Keep the current window's colour pair (property 11: background in
	; the high nybble, foreground in the low, as z-colour numbers) in step
	; with set_colour's operands -- 0 keeps a colour, 1 means the default.
	; Then decide whether the pair has become a swap of the screen
	; colours: the new foreground is the screen background while the new
	; background is not. If so, switch on reverse-video rendering with the
	; new background as the glyph colour and leave the real colours alone
	; (see s_colour_swap). ECM keeps the tracking for get_wind_prop but
	; never swaps: it has no reversed glyphs.
	ldx current_window
	lda window_colour,x
	sta .stc_pair
	and #$0f
	sta .stc_old_fg
	lda z_operand_value_low_arr
	beq .stc_fg_done	; 0: keep the foreground
	cmp #$ff
	beq .stc_fg_done	; -1: the colour under the cursor -- keep
	cmp #1
	bne +
	lda #FGCOL		; 1: the default
+	and #$0f
	sta .stc_nybble
	lda .stc_pair
	and #$f0
	ora .stc_nybble
	sta .stc_pair
.stc_fg_done
	lda z_operand_value_low_arr + 1
	beq .stc_bg_done	; 0: keep the background
	cmp #$ff
	beq .stc_bg_done	; -1: the colour under the cursor -- keep
	cmp #1
	bne +
	lda #BGCOL		; 1: the default
+	and #$0f
	asl
	asl
	asl
	asl
	sta .stc_nybble
	lda .stc_pair
	and #$0f
	ora .stc_nybble
	sta .stc_pair
.stc_bg_done
	lda .stc_pair
	sta window_colour,x
!ifndef Z6_ECM_MODE {
	; a swap must be exact: the new foreground is the screen background
	; and the new background is the old foreground
	and #$0f
	cmp s_bg_zcolour
	bne .stc_normal		; the foreground is a real colour: no swap
	lda .stc_pair
	lsr
	lsr
	lsr
	lsr
	cmp s_bg_zcolour
	beq .stc_normal		; both are the screen background: not a swap
	cmp .stc_old_fg
	bne .stc_normal		; some other background: a real colour change
	tax
	lda zcolours,x
	jsr s_set_text_colour	; the field takes the requested background
	lda #$80
	sta s_colour_swap
	rts
.stc_normal
	lda #0
	sta s_colour_swap
	; the background is about to be applied for real: remember it
	lda z_operand_value_low_arr + 1
	beq +
	lda .stc_pair
	lsr
	lsr
	lsr
	lsr
	sta s_bg_zcolour
+
}
	rts
.stc_pair	!byte 0
.stc_nybble	!byte 0
.stc_old_fg	!byte 0
}

z_ins_set_colour
	; set_colour foreground background [window]
	; (in ECM mode the background is set per window, otherwise the window
	; operand is not used in Ozmoo)
	jsr printchar_flush

!ifdef Z6 {
	jsr s_track_colours	; the window's colour pair (property 11)
!ifndef Z6_ECM_MODE {
	lda s_colour_swap
	beq +
	rts	; swap mode: reverse video does the work, the colours stay put
+
}
}

; Load y with bordercol (needed later)
	ldx darkmode
	ldy bordercol,x

; Set background colour
	ldx z_operand_value_low_arr + 1
	beq .current_background
!ifdef Z6 {
	cpx #$ff
	beq .current_background	; -1: the colour under the cursor -- keep
}
	lda zcolours,x
	bpl +
	sty zp_temp
	ldy #header_default_bg_colour - 1
	jsr read_header_word
	ldy zp_temp
	lda zcolours,x
+
!ifdef Z6_ECM_MODE {
	; give the window its own background register
	sty zp_temp
	ldx current_window
	ldy z_operand_count
	cpy #3
	bcc +
	ldx z_operand_value_low_arr + 2
	cpx #8
	bcc +
	ldx current_window ; window -3/-2/-1 (and anything odd): use the current one
+	jsr ecm_set_window_bg
	ldy zp_temp
	; the border follows background register 0 only
	ldx current_window
	lda window_bg_index,x
	bne .current_background
	lda ecm_bg_colours
} else {
	+SetBackgroundColour
}
; Also set bordercolour to same as background colour, if bordercolour is set to the magic value 0
	cpy #0
	bne .current_background
	+SetBorderColour
.current_background

; Set foreground colour
	ldx z_operand_value_low_arr
	beq .current_foreground
!ifdef Z6 {
	cpx #$ff
	beq .current_foreground	; -1: the colour under the cursor -- keep
}
	lda zcolours,x
	bpl + ; Branch unless it's the special value $ff, which means "default colour"
	sty zp_temp
	ldy #header_default_fg_colour - 1
	jsr read_header_word
	ldy zp_temp
	lda zcolours,x
+
; Also set bordercolour to same as foreground colour, if bordercolour is set to the magic value 1
	cpy #1
	bne +
	+SetBorderColour
+
	jsr s_set_text_colour ; change foreground colour
.current_foreground

; Set cursor colour
	lda s_colour
	ldx darkmode
	ldy cursorcol,x
	cpy #1
	beq +
	lda zcolours,y
+	sta current_cursor_colour

	rts
}

!ifdef TESTSCREEN {

.testtext
	;!pet 147,2,"hello",3,"johan",0
	!pet 2, 5,147,18,"Status Line 123         ",146,13    ; white REV
	!pet 3, 28,"resx",20,"t aA@! ",18,"Test aA@!",146,13  ; red
	!pet 155,"third",20,13                                ; light gray
	!pet "fourth line",13
	!pet 13,13,13,13,13,13
	!pet 13,13,13,13,13,13,13
	!pet 13,13,13,13,13,13,13
	!pet "last line",1
	!pet "aaaaaaaaabbbbbbbbbbbcccccccccc",1
	!pet "d",1 ; last char on screen
	!pet "efg",1 ; should scroll here and put efg on new line
	!pet 13,"h",1; should scroll again and f is on new line
	!pet 0

testscreen
	jsr init_screen_colours
!ifdef TARGET_X16 {
    lda #14 
    jsr $ffd2
} else ifdef TARGET_PLUS4 {
	lda #212 ; 212 upper/lower, 208 = upper/special
} else {
	lda #23 ; 23 upper/lower, 21 = upper/special (22/20 also ok)
}
	sta reg_screen_char_mode
	jsr s_init
    lda #3
    +SetBackgroundColour
	lda #1
	sta zp_screenrow
    jsr s_erase_line
    ;rts
	lda s_screen_height
	sec
	sbc #1
	sta window_y_size ; total number of lines in window 0
	lda #1
	sta window_y ; window 0 starts below the 1-line status window
	sta window_y_size + 1
	lda #0
	sta window_y + 1
	ldx #0
-   lda .testtext,x
	bne +
	rts
+   cmp #2
	bne +
	; use upper window
	lda #1
	sta current_window
	jmp ++
+   cmp #3
	bne +
	; use lower window
	lda #0
	sta current_window
	jmp ++
+   cmp #1
	bne +
	txa
	pha
--  jsr kernal_getchar
	beq --
	pla
	tax
	bne ++
	; NOTE: s_printchar no longer recognizes the colour codes, so the
	; colours will not change. But rev on/off still works
+   jsr s_printchar
++  inx
	bne -
}
}

