; Z6 version of screen.asm (used when the Z6 window model is active).
; Kept as close to screen.asm as possible; differences:
; - the z6 window model: 8 windows with property arrays (window_y etc.,
;   laid out as required by get_wind_prop/put_wind_prop, see z-spec 8.8.3.2)
; - window_start_row replaced: +1 -> window_y (top row of window 0),
;   +2 -> window_y + 1, bare -> s_screen_height
; - implementations/stubs for the z6 opcodes (draw_picture, move_window, ...)

; screen update routines

!macro init_screen_model {
    ; default values (see z-spec 8.8.3.3)
    ; all coordinates are stored 0-based internally; the opcodes
    ; convert from/to the 1-based coordinates the z-machine uses
	lda #0
	sta current_window
	ldx #(16 * 8) - 1 ; clear all 16 window property arrays
-   sta window_y,x
	dex
	bpl -
	ldx #6
	lda #WIN_BUFFERED ; windows 1-7 start with buffering only
-   sta window_attributes + 1,x
	dex
	bpl -
	ldx #7
	lda #1 ; every window uses font 1, the normal font
-   sta window_font,x
	dex
	bpl -
	; window 0 fills the whole screen; wrapping, scrolling,
	; transcripting and buffering all on
	lda #15
	sta window_attributes
	lda s_screen_height
	sta window_y_size
	lda s_screen_width
	sta window_x_size
!ifdef Z6_ECM_MODE {
	jsr ecm_init
}
    lda #147 ; clear screen
    jsr s_printchar
}

WIN_WRAPPING = 1
WIN_SCROLLING = 2
WIN_TRANSCRIPT = 4
WIN_BUFFERED = 8

; the props must be defined as for put/get_wind_prop to work (8.8.3.2)
window_y               !byte 0,0,0,0,0,0,0,0
window_x               !byte 0,0,0,0,0,0,0,0
window_y_size          !byte 0,0,0,0,0,0,0,0
window_x_size          !byte 0,0,0,0,0,0,0,0
window_y_cursor        !byte 0,0,0,0,0,0,0,0
window_x_cursor        !byte 0,0,0,0,0,0,0,0
window_left_margin     !byte 0,0,0,0,0,0,0,0
window_right_margin    !byte 0,0,0,0,0,0,0,0
window_newline_routine !byte 0,0,0,0,0,0,0,0
window_newline_countd  !byte 0,0,0,0,0,0,0,0
window_style           !byte 0,0,0,0,0,0,0,0
window_colour          !byte 0,0,0,0,0,0,0,0
window_font            !byte 0,0,0,0,0,0,0,0
; Property 13 is the font size, and it is the only property that is a real
; word: height in the high byte, width in the low one. It cannot be held in a
; byte per window like the rest, so get_wind_prop answers it directly (1,1, one
; unit each way, as the header promises) and nothing reads these bytes. They
; stay because the properties are indexed as window_y + 8 * property + window,
; so removing them would move window_attributes and window_linecount.
window_font_size_slot  !byte 0,0,0,0,0,0,0,0
window_attributes      !byte 0,0,0,0,0,0,0,0
window_linecount       !byte 0,0,0,0,0,0,0,0

!ifdef Z6_PICTURES {
!source "../temp/pictures.asm"

; The pictures are files on the disk, preloaded into attic RAM at boot the same
; way the sound effects are. Drawing one copies its tiles down into the tile
; store, shifting every pixel index into the drawing window's palette bank,
; loads its palette, and fills its cells in screen RAM.
;
; A window holds at most one picture, so each window owns a run of the tile
; store and a bank of 16 palette entries above the 16 text colours.

PIC_ATTIC_PAGE = $3000		; $08300000: past the story, the sounds and scrollback
; PIC_MAX_TILES, FCM_TILE_STORE and FCM_TILE_CODE_HI are in constants.asm:
; where the store can live depends on what else is in the target's fast RAM.

.pic_ptr = z_temp			; 2 bytes, the screen row being written
.pic_att = z_temp + 2		; 4 bytes, a 32 bit pointer into attic RAM
.pic_dst = z_temp + 6		; 4 bytes, a 32 bit pointer into the tile store

.pic_index   !byte 0
.pic_w       !byte 0		; cells across
.pic_h       !byte 0		; cells down
.pic_ntiles  !byte 0,0
.pic_slot    !byte 0,0		; the picture's first tile in the store
.pic_pal_off   !byte 0		; 16 * the window being drawn into
.pic_pixel_base !byte 0		; 16 + .pic_pal_off: what a colour index of 1 becomes
.pic_row     !byte 0
.pic_col2    !byte 0
.pic_map     !byte 0,0,0	; where the cell map starts in attic RAM
.pic_count   !byte 0,0		; a general 16 bit counter
.pfc_lo      !byte 0		; a cell's tile index low byte while drawing

pic_next_tile  !byte 0,0
pic_win_base   !fill 16, 0	; two bytes a window
pic_win_count  !fill 16, 0
pic_win_number !fill 8, $ff	; the picture index resident in each window's run,
							; $ff = none. A window's run may only be reused for
							; the same picture; a different one must not overwrite
							; tiles the resident picture's still-visible cells use.
; Each drawn picture gets its own palette bank of 16 entries, so pictures that
; coexist in one window (Arthur keeps a frame and two side bars in window 7)
; keep their own colours. Banks 1..PIC_PAL_BANKS sit above the 16 text colours;
; a picture's tiles are baked to point into its bank, so the bank travels with
; the tile run and is reused or freshly bumped alongside it. Bank 15 is left
; out: its top colour would be pixel value 255, which FCM takes from colour RAM.
PIC_PAL_BANKS = 14
pic_next_bank  !byte 1
pic_win_bank   !fill 8, 0
; The palette an adaptive picture (Blorb APal) draws in: the pixel base and
; matching pal offset of the last direct picture drawn. Seeded with bank 1 in
; case an adaptive picture is somehow drawn before any direct one.
pic_direct_base !byte 16
pic_direct_off  !byte 0

; ---------------------------------------------------------------------------
pic_file_name !text "P000" ; make.rb upper-cases the names it puts on the disk
PIC_FILE_NAME_LEN = 4

.pic_next_page !byte 0,0

pic_load_all
	; Preload every picture into attic RAM. Called at boot, next to the sound
	; effects, and for the same reason: the files are far too big to assemble
	; into the interpreter. They are RLE compressed, and are expanded on the way
	; in, so attic holds them ready to draw.
	lda #<PIC_ATTIC_PAGE
	sta .pic_next_page
	lda #>PIC_ATTIC_PAGE
	sta .pic_next_page + 1
	lda #0
	sta .pic_index
.pla_loop
	ldy .pic_index
	lda pic_number,y
	jsr .pic_set_filename
	lda #PIC_FILE_NAME_LEN
	ldx #<pic_file_name
	ldy #>pic_file_name
	jsr kernal_setnam
	lda #2					; logical file 2
	tay						; secondary 2: a SEQ file, opened for reading
	ldx boot_device
	jsr kernal_setlfs
	jsr kernal_open
	bcc +
	lda #ERROR_FLOPPY_READ_ERROR
	jsr fatalerror
+	ldx #2
	jsr kernal_chkin

	ldy .pic_index			; the picture starts on the next free page
	lda .pic_next_page
	sta pic_page_lo,y
	sta .pic_att + 1
	lda .pic_next_page + 1
	sta pic_page_hi,y
	sta .pic_att + 2
	lda #0
	sta .pic_att
	lda #$08				; attic RAM starts at $08000000
	sta .pic_att + 3

	jsr .pic_unrle

	lda #2
	jsr kernal_close
	jsr kernal_clrchn

	lda .pic_att			; round the write pointer up to the next page
	beq +
	inc .pic_att + 1
	bne +
	inc .pic_att + 2
+	lda .pic_att + 1
	sta .pic_next_page
	lda .pic_att + 2
	sta .pic_next_page + 1

	inc .pic_index
	lda .pic_index
	cmp #picture_count
	bne .pla_loop
	rts

.rle_eof   !byte 0
.rle_byte  !byte 0
.rle_count !byte 0
.rle_value !byte 0

.rle_getc
	; Read the next byte of the open file. Sets .rle_eof when it was the last.
	jsr kernal_readchar		; clobbers x and y, so counts live in memory
	sta .rle_byte
	jsr kernal_readst
	sta .rle_eof
	lda .rle_byte
	rts

.pic_store
	; Write a to attic RAM and step .pic_att on.
	ldz #0
	sta [.pic_att],z
	inc .pic_att
	bne +
	inc .pic_att + 1
	bne +
	inc .pic_att + 2
+	rts

.pic_unrle
	; PackBits: a token of 0..127 is followed by token+1 literal bytes; a token
	; of 129..255 is followed by one byte, repeated 257-token times; 128 is
	; unused. No lookahead, which is what keeps this short.
.unrle_next
	jsr .rle_getc
	ldx .rle_eof
	bne .unrle_done
	cmp #$80
	beq .unrle_next			; 128: nothing to do
	bcs .unrle_run
	clc						; literal run of a+1 bytes
	adc #1
	sta .rle_count
.unrle_lit
	jsr .rle_getc
	jsr .pic_store
	lda .rle_eof
	bne .unrle_done
	dec .rle_count
	bne .unrle_lit
	beq .unrle_next			; always
.unrle_run
	eor #$ff				; 257 - a, which is 2..128
	clc
	adc #2
	sta .rle_count
	jsr .rle_getc
	sta .rle_value
.unrle_rep
	lda .rle_value
	jsr .pic_store
	dec .rle_count
	bne .unrle_rep
	lda .rle_eof
	beq .unrle_next
.unrle_done
	rts

.pic_set_filename
	; a = picture number. Write it into pic_file_name as three digits.
	ldx #$2f					; '0' - 1
-	inx
	sec
	sbc #100
	bcs -
	adc #100
	stx pic_file_name + 1
	ldx #$2f
-	inx
	sec
	sbc #10
	bcs -
	adc #10
	stx pic_file_name + 2
	ora #$30
	sta pic_file_name + 3
	rts

; ---------------------------------------------------------------------------
.pic_find
	; Find the picture whose number is in a,x (high, low). Returns its index in
	; .pic_index with carry set, or carry clear if this build does not have it.
	cmp #0
	bne .pic_not_found		; no picture number we hold needs a high byte
	ldy #0					; count up: a game may have more than 128 pictures,
-	txa						; and then a countdown's bpl would never be taken
	cmp pic_number,y
	beq +
	iny
	cpy #picture_count
	bne -
.pic_not_found
	clc
	rts
+	sty .pic_index
	sec
	rts

.pic_att_next
	; Read the byte at .pic_att and step the pointer on.
	ldz #0
	lda [.pic_att],z
	inc .pic_att
	bne +
	inc .pic_att + 1
	bne +
	inc .pic_att + 2
+	rts

.pic_open
	; Point .pic_att at the start of the picture's file in attic RAM.
	ldy .pic_index
	lda #0
	sta .pic_att			; the file starts on a page boundary
	lda pic_page_lo,y
	sta .pic_att + 1
	lda pic_page_hi,y
	sta .pic_att + 2
	lda #$08				; attic RAM starts at $08000000
	sta .pic_att + 3
	rts

.pic_bank_start
	; .pic_col2 = the first palette entry of this window's bank
	lda #16
	clc
	adc .pic_pal_off
	sta .pic_col2
	rts

.pic_read_palette
	; The 48 bytes after the header, into this window's bank. They are already
	; nybble swapped, as the palette registers want.
	jsr mega65io
	jsr .pic_bank_start
	ldy #0
-	jsr .pic_att_next
	ldx .pic_col2
	sta $d100,x
	inc .pic_col2
	iny
	cpy #16
	bne -
	jsr .pic_bank_start
	ldy #0
-	jsr .pic_att_next
	ldx .pic_col2
	sta $d200,x
	inc .pic_col2
	iny
	cpy #16
	bne -
	jsr .pic_bank_start
	ldy #0
-	jsr .pic_att_next
	ldx .pic_col2
	sta $d300,x
	inc .pic_col2
	iny
	cpy #16
	bne -
	rts

.pic_cells
	; a,x = the picture's cell count, w * h
	jsr mega65io
	lda .pic_w
	sta $d770
	lda #0
	sta $d771
	sta $d772
	sta $d773
	sta $d775
	sta $d776
	sta $d777
	lda .pic_h
	sta $d774
	ldx $d778
	lda $d779
	rts

.pic_alloc
	; Give this window a run of the tile store big enough for the picture. The
	; window's old run can be reused only when the SAME picture is being redrawn
	; into it: a game composites (Arthur draws a small scene centred inside a
	; larger frame, both in the picture window), so a different picture must get
	; its own run or it would overwrite tiles the frame's still-visible cells
	; point at. When the store runs out we start again at the bottom, which can
	; only spoil a picture that is no longer the newest in its window.
	lda current_window
	tay
	asl
	tax
	lda .pic_index			; same picture as this window last held?
	cmp pic_win_number,y
	bne .pa_fresh
	lda pic_win_count,x		; and does the window's own run still fit it?
	cmp .pic_ntiles
	lda pic_win_count + 1,x
	sbc .pic_ntiles + 1
	bcc .pa_fresh
	lda pic_win_base,x
	sta .pic_slot
	lda pic_win_base + 1,x
	sta .pic_slot + 1
	lda pic_win_bank,y		; reuse the bank this picture's tiles are baked for
	jmp .pa_set_bank
.pa_fresh
	lda pic_next_tile		; would it run off the end of the store?
	clc
	adc .pic_ntiles
	tay
	lda pic_next_tile + 1
	adc .pic_ntiles + 1
	cmp #>PIC_MAX_TILES
	bcc +
	bne .pa_reset
	cpy #<PIC_MAX_TILES
	bcc +
.pa_reset
	lda #0
	sta pic_next_tile
	sta pic_next_tile + 1
+	lda pic_next_tile
	sta .pic_slot
	sta pic_win_base,x
	lda pic_next_tile + 1
	sta .pic_slot + 1
	sta pic_win_base + 1,x
	lda .pic_ntiles
	sta pic_win_count,x
	clc
	adc pic_next_tile
	sta pic_next_tile
	lda .pic_ntiles + 1
	sta pic_win_count + 1,x
	adc pic_next_tile + 1
	sta pic_next_tile + 1
	ldy current_window		; remember which picture now owns this run
	lda .pic_index
	sta pic_win_number,y
	; give it the next palette bank, wrapping after the last one, which can only
	; spoil the colours of a picture that is no longer the newest on screen
	ldx pic_next_bank
	inc pic_next_bank
	lda pic_next_bank
	cmp #PIC_PAL_BANKS + 1
	bcc +
	lda #1
	sta pic_next_bank
+	txa
	sta pic_win_bank,y
	; fall through to .pa_set_bank

.pa_set_bank
	; a = palette bank 1..PIC_PAL_BANKS. Its 16 entries start at 16 * bank, and a
	; colour index of 1..15 in the tiles becomes that entry plus the index.
	asl
	asl
	asl
	asl
	sta .pic_pixel_base
	sec
	sbc #16
	sta .pic_pal_off
	rts

.pic_copy_tiles
	; Copy the picture's tiles from attic RAM into its run of the tile store.
	; Attic holds two pixels a byte; the store holds one. A pixel of 0 stays 0,
	; which is transparent in every bank; anything else is shifted into this
	; window's bank. The DMA engine can neither expand nor add, so the CPU does
	; it; at 40 MHz even a full screen picture is a blink.
	lda .pic_slot			; destination = FCM_TILE_STORE + slot * 64
	sta .pic_dst
	lda .pic_slot + 1
	sta .pic_dst + 1
	lda #0					; slot * 64 needs 24 bits: a store of 2048 tiles
	sta .pic_dst + 2		; runs to $1ffc0, past what two bytes can hold
	ldx #6
-	asl .pic_dst
	rol .pic_dst + 1
	rol .pic_dst + 2
	dex
	bne -
	lda .pic_dst + 2		; the store's low 16 bits are zero, so the base
	clc						; only ever lands in the third byte
	adc #((FCM_TILE_STORE >> 16) & $0f)
	sta .pic_dst + 2
	lda #0
	sta .pic_dst + 3
	; source bytes = ntiles * 32, which cannot overflow: one picture covers at
	; most the 1000 cells of the screen, so it has at most 1000 tiles
	lda .pic_ntiles
	sta .pic_count
	lda .pic_ntiles + 1
	sta .pic_count + 1
	ldx #5
-	asl .pic_count
	rol .pic_count + 1
	dex
	bne -
.pct_loop
	jsr .pic_att_next
	pha
	lsr						; the high nybble is the left pixel
	lsr
	lsr
	lsr
	jsr .pic_put_pixel
	pla
	and #$0f
	jsr .pic_put_pixel
	lda .pic_count
	bne +
	dec .pic_count + 1
+	dec .pic_count
	lda .pic_count
	ora .pic_count + 1
	bne .pct_loop
	rts

.pic_put_pixel
	; a = a colour index of 0..15. Store it in the tile store, in this window's
	; palette bank, and step the destination on.
	cmp #0
	beq +
	clc
	adc .pic_pixel_base
+	ldz #0
	sta [.pic_dst],z
	inc .pic_dst
	bne +
	inc .pic_dst + 1
	bne +
	inc .pic_dst + 2
+	rts

.pic_point_at_row
	; .pic_ptr = SCREEN_ADDRESS + .pic_y * SCREEN_ROW_BYTES
	jsr mega65io
	lda .pic_y
	sta $d770
	lda #0
	sta $d771
	sta $d772
	sta $d773
	sta $d775
	sta $d776
	sta $d777
	lda #SCREEN_ROW_BYTES
	sta $d774
	lda $d778
	sta .pic_ptr
	lda $d779
	clc
	adc #>SCREEN_ADDRESS
	sta .pic_ptr + 1
	rts

.pic_row_width
	; a = the byte offset just past the picture's last cell on a screen row
	lda .pic_w
	asl
	clc
	adc .pic_x
	adc .pic_x
	rts

.pic_fill_cells
	; Read the cell map back out of attic RAM and write the screen codes. A
	; cell's code is its tile's address divided by 64, so it is
	; $0400 + slot + index, and the map holds the index.
	lda .pic_map
	sta .pic_att
	lda .pic_map + 1
	sta .pic_att + 1
	lda .pic_map + 2
	sta .pic_att + 2
	lda #$08
	sta .pic_att + 3
	jsr .pic_point_at_row
	lda #0
	sta .pic_row
.pfc_row
	; Clip to the screen. A picture placed low or far right (draw_picture may be
	; told to use the cursor's own position, which drifts with the text) would
	; otherwise run its row loop past the last screen row and scribble over the
	; interpreter, or spill a row's tail into the next row. Both must be fenced.
	lda .pic_row
	clc
	adc .pic_y
	cmp #SCREEN_HEIGHT		; this row past the bottom edge? the rest are too
	bcs .pfc_done
	lda .pic_x
	asl
	sta .pic_col2
.pfc_cell
	jsr .pic_att_next		; index, low byte
	sta .pfc_lo
	jsr .pic_att_next		; index, high byte
	cmp #$ff				; $ffff marks a fully transparent cell: leave what
	beq .pfc_advance		; is under it, so a picture behind shows through
	ldy .pic_col2
	cpy #SCREEN_ROW_BYTES	; column past the right edge? drop the write, but
	bcs .pfc_advance		; keep consuming the map so the next row stays aligned
	pha						; the high byte, while we build the low one
	lda .pfc_lo
	clc
	adc .pic_slot
	sta (.pic_ptr),y		; screen code low byte = index low + slot low
	iny
	pla
	adc .pic_slot + 1
	adc #FCM_TILE_CODE_HI	; screen code high; carry clear, never reaches $4000
	sta (.pic_ptr),y
.pfc_advance
	lda .pic_col2
	clc
	adc #2
	sta .pic_col2
	jsr .pic_row_width
	cmp .pic_col2
	bne .pfc_cell
	lda .pic_ptr
	clc
	adc #SCREEN_ROW_BYTES
	sta .pic_ptr
	bcc +
	inc .pic_ptr + 1
+	inc .pic_row
	lda .pic_h
	cmp .pic_row
	bne .pfc_row
.pfc_done
	rts

.pic_draw
	; Draw the picture in .pic_index with its top left cell at .pic_y, .pic_x.
	; Only screen RAM is touched: a cell's colour bytes hold flags (zero) and
	; the colour for pixel value 255, which no picture pixel ever is.
	jsr .pic_open
	jsr .pic_att_next
	sta .pic_w
	jsr .pic_att_next
	sta .pic_h
	jsr .pic_att_next
	sta .pic_ntiles
	jsr .pic_att_next
	sta .pic_ntiles + 1

	jsr .pic_alloc			; picks the tile run and the palette bank to bake for
	; An adaptive picture is baked into, and shown in, the last direct picture's
	; palette; a direct one uses its own bank and makes it the current palette.
	ldy .pic_index
	lda pic_adaptive,y
	beq .pd_direct
	lda pic_direct_off
	sta .pic_pal_off
	lda pic_direct_base
	sta .pic_pixel_base
	clc						; step over our own 48 palette bytes unread: we keep
	lda .pic_att			; the current picture's palette loaded instead
	adc #48
	sta .pic_att
	lda .pic_att + 1
	adc #0
	sta .pic_att + 1
	lda .pic_att + 2
	adc #0
	sta .pic_att + 2
	jmp +
.pd_direct
	lda .pic_pal_off
	sta pic_direct_off
	lda .pic_pixel_base
	sta pic_direct_base
	jsr .pic_read_palette	; the picture's palette, into its bank
+

	; .pic_att now points at the cell map. Remember it, then skip over it.
	lda .pic_att
	sta .pic_map
	lda .pic_att + 1
	sta .pic_map + 1
	lda .pic_att + 2
	sta .pic_map + 2
	jsr .pic_cells			; a,x = w * h
	sta .pic_count + 1
	stx .pic_count
	asl .pic_count			; two bytes a cell
	rol .pic_count + 1
	lda .pic_att
	clc
	adc .pic_count
	sta .pic_att
	lda .pic_att + 1
	adc .pic_count + 1
	sta .pic_att + 1
	bcc +
	inc .pic_att + 2
+
	jsr .pic_copy_tiles
	jmp .pic_fill_cells

.pic_erase
	; Blank the rectangle the picture in .pic_index occupies at .pic_y, .pic_x,
	; by putting a space in every cell it covered. s_printchar would do it, but
	; it would also wrap, scroll and move the cursor.
	jsr .pic_open
	jsr .pic_att_next
	sta .pic_w
	jsr .pic_att_next
	sta .pic_h
	jsr .pic_point_at_row
	lda #0
	sta .pic_row
.pic_erase_row
	lda .pic_row			; clip to the screen, exactly as .pic_fill_cells does
	clc
	adc .pic_y
	cmp #SCREEN_HEIGHT
	bcs .pic_erase_done
	lda .pic_x
	asl
	sta .pic_col2
.pic_erase_cell
	ldy .pic_col2
	cpy #SCREEN_ROW_BYTES
	bcs .pic_erase_next
	lda #$20				; a space, which is a text character, not a tile
	sta (.pic_ptr),y
	iny
	lda #0					; and so its high byte must go back to zero
	sta (.pic_ptr),y
.pic_erase_next
	lda .pic_col2
	clc
	adc #2
	sta .pic_col2
	jsr .pic_row_width
	cmp .pic_col2
	bne .pic_erase_cell
	lda .pic_ptr
	clc
	adc #SCREEN_ROW_BYTES
	sta .pic_ptr
	bcc +
	inc .pic_ptr + 1
+	inc .pic_row
	lda .pic_h
	cmp .pic_row
	bne .pic_erase_row
.pic_erase_done
	rts
}

z_ins_draw_picture
	; draw_picture picture-number y x
	; Where we have the picture (MEGA65, -fcm, -pics) it is blitted from bank
	; 1. Otherwise Ozmoo will never draw pictures on this machine, so instead
	; of leaving a hole in the layout it writes a "pic:N" note where the
	; picture belongs. The note goes straight to the screen, so it never
	; reaches the transcript, and the game's cursor is put back afterwards.
!ifdef TRACE_SCREEN {
	jsr print_following_string
	!pet "z_ins_draw_picture ",0
	jsr newline
}
!ifdef Z6_PICTURES {
	lda z_operand_value_high_arr
	ldx z_operand_value_low_arr
	jsr .pic_find
	bcc .dp_not_image
	jsr .pic_place_cursor
	jsr .pic_draw
	jmp restore_cursor
.dp_not_image
	ldx z_operand_value_low_arr
	jsr .rect_find		; a Rect placeholder is invisible: nothing to draw
	bcc +
	rts
+
}
	jsr .pic_place_cursor
	lda #>.pic_prefix
	ldx #<.pic_prefix
	jsr printstring_raw
	lda z_operand_value_high_arr
	ldx z_operand_value_low_arr
	jsr .pic_print_number
	jmp restore_cursor

.pic_prefix !pet "pic:",0

z_ins_picture_data
	; picture_data picture-number array ?(label)
	; Where we have the picture, report its size and branch. Picture 0 asks for
	; the number of pictures available and the release number of the picture
	; file instead of a size.
	;
	; The spec calls the two words a height and a width "in pixels", but a
	; pixel here is whatever unit the rest of the screen model counts in, and
	; Ozmoo counts characters: the header reports a 40x25 screen and
	; get_wind_prop answers 1x1 for the font size. A game divides one by the
	; other, so the size must come back in cells too. Arthur centres a picture
	; with (get_wind_prop 3 - width) / 2, straight against the window's column
	; count, and would put it off screen eightfold otherwise.
!ifdef TRACE_SCREEN {
	jsr print_following_string
	!pet "z_ins_picture_data ",0
	jsr newline
}
	lda z_operand_value_low_arr
	ora z_operand_value_high_arr
	bne .pd_picture
	; picture 0: the number of pictures, then the picture file's release number
	jsr .pd_set_array
	lda #0
	jsr write_next_byte
!ifdef Z6_PICTURES {
	lda #picture_count
} else {
	lda #0
}
	jsr write_next_byte
	lda #0
	jsr write_next_byte
	jsr write_next_byte
	jmp make_branch_false ; picture 0 never branches
.pd_picture
!ifdef Z6_PICTURES {
	lda z_operand_value_high_arr
	ldx z_operand_value_low_arr
	jsr .pic_find
	bcc .pd_try_rect
	jsr .pic_open
	jsr .pic_att_next ; cells across
	sta .pic_w
	jsr .pic_att_next ; cells down
	sta .pic_h
	jmp .pd_report
.pd_try_rect
	; Not a real picture. A Rect placeholder has no image, only a size, which
	; the game reads to lay real pictures out; Arthur's frame is built this way.
	jsr .rect_find
	bcc +
	lda rect_width,y
	sta .pic_w
	lda rect_height,y
	sta .pic_h
.pd_report
	jsr .pd_set_array
	lda #0
	jsr write_next_byte
	lda .pic_h ; the height is word 0
	jsr write_next_byte
	lda #0
	jsr write_next_byte
	lda .pic_w ; and the width word 1
	jsr write_next_byte
	jmp make_branch_true
+
}
	jmp make_branch_false

!ifdef Z6_PICTURES {
.rect_find
	; Picture number in x (low byte); rects never need a high byte. Return its
	; index in y with carry set, or carry clear if it is not a rect.
!if rect_count > 0 {
	lda z_operand_value_high_arr
	bne +
	ldy #0
-	txa
	cmp rect_number,y
	beq ++
	iny
	cpy #rect_count
	bne -
}
+	clc
	rts
!if rect_count > 0 {
++	sec
	rts
}
}

.pd_set_array
	; Point the write cursor at the array in operand 1.
	ldx z_operand_value_low_arr + 1
	lda z_operand_value_high_arr + 1
	jmp set_z_address

z_ins_erase_picture
	; erase_picture picture-number y x
	; Where we drew a real picture, blank its rectangle. Otherwise paint over
	; the note draw_picture wrote, so that a game which erases a picture leaves
	; clean screen behind either way.
!ifdef TRACE_SCREEN {
	jsr print_following_string
	!pet "z_ins_erase_picture ",0
	jsr newline
}
!ifdef Z6_PICTURES {
	lda z_operand_value_high_arr
	ldx z_operand_value_low_arr
	jsr .pic_find
	bcc +
	jsr .pic_place_cursor
	jsr .pic_erase
	jmp restore_cursor
+
}
	jsr .pic_place_cursor
	lda z_operand_value_high_arr
	ldx z_operand_value_low_arr
	jsr .pic_number_width
	clc
	adc #4 ; the "pic:" prefix
	tay
-	lda #$20
	jsr s_printchar
	dey
	bne -
	jmp restore_cursor

.pic_place_cursor
	; Put the live cursor where the picture belongs. y and x are 1-based and
	; relative to the current window; zero, or a missing operand, means "the
	; cursor's own y or x" (see the draw_picture entry in the spec).
	jsr printchar_flush ; anything buffered belongs on screen first
	jsr save_cursor
	lda #0
	sta .pic_y
	sta .pic_x
	ldx z_operand_count
	cpx #2
	bcc +
	lda z_operand_value_low_arr + 1
	sta .pic_y
	cpx #3
	bcc +
	lda z_operand_value_low_arr + 2
	sta .pic_x
+	ldy current_window
	ldx .pic_y
	beq +
	dex ; 1-based to 0-based
	txa
	clc
	adc window_y,y
	jmp ++
+	lda window_y_cursor,y
++	sta .pic_y
	ldx .pic_x
	beq +
	dex
	txa
	clc
	adc window_x,y
	jmp ++
+	lda window_x_cursor,y
++	sta .pic_x ; keep the absolute column: the picture blitter needs it too
	tay ; y = column
	ldx .pic_y ; x = row
	jmp set_cursor

.pic_print_number
	; a,x = high,low byte of an unsigned number: print it on the screen
	jsr .pic_split_number ; y = digit count, .pic_buf holds them backwards
-	dey
	lda .pic_buf,y
	jsr s_printchar
	cpy #0
	bne -
	rts

.pic_number_width
	; a,x = high,low byte of an unsigned number: return its length in a
	jmp .pic_split_number

.pic_split_number
	; a,x = high,low byte of an unsigned number. Store its digits in
	; .pic_buf, least significant first, and return the count in a and y.
	sta .pic_num + 1
	stx .pic_num
	ldy #0
-	jsr .pic_div10
	clc
	adc #$30 ; '0'
	sta .pic_buf,y
	iny
	lda .pic_num
	ora .pic_num + 1
	bne -
	tya
	rts

.pic_div10
	; .pic_num /= 10, remainder returned in a
	lda #0
	sta .pic_rem
	ldx #16
-	asl .pic_num
	rol .pic_num + 1
	rol .pic_rem
	lda .pic_rem
	cmp #10
	bcc +
	sbc #10
	sta .pic_rem
	inc .pic_num ; the quotient's bit 0, just vacated by the shift
+	dex
	bne -
	lda .pic_rem
	rts

.pic_y   !byte 0
.pic_x   !byte 0
.pic_num !byte 0,0
.pic_rem !byte 0
.pic_buf !byte 0,0,0,0,0 ; at most five digits

window_from_operand
	; x = which operand holds a window number. Returns that window in a and y.
	; The z-machine writes the current window as -3 (z-spec 8.8.3), and Arthur
	; does so constantly: 22 of its get_wind_prop calls and 5 of its
	; window_style calls name the window that way. Anything else is masked to
	; the eight windows that exist.
	lda z_operand_value_high_arr,x
	cmp #$ff
	bne +
	lda z_operand_value_low_arr,x
	cmp #$fd
	bne +
	lda current_window
	tay
	rts
+	lda z_operand_value_low_arr,x
	and #7
	tay
	rts

z_ins_set_margins
	; set_margins left right [window]
	; The margins are in pixels, and a character is one pixel wide here, so
	; they are simply column counts. Text wraps between them.
!ifdef TRACE_SCREEN {
	jsr print_following_string
	!pet "z_ins_set_margins ",0
	jsr newline
}
	ldy current_window
	lda z_operand_count
	cmp #3
	bcc +
	ldx #2
	jsr window_from_operand
+	lda z_operand_value_low_arr
	sta window_left_margin,y
	lda z_operand_value_low_arr + 1
	sta window_right_margin,y
	; "If the cursor is overtaken and now lies outside the margins
	; altogether, move it back to the left margin of the current line."
	sty .sm_window
	jsr save_cursor ; clobbers y with the current window
	ldy .sm_window
	lda window_x,y
	clc
	adc window_left_margin,y
	sta .sm_left
	lda window_x,y
	clc
	adc window_x_size,y
	sec
	sbc window_right_margin,y
	bcs +
	lda window_x,y ; a margin wider than the window leaves no room at all
+	sta .sm_right
	lda window_x_cursor,y
	cmp .sm_left
	bcc .sm_outside
	cmp .sm_right
	bcc .sm_inside
.sm_outside
	lda .sm_left
	sta window_x_cursor,y
.sm_inside
	cpy current_window
	bne +
	jmp restore_cursor
+	rts

.sm_left   !byte 0
.sm_right  !byte 0
.sm_window !byte 0

z_ins_move_window
	; move_window window y x
!ifdef TRACE_SCREEN {
	jsr print_following_string
	!pet "z_ins_move_window ",0
	jsr newline
}
	ldx #0
	jsr window_from_operand
	ldx z_operand_value_low_arr + 1
	beq +
	dex ; z-machine uses 1-based coordinates, we use 0-based
+	txa
	sta window_y,y
	sta window_y_cursor,y
	ldx z_operand_value_low_arr + 2
	beq +
	dex
+	txa
	sta window_x,y
	sta window_x_cursor,y
	cpy current_window
	bne +
	jsr restore_cursor ; the current window moved: update the live cursor
+	rts
 
z_ins_window_size
	; window_size window y x
!ifdef TRACE_SCREEN {
	jsr print_following_string
	!pet "z_ins_window_size ",0
	jsr newline
}
	ldx #0
	jsr window_from_operand
	lda z_operand_value_low_arr + 1
	sta window_y_size,y
	lda z_operand_value_low_arr + 2
	sta window_x_size,y
	rts
 
z_ins_window_style
	; window_style window flags operation
!ifdef TRACE_SCREEN {
	jsr print_following_string
	!pet "z_ins_window_style ",0
	jsr newline
}
	ldx #0
	jsr window_from_operand
	ldx z_operand_value_low_arr + 2
	bne +
	; set to these settings
	lda z_operand_value_low_arr + 1
	jmp ++
+   cpx #1
	bne +
	; set the bits supplied
	lda window_attributes,y
	ora z_operand_value_low_arr + 1
	jmp ++
+   cpx #2
	bne +
	; clear the bits supplied
	lda z_operand_value_low_arr + 1
	eor #$ff
	and window_attributes,y
	jmp ++
+   ; reverse the bits supplied (xor)
	lda window_attributes,y
	eor z_operand_value_low_arr + 1
++
	sta window_attributes,y
	rts
 
z_ins_get_wind_prop
	; get_wind_prop window property-number -> (result)
!ifdef TRACE_SCREEN {
	jsr print_following_string
	!pet "z_ins_window_size ",0
	jsr newline
	lda #99
	jsr printa
	jsr newline
}
	lda z_operand_value_low_arr + 1
	cmp #13
	bne +
	; Property 13 is the font size: height in the high byte, width in the low
	; one. It is the only property that is a real word, so it cannot live in
	; the byte-per-window arrays below. The header tells the game a character
	; is one unit wide and one unit high, so the answer is always 1,1.
	; Arthur takes the height from here and divides by it, so a zero is fatal.
	lda #1
	ldx #1
	jmp z_store_result
+
	; return value at window_y + property-number * 8 + window
	ldx #0
	jsr window_from_operand
	sta .gwp_window
	lda z_operand_value_low_arr + 1
	asl
	asl
	asl
	clc
	adc .gwp_window
	tay
	ldx window_y,y
	; convert 0-based internal values to what the z-machine expects
	ldy .gwp_window
	lda z_operand_value_low_arr + 1
	cmp #2
	bcs +
	inx ; property 0/1 (y/x position): 1-based
	bne .gwp_store ; Always branch
+	cmp #4
	beq .gwp_cursor_y
	cmp #5
	bne .gwp_store
	; property 5 (x cursor): stored absolute, return window-relative 1-based
	txa
	sec
	sbc window_x,y
	tax
	inx
	bne .gwp_store ; Always branch
.gwp_cursor_y
	; property 4 (y cursor): stored absolute, return window-relative 1-based
	txa
	sec
	sbc window_y,y
	tax
	inx
.gwp_store
	lda #0
	jmp z_store_result

.gwp_window !byte 0

z_ins_scroll_window
	; scroll_window window pixels
	; The header tells the game a character is one unit wide and one high, so
	; a pixel here is a character cell. A negative count scrolls the window
	; backwards, that is, down.
!ifdef TRACE_SCREEN {
	jsr print_following_string
	!pet "z_ins_scroll_window ",0
	jsr newline
}
	jsr printchar_flush ; buffered text belongs on screen before it moves
	jsr save_cursor
	ldx #0
	jsr window_from_operand
	sta .swin_window
	lda z_operand_value_high_arr + 1
	bmi .swin_backwards
	; forwards: the count is the operand, clamped to a byte
	beq +
	lda #255
	bne ++ ; always branch
+	lda z_operand_value_low_arr + 1
++	ldx .swin_window
	clc ; scroll up
	jsr s_scroll_window
	jmp restore_cursor
.swin_backwards
	; backwards: the count is the negated operand, clamped to a byte
	lda #0
	sec
	sbc z_operand_value_low_arr + 1
	tay
	lda #0
	sbc z_operand_value_high_arr + 1
	beq +
	lda #255
	bne ++ ; always branch
+	tya
++	ldx .swin_window
	sec ; scroll down
	jsr s_scroll_window
	jmp restore_cursor

.swin_window !byte 0

z_ins_pop_stack
	; pop_stack items [stack]
	; Throw away the top <items> values of the game stack, or, if a user
	; stack is given, just give its slots back.
!ifdef TRACE_SCREEN {
	jsr print_following_string
	!pet "z_ins_pop_stack ",0
	jsr newline
}
	lda z_operand_count
	cmp #2
	bcs .pop_user_stack
	ldx z_operand_value_low_arr
	beq .pop_stack_done
-	txa
	pha
	jsr stack_pull
	pla
	tax
	dex
	bne -
.pop_stack_done
	rts
.pop_user_stack
	; the first word of a user stack is the number of free slots
	jsr .read_user_stack_count
	lda .user_stack_lo
	clc
	adc z_operand_value_low_arr
	tay
	lda .user_stack_hi
	adc z_operand_value_high_arr
	sty .user_stack_lo
	sta .user_stack_hi
	jmp .write_user_stack_count

z_ins_push_stack
	; push_stack value stack ?(label)
	; Push value onto the user stack, branching if there was room.
!ifdef TRACE_SCREEN {
	jsr print_following_string
	!pet "z_ins_push_stack ",0
	jsr newline
}
	jsr .read_user_stack_count
	lda .user_stack_lo
	ora .user_stack_hi
	beq .user_stack_full
	; the value goes in the word at stack + 2 * free slots
	lda .user_stack_lo
	asl
	tay
	lda .user_stack_hi
	rol
	; add that to the address of the user stack
	pha
	tya
	clc
	adc z_operand_value_low_arr + 1
	tax
	pla
	adc z_operand_value_high_arr + 1
	jsr set_z_address
	lda z_operand_value_high_arr
	jsr write_next_byte
	lda z_operand_value_low_arr
	jsr write_next_byte
	; one slot fewer is free
	lda .user_stack_lo
	bne +
	dec .user_stack_hi
+	dec .user_stack_lo
	jsr .write_user_stack_count
	jmp make_branch_true
.user_stack_full
	jmp make_branch_false

.read_user_stack_count
	; read the free slot count from the user stack in operand 2
	ldx z_operand_value_low_arr + 1
	lda z_operand_value_high_arr + 1
	jsr set_z_address
	jsr read_next_byte
	sta .user_stack_hi
	jsr read_next_byte
	sta .user_stack_lo
	rts

.write_user_stack_count
	ldx z_operand_value_low_arr + 1
	lda z_operand_value_high_arr + 1
	jsr set_z_address
	lda .user_stack_hi
	jsr write_next_byte
	lda .user_stack_lo
	jmp write_next_byte

.user_stack_hi !byte 0
.user_stack_lo !byte 0

z_ins_read_mouse
	; read_mouse array: word 0 y, word 1 x, word 2 buttons, word 3 menu word
!ifdef TRACE_SCREEN {
	jsr print_following_string
	!pet "z_ins_read_mouse ",0
	jsr newline
}
	ldx z_operand_value_low_arr
	lda z_operand_value_high_arr
	jsr set_z_address
	lda #0
	jsr write_next_byte
!ifdef Z6_FCM_MODE {
	lda mouse_cell_y
	jsr write_next_byte ; y coordinate
	lda #0
	jsr write_next_byte
	lda mouse_cell_x
	jsr write_next_byte ; x coordinate
	lda #0
	jsr write_next_byte
	lda mouse_button	; bit 0 = button one held
	jsr write_next_byte ; buttons
} else {
	lda #1
	jsr write_next_byte ; y coordinate
	lda #0
	jsr write_next_byte
	lda #1
	jsr write_next_byte ; x coordinate
	lda #0
	jsr write_next_byte
	jsr write_next_byte ; buttons
}
	lda #0
	jsr write_next_byte
	jmp write_next_byte ; menu word

z_ins_mouse_window
	; mouse_window window: -1 (free) or a window number the mouse is confined to
!ifdef TRACE_SCREEN {
	jsr print_following_string
	!pet "z_ins_mouse_window ",0
	jsr newline
}
!ifdef Z6_FCM_MODE {
	lda z_operand_value_high_arr
	cmp #$ff			; -1 means free
	beq +
	lda z_operand_value_low_arr
	and #7
	sta mouse_window
	rts
+	lda #$ff
	sta mouse_window
}
	rts
 
z_ins_put_wind_prop
	; put_wind_prop window property-number value
	; Note: a game should only use put_wind_prop to set the
	; newline interrupt routine, the interrupt countdown and
	; the line count, everything else is either set by the
	; interpreter or by specialised opcodes (such as set_font)
!ifdef TRACE_SCREEN {
	jsr print_following_string
	!pet "z_ins_put_wind_prop ",0
	jsr newline
}
	ldx #0
	jsr window_from_operand
	sta .pwp_window
	lda z_operand_value_low_arr + 1
	asl ; * 8
	asl
	asl
	clc
	adc .pwp_window
	tay
	lda z_operand_value_low_arr + 2
	sta window_y,y
	rts

.pwp_window !byte 0
 
z_ins_print_form
	; print_form formatted-table
	; The table is a sequence of lines, terminated by a zero word. Each line
	; is a word holding a character count, followed by that many ZSCII bytes.
!ifdef TRACE_SCREEN {
	jsr print_following_string
	!pet "z_ins_print_form ",0
	jsr newline
}
	lda z_operand_value_high_arr
	ldx z_operand_value_low_arr
	jsr set_z_address
.pf_next_line
	jsr read_next_byte
	sta .pf_count + 1
	jsr read_next_byte
	sta .pf_count
	ora .pf_count + 1
	beq .pf_done ; a zero word ends the table
-	jsr read_next_byte
	jsr streams_print_output
	lda .pf_count
	bne +
	dec .pf_count + 1
+	dec .pf_count
	lda .pf_count
	ora .pf_count + 1
	bne -
	lda #13
	jsr streams_print_output
	jmp .pf_next_line
.pf_done
	rts

.pf_count !byte 0,0

z_ins_make_menu
	; make_menu number table ?(label)
!ifdef TRACE_SCREEN {
	jsr print_following_string
	!pet "z_ins_make_menu ",0
	jsr newline
}
	jmp make_branch_false
 
z_ins_picture_table
	; picture_table table
!ifdef TRACE_SCREEN {
	jsr print_following_string
	!pet "z_ins_picture_table ",0
	jsr newline
}
	rts

;init_screen_colours_invisible
;	lda zcolours + BGCOL
;	bpl + ; Always branch
init_screen_colours
	jsr s_init
	; calculate the position for the more prompt
	; (self modifying code since we don't want to
	; ZP space is limited)
!ifndef TARGET_X16 {
	lda s_screen_size + 1
	clc
	adc #>SCREEN_ADDRESS
	sta .more_access1 + 2
	sta .more_access2 + 2
	sta .more_access4 + 2
	lda s_screen_size + 1
	clc
	adc #>COLOUR_ADDRESS
!ifndef BENCHMARK {
	sta .more_access3 + 2
}
	lda s_screen_size
	sec
	sbc #1
	sta .more_access1 + 1
	sta .more_access2 + 1
!ifndef BENCHMARK {
	sta .more_access3 + 1
}
	sta .more_access4 + 1
}
	; colours
!ifdef NODARKMODE {
	lda zcolours + FGCOL
!if BORDERCOL_FINAL = 1 {
	+SetBorderColour
}
+	jsr s_set_text_colour
	lda zcolours + BGCOL
	+SetBackgroundColour
!if BORDERCOL_FINAL = 0 {
	+SetBorderColour
} else {
	!if BORDERCOL_FINAL != 1 {
		lda zcolours + BORDERCOL_FINAL
		+SetBorderColour
	}
}
!if CURSORCOL = 1 {
	lda zcolours + FGCOL
} else {
	lda zcolours + CURSORCOL
}
	sta current_cursor_colour
!ifdef Z5PLUS {
	; store default colours in header
	lda #BGCOL ; blue
	ldy #header_default_bg_colour
	jsr write_header_byte
	lda #FGCOL ; white
	ldy #header_default_fg_colour
	jsr write_header_byte
}
} else { ; Darkmode is available
	lda darkmode
	eor #1
	sta darkmode
	jsr toggle_darkmode
}
	lda #147 ; clear screen
	jmp s_printchar
; !ifndef NODARKMODE {
	; lda darkmode
	; beq +
	; dec darkmode
	; jmp toggle_darkmode
; +	
; }
;	rts	

!ifdef Z4PLUS {
z_ins_erase_window
	; erase_window window (0-7, -1 = unsplit + clear screen, -2 = clear screen)
	jsr printchar_flush
	jsr save_cursor
	ldx z_operand_value_low_arr
;    jmp erase_window ; Not needed, since erase_window follows
}

erase_window
	; x = window number, $ff (-1) or $fe (-2)
	cpx #$fe
	bcs .erase_whole_screen
	; erase a single window (0-7)
	jsr .erase_window_rect
	ldx .rect_win
	jmp .home_cursor
.erase_whole_screen
	cpx #$ff
	bne +
	; -1: unsplit - window 0 fills the screen and is selected
	lda #0
	sta current_window
	sta window_y
	sta window_x
	lda s_screen_height
	sta window_y_size
	lda s_screen_width
	sta window_x_size
+
!ifdef Z6_ECM_MODE {
	jsr ecm_update_bits
}
	lda #147 ; clear screen
	jsr s_printchar
	ldx current_window
.home_cursor
	; move the erased window's cursor to its top left corner, inside the
	; left margin (the cursor always lies between the margins, see 8.8.3.2.2.1)
	lda window_y,x
	sta window_y_cursor,x
	jsr s_window_left_edge
	sta window_x_cursor,x
	lda #0
	sta window_linecount,x ; the window is empty again
	; put the live cursor back where the current window wants it
	jsr restore_cursor
	jmp start_buffering

.erase_window_rect
	; erase the screen rectangle of window x (fills it with spaces
	; in the current colours, using s_delete_cursor so all targets work)
	stx .rect_win
!ifdef Z6_ECM_MODE {
	jsr ecm_set_bits_for_window ; fill with this window's background colour
	ldx .rect_win
}
	lda window_y_size,x
	beq .rect_done
	sta .rect_rows_left
	lda window_y,x
	sta zp_screenrow
.rect_row_loop
	lda zp_screenrow
	cmp s_screen_height
	bcs .rect_done
	ldx .rect_win
	lda window_x_size,x
	beq .rect_done
	sta .rect_cols_left
	ldy window_x,x
	ldx zp_screenrow
	clc
	jsr s_plot ; set row/column and update screen pointers
.rect_col_loop
	ldy zp_screencolumn
	jsr s_delete_cursor ; writes a space at the cursor position
	inc zp_screencolumn
	dec .rect_cols_left
	bne .rect_col_loop
	inc zp_screenrow
	dec .rect_rows_left
	bne .rect_row_loop
.rect_done
!ifdef Z6_ECM_MODE {
	jmp ecm_update_bits ; back to the current window's background colour
}
	rts

.rect_win       !byte 0
.rect_rows_left !byte 0
.rect_cols_left !byte 0

!ifdef Z4PLUS {
z_ins_erase_line
	; erase_line value
	; clear current line (where the cursor is)
	lda z_operand_value_low_arr
	cmp #1
	bne .return
	jmp s_erase_line_from_cursor
.return
	rts

!ifdef Z5PLUS {
.pt_cursor = z_temp;  !byte 0,0
.pt_width = z_temp + 2 ; !byte 0
.pt_height = z_temp + 3; !byte 0
.pt_skip = z_temp + 4; !byte 0,0
.current_col = z_temp + 6; !byte 0

z_ins_print_table
	; print_table zscii-text width [height = 1] [skip]
	; ; defaults
	lda #1
	sta .pt_height
	lda #0
	sta .pt_skip
	sta .pt_skip + 1
	; Read args
	lda z_operand_value_low_arr + 1
	beq .print_table_done
	sta .pt_width
	ldy z_operand_count
	cpy #3
	bcc ++
	lda z_operand_value_low_arr + 2
	beq .print_table_done
	sta .pt_height
+   cpy #4
	bcc ++
	lda z_operand_value_low_arr + 3
	sta .pt_skip
	lda z_operand_value_high_arr + 3
	sta .pt_skip + 1
++	lda .pt_height
	cmp #1
	beq .print_table_oneline
; start printing multi-line table
	jsr printchar_flush
	jsr get_cursor ; x=row, y=column
	stx .pt_cursor
	sty .pt_cursor + 1
	lda z_operand_value_high_arr ; Start address
	ldx z_operand_value_low_arr
--	jsr set_z_address
	ldx .pt_cursor + 1
	stx .current_col
	ldy .pt_width
-	jsr read_next_byte
	ldx .current_col
	cpx s_screen_width
	bcs +
	jsr streams_print_output
+	inc .current_col
	dey
	bne -
	dec .pt_height
	beq .print_table_done
; Move cursor to start of next line to print
	inc .pt_cursor
	ldx .pt_cursor
	ldy .pt_cursor + 1
	jsr set_cursor
; Skip the number of bytes requested
	jsr get_z_address
	pha
	txa
	clc
	adc .pt_skip
	tax
	pla
	adc .pt_skip + 1
	bcc -- ; Always jump
.print_table_done	
	rts
.print_table_oneline
	lda z_operand_value_high_arr ; Start address
	ldx z_operand_value_low_arr
	jsr set_z_address
	ldy .pt_width
-	jsr read_next_byte
	jsr translate_zscii_to_petscii
	bcs + ; Illegal char
	jsr printchar_buffered
+	dey
	bne -
	rts
}

z_ins_buffer_mode 
	; buffer_mode flag
	; If buffer mode goes from 0 to 1, remember the start column
	; If buffer mode goes from 1 to 0, flush the buffer 
	
	lda z_operand_value_low_arr
	beq +
	lda #1
+	cmp is_buffered_window
	beq .buffer_mode_done
; Buffer mode changes
	sta is_buffered_window ; set lower window to buffered or unbuffered mode
	cmp #0
	bne start_buffering
	jsr printchar_flush
.buffer_mode_done
	rts

}

start_buffering
	; the buffer always belongs to the current window, and buffer
	; positions are absolute screen columns
	jsr get_cursor ; y = column
	sty first_buffered_column
	sty buffer_index
	ldy #0
	sty last_break_char_buffer_pos
	rts

z_ins_split_window
	; split_window lines
	ldx z_operand_value_low_arr
;    jmp split_window ; Not needed since split_window follows

split_window
!ifdef SMOOTHSCROLL {
	jsr wait_smoothscroll
}
	; x = number of lines for window 1 at the top; 0 = unsplit
	; both windows become full width (v6 behaviour of this opcode)
	cpx s_screen_height
	bcc +
	ldx s_screen_height
+	stx window_y_size + 1
	stx window_y
	lda #0
	sta window_y + 1
	sta window_x
	sta window_x + 1
	lda s_screen_width
	sta window_x_size
	sta window_x_size + 1
	lda s_screen_height
	sec
	sbc window_y
	sta window_y_size
	lda current_window
	beq .ensure_cursor_in_window
	cmp #1
	bne .do_nothing
	; Window 1 was selected => Reset cursor if outside window
	jsr get_cursor
	cpx window_y ; window 0's top row = bottom edge of window 1
	bcc .do_nothing
	ldx #0
	ldy #0
	jmp set_cursor
.do_nothing
	rts
.ensure_cursor_in_window
	jsr get_cursor
	cpx window_y
	bcs .do_nothing
	ldx window_y
	ldy #0
	jmp set_cursor

z_ins_set_window
	;  set_window window
	jsr printchar_flush ; the print buffer belongs to the old window
	jsr save_cursor
	lda z_operand_value_low_arr
	and #7
	sta current_window
!ifdef Z6_ECM_MODE {
	jsr ecm_update_bits ; print in the new window's background colour
}
	jsr restore_cursor ; each window keeps its own cursor
	jmp start_buffering

!ifdef Z4PLUS {
z_ins_set_text_style
	lda z_operand_value_low_arr
	bne .t0
	; roman
	lda #146 ; reverse off
	jmp s_printchar
.t0 cmp #1
	bne .do_nothing
	lda #18 ; reverse on
	jmp s_printchar

z_ins_get_cursor
	; get_cursor array
	; returns the cursor position of the current window,
	; window-relative and 1-based
	ldx z_operand_value_low_arr
	lda z_operand_value_high_arr
	jsr set_z_address
	jsr get_cursor ; x=row, y=column (absolute, 0-based)
	txa
	ldx current_window
	sec
	sbc window_y,x
	pha
	tya
	sec
	sbc window_x,x
	tay
	iny ; In Z-machine, cursor has position 1+
	pla
	tax
	inx ; In Z-machine, cursor has position 1+
	lda #0
	jsr write_next_byte
	txa
	jsr write_next_byte
	lda #0
	jsr write_next_byte
	tya
	jmp write_next_byte

z_ins_set_cursor
	; set_cursor line column [window]
	; coordinates are 1-based and relative to the window
	ldy current_window
	lda z_operand_count
	cmp #3
	bcc +
	lda z_operand_value_low_arr + 2
	and #7
	tay
+	; y = window to move the cursor in
	ldx z_operand_value_low_arr ; line 1..
	beq + ; If line is 0, it's a mistake - they mean line 1.
	dex ; line 0..
+	txa
	clc
	adc window_y,y
	sta window_y_cursor,y
	ldx z_operand_value_low_arr + 1 ; column 1..
	beq +
	dex
+	txa
	clc
	adc window_x,y
	sta window_x_cursor,y
	cpy current_window
	bne .do_nothing_2
	jmp restore_cursor ; make the move visible immediately
}

clear_num_rows
	; every window counts its own printed lines (property 15)
	lda #0
	ldx current_window
	sta window_linecount,x
.do_nothing_2
	rts

.window_rows_minus_one
	; a = number of lines in the current window, minus one
	; y = current window. x is preserved.
	ldy current_window
	lda window_y,y
	clc
	adc window_y_size,y
	cmp s_screen_height
	bcc +
	lda s_screen_height
+	sec
	sbc window_y,y
	sec
	sbc #1
	rts

!ifdef TARGET_C128 {
vdc_set_more_char_address
    lda #$cf ; low
    ldy #$07 ; high
    jmp VDCSetAddress

vdc_set_more_colour_address
    lda #$cf ; low
    ldy #$0f ; high
    jmp VDCSetAddress

vdc_show_more
	; character
	jsr vdc_set_more_char_address
	ldx #VDC_DATA
	jsr VDCReadReg
	sta .more_text_char
	jsr vdc_set_more_char_address
	lda #128 + $2a ; screen code for reversed "*"
	ldx #VDC_DATA
	jsr VDCWriteReg
	; colour
	jsr vdc_set_more_colour_address
	ldy s_colour
	lda vdc_vic_colours,y
	ldx #VDC_DATA
	jmp VDCWriteReg

vdc_hide_more
	jsr vdc_set_more_char_address
	lda .more_text_char
	ldx #VDC_DATA
	jmp VDCWriteReg
}

!ifdef TARGET_X16 {

.vera_more_temp !byte 0
vera_show_more
	sty .vera_more_temp
	lda s_screen_height_minus_one
	sta zp_screenline + 1
	lda #$2a + 128
	bne .vera_common_more ; Always branch

vera_hide_more
	sty .vera_more_temp
	lda s_screen_height_minus_one
	sta zp_screenline + 1
	lda #32
.vera_common_more
	ldy s_screen_width_minus_one
	jsr VERAPrintChar
	; lda s_colour
	; jsr VERAPrintColourAfterChar
	lda zp_screenrow
	sta zp_screenline + 1
	ldy .vera_more_temp
	rts
}



increase_num_rows
	ldx current_window
	lda window_attributes,x
	and #WIN_BUFFERED
	beq .increase_num_rows_done ; An unbuffered window never shows [More]
	inc window_linecount,x
	lda is_buffered_window
	beq .increase_num_rows_done
	jsr .window_rows_minus_one
	cmp window_linecount,y
	bcs .increase_num_rows_done
show_more_prompt
	; time to show [More]
	jsr clear_num_rows
!ifndef TARGET_X16 {
	jsr .set_more_prompt_pos
}

!ifdef TARGET_C128 {
    bit COLS_40_80
    bpl +
    ; 80 columns
	jsr vdc_show_more
	jmp .alternate_colours
    ; 40 columns
+
}
.more_access1
	lda SCREEN_ADDRESS + (SCREEN_WIDTH*SCREEN_HEIGHT-1)
	sta .more_text_char
!ifdef Z6_ECM_MODE {
	; bit 7 selects a background register in ECM, so no reverse video
	lda #$2a ; screen code for "*"
	ora ecm_bits
} else {
	lda #128 + $2a ; screen code for reversed "*"
}
.more_access2
!ifndef TARGET_X16 {
	sta SCREEN_ADDRESS + (SCREEN_WIDTH*SCREEN_HEIGHT-1)
} else {
	lda $8000
}

	; wait for ENTER
.alternate_colours
!ifndef BENCHMARK {
--	ldx s_colour
!ifdef TARGET_PLUS4 {
	lda plus4_vic_colours,x
	tax
}
	iny
	tya
	and #1
	beq +
!ifdef TARGET_C128 {
	bit COLS_40_80
	bpl +++
	; 80 columns
	jsr vdc_hide_more
	jmp ++
	; 40 columns
+++	ldx reg_backgroundcolour
} else ifdef TARGET_X16 {
	jsr vera_hide_more
	jmp ++
} else {
	ldx reg_backgroundcolour
}
+
!ifdef TARGET_C128 {
	bit COLS_40_80
	bpl ++
	; 80 columns
	jsr vdc_show_more
} else ifdef TARGET_X16 {
	jsr vera_show_more
}
++
!ifdef TARGET_MEGA65 {
	jsr colour2k
}
.more_access3
!ifndef TARGET_X16 {
	stx COLOUR_ADDRESS + (SCREEN_WIDTH*SCREEN_HEIGHT-1)
} else {
	ldx $8000
}
!ifdef TARGET_MEGA65 {
	jsr colour1k
}
.check_for_keypress
	ldx #40
---
	jsr wait_a_jiffy
	jsr getchar_and_maybe_toggle_darkmode
	cmp #0
	bne +
	dex
	bne ---
	beq -- ; Always branch
+
}
!ifdef TARGET_C128 {
    bit COLS_40_80
    bpl +
    ; 80 columns
	jsr vdc_hide_more
	jmp .increase_num_rows_done
    ; 40 columns
+
}
	lda .more_text_char
.more_access4
!ifndef TARGET_X16 {
	sta SCREEN_ADDRESS + (SCREEN_WIDTH*SCREEN_HEIGHT -1)
} else {
	lda $8000
	jsr vera_hide_more
}
.increase_num_rows_done
	rts

.more_text_char !byte 0

!ifndef TARGET_X16 {
.set_more_prompt_pos
	; Point the [More] prompt at the bottom right cell of the current
	; window, by rewriting the addresses in .more_access1-4. In z6 every
	; window has its own rectangle, so this can't be a fixed address.
	jsr get_cursor ; x=row, y=column
	stx .more_saved_row
	sty .more_saved_column
	ldx current_window
	; last column of the window, clamped to the screen
	lda window_x,x
	clc
	adc window_x_size,x
	cmp s_screen_width
	bcc +
	lda s_screen_width
+	sec
	sbc #1
	pha
	; last row of the window, clamped to the screen
	lda window_y,x
	clc
	adc window_y_size,x
	cmp s_screen_height
	bcc +
	lda s_screen_height
+	sec
	sbc #1
	tax
	pla
	tay
	clc
	jsr s_plot ; sets zp_screenline/zp_colourline for that row
	; the cell's address is the start of the line plus the column
!ifdef Z6_FCM_MODE {
	lda zp_screencolumn ; a cell is two bytes wide
	asl
	sta .more_cell_offset
} else {
	lda zp_screencolumn
	sta .more_cell_offset
}
	lda zp_screenline
	clc
	adc .more_cell_offset
	sta .more_access1 + 1
	sta .more_access2 + 1
	sta .more_access4 + 1
	lda zp_screenline + 1
	adc #0
	sta .more_access1 + 2
	sta .more_access2 + 2
	sta .more_access4 + 2
!ifndef BENCHMARK {
	lda zp_colourline
	clc
	adc .more_cell_offset
	sta .more_access3 + 1
	lda zp_colourline + 1
	adc #0
	sta .more_access3 + 2
}
	; put the cursor back where the text is being printed
	ldx .more_saved_row
	ldy .more_saved_column
	clc
	jmp s_plot

.more_saved_row    !byte 0
.more_saved_column !byte 0
.more_cell_offset  !byte 0
}

printchar_flush
	; flush the printchar buffer into the current window
	lda s_reverse
	pha

	ldx first_buffered_column
	cpx buffer_index
	bcs +

	ldx buffer_index
	dex
	stx last_break_char_buffer_pos
	jsr print_line_from_buffer
	
	bcs + ; The line couldn't be printed
	ldx buffer_index
	dex
	lda print_buffer2,x
	sta s_reverse
	lda print_buffer,x
	jsr s_printchar
+

	; ldx first_buffered_column
; -   cpx buffer_index
	; bcs +
	; lda print_buffer2,x
	; sta s_reverse
	; lda print_buffer,x
	; jsr s_printchar
	; inx
	; bne -

+	pla
	sta s_reverse
	jmp start_buffering

print_line_from_buffer
	; Prints the text from first_buffered_column to last_break_char_buffer_pos
	ldx window_y
	cpx s_screen_height
	bcc +
	; There is no free line to print on, return with carry set
	rts
+
!ifdef TARGET_C128 {
	bit COLS_40_80
	bmi +
	jmp .printline40

+	lda zp_screenline + 1
	sec
	sbc #$04 ; adjust from $0400 (VIC-II) to $0000 (VDC)
	tay
	lda zp_screenline
	clc
	adc zp_screencolumn
	bcc +
	iny
+	jsr VDCSetAddress
	ldy #VDC_DATA
	sty VDC_ADDR_REG

	ldx first_buffered_column
-   cpx last_break_char_buffer_pos
	bcs .done_print_80
	lda print_buffer,x
	jsr convert_petscii_to_screencode
	ora print_buffer2,x
--	bit     VDC_ADDR_REG
	bpl --
	sta VDC_DATA_REG
	inx
	bne - ; Always branch

.done_print_80	

	lda last_break_char_buffer_pos
	sec
	sbc first_buffered_column

!ifdef COLOURFUL_LOWER_WIN {

	pha ; Char count

	; ; Fill relevant portion of colour RAM (start at offset $1800) with the game's foreground colour
	lda zp_colourline + 1
	sec
	sbc #$d0 ; adjust from $d800 (VIC-II) to $0800 (VDC)
	tay
	lda zp_colourline
	clc
	adc zp_screencolumn
	bcc +
	iny
+	jsr VDCSetAddress

	ldx s_colour
	lda vdc_vic_colours,x
	ora #$80 ; Bit 7 = charset, bit 0-4 = fg colour
	ldx #VDC_DATA
	jsr VDCWriteReg
	; We have written default fg colour to the first position in colour RAM. Now fill the rest positions.
	lda #0 ; Set to Fill mode ; Not needed, we have 0 in A
	ldx #VDC_VSCROLL
	jsr VDCWriteReg
	ldx #VDC_COUNT
	pla
	sec
	sbc #1
	jsr VDCWriteReg
	
.dont_colour_80	
}
	jmp .done_print_line_from_buffer
	
.printline40
}

!ifdef TARGET_X16 {
	ldy first_buffered_column
	cpy last_break_char_buffer_pos
	bcs ++
	lda print_buffer2,y
	sta s_reverse
	lda print_buffer,y
	jsr s_printchar
	iny
	dec zp_screencolumn ; I have no idea why we need to do this, but we do...

	; Keep colour + background in x
	ldx vera_composite_colour
	; lda s_colour
	; ora vera_background
	; tax
	
-   cpy last_break_char_buffer_pos
	bcs ++
	lda print_buffer,y
	jsr convert_petscii_to_screencode
	ora print_buffer2,y
	sta VERA_data0
	stx VERA_data0
	iny
	bne - ; Always branch
++
	
} else ifdef Z6_FCM_MODE {
		jsr colour2k
		; y indexes the print buffer by column, but a screen cell is two
		; bytes, so double it for the store and halve it again afterwards.
		ldy first_buffered_column
-		cpy last_break_char_buffer_pos
		bcs ++
		lda print_buffer,y
		jsr convert_petscii_to_screencode
		ora print_buffer2,y
		pha
		tya
		asl
		tay
		pla
		sta (zp_screenline),y
		+clear_cell_high_byte
		lda s_colour
		sta (zp_colourline),y ; the colour pointer is biased by one
		tya
		lsr
		tay
		iny
		bne - ; Always branch
++
		jsr colour1k
} else {
	!ifdef TARGET_MEGA65 {
		jsr colour2k	
	}
		ldy first_buffered_column
-		cpy last_break_char_buffer_pos
		bcs ++
		lda print_buffer,y
		jsr convert_petscii_to_screencode
	!ifdef Z6_ECM_MODE {
		and #$3f ; only 64 characters, and the top bits select the background
		ora ecm_bits
	} else {
		ora print_buffer2,y
	}
		sta (zp_screenline),y
		+clear_cell_high_byte
	!ifdef COLOURFUL_LOWER_WIN {
	!ifdef TARGET_PLUS4 {
		ldx s_colour
		lda plus4_vic_colours,x
	} else {
		lda s_colour
	}
		sta (zp_colourline),y
	}
		iny
		bne - ; Always branch

++	
	!ifdef TARGET_MEGA65 {
		jsr colour1k
	}
}

.done_print_line_from_buffer
	lda last_break_char_buffer_pos
	sec
	sbc first_buffered_column
	clc
	adc zp_screencolumn
	sta zp_screencolumn

	clc
	rts

printchar_buffered
	; a is PETSCII character to print
	sta .buffer_char
	cmp #13
	beq +
	sta anything_printed
+	
	; need to save x,y
	txa
	pha
	tya
	pha
	; is this a buffered window?
	ldx current_window
	lda window_attributes,x
	and #WIN_BUFFERED
	beq .is_not_buffered
	lda is_buffered_window ; global flag, set by the buffer_mode opcode
	bne .buffered_window
.is_not_buffered
	lda .buffer_char
	jsr s_printchar
	jmp .printchar_done
	; update the buffer
.buffered_window
	; calculate the left edge and right edge (exclusive) of the current
	; window's text area; buffer positions are absolute screen columns
	ldx current_window
	jsr s_window_left_edge
	sta .buffer_left
	jsr s_window_right_edge
	sta .buffer_edge
	lda .buffer_char
	; add this char to the buffer
	cmp #$0d
	bne .check_break_char
	jsr printchar_flush
	; more on the same line
	jsr increase_num_rows
	lda #$0d
	jsr s_printchar
	jsr start_buffering
	jmp .printchar_done
.check_break_char
	ldy buffer_index
	cpy .buffer_edge
	bcs .add_char ; Don't register break chars on last position of buffer.
	cmp #$20 ; Space
	beq .break_char
	cmp #$2d ; -
	bne .add_char
.break_char
	; update index to last break character
	sty last_break_char_buffer_pos
.add_char
	ldx .buffer_edge
	sta print_buffer,y
	lda s_reverse
	sta print_buffer2,y
	iny
	sty buffer_index
	cpy .buffer_edge ; right edge of the current window
	beq ++ 
	bcs + ; Clear case - always print a line

-	jmp .printchar_done

++	; Print a line *if* we're on last line of a windowful of text
	jsr .window_rows_minus_one ; x is preserved
	cmp window_linecount,y
	bne - ; Not on last line
	dex
+
	; print the line until last space
	; First calculate max# of characters on line
	; ldx s_screen_width
	; lda s_screen_height
	; sec
	; sbc window_y
	; sbc #1
	; cmp num_rows
	; bne +
	; dex ; Max 39 chars on last line on screen.
; +	
	stx max_chars_on_line
	; Check if we have a "perfect space" - a space after 40 characters
	lda print_buffer,x
	cmp #$20
	beq .print_40_2 ; Print all in buffer, regardless of which column buffering started in
	; Now find the character to break on
	ldy last_break_char_buffer_pos
	beq .print_40 ; If there are no break characters on the line, print all 40 characters
	; Check if the break character is a space
	lda print_buffer,y
	cmp #$20
	beq .print_buffer
	iny
	bne .store_break_pos ; Always branch
.print_40
	; If we can't find a place to break, and buffered output started after the window's left edge, print a line break and move the text in the buffer to the next line.
	ldx first_buffered_column
	cpx .buffer_left
	beq .print_40_2
	jmp .move_remaining_chars_to_buffer_start
.print_40_2	
	ldy max_chars_on_line
.store_break_pos
	sty last_break_char_buffer_pos
.print_buffer
	lda s_reverse
	pha

	dec last_break_char_buffer_pos ; Print last character using normal print routine, to avoid trouble

	jsr print_line_from_buffer

	ldx last_break_char_buffer_pos
	inc last_break_char_buffer_pos ; Restore old value, since we decreased it by one before

	bcs + ; The line couldn't be printed
	; Print last character
	lda print_buffer2,x
	sta s_reverse
	lda print_buffer,x
	jsr s_printchar
+
	inx

	pla
	sta s_reverse

.move_remaining_chars_to_buffer_start
	; Skip initial spaces, move the rest of the line back to the window's left edge and update indices
	ldy .buffer_left
	cpx buffer_index
	beq .after_copy_loop
	lda print_buffer,x
	cmp #$20
	bne .copy_loop
	inx
.copy_loop
	cpx buffer_index
	beq .after_copy_loop
	lda print_buffer,x
	sta print_buffer,y
	lda print_buffer2,x
	sta print_buffer2,y
	iny
	inx
	bne .copy_loop ; Always branch
.after_copy_loop
	sty buffer_index
	lda .buffer_left
	sta first_buffered_column
	; more on the same line
	jsr increase_num_rows
	lda last_break_char_buffer_pos
	cmp .buffer_edge
	bcs +
	lda #$0d
	jsr s_printchar
+   ldy #0
	sty last_break_char_buffer_pos
.printchar_done
	pla
	tay
	pla
	tax
	rts
anything_printed       !byte 0
.buffer_char       !byte 0
.buffer_left       !byte 0
.buffer_edge       !byte 0
; print_buffer            !fill 41, 0
.save_x			   !byte 0
.save_y			   !byte 0
first_buffered_column !byte 0

clear_screen_raw
	lda #147
	jsr s_printchar
	rts

printstring_raw
; Parameters: Address in a,x to 0-terminated string
	stx .read_byte + 1
	sta .read_byte + 2
	ldx #0
.read_byte
	lda $8000,x
	beq +
	jsr s_printchar
	inx
	bne .read_byte
+	rts
	

save_cursor
	; remember the live cursor position in the current window's
	; cursor properties (absolute screen coordinates)
	jsr get_cursor
	tya
	ldy current_window
	sta window_x_cursor,y
	txa
	sta window_y_cursor,y
	rts

restore_cursor
	; move the live cursor to the current window's stored position
	ldy current_window
	ldx window_y_cursor,y
	lda window_x_cursor,y
	tay
;	jmp set_cursor

set_cursor
	; input: y=column (0-39)
	;        x=row (0-24)
	clc
	jmp s_plot

get_cursor
	; output: y=column (0-39)
	;         x=row (0-24)
	sec
	jmp s_plot

!ifndef Z4PLUS {

.statusline_temp = z_operand_value_low_arr + 4
.num_width_temp = z_operand_value_high_arr + 4;

number_print_width
; a,x = signed number (a is HB)
; Returns: y = number of characters
	ldy #1 ; Base length
;	sty .num_width_temp
	cmp #$80
	bcc + ; Positive number
	iny ; Add 1 for minus
	eor #$ff
	pha
	txa
	eor #$ff
	adc #0 ; Carry is set, so this adds 1
	tax
	pla
	adc #0
+	sta .num_width_temp + 1
	cpx #10
	sbc #0
	bcc ++ ; Done
	iny
	lda .num_width_temp + 1
	cpx #100
	sbc #0
	bcc ++
	iny
	lda .num_width_temp + 1
	cpx #<1000
	sbc #>1000
	bcc ++
	iny
	lda .num_width_temp + 1
	cpx #<10000
	sbc #>10000
	bcc ++
	iny
++	rts

statusline_print_room
	; Input:
	; y = columns to the right that don't need emptying

	sty .statusline_temp + 1
	;
	; Room name
	; 
	; name of the object whose number is in the first global variable
	lda #16
	jsr z_get_low_global_variable_value
	jsr print_obj

	; Make sure cursor is on top row
	sec
	jsr s_plot
	cpx #0
	beq +
	; Cursor was moved down (object name probably contains a newline character). Put cursor on top row again.
	ldx #0
	clc
	jsr s_plot
+
	;
	; fill the rest of the line with spaces
	;
	lda s_screen_width
	sec
	sbc .statusline_temp + 1
	sta .statusline_temp + 1
-   lda zp_screencolumn
	cmp .statusline_temp + 1
	bcs +
	lda #$20
	jsr s_printchar
	jmp -
+   rts
	
z_ins_show_status
	; show_status (hardcoded size)

draw_status_line
	lda current_window
	pha
	jsr save_cursor
	lda #2
	sta current_window
	ldx #0
	ldy #0
	jsr set_cursor
	lda #18 ; reverse on
	jsr s_printchar
	ldx darkmode
	ldy statuslinecol,x 
	lda zcolours,y
	jsr s_set_text_colour

!ifdef TARGET_X16 {
	lda s_screen_width
	cmp #30
	bcs +
	ldy #0
	jsr statusline_print_room
	jmp .statusline_done
+
}

	;
	; score or time game?
	;

!ifdef Z3 {
	ldy #header_flags_1
	jsr read_header_word
	and #$02
	beq +
	jmp .timegame
+
}
	; score game
	lda z_operand_value_low_arr
	pha
	lda z_operand_value_high_arr
	pha
	lda z_operand_value_low_arr + 1
	pha
	lda z_operand_value_high_arr + 1
	pha

	; If we get here, the screen is 32, 40, 64 or 80 columns
!ifdef SUPPORT_80COL {
	lda s_screen_width
	cmp #60
	bcc + 
	jmp .print_score_64 ; 64+ wide statusline 
+
}
	lda #17
	jsr z_get_low_global_variable_value
	jsr number_print_width
	sty .statusline_temp
	lda #18
	jsr z_get_low_global_variable_value
	jsr number_print_width
;	sty .statusline_temp + 1
	tya
	clc
	adc .statusline_temp
	sta .statusline_temp

	ldx #0

!ifdef TARGET_X16 {
	lda s_screen_width
	cmp #35
	bcs +++
; .print_score_32
; 12345678901234567890123456789012
; A Cave                  123:1234
	ldy .statusline_temp
	iny
	iny
	jsr statusline_print_room

	lda s_screen_width
	sec
	sbc .statusline_temp
	sbc #2
	tay
	jsr set_cursor
	lda #32
	jsr s_printchar
	lda #17
	jsr print_low_global_variable_value
	lda #58
	jsr s_printchar
	jmp .print_moves
+++
}
	; If we get here, the screen is 40 columns

; 1234567890123456789012345678901234567890
; A Cave                    Sc:123 Mv:1234

!ifndef TARGET_MEGA65 {
; .print_score_40
	lda .statusline_temp
	clc
	adc #8
	tay	
	jsr statusline_print_room

	lda s_screen_width
	sec
	sbc .statusline_temp
	sbc #8
	tay
	jsr set_cursor
	; Print " Sc:"
	lda #>.score_short_str
	ldx #<.score_short_str
	jsr printstring_raw
	lda #17
	jsr print_low_global_variable_value
	; Print " Mv:"
	lda #>.turns_short_str
	ldx #<.turns_short_str
	jsr printstring_raw
	jmp .print_moves
}

!ifdef SUPPORT_80COL {
.print_score_64
; 1234567890123456789012345678901234567890123456789012345678901234
; A Cave                                 Score: 123  Moves: 1234

	ldy #26
	jsr statusline_print_room

	; Print " Score: "
	lda s_screen_width
	sec
	sbc #26
	tay
	jsr set_cursor
	lda #>.score_str
	ldx #<.score_str
	jsr printstring_raw
	lda #17
	jsr print_low_global_variable_value
	jsr get_cursor
	sty .statusline_temp
	; Print " Moves: "
	lda s_screen_width
	sec
	sbc #14
	sbc .statusline_temp
	tay
-	lda #32
	jsr s_printchar
	dey
	bne -
	; ldx #0
	; jsr set_cursor
	lda #>.turns_str
	ldx #<.turns_str
	jsr printstring_raw
}
	
.print_moves
	lda #18
	jsr print_low_global_variable_value
!ifdef SUPPORT_80COL {
	lda s_screen_width
	cmp #60
	bcc +
	jsr get_cursor
	sty .statusline_temp
	sec
	sbc .statusline_temp
	tay
-	lda #32
	jsr s_printchar
	dey
	bne -
+
}	
.all_done_score_sl
	pla
	sta z_operand_value_high_arr + 1
	pla
	sta z_operand_value_low_arr + 1
	pla
	sta z_operand_value_high_arr
	pla
	sta z_operand_value_low_arr
	jmp .statusline_done

!ifdef Z3 {
.time_str !pet " Time: ",0
.ampm_str !pet " AM ",0

.print_clock_number
	sty z_temp + 11
	txa
	ldy #0
-	cmp #10
	bcc .print_tens
	sbc #10 ; C is already set
	iny
	bne - ; Always branch
.print_tens
	tax
	tya
	bne +
	lda z_temp + 11
	bne ++
+	ora #$30
++	jsr s_printchar
	txa
	ora #$30
	jmp s_printchar

.timegame
	; time game
	ldx #0
	lda s_screen_width
!ifdef TARGET_X16 {
	cmp #37
	bcs .normal_time

	; This is a 32 column screen (< 32 don't get to this point)
	ldy #9
	jsr statusline_print_room
	
	; Don't print " Time: " string
	ldx #0
	ldy #23
	jsr set_cursor
	jmp .print_time_data
.normal_time
}
	ldy #16
	jsr statusline_print_room

	lda s_screen_width
	sec
	sbc #16
	tay
	jsr set_cursor
	lda #>.time_str
	ldx #<.time_str
	jsr printstring_raw
.print_time_data
; Print hours
	lda #65 + 32
	sta .ampm_str + 1
	lda #17 ; hour
	jsr z_get_low_global_variable_value
; Change AM to PM if hour >= 12
	cpx #12
	bcc +
	lda #80 + 32
	sta .ampm_str + 1
+	cpx #0
	bne +
	ldx #12
; Subtract 12 from hours if hours >= 13, so 15 becomes 3 etc
+	cpx #13
	bcc +
	txa
	sbc #12
	tax
+	ldy #$20 ; " " before if < 10
	jsr .print_clock_number
	lda #58 ; :
	jsr s_printchar
; Print minutes
	lda #18 ; minute
	jsr z_get_low_global_variable_value
	ldy #$30 ; "0" before if < 10
	jsr .print_clock_number
; Print AM/PM
	lda #>.ampm_str
	ldx #<.ampm_str
	jsr printstring_raw
}
.statusline_done
	ldx darkmode
	ldy fgcol,x 
	lda zcolours,y
	jsr s_set_text_colour
	lda #146 ; reverse off
	jsr s_printchar
	pla
	sta current_window
	jmp restore_cursor

!ifndef TARGET_MEGA65 {
.score_short_str !pet " Sc:",0
.turns_short_str !pet " Mv:",0
}
!ifdef SUPPORT_80COL {
.score_str !pet " Score: ",0
.turns_str !pet " Moves: ",0
}
}

