; A background colour per window on the MEGA65 full colour screen.
;
; A v6 window owns a colour PAIR (property 11), but the VIC-IV in FCM has one
; global background register: an ordinary text cell is a ROM glyph drawn in the
; colour RAM's foreground colour on $d021, and there is no per-cell background
; byte to write (unlike VERA's colour nybble, which is why the X16 needs none of
; this). The reverse-video swap (s_colour_swap) fakes one for the exact swap of
; the screen's pair - which is all Infocom's four games ever ask for - and
; nothing else: a window asking for black on cyan while the screen is white on
; blue used to print black on BLUE.
;
; Such a cell is drawn as a full colour TILE instead of a ROM glyph. The tile is
; the glyph's own 8x8 bitmap with
;   - a set pixel written as palette index 255, which the VIC-IV takes from the
;     cell's own colour RAM byte - the ink Ozmoo writes there anyway, so one
;     tile serves every foreground colour, and
;   - a clear pixel written as 240 + the window's background colour, out of the
;     text-ink palette bank (entries 240-255 duplicate the sixteen text
;     colours; see init_mega65).
; The C64 font holds the reversed glyphs as a second copy at code + $80, so a
; reversed cell in a coloured window comes out as reverse video in that window's
; own two colours, with no special case here.
;
; The tiles live in a store of their own in bank 1, so nothing here competes
; with the picture engine's store in banks 4 and 5 (or bank 1 in a build without
; pictures - FCM_TILE_STORE is $10000 there, below this). They are baked on
; demand, one per (glyph, background), and organised as FCM_TEXT_SLOTS blocks of
; FCM_TEXT_GLYPHS: a slot is claimed by a background colour the first time a
; window with that background prints, and the whole store is dropped when the
; screen is cleared, which is the only moment no cell can still be showing one.
; Past FCM_TEXT_SLOTS backgrounds on one screen the extra windows degrade to
; ordinary glyphs on the screen background - the pre-August-2026 behaviour.
;
; Not baked, and so left on the screen background: a reversed glyph (code $80
; and up, which is the whole second half of the font and would double the
; store), and a background of hardware colour 15, whose palette index would be
; the 255 that means "take the colour RAM byte".

!ifdef Z6_FCM_WINDOW_BG {

FCM_TEXT_SLOTS   = 2			; distinct window backgrounds at once
FCM_TEXT_GLYPHS  = 128			; screen codes $00-$7f; $80+ are the reversed half
FCM_TEXT_BITMAP  = FCM_TEXT_GLYPHS / 8

; The slot the CURRENT window's cells are drawn on, $ff for "an ordinary glyph
; on the screen background". Recomputed whenever the window or its colours
; change (fcm_update_paper), and pointed at another window for the length of an
; erase_window that names one that is not current.
fcm_paper_slot	!byte $ff
; The hardware background colour each slot holds, $ff = free.
fcm_slot_paper	!fill FCM_TEXT_SLOTS, $ff
; Each slot's first tile, so a tile index is slot base + glyph.
fcm_slot_base	!byte 0, FCM_TEXT_GLYPHS
; One bit per glyph per slot: has this tile been baked yet.
fcm_slot_baked	!fill FCM_TEXT_SLOTS * FCM_TEXT_BITMAP, 0

fcm_write_cell_high
	; The +clear_cell_high_byte macro, which every text write site calls right
	; after storing the character, so this is the one hook the whole screen
	; layer needs.
	; in:  a = the screen code just stored, y = 2 * column (the cell's even byte
	;      in the row), zp_screenline -> the row.
	; out: the cell's odd (tile select) byte written - zero for an ordinary
	;      glyph, or the tile code's high byte, in which case the even byte is
	;      rewritten with the tile code's low byte. x and y are preserved; a is
	;      dead at every call site.
	ldx fcm_paper_slot
	bmi .fw_plain			; $ff: the window prints on the screen background
	cmp #FCM_TEXT_GLYPHS
	bcs .fw_plain			; a reversed glyph: not baked
	phx
	sta .fw_glyph
	stx .fw_slot
	sty .fw_yoff
	clc						; the tile index, which is also the code's low byte:
	adc fcm_slot_base,x		; the store is 256 tiles, so the high byte is fixed
	sta .fw_code
	jsr .fw_bake			; make sure this (glyph, background) tile exists
	ldy .fw_yoff
	lda .fw_code
	sta (zp_screenline),y
	iny
	lda #FCM_TEXT_TILE_CODE_HI
	sta (zp_screenline),y
	dey
	plx
	rts
.fw_plain
	iny
	lda #0
	sta (zp_screenline),y
	dey
	rts

.fw_bake
	; Bake the tile for glyph .fw_glyph (tile .fw_code) on slot .fw_slot, unless
	; it is baked already. Clobbers a/x/y/z and zp_fcm_tile.
	lda .fw_glyph
	lsr
	lsr
	lsr						; the glyph's byte in the slot's bitmap
	sta .fw_bit
	lda .fw_slot
	asl
	asl
	asl
	asl						; * FCM_TEXT_BITMAP (16)
	clc
	adc .fw_bit
	tax
	lda .fw_glyph
	and #7
	tay
	lda .fw_bitmask,y
	sta .fw_bit
	and fcm_slot_baked,x
	beq +
	rts						; already baked
+	lda fcm_slot_baked,x
	ora .fw_bit
	sta fcm_slot_baked,x

	; the paper: the slot's colour in the text-ink palette bank
	ldx .fw_slot
	lda fcm_slot_paper,x
	clc
	adc #240
	sta .fw_paper

	; read the glyph's eight ROM font bytes. FCM_CHARSET is a linear address, so
	; a 32-bit pointer reads exactly the bytes the VIC-IV fetches.
	lda .fw_glyph
	sta zp_fcm_tile
	lda #0
	sta zp_fcm_tile + 1
	asl zp_fcm_tile			; glyph * 8
	rol zp_fcm_tile + 1
	asl zp_fcm_tile
	rol zp_fcm_tile + 1
	asl zp_fcm_tile
	rol zp_fcm_tile + 1
	lda zp_fcm_tile
	clc
	adc #<FCM_CHARSET
	sta zp_fcm_tile
	lda zp_fcm_tile + 1
	adc #>FCM_CHARSET
	sta zp_fcm_tile + 1
	lda #^FCM_CHARSET
	sta zp_fcm_tile + 2
	lda #0
	sta zp_fcm_tile + 3
	ldy #0
-	tya
	taz
	lda [zp_fcm_tile],z
	sta .fw_rows,y
	iny
	cpy #8
	bne -

	; point at the tile: FCM_TEXT_TILE_STORE + tile * 64. The store is 256 tiles
	; of 64 bytes, so the offset fills the low word (whose base is zero) exactly.
	lda .fw_code
	sta zp_fcm_tile + 1		; tile * 256 ...
	lda #0
	sta zp_fcm_tile
	lsr zp_fcm_tile + 1		; ... / 4 = tile * 64
	ror zp_fcm_tile
	lsr zp_fcm_tile + 1
	ror zp_fcm_tile
	lda zp_fcm_tile + 1
	clc
	adc #>FCM_TEXT_TILE_STORE
	sta zp_fcm_tile + 1
	lda #^FCM_TEXT_TILE_STORE
	sta zp_fcm_tile + 2
	lda #0
	sta zp_fcm_tile + 3

	; write the 64 pixels: a set bit (MSB leftmost) takes 255, the ink out of
	; colour RAM; a clear one takes the window's background.
	ldz #0
	ldx #0
.fw_row
	lda .fw_rows,x
	sta .fw_bits
	ldy #8
-	asl .fw_bits
	bcc +
	lda #255
	bne ++					; always
+	lda .fw_paper
++	sta [zp_fcm_tile],z
	inz
	dey
	bne -
	inx
	cpx #8
	bne .fw_row
	rts

.fw_bitmask	!byte $80,$40,$20,$10,$08,$04,$02,$01
.fw_glyph	!byte 0
.fw_code	!byte 0
.fw_slot	!byte 0
.fw_yoff	!byte 0
.fw_bit		!byte 0
.fw_paper	!byte 0
.fw_bits	!byte 0
.fw_rows	!fill 8, 0

fcm_update_paper
	; Work out how the CURRENT window's cells are drawn, after anything that can
	; change it: a set_colour, a window switch, a screen clear.
	ldx current_window
	; fall through

fcm_paper_for_window
	; x = the window whose background the next cells written should take.
	; Clobbers a/x/y.
	lda #$ff
	sta fcm_paper_slot
	lda s_colour_swap
	bne .fp_done			; reverse video already gives this window a field
!ifdef Z6_FCM_TEXT_BAKE {
	lda window_bake,x
	bne .fp_done			; transparent: s_bake_char paints the art through
}
	lda window_colour,x		; property 11: background in the high nybble
	lsr
	lsr
	lsr
	lsr
	cmp #15
	beq .fp_done			; z-colour 15 is transparent, not a colour
	cmp s_bg_zcolour
	beq .fp_done			; the screen's own background: an ordinary cell
	tax
	jsr zcolour_to_hw_bg	; z-colour -> hardware colour (defaults resolved)
	cmp #15
	beq .fp_done			; palette index 255 means "the colour RAM byte"
	sta .fp_colour

	ldx #FCM_TEXT_SLOTS - 1	; a slot already holding this background?
-	lda fcm_slot_paper,x
	cmp .fp_colour
	beq .fp_take
	dex
	bpl -
	ldx #FCM_TEXT_SLOTS - 1	; no: claim a free one
-	lda fcm_slot_paper,x
	cmp #$ff
	beq .fp_claim
	dex
	bpl -
	rts						; every slot is spoken for: an ordinary cell
.fp_claim
	stx .fp_slot
	lda .fp_colour
	sta fcm_slot_paper,x
	txa						; nothing in this slot is baked yet
	asl
	asl
	asl
	asl						; * FCM_TEXT_BITMAP (16)
	tay
	ldx #FCM_TEXT_BITMAP
	lda #0
-	sta fcm_slot_baked,y
	iny
	dex
	bne -
	ldx .fp_slot
.fp_take
	stx fcm_paper_slot
.fp_done
	rts
.fp_colour	!byte 0
.fp_slot	!byte 0

fcm_text_reset
	; Drop every slot. Only safe when no cell can still be showing one of these
	; tiles, i.e. when the whole screen is about to be filled with spaces.
	ldx #FCM_TEXT_SLOTS - 1
	lda #$ff
-	sta fcm_slot_paper,x
	dex
	bpl -
	sta fcm_paper_slot
	ldx #(FCM_TEXT_SLOTS * FCM_TEXT_BITMAP) - 1
	lda #0
-	sta fcm_slot_baked,x
	dex
	bpl -
	rts
}
