; The z6 picture engine for the Commander X16: the same job as the MEGA65
; engine in pictures-mega65.asm (which this is a port of), done with VERA
; instead of the VIC-IV.
;
; The screen is two VERA layers. Text stays on layer 1 exactly as in the
; text-only build; the pictures live behind it on layer 0, a 64x32 map of
; 16x8-pixel 4bpp tiles. One tile is one logical cell of the 320-wide art
; (8x8 art pixels, each written twice as it is baked, so the art keeps its
; scale next to 8-pixel text, as on the MEGA65's 80-column screen). A text
; cell whose background nybble is 0 is transparent, so the picture shows
; through; drawing a picture never disturbs the text in front of it.
;
; The tile store is all of VRAM bank 0: 1024 tiles of 64 bytes. Tile 0 is
; reserved as the all-transparent tile an empty map cell shows, so runs
; start at PIC_FIRST_TILE. A map entry is the tile index (10 bits) plus a
; palette offset nybble, which is how each drawn picture keeps its own
; 16-colour bank: the bank rides in the map cells, not in the pixels, so
; the store holds raw colour indices 0..15 (0 transparent).
;
; Unlike the MEGA65 there is no attic RAM to preload into: a picture is
; LOADed from SD on demand, uncompressed, into a staging area of banked RAM
; just above the story (PIC_STAGING_BANK, from make.rb), and the staged
; picture is remembered so redrawing the same one (Arthur's frame, the
; status icons) does not touch the disk. picture_data answers from the
; assembled-in pic_width/pic_height tables, because the picture it asks
; about is usually not the one staged.
;
; A picture may be placed off the tile grid - at an odd text column (Arthur
; centres scenes), or, once the screen model reports pixels, at any art pixel
; inside a cell on either axis (Arthur's map lattice is 18 art pixels, so it
; needs both). .pic_shift and .pic_shift_y hold those offsets in art pixels,
; 0..7 each, and when either is non-zero the cells are generated from the
; staged picture instead of copied - see .pic_gen_fill and todo.txt.

; --- zero page, borrowed from z_temp like the MEGA65 engine ---
.pi_ptr  = z_temp			; 2 bytes, indexes the pic_* tables by .pic_index
.pic_att = z_temp + 2		; 3 bytes: pointer into the staging window at
							; $a000-$bfff (lo, hi), then the RAM bank
.pic_tmp = z_temp + 5		; 2 bytes of general scratch

; --- the engine's state ---
.pic_index   !byte 0,0		; word: a game may have more than 255 pictures
.pic_w       !byte 0		; text cells across (what picture_data reports)
.pic_h       !byte 0		; text cells down
.pic_cw      !byte 0		; art cells across: the file's own cell grid
.pic_ch      !byte 0		; art cells down
.pic_ntiles  !byte 0,0
.pic_slot    !byte 0,0		; the picture's first tile in the store
.pic_bank    !byte 0		; the palette bank being drawn with (1..14)
.pic_entry_hi !byte 0		; that bank in map-entry form: bank << 4
.pic_row     !byte 0
.pic_lx      !byte 0		; the picture's first layer 0 map column
.pic_cols_left !byte 0		; cells left on the row being filled or erased
.pic_vis     !byte 0		; how many of them are on screen (right clip)
.pic_shift   !byte 0		; art pixels the picture starts INTO its first map
.pic_shift_y !byte 0		; cell, across and down (0..7 each; both zero means
							; it lands on the tile grid and needs no generating)
.gen_mw      !byte 0		; map cells the picture spans, across and down:
.gen_mh      !byte 0		; cw + 1 and ch + 1 when shifted on that axis
.gen_next    !byte 0,0		; the next unused tile of the reserved run
.pic_ftiles  !byte 0,0		; the picture file's own (deduplicated) tile count,
							; kept because .pic_ntiles becomes the reservation
.gen_base    !byte 0,0,0	; what .pic_seek offsets from
.gen_tiles   !byte 0,0,0	; where the tile block starts in the staging banks
.gen_buf     !fill 64, 0	; one source art cell, unpacked to a byte a pixel
.gen_cx      !byte 0		; the source art cell being fetched; $ff, or past
.gen_cy      !byte 0		; .pic_cw / .pic_ch, means "off the picture"
.gen_sr      !byte 0		; .gen_blit's rectangle: source row/column in
.gen_sc      !byte 0		; .gen_buf, destination row/column in .pcf_buf,
.gen_dr      !byte 0		; and how many rows and columns to move
.gen_dc      !byte 0
.gen_nr      !byte 0
.gen_nc      !byte 0
.gen_rows    !byte 0		; its counters
.gen_cols    !byte 0
dbg_gen     !fill 10, 0	; DEBUG_PIC_GEN: state of the last generated draw
!ifdef DEBUG_PIC_GEN {
; A ring of the last 32 draws, 16 bytes each, so a screen built out of many
; pictures can be read back whole. Every draw is recorded, copied or generated:
; a picture that .pic_gen_size snapped back to the grid never reaches
; .pic_gen_fill, so its absence from a generated-only log would say nothing.
dbg_ring    !fill 512, 0
dbg_ring_at !byte 0			; the next entry, 0..31
dbg_req     !byte 0,0		; the shift .pic_map_pos asked for, before the fit
							; check in .pic_gen_size can take it away
}
.gen_left    !byte 0		; does either text half of the cell just built have
.gen_right   !byte 0		; an opaque pixel in it? (for blanking the text)
.pfo_m       !byte 0		; the fill's map cell counter, 0..gen_mw
.pfo_vis     !byte 0		; cells of the row still on screen
.pic_map     !byte 0,0,0	; where the cell map starts in the staging banks
.pic_count   !byte 0,0		; a general 16 bit counter
.pfc_lo      !byte 0		; a cell's tile index low byte while drawing
.pfc_hi      !byte 0		; and high byte
.pcf_under_lo !byte 0		; the map entry already in the cell (what's behind)
.pcf_under_hi !byte 0
.pcf_newcode_lo !byte 0		; the composited cell's map entry
.pcf_newcode_hi !byte 0
.pcf_buf     !fill 64, 0	; one tile being composited, two pixels a byte
.pcf_xlat    !fill 16, 0	; colour translation into the overlay's bank
.pcf_same_bank !byte 0

.cur_pic     !byte $ff,$ff	; the picture index staged in banked RAM; $ffff none

; A CPU-side copy of every loaded palette bank (VERA format: GGGGBBBB then
; 0000RRRR an entry), for translating colours when a composited cell has to
; show two pictures' pixels through one palette offset. Bank b at b * 32.
pic_bank_pal !fill 15 * 32, 0

; Tile-store compaction (.pic_gc): a bit per tile for "a cell outside the
; incoming picture still shows this", the survivor count below each bitmap
; byte, and the byte-arithmetic helper tables. 1024 tiles = 128 bitmap bytes.
.gc_bitmap   !fill 128, 0
.gc_pref_lo  !fill 128, 0
.gc_pref_hi  !fill 128, 0
.gc_bit      !byte 1, 2, 4, 8, 16, 32, 64, 128
.gc_below    !byte 0, 1, 3, 7, 15, 31, 63, 127
.gc_pop						; how many bits a byte has set
!for i, 0, 255 {
	!byte (i&1) + ((i>>1)&1) + ((i>>2)&1) + ((i>>3)&1) + ((i>>4)&1) + ((i>>5)&1) + ((i>>6)&1) + ((i>>7)&1)
}
.gc_row      !byte 0
.gc_col      !byte 0
.gc_y0       !byte 0		; the incoming rectangle in layer 0 map cells:
.gc_y1       !byte 0		; only cells it covers completely die with it
.gc_x0       !byte 0
.gc_x1       !byte 0
.gc_next     !byte 0,0		; the compacted store's next free tile
.gc_old      !byte 0,0		; the survivor being moved
.gc_byi      !byte 0		; bitmap byte index being walked
.gc_t        !byte 0
.gc_t2       !byte 0

; .pic_dub doubles a colour index into a byte of two identical 4bpp pixels
.pic_dub
!for i, 0, 15 {
	!byte i * $11
}

pic_next_tile  !byte PIC_FIRST_TILE, 0
pic_win_base   !fill 16, 0	; two bytes a window
pic_win_count  !fill 16, 0
pic_win_shift  !fill 8, 0	; the placement each window's run was built for
							; (.pa_pack_shift), one byte a window
pic_win_number !fill 16, $ff ; the picture index (a word, so two bytes a window)
							; resident in each window's run; $ffff = none. A
							; window's run may only be reused for the same picture;
							; a different one must not overwrite tiles the resident
							; picture's still-visible cells use.
; Each drawn picture gets its own palette bank of 16 entries, picked by the
; palette offset nybble in its map entries. Banks 1..PIC_PAL_BANKS sit above
; the 16 text colours (bank 0). Unlike the MEGA65 the bank never touches the
; pixels, so nothing needs baking when a bank is reassigned.
PIC_PAL_BANKS = 14
pic_next_bank  !byte 1
pic_win_bank   !fill 8, 0
; Which picture's palette each bank currently holds ($ffff = none), entry
; (bank - 1). A picture drawn again gets the bank it is already in, wherever
; and however it is placed and whatever window it goes to: a picture's palette
; is a property of the picture, so this is always right, and it is what keeps
; the fourteen banks from running out. Arthur's F2 map is the case that needs
; it - it redraws the same handful of pictures (paper, room boxes, connectors)
; dozens of times, and one bank per DRAW wrapped the allocator round onto banks
; the paper's own cells were still pointing at, which turned the map's brown
; background black on the second turn.
pic_bank_pic   !fill PIC_PAL_BANKS * 2, $ff
; The palette bank an adaptive picture (Blorb APal) draws in: that of the
; last direct picture drawn. Seeded with bank 1 in case an adaptive picture
; is somehow drawn before any direct one.
pic_direct_bank !byte 1

; ---------------------------------------------------------------------------
; make.rb writes the picture files into the game directory as [P004] etc,
; next to [ZCODE]. !pet lowercase becomes the host's uppercase, as it does
; for "[zcode],s,r" in ozmoo.asm.
pic_file_name !pet "[p000],s,r"
PIC_FILE_NAME_LEN = 10

.pic_addr
	; .pi_ptr = table base (a,x = lo,hi) + .pic_index, so a game with more than
	; 255 pictures can index the parallel pic_* tables past a single page. The
	; caller then reads or writes (.pi_ptr),y with y = 0.
	clc
	adc .pic_index
	sta .pi_ptr
	txa
	adc .pic_index + 1
	sta .pi_ptr + 1
	rts

pic_load_all
	; The MEGA65 preloads every picture into attic RAM here. The X16 has
	; nowhere to put half a megabyte, and does not need to: the SD card is
	; fast enough to LOAD a picture the moment it is drawn. Nothing staged yet.
	lda #$ff
	sta .cur_pic
	sta .cur_pic + 1
	rts

.pic_stage
	; Make sure the picture in .pic_index is in the staging banks, loading it
	; from SD if it is not the one already there.
	lda .pic_index
	cmp .cur_pic
	bne +
	lda .pic_index + 1
	cmp .cur_pic + 1
	bne +
	rts
+	lda #<pic_number_lo		; build the [Pnnn] filename from the number
	ldx #>pic_number_lo
	jsr .pic_addr
	lda (.pi_ptr)
	sta .pic_num
	lda #<pic_number_hi
	ldx #>pic_number_hi
	jsr .pic_addr
	lda (.pi_ptr)
	sta .pic_num + 1
	jsr .pic_set_filename

	lda #PIC_FILE_NAME_LEN
	ldx #<pic_file_name
	ldy #>pic_file_name
	jsr kernal_setnam
	lda #2					; logical file 2
	tay						; secondary 2: read
	ldx boot_device
	jsr kernal_setlfs
	jsr kernal_open
	bcc +
	lda #ERROR_FLOPPY_READ_ERROR
	jmp fatalerror
+	ldx #2
	jsr kernal_chkin

	; Read the file into the staging banks: bank PIC_STAGING_BANK and up,
	; through the $a000-$bfff window. The same loop as x16_load_file_to_reu,
	; without its page limits and progress bar.
	lda #PIC_STAGING_BANK
	sta 0
	lda #0
	sta .pic_att
	lda #$a0
	sta .pic_att + 1
	ldy #0
-	jsr kernal_readst
	bne .stage_done
	jsr kernal_readchar
	sta (.pic_att),y
	iny
	bne -
	inc .pic_att + 1
	lda .pic_att + 1
	cmp #$c0
	bne -
	lda #$a0
	sta .pic_att + 1
	inc 0
	bne -					; always: the bank register never wraps to 0 here

.stage_done
	jsr kernal_clrchn
	lda #2
	jsr kernal_close
	lda .pic_index
	sta .cur_pic
	lda .pic_index + 1
	sta .cur_pic + 1
	rts

.pic_set_filename
	; .pic_num = picture number (up to 999). Write it into pic_file_name as
	; three digits. Numbers run past 255, so the hundreds are counted off a
	; 16-bit value; this consumes .pic_num, which the caller reloads each time.
	ldx #0						; hundreds
-	lda .pic_num + 1
	bne +						; >= 256, so certainly >= 100
	lda .pic_num
	cmp #100
	bcc ++						; < 100, hundreds done
+	lda .pic_num				; .pic_num -= 100
	sec
	sbc #100
	sta .pic_num
	lda .pic_num + 1
	sbc #0
	sta .pic_num + 1
	inx
	bne -						; always (x stays < 10)
++	txa
	ora #$30
	sta pic_file_name + 2
	lda .pic_num				; now < 100, low byte only: tens then units
	ldx #$2f					; '0' - 1
-	inx
	sec
	sbc #10
	bcs -
	adc #10
	stx pic_file_name + 3
	ora #$30
	sta pic_file_name + 4
	rts

; ---------------------------------------------------------------------------
.pic_find
	; Find the picture whose number is in a,x (high, low). Returns its index in
	; .pic_index with carry set, or carry clear if this build does not have it.
	; Numbers run to 999 and there may be more than 255 pictures, so both the
	; entries and the index are 16 bit.
	sta .pic_num + 1
	stx .pic_num
	lda #0
	sta .pic_index
	sta .pic_index + 1
.pf_loop
	lda #<pic_number_lo
	ldx #>pic_number_lo
	jsr .pic_addr
	lda (.pi_ptr)
	cmp .pic_num
	bne .pf_next
	lda #<pic_number_hi
	ldx #>pic_number_hi
	jsr .pic_addr
	lda (.pi_ptr)
	cmp .pic_num + 1
	beq .pf_found
.pf_next
	inc .pic_index
	bne +
	inc .pic_index + 1
+	lda .pic_index
	cmp #<picture_count
	lda .pic_index + 1
	sbc #>picture_count
	bcc .pf_loop
	clc
	rts
.pf_found						; .pic_index already holds the matching index
	sec
	rts

.pic_att_next
	; Read the byte the staging pointer is at and step it on, wrapping from
	; the top of the banked window into the next bank. The bank register is
	; set on every read because everything else (the story, the kernal) moves
	; it between calls.
	lda .pic_att + 2
	sta 0
	lda (.pic_att)
	inc .pic_att
	bne +
	inc .pic_att + 1
	pha
	lda .pic_att + 1
	cmp #$c0
	bne ++
	lda #$a0
	sta .pic_att + 1
	inc .pic_att + 2
++	pla
+	rts

.pic_open
	; Point .pic_att at the start of the staged picture.
	lda #0
	sta .pic_att
	lda #$a0
	sta .pic_att + 1
	lda #PIC_STAGING_BANK
	sta .pic_att + 2
	rts

.pic_size
	; Set .pic_w and .pic_h for the picture in .pic_index, for picture_data.
	; The X16 answers from the assembled-in tables - in text cells, like the
	; MEGA65 - because the picture asked about is usually not the one staged.
	lda #<pic_width
	ldx #>pic_width
	jsr .pic_addr
	lda (.pi_ptr)
	sta .pic_w
	lda #<pic_height
	ldx #>pic_height
	jsr .pic_addr
	lda (.pi_ptr)
	sta .pic_h
	rts

.pic_read_palette
	; The 32 bytes after the header: 16 palette entries in VERA order, into
	; this picture's bank of palette RAM ($1fa00 + bank * 32) and into the
	; CPU-side copy compositing translates colours with.
	lda .pic_bank
	asl						; bank * 32, high bit into carry for the address
	asl
	asl
	asl
	asl
	sta .pic_tmp			; low byte of bank * 32
	lda .pic_bank
	lsr
	lsr
	lsr					; bank * 32 / 256
	sta .pic_tmp + 1
	stz VERA_ctrl
	lda #$11				; stride 1, address bit 16 ($1fa00 is in bank 1)
	sta VERA_addr_bank
	lda .pic_tmp + 1
	clc
	adc #$fa
	sta VERA_addr_high
	lda .pic_tmp
	sta VERA_addr_low
	; the RAM copy sits at pic_bank_pal + bank * 32
	lda .pic_tmp
	clc
	adc #<pic_bank_pal
	sta .pic_tmp
	lda .pic_tmp + 1
	adc #>pic_bank_pal
	sta .pic_tmp + 1
	ldy #0
-	phy
	jsr .pic_att_next
	ply
	sta VERA_data0
	sta (.pic_tmp),y
	iny
	cpy #32
	bne -
	rts

.pic_cells
	; a,x = the picture's cell count, .pic_cw * .pic_ch (high, low)
	lda #0
	sta .pic_tmp
	sta .pic_tmp + 1
	ldx .pic_ch
	beq +
-	lda .pic_tmp
	clc
	adc .pic_cw
	sta .pic_tmp
	bcc ++
	inc .pic_tmp + 1
++	dex
	bne -
+	lda .pic_tmp + 1
	ldx .pic_tmp
	rts

; ---------------------------------------------------------------------------
.pic_alloc
	; Give this window a run of the tile store big enough for the picture. The
	; window's old run can be reused only when the SAME picture is being redrawn
	; into it: a game composites (Arthur draws a small scene centred inside a
	; larger frame, both in the picture window), so a different picture must get
	; its own run or it would overwrite tiles the frame's still-visible cells
	; point at. When the store runs out we compact, and only then start again
	; just above the reserved transparent tile.
	lda current_window
	tay						; y = window (pic_win_bank is one byte a window)
	asl
	tax						; x = window * 2 (the word-per-window tables)
	lda .pic_index			; same picture as this window last held?
	cmp pic_win_number,x
	bne .pa_fresh
	lda .pic_index + 1
	cmp pic_win_number + 1,x
	bne .pa_fresh
	jsr .pa_pack_shift		; ...and placed the same way? A run generated for
	cmp pic_win_shift,y		; an off-grid position holds tiles that are only
	bne .pa_fresh			; right at THAT position, so a redraw at another
							; one has to build its own - reusing the run would
							; rewrite the tiles the first placement's cells are
							; still pointing at. (Before the cells were
							; generated this could not happen: a picture's run
							; held the picture's own tiles wherever it was put,
							; so rewriting it changed nothing.)
	lda pic_win_count,x		; and does the window's own run still fit it?
	cmp .pic_ntiles
	lda pic_win_count + 1,x
	sbc .pic_ntiles + 1
	bcc .pa_fresh
	lda pic_win_base,x
	sta .pic_slot
	lda pic_win_base + 1,x
	sta .pic_slot + 1
	lda pic_win_bank,y		; reuse the bank this picture's cells point at
	jmp .pa_set_bank
.pa_fresh
	lda pic_next_tile		; would it run off the end of the store?
	clc
	adc .pic_ntiles
	tay
	lda pic_next_tile + 1
	adc .pic_ntiles + 1
	cmp #>PIC_MAX_TILES
	bcc .pa_place
	bne .pa_compact
	cpy #<PIC_MAX_TILES
	bcc .pa_place
.pa_compact
	; Out of store. Before wrapping over tiles that cells still on screen
	; point at, compact the survivors to the bottom of the store and try
	; again. x still indexes the window tables, and the sweep needs every
	; register.
	phx
	jsr .pic_gc
	plx
	lda pic_next_tile
	clc
	adc .pic_ntiles
	tay
	lda pic_next_tile + 1
	adc .pic_ntiles + 1
	cmp #>PIC_MAX_TILES
	bcc .pa_place
	bne .pa_reset
	cpy #<PIC_MAX_TILES
	bcc .pa_place
.pa_reset
	; still too big: start over at the bottom, which can only spoil what is
	; already doomed. Falls through to .pa_place - nothing may come between
	; them: a .pic_alloc that returns without placing leaves .pic_slot pointing
	; at the LAST picture's run, so this picture's tiles are written over one
	; the screen is still showing (that was Arthur's frame, and .pa_pack_shift
	; sat here for a while), and leaves pic_next_tile at the bottom of the
	; store for everything after it.
	lda #PIC_FIRST_TILE
	sta pic_next_tile
	lda #0
	sta pic_next_tile + 1
.pa_place
	lda pic_next_tile
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
	ldy current_window		; remember which picture now owns this run (y for
	lda .pic_index			; the bank store below; x is still window * 2)
	sta pic_win_number,x
	lda .pic_index + 1
	sta pic_win_number + 1,x
	jsr .pa_pack_shift		; and where it was placed - see the reuse test
	sta pic_win_shift,y
	; give it the bank its palette is already in, or the next one round
	jsr .pa_pick_bank
	sta pic_win_bank,y
	; fall through to .pa_set_bank

.pa_set_bank
	; a = palette bank 1..PIC_PAL_BANKS. It rides in the top nybble of every
	; map entry the picture writes.
	sta .pic_bank
	asl
	asl
	asl
	asl
	sta .pic_entry_hi
	rts

.pa_pick_bank
	; a = the palette bank for the picture in .pic_index: the one it is already
	; loaded into if there is one, else the next bank round, which it claims.
	; y holds the window on entry and still does on exit.
	;
	; Reusing the bank across placements and windows is what a per-DRAW bank
	; could not do. A picture's palette does not depend on where it is drawn,
	; so this is exact, not an approximation - and it is the difference between
	; needing a bank per draw and needing one per distinct picture on screen.
	sty .pab_win
	lda #<pic_adaptive		; an adaptive picture is drawn in the last direct
	ldx #>pic_adaptive		; picture's bank (.pic_draw sets it again below), so
	jsr .pic_addr			; it needs no bank of its own and must not claim
	lda (.pi_ptr)			; one - Arthur's frame and side bars are adaptive,
	beq .pab_direct			; and they were costing three banks a room
	lda pic_direct_bank
	ldy .pab_win
	rts
.pab_direct
	jsr .pab_find			; already loaded somewhere?
	bcs .pab_found
	jsr .pab_free_slot		; a bank nobody has claimed?
	bcs .pab_claim
	jsr .pa_reclaim_banks	; none: give back the ones the screen has finished with
	jsr .pab_free_slot
	bcs .pab_claim
	; all fourteen are still on screen at once. Take the next one round, as
	; before, and spoil it - there is nothing else left to do.
	lda pic_next_bank
	sec
	sbc #1
	asl
	tax
.pab_claim
	; x = (bank - 1) * 2: record what is now in the bank and hand it back
	lda .pic_index
	sta pic_bank_pic,x
	lda .pic_index + 1
	sta pic_bank_pic + 1,x
	txa						; keep the round robin moving past it, so a forced
	lsr						; steal cycles instead of sticking on one bank
	clc
	adc #2
	cmp #PIC_PAL_BANKS + 1
	bcc +
	lda #1
+	sta pic_next_bank
.pab_found
	txa						; (bank - 1) * 2 -> bank
	lsr
	clc
	adc #1
	ldy .pab_win
	rts
.pab_win !byte 0

.pab_find
	; carry set and x = (bank - 1) * 2 if .pic_index's palette is in a bank
	ldx #0
	ldy #PIC_PAL_BANKS
-	lda pic_bank_pic,x
	cmp .pic_index
	bne +
	lda pic_bank_pic + 1,x
	cmp .pic_index + 1
	beq .pab_hit
+	inx
	inx
	dey
	bne -
	clc
	rts

.pab_free_slot
	; carry set and x = (bank - 1) * 2 for the first bank holding no picture
	ldx #0
	ldy #PIC_PAL_BANKS
-	lda pic_bank_pic,x
	and pic_bank_pic + 1,x
	cmp #$ff				; $ffff = free
	beq .pab_hit
	inx
	inx
	dey
	bne -
	clc
	rts
.pab_hit
	sec
	rts

.pab_live !fill 16, 0		; per bank: does a cell on screen still show it?

.pa_reclaim_banks
	; Hand back every bank the screen has finished with. Without this the
	; fourteen only ever fill up: a bank was held for as long as the game ran,
	; so Arthur's map (7 pictures) plus two rooms exhausted them and the next
	; new picture spoiled a live one. A bank is dead when no cell on layer 0
	; shows it, which the map says directly - each entry carries the palette
	; offset nybble the cell renders with.
	ldx #15
	lda #0
-	sta .pab_live,x
	dex
	bpl -
	lda pic_direct_bank		; never free this one: the next adaptive picture
	tax						; draws in it and may have no cells of its own yet
	lda #1
	sta .pab_live,x
	lda #0
	sta .gc_row
.parb_row
	jsr .gc_row_port0		; port 0 -> this map row, column 0
	ldy #SCREEN_WIDTH / 2
.parb_cell
	lda VERA_data0			; tile index low
	sta .pic_tmp
	lda VERA_data0			; palette offset in the top nybble, index high in 0-1
	tax
	and #3
	ora .pic_tmp
	beq .parb_next			; tile 0 = nothing here
	txa
	lsr
	lsr
	lsr
	lsr
	tax
	lda #1
	sta .pab_live,x
.parb_next
	dey
	bne .parb_cell
	inc .gc_row
	lda .gc_row
	cmp #SCREEN_HEIGHT
	bcc .parb_row
	; free the banks nothing is showing
	ldx #0					; x = (bank - 1) * 2
	ldy #1					; y = bank
.parb_free
	lda .pab_live,y
	bne +
	lda #$ff
	sta pic_bank_pic,x
	sta pic_bank_pic + 1,x
	phx						; .pab_drop_runs needs both registers
	phy
	tya
	jsr .pab_drop_runs		; and no window may reuse a run drawn for it
	ply
	plx
+	inx
	inx
	iny
	cpy #PIC_PAL_BANKS + 1
	bne .parb_free
	rts

.pab_drop_runs
	; a = a bank just freed. A window whose run was built for it must not reuse
	; that run: .pic_alloc's reuse path takes the window's remembered bank
	; straight from pic_win_bank, and would reload the picture's palette into a
	; bank that now belongs to something else. The run is dead anyway - its
	; picture is off screen, which is why the bank was freed.
	ldy #7
-	cmp pic_win_bank,y
	bne +
	pha
	tya
	asl
	tax
	lda #$ff
	sta pic_win_number,x
	sta pic_win_number + 1,x
	pla
+	dey
	bpl -
	rts

.pa_pack_shift
	; The placement a run was built for, as one byte: the horizontal offset in
	; the low nybble and the vertical in the high. Both are 0..7. y must hold
	; the window number on entry and still does on exit. It lives outside
	; .pic_alloc, as the MEGA65 engine's copy does, because the allocator is a
	; chain of fall-throughs with no room for a subroutine in the middle.
	lda .pic_shift_y
	asl
	asl
	asl
	asl
	ora .pic_shift
	rts

; ---------------------------------------------------------------------------
.pic_map_row_addr
	; Set VERA port y (0 or 1) to the layer 0 map cell (.pic_row + .pic_y,
	; .pic_lx). A map row is 64 entries = 128 bytes, so the address is
	; VRAM_L0_MAP + row * 128 + column * 2, all inside VRAM bank 1.
	sty VERA_ctrl
	lda .pic_row
	clc
	adc .pic_y
	lsr						; row / 2 into the high byte, row & 1 -> carry
	sta .pic_tmp
	lda .pic_lx
	asl						; column * 2; carry from the LSR is unaffected...
	sta .pic_tmp + 1
	lda .pic_row
	clc
	adc .pic_y
	and #1
	beq +
	lda .pic_tmp + 1
	ora #$80				; odd rows start halfway into the page
	sta .pic_tmp + 1
+	lda #$11				; stride 1, address bit 16 (the map is in bank 1)
	sta VERA_addr_bank
	lda .pic_tmp
	clc
	adc #>(VRAM_L0_MAP & $ffff)
	sta VERA_addr_high
	lda .pic_tmp + 1
	sta VERA_addr_low
	stz VERA_ctrl
	rts

.pic_tile_addr
	; Set VERA port y (0 or 1) to tile a,x (low, high) in the store: the
	; tile's VRAM address is its index * 64, all inside VRAM bank 0.
	sty VERA_ctrl
	sta .pic_tmp
	stx .pic_tmp + 1
	ldx #6
-	asl .pic_tmp
	rol .pic_tmp + 1
	dex
	bne -
	lda #$10				; stride 1, bank 0
	sta VERA_addr_bank
	lda .pic_tmp + 1
	sta VERA_addr_high
	lda .pic_tmp
	sta VERA_addr_low
	stz VERA_ctrl
	rts

; ---------------------------------------------------------------------------
.pic_gc
	; The store must take a picture bigger than the space left, and wrapping
	; would overwrite tiles that cells still on screen point at. Keep those:
	; mark every tile a cell outside the incoming picture's rectangle shows,
	; copy the survivors to the bottom of the store in ascending index order
	; (safe in place: a survivor can only move down), and repoint their
	; cells. pic_next_tile comes back as the survivor count, so the caller's
	; run and the composites baked over it land above them. Cells the new
	; picture covers completely are left alone: it is about to overwrite
	; them, and if their tiles are shared with cells outside the sharing
	; marks them survivors anyway. A cell the picture only half covers (a
	; shifted placement's two edge cells) counts as outside: its tile must
	; survive.

	; The incoming rectangle in map cells, interior only. A shifted picture
	; spans .pic_lx .. .pic_lx + cw, sharing both edge cells, so only
	; .pic_lx + 1 .. .pic_lx + cw - 1 is fully its own; an aligned one owns
	; .pic_lx .. .pic_lx + cw - 1. Either way the exclusive end is lx + cw.
	lda .pic_lx
	sta .gc_x0
	clc
	adc .pic_cw
	sta .gc_x1
	lda .pic_shift
	beq +
	inc .gc_x0
+
	lda .pic_y
	sta .gc_y0
	clc
	adc .pic_h
	sta .gc_y1
	lda .pic_shift_y		; the same down the other axis, since phase 0b: a
	beq +					; picture shifted vertically shares its top edge
	inc .gc_y0				; row with whatever it is drawn over
+

	; pass 1: which tiles are still needed?
	ldx #0
	txa
-	sta .gc_bitmap,x
	inx
	cpx #128
	bne -
	lda #0
	sta .gc_row
.gc_mark_row
	jsr .gc_row_port0		; port 0 reads the map row's 40 entries
	lda #0
	sta .gc_col
.gc_mark_cell
	lda VERA_data0			; the entry: index low, then flags + index high
	sta .gc_t2
	lda VERA_data0
	sta .gc_t
	lda .gc_row
	cmp .gc_y0
	bcc .gc_mark_keep		; above the rectangle
	cmp .gc_y1
	bcs .gc_mark_keep		; below it
	lda .gc_col
	cmp .gc_x0
	bcc .gc_mark_keep		; left of it
	cmp .gc_x1
	bcs .gc_mark_keep		; right of it
	bcc .gc_mark_next		; inside: dies with the old picture
.gc_mark_keep
	lda .gc_t
	and #3					; the index's high bits; index 0 = no tile
	sta .gc_t
	ora .gc_t2
	beq .gc_mark_next
	; bitmap byte = index high * 32 + index low / 8
	lda .gc_t
	asl
	asl
	asl
	asl
	asl
	sta .gc_t
	lda .gc_t2
	lsr
	lsr
	lsr
	clc
	adc .gc_t
	tay
	lda .gc_t2
	and #7
	tax
	lda .gc_bit,x
	ora .gc_bitmap,y
	sta .gc_bitmap,y
.gc_mark_next
	inc .gc_col
	lda .gc_col
	cmp #SCREEN_WIDTH / 2
	bcc .gc_mark_cell
	inc .gc_row
	lda .gc_row
	cmp #SCREEN_HEIGHT
	bcc .gc_mark_row

	; pass 2: count the survivors below each bitmap byte, and move each one
	; down to its new home as it is passed
	lda #PIC_FIRST_TILE
	sta .gc_next
	lda #0
	sta .gc_next + 1
	sta .gc_byi
.gc_sweep_byte
	ldy .gc_byi
	lda .gc_next
	sta .gc_pref_lo,y
	lda .gc_next + 1
	sta .gc_pref_hi,y
	ldx #0
.gc_sweep_bit
	ldy .gc_byi
	lda .gc_bitmap,y
	and .gc_bit,x
	beq .gc_sweep_next
	tya						; survivor: its old index is byi * 8 + bit
	sta .gc_old
	lda #0
	sta .gc_old + 1
	asl .gc_old
	rol .gc_old + 1
	asl .gc_old
	rol .gc_old + 1
	asl .gc_old
	rol .gc_old + 1
	txa
	ora .gc_old
	sta .gc_old
	jsr .gc_copy_tile
	inc .gc_next
	bne .gc_sweep_next
	inc .gc_next + 1
.gc_sweep_next
	inx
	cpx #8
	bcc .gc_sweep_bit
	inc .gc_byi
	lda .gc_byi
	cmp #128
	bcc .gc_sweep_byte

	; pass 3: point the surviving cells at the tiles' new homes. Port 0 reads
	; a row's entries and port 1, walking two bytes behind it, writes them
	; back, so an entry is rewritten in place.
	lda #0
	sta .gc_row
.gc_fix_row
	jsr .gc_row_port0
	ldy #1
	jsr .gc_row_port1
	lda #0
	sta .gc_col
.gc_fix_cell
	lda VERA_data0
	sta .gc_t2				; index low
	lda VERA_data0
	sta .gc_t				; flags + index high
	and #3
	ora .gc_t2				; index 0: not a tile
	beq .gc_fix_keep
	lda .gc_t
	and #3
	asl
	asl
	asl
	asl
	asl
	sta .pic_tmp
	lda .gc_t2
	lsr
	lsr
	lsr
	clc
	adc .pic_tmp
	tax						; x = the entry's bitmap byte
	lda .gc_t2
	and #7
	tay						; y = its bit
	lda .gc_bitmap,x
	and .gc_bit,y
	beq .gc_fix_keep		; covered by the new picture: leave it be
	lda .gc_bitmap,x
	and .gc_below,y
	tay
	lda .gc_pop,y			; survivors below it within its own byte...
	clc
	adc .gc_pref_lo,x		; ...plus those below its byte = its new index
	sta .gc_t2
	lda .gc_pref_hi,x
	adc #0
	and #3					; the new index's high bits sit in the entry's
	sta .pic_tmp			; bits 0-1, under the palette offset and flips
	lda .gc_t
	and #$fc
	ora .pic_tmp
	sta .gc_t
	lda .gc_t2
	sta VERA_data1
	lda .gc_t
	sta VERA_data1
	jmp .gc_fix_next
.gc_fix_keep
	lda .gc_t2				; write the entry back unchanged to keep the
	sta VERA_data1			; write port walking in step
	lda .gc_t
	sta VERA_data1
.gc_fix_next
	inc .gc_col
	lda .gc_col
	cmp #SCREEN_WIDTH / 2
	bcs +
	jmp .gc_fix_cell		; the loop body outgrew a direct branch
+	inc .gc_row
	lda .gc_row
	cmp #SCREEN_HEIGHT
	bcs +
	jmp .gc_fix_row
+

	; the survivors are the new bottom of the store
	lda .gc_next
	sta pic_next_tile
	lda .gc_next + 1
	sta pic_next_tile + 1
	; every window's run has moved: no run may be reused until redrawn
	ldx #15
	lda #$ff
-	sta pic_win_number,x
	dex
	bpl -
	rts

.gc_row_port0
	; Point port 0 at map row .gc_row, column 0, stride 1, and select port 0.
	lda .pic_row
	pha
	lda .pic_lx
	pha
	lda .gc_row
	sec
	sbc .pic_y				; .pic_map_row_addr adds .pic_y back
	sta .pic_row
	lda #0
	sta .pic_lx
	ldy #0
	jsr .pic_map_row_addr
	pla
	sta .pic_lx
	pla
	sta .pic_row
	rts

.gc_row_port1
	; The same for port 1 (y = 1 on entry), leaving port 0 selected.
	lda .pic_row
	pha
	lda .pic_lx
	pha
	lda .gc_row
	sec
	sbc .pic_y
	sta .pic_row
	lda #0
	sta .pic_lx
	jsr .pic_map_row_addr
	pla
	sta .pic_lx
	pla
	sta .pic_row
	rts

.gc_copy_tile
	; move tile .gc_old down to tile .gc_next, 64 bytes, port 0 reading and
	; port 1 writing. When nothing below has been freed yet they are the same
	; slot, and there is nothing to do.
	lda .gc_old
	cmp .gc_next
	bne +
	lda .gc_old + 1
	cmp .gc_next + 1
	bne +
	rts
+	txa
	pha
	tya
	pha
	lda .gc_old
	ldx .gc_old + 1
	ldy #0
	jsr .pic_tile_addr
	lda .gc_next
	ldx .gc_next + 1
	ldy #1
	jsr .pic_tile_addr
	stz VERA_ctrl
	ldy #64
-	lda VERA_data0
	sta VERA_data1
	dey
	bne -
	pla
	tay
	pla
	tax
	rts

; ---------------------------------------------------------------------------
.pic_copy_tiles
	; Copy the picture's tiles from the staging banks into its run of the tile
	; store. A tile is 16 bytes on disk (two 4-bit art pixels a byte) and 64
	; in the store: each art pixel becomes a byte of two identical 4bpp store
	; pixels, doubling the picture horizontally. The pixels stay raw colour
	; indices - the palette bank rides in the map entries instead.
	; While copying, record which palette indices the picture actually uses, so
	; a free one can hold the window background for transparent pixels.
	ldx #15
	lda #0
-	sta pic_used,x
	dex
	bpl -
	lda .pic_slot
	ldx .pic_slot + 1
	ldy #0
	jsr .pic_tile_addr		; port 0 -> the run's first tile
	; source bytes = ntiles * 32: a tile is 8x8 art pixels, two to a byte
	lda .pic_ntiles
	sta .pic_count
	lda .pic_ntiles + 1
	sta .pic_count + 1
	ldx #5
-	asl .pic_count
	rol .pic_count + 1
	dex
	bne -
	lda .pic_count
	ora .pic_count + 1
	beq .pct_done
.pct_loop
	jsr .pic_att_next
	pha
	lsr						; the high nybble is the left pixel
	lsr
	lsr
	lsr
	tax
	lda #$ff
	sta pic_used,x			; this index is used
	lda .pic_dub,x
	sta VERA_data0
	pla
	and #$0f
	tax
	lda #$ff
	sta pic_used,x
	lda .pic_dub,x
	sta VERA_data0
	lda .pic_count
	bne +
	dec .pic_count + 1
+	dec .pic_count
	lda .pic_count
	ora .pic_count + 1
	bne .pct_loop
.pct_done
	rts

; ---------------------------------------------------------------------------
.pic_start_row
	; Start a row of .pic_fill_cells or .pic_erase: how many of the picture's
	; cells there are (.pic_cols_left counts them all, so the staging pointer
	; stays aligned) and how many are actually on screen (.pic_vis).
	lda .pic_cw
	sta .pic_cols_left
	lda #SCREEN_WIDTH / 2
	sec
	sbc .pic_lx				; cells from .pic_lx to the right edge
	cmp .pic_cw
	bcc +
	lda .pic_cw
+	sta .pic_vis
	rts

.pic_fill_cells
	; Read the cell map back out of the staging banks and write the layer 0
	; map entries: the staged index plus the run's slot, with the palette
	; bank in the top nybble. Each row's map entries are buffered first,
	; because they are walked twice: once to fill the layer 0 row (port 0
	; reads what is already in a cell, for compositing, and port 1, in step,
	; writes the new entry), and once to blank the text cells over every
	; cell the picture writes - the text layer sits in front, and a window's
	; painted background would hide the picture entirely otherwise. This is
	; the MEGA65's semantics, where a drawn picture replaces the text in its
	; cells; a fully transparent cell ($ffff) leaves both layers alone.
	lda .pic_map
	sta .pic_att
	lda .pic_map + 1
	sta .pic_att + 1
	lda .pic_map + 2
	sta .pic_att + 2
	lda #0
	sta .pic_row
.pfc_row
	lda .pic_row
	clc
	adc .pic_y
	cmp #SCREEN_HEIGHT		; this row past the bottom edge? the rest are too
	bcc +
	jmp .pfc_done
+	; buffer the row's map entries
	lda .pic_cw
	asl
	sta .pic_tmp			; bytes in this row
	ldx #0
-	phx
	jsr .pic_att_next
	plx
	sta .pfc_rowbuf,x
	inx
	cpx .pic_tmp
	bne -
	jsr .pic_start_row
	ldy #0
	jsr .pic_map_row_addr	; port 0: the entries as they are
	ldy #1
	jsr .pic_map_row_addr	; port 1: where the new entries go
	ldx #0
.pfc_cell
	lda .pic_vis
	bne +
	jmp .pfc_rowdone		; the rest of the row is right of the screen
+	dec .pic_vis
	lda VERA_data0			; what is already in this cell (the picture behind)?
	sta .pcf_under_lo
	lda VERA_data0
	sta .pcf_under_hi
	lda .pfc_rowbuf,x		; our index, low byte
	sta .pfc_lo
	lda .pfc_rowbuf + 1,x	; and high
	sta .pfc_hi
	cmp #$ff				; $ffff marks a fully transparent cell: leave what
	beq .pfc_leave			; is under it alone
	lda .pcf_under_lo		; is a tile there already? index != 0 means yes
	sta .pic_tmp
	lda .pcf_under_hi
	and #3
	ora .pic_tmp
	bne .pfc_composite
	; nothing behind. If the window has a background colour we can show (like a
	; transparent FCM pixel showing the MEGA65's $d021), bake it into our
	; transparent pixels; otherwise write our tile directly, its 0 pixels the
	; VERA backdrop.
	lda pic_bg_index
	beq .pfc_nb_direct
	phx
	jsr .pfc_save_ports
	jsr .pcf_bake_bg
	jsr .pfc_restore_ports
	plx
	lda .pcf_newcode_lo
	sta VERA_data1
	lda .pcf_newcode_hi
	sta VERA_data1
	jmp .pfc_advance
.pfc_nb_direct
	lda .pfc_lo
	clc
	adc .pic_slot
	sta VERA_data1
	lda .pfc_hi
	adc .pic_slot + 1
	and #3
	ora .pic_entry_hi
	sta VERA_data1
	jmp .pfc_advance
.pfc_composite
	phx
	jsr .pfc_save_ports		; .pcf_make_tile repoints both ports at the
	jsr .pcf_make_tile		; tile store: bake a fresh tile of us over what
	jsr .pfc_restore_ports	; was behind, then resume the map walk
	plx
	lda .pcf_newcode_lo
	sta VERA_data1
	lda .pcf_newcode_hi
	sta VERA_data1
	jmp .pfc_advance
.pfc_leave
	lda .pcf_under_lo		; keep the cell as it was; the write port must
	sta VERA_data1			; still step
	lda .pcf_under_hi
	sta VERA_data1
.pfc_advance
	inx
	inx
	dec .pic_cols_left
	beq .pfc_rowdone
	jmp .pfc_cell
.pfc_rowdone
	jsr .pfc_blank_text
	inc .pic_row
	lda .pic_ch
	cmp .pic_row
	beq .pfc_done
	jmp .pfc_row
.pfc_done
	rts

; ---------------------------------------------------------------------------
; ---------------------------------------------------------------------------
; Off-grid placement. A map cell is 8 art pixels each way (16 physical across,
; doubled), so a picture whose corner is not on that grid cannot use its own
; tiles as they stand: every cell it covers shows parts of up to four of them.
;
; Those cells are GENERATED here, straight from the picture still sitting in the
; staging banks, and the picture's own run is never copied into the store at all
; - .pic_draw skips .pic_copy_tiles when either shift is non-zero. That is what
; makes both axes affordable: baking instead, from a copied run, costs the run
; PLUS a fresh tile per covered cell, which for Arthur peaks at 1676 tiles
; against a 1023-tile store, while generating peaks at 925. tools/tilebudget.py
; measures it over a whole blorb; the numbers for all four games are in todo.txt.
;
; It is also exactly accountable: the cell count is known before the draw, so
; .pic_alloc reserves the run and every tile written comes out of it. Nothing is
; allocated mid-draw, which is the class of bug that ate Arthur's frame.
;
; Source pixel (mx * 8 + c - dx, my * 8 + r - dy) goes to row r, column c of the
; cell at map position (mx, my), with dx/dy the offsets in .pic_shift and
; .pic_shift_y. So a cell is four rectangles taken from the four source art
; cells around (mx, my) - fewer when a shift is zero, or when a neighbour is off
; the edge of the picture and reads as transparent.

.pic_seek
	; Point the staging cursor .pic_att at .gen_base + the 16-bit offset in
	; .pic_count. A picture is loaded contiguously and is at most 32 KB, so the
	; offset only has to be walked up through the 8 KB banked window.
	;
	; The offset is split into whole banks and a remainder BEFORE it is added,
	; because .gen_base sits in $a000..$bfff and the offset can be most of a
	; 32 KB picture: adding it whole overflows $ffff, and the carry has nowhere
	; to go - the bank is a byte of its own, and the $c0 normalisation below
	; never sees the wrapped address as too high. Every tile past index
	; ($ffff - .gen_tiles) / 32 then came out of the wrong bank. Arthur's two
	; full-screen intro pictures are the only ones whose tile block reaches
	; that far (37x25 cells, 723 tiles: the break was at index 710), and the
	; bottom two rows of both were built from whatever was at the wrapped
	; address. Nothing else uses .pic_seek, which is why only off-grid
	; placement - the pixel model's doing - ever showed it.
	lda .pic_count + 1
	and #$1f				; the part of the offset inside one 8 KB bank
	clc
	adc .gen_base + 1
	sta .pic_att + 1		; $a0..$bf plus $00..$1f: no carry out of the byte
	lda .gen_base
	clc
	adc .pic_count
	sta .pic_att
	bcc +
	inc .pic_att + 1
+	lda .pic_count + 1
	lsr
	lsr
	lsr
	lsr
	lsr						; whole 8 KB banks in the offset
	clc
	adc .gen_base + 2
	sta .pic_att + 2
-	lda .pic_att + 1
	cmp #$c0
	bcc +
	sbc #$20				; $c0.. -> $a0.., one bank up
	sta .pic_att + 1
	inc .pic_att + 2
	bra -
+	rts

.gen_load_cell
	; Unpack source art cell (.gen_cx, .gen_cy) into .gen_buf, a byte a pixel,
	; already doubled into the store's two-identical-nybbles form. A cell off
	; the edge of the picture, or one the file marks fully transparent ($ffff),
	; comes back as zeroes - which is what "transparent" means to everything
	; downstream.
	lda .gen_cx
	cmp #$ff
	beq .glc_far
	cmp .pic_cw
	bcs .glc_far
	lda .gen_cy
	cmp #$ff
	beq .glc_far
	cmp .pic_ch
	bcc .glc_inside
.glc_far
	jmp .glc_blank			; the fill is past the end of the routine
.glc_inside
	lda #0					; cell map offset = (cy * cw + cx) * 2
	sta .pic_count
	sta .pic_count + 1
	ldx .gen_cy
	beq .glc_addx
-	lda .pic_count
	clc
	adc .pic_cw
	sta .pic_count
	bcc +
	inc .pic_count + 1
+	dex
	bne -
.glc_addx
	lda .pic_count
	clc
	adc .gen_cx
	sta .pic_count
	bcc +
	inc .pic_count + 1
+	asl .pic_count
	rol .pic_count + 1
	lda .pic_map			; .pic_draw kept the cell map's start
	sta .gen_base
	lda .pic_map + 1
	sta .gen_base + 1
	lda .pic_map + 2
	sta .gen_base + 2
	jsr .pic_seek
	jsr .pic_att_next
	sta .pic_tmp
	jsr .pic_att_next
	sta .pic_tmp + 1
	cmp #$ff
	bne .glc_have
	lda .pic_tmp
	cmp #$ff
	beq .glc_blank
.glc_have
	lda .pic_tmp			; tile offset = index * 32
	sta .pic_count
	lda .pic_tmp + 1
	sta .pic_count + 1
	ldx #5
-	asl .pic_count
	rol .pic_count + 1
	dex
	bne -
	lda .gen_tiles
	sta .gen_base
	lda .gen_tiles + 1
	sta .gen_base + 1
	lda .gen_tiles + 2
	sta .gen_base + 2
	jsr .pic_seek
	ldy #0					; 32 packed bytes -> 64 doubled ones
-	jsr .pic_att_next
	pha
	lsr
	lsr
	lsr
	lsr
	tax
	lda .pic_dub,x
	sta .gen_buf,y
	iny
	pla
	and #$0f
	tax
	lda .pic_dub,x
	sta .gen_buf,y
	iny
	cpy #64
	bne -
	rts
.glc_blank
	lda #0
	ldy #63
-	sta .gen_buf,y
	dey
	bpl -
	rts

.gen_blit
	; Move the .gen_nr x .gen_nc rectangle at (.gen_sr, .gen_sc) in .gen_buf to
	; (.gen_dr, .gen_dc) in .pcf_buf. Both are 8x8 bytes.
	lda .gen_nr
	beq .gb_done
	lda .gen_nc
	beq .gb_done
	lda .gen_sr
	asl
	asl
	asl
	clc
	adc .gen_sc
	sta .pic_tmp			; running source index
	lda .gen_dr
	asl
	asl
	asl
	clc
	adc .gen_dc
	sta .pic_tmp + 1		; running destination index
	lda .gen_nr
	sta .gen_rows
.gb_row
	ldx .pic_tmp
	ldy .pic_tmp + 1
	lda .gen_nc
	sta .gen_cols
-	lda .gen_buf,x
	sta .pcf_buf,y
	inx
	iny
	dec .gen_cols
	bne -
	lda .pic_tmp
	clc
	adc #8
	sta .pic_tmp
	lda .pic_tmp + 1
	clc
	adc #8
	sta .pic_tmp + 1
	dec .gen_rows
	bne .gb_row
.gb_done
	rts

.gen_tile
	; Build the cell at map position (.pfo_m, .pic_row) into .pcf_buf, out of
	; the four source art cells that can reach it. The picture's own cell
	; (mx, my) always contributes; the cell above contributes only when the
	; picture is shifted down, the cell to the left only when it is shifted
	; right, and the one diagonally up-left only when it is shifted both ways.
	lda #0
	ldy #63
-	sta .pcf_buf,y
	dey
	bpl -

	lda .pic_shift_y
	beq .gt_bottom			; on the row grid: nothing from the row above
	lda .pic_shift
	beq .gt_topright
	jsr .gt_left			; up and left: rows 0..dy-1, columns 0..dx-1
	jsr .gt_above
	jsr .gen_load_cell
	jsr .gt_srtop
	jsr .gt_scleft
	lda #0
	sta .gen_dr
	sta .gen_dc
	lda .pic_shift_y
	sta .gen_nr
	lda .pic_shift
	sta .gen_nc
	jsr .gen_blit
.gt_topright
	jsr .gt_right			; up: rows 0..dy-1, columns dx..7
	jsr .gt_above
	jsr .gen_load_cell
	jsr .gt_srtop
	lda #0
	sta .gen_sc
	sta .gen_dr
	lda .pic_shift
	sta .gen_dc
	lda .pic_shift_y
	sta .gen_nr
	jsr .gt_ncright
	jsr .gen_blit
.gt_bottom
	lda .pic_shift
	beq .gt_bottomright
	jsr .gt_left			; left: rows dy..7, columns 0..dx-1
	jsr .gt_here
	jsr .gen_load_cell
	lda #0
	sta .gen_sr
	sta .gen_dc
	jsr .gt_scleft
	lda .pic_shift_y
	sta .gen_dr
	jsr .gt_nrbottom
	lda .pic_shift
	sta .gen_nc
	jsr .gen_blit
.gt_bottomright
	jsr .gt_right			; the picture's own cell: rows dy..7, columns dx..7
	jsr .gt_here
	jsr .gen_load_cell
	lda #0
	sta .gen_sr
	sta .gen_sc
	lda .pic_shift_y
	sta .gen_dr
	lda .pic_shift
	sta .gen_dc
	jsr .gt_nrbottom
	jsr .gt_ncright
	jmp .gen_blit

.gt_left
	ldx .pfo_m				; the source cell column left of this map cell
	dex						; ($ff when there is none - .gen_load_cell blanks)
	stx .gen_cx
	rts
.gt_right
	lda .pfo_m
	sta .gen_cx
	rts
.gt_above
	ldx .pic_row
	dex
	stx .gen_cy
	rts
.gt_here
	lda .pic_row
	sta .gen_cy
	rts
.gt_srtop
	lda #8					; the bottom .pic_shift_y rows of the cell above
	sec
	sbc .pic_shift_y
	sta .gen_sr
	rts
.gt_scleft
	lda #8					; the rightmost .pic_shift columns of the cell left
	sec
	sbc .pic_shift
	sta .gen_sc
	rts
.gt_nrbottom
	lda #8
	sec
	sbc .pic_shift_y
	sta .gen_nr
	rts
.gt_ncright
	lda #8
	sec
	sbc .pic_shift
	sta .gen_nc
	rts

.gen_scan
	; Look over the cell just built: x comes back as the count of transparent
	; (0) bytes, so 64 means "leave the cell alone" and 0 means "no compositing
	; needed", and .gen_left / .gen_right say whether each of the two TEXT cells
	; over this map cell has any opaque pixel under it. A text cell is 4 art
	; pixels, so byte index bit 2 picks which half a pixel belongs to.
	ldx #0
	stz .gen_left
	stz .gen_right
	ldy #0
-	lda .pcf_buf,y
	bne .gs_opaque
	inx
	bra .gs_next
.gs_opaque
	tya
	and #4
	bne .gs_isright
	lda #1
	sta .gen_left
	bra .gs_next
.gs_isright
	lda #1
	sta .gen_right
.gs_next
	iny
	cpy #64
	bne -
	rts

.gen_write_slot
	; Write .pcf_buf into the next tile of the run .pic_alloc reserved, and
	; leave its map entry in .pcf_newcode. Unlike the mid-draw bakes this
	; replaced there is no way to run out: the run was reserved for exactly the
	; cells this picture spans, and a fully transparent cell does not take one.
	lda .pic_slot
	clc
	adc .gen_next
	sta .pic_tmp
	lda .pic_slot + 1
	adc .gen_next + 1
	sta .pic_tmp + 1
	lda .pic_tmp
	sta .pcf_newcode_lo
	lda .pic_tmp + 1
	and #3
	ora .pic_entry_hi
	sta .pcf_newcode_hi
	lda .pic_tmp
	ldx .pic_tmp + 1
	ldy #1
	jsr .pic_tile_addr		; port 1 -> the tile
	inc .gen_next
	bne +
	inc .gen_next + 1
+	ldy #0
-	lda .pcf_buf,y
	sta VERA_data1
	iny
	cpy #64
	bne -
	rts

.pic_gen_fill
	; The off-grid equivalent of .pic_fill_cells: build and write every map cell
	; the picture covers, .gen_mw across and .gen_mh down. Compositing, the
	; window-background fill and the text blanking are the same as the aligned
	; path's - only where the cell's pixels come from is different.
!ifdef DEBUG_PIC_GEN {
	lda .pic_shift
	sta dbg_gen
	lda .pic_shift_y
	sta dbg_gen + 1
	lda .gen_mw
	sta dbg_gen + 2
	lda .gen_mh
	sta dbg_gen + 3
	lda .pic_lx
	sta dbg_gen + 4
	lda .pic_y
	sta dbg_gen + 5
	lda .pic_cw
	sta dbg_gen + 6
	lda .pic_ch
	sta dbg_gen + 7
	lda .pic_slot
	sta dbg_gen + 8
	lda .pic_slot + 1
	sta dbg_gen + 9
}
	lda #0
	sta .gen_next
	sta .gen_next + 1
	sta .pic_row
.pgf_row
	lda .pic_row
	clc
	adc .pic_y
	cmp #SCREEN_HEIGHT
	bcc +
	jmp .pgf_done
+	ldy #0					; port 0 reads what is there, port 1 writes anew
	jsr .pic_map_row_addr
	ldy #1
	jsr .pic_map_row_addr
	lda #SCREEN_WIDTH / 2
	sec
	sbc .pic_lx				; cells from .pic_lx to the right edge
	sta .pfo_vis
	stz .pfo_m
.pgf_cell
	lda .pfo_vis
	bne +
	jmp .pgf_rowdone
+	lda .pfo_m
	cmp .gen_mw
	bcc +
	jmp .pgf_rowdone
+	dec .pfo_vis
	lda VERA_data0			; what is behind, for compositing
	sta .pcf_under_lo
	lda VERA_data0
	sta .pcf_under_hi
	jsr .gen_tile			; -> .pcf_buf (staging only; VERA is untouched)
	jsr .gen_scan
	cpx #64
	bne .pgf_draw
	ldy .pfo_m				; nothing of the picture here: keep what is under
	lda #0
	sta .pfo_drawn,y
	lda .pcf_under_lo
	sta VERA_data1
	lda .pcf_under_hi
	sta VERA_data1
	jmp .pgf_next
.pgf_draw
	lda #0					; record which text halves this cell covers
	ldy .gen_left
	beq +
	ora #1
+	ldy .gen_right
	beq +
	ora #2
+	ldy .pfo_m
	sta .pfo_drawn,y
	phx
	jsr .pfc_save_ports
	plx
	cpx #0
	beq .pgf_write			; fully opaque: no compositing
	lda .pcf_under_lo		; is there a tile behind? index != 0
	sta .pic_tmp
	lda .pcf_under_hi
	and #3
	ora .pic_tmp
	beq .pgf_nothing_behind
	jsr .pcf_build_xlat
	jsr .pcf_composite_under
	bra .pgf_write
.pgf_nothing_behind
	lda pic_bg_index		; show the window background through our transparent
	beq .pgf_write			; pixels (0 = none: leave them the backdrop)
	jsr .pcf_fill_bg
.pgf_write
	jsr .gen_write_slot
	jsr .pfc_restore_ports
	lda .pcf_newcode_lo
	sta VERA_data1
	lda .pcf_newcode_hi
	sta VERA_data1
.pgf_next
	inc .pfo_m
	jmp .pgf_cell
.pgf_rowdone
	jsr .pgf_blank_text
	inc .pic_row
	lda .pic_row
	cmp .gen_mh
	beq .pgf_done
	jmp .pgf_row
.pgf_done
	rts

.pgf_blank_text
	; Blank the text over the row's drawn cells, two text cells to a map cell,
	; leaving the text where the picture put nothing. .pfo_drawn was filled by
	; the pass above: bit 0 is the left text cell, bit 1 the right.
	lda #1
	sta VERA_ctrl
	jsr .pfc_text_addr
	stz VERA_ctrl
	jsr .pfc_text_addr
	lda #SCREEN_WIDTH / 2
	sec
	sbc .pic_lx
	sta .pfo_vis
	stz .pfo_m
.pgbt_cell
	lda .pfo_vis
	beq .pgbt_done
	lda .pfo_m
	cmp .gen_mw
	bcs .pgbt_done
	dec .pfo_vis
	ldy .pfo_m
	lda .pfo_drawn,y
	sta .pic_tmp
	and #1
	beq .pgbt_lkeep
	lda VERA_data0			; covered: blank (space, keep fg, clear bg)
	lda #$20
	sta VERA_data1
	lda VERA_data0
	and #$0f
	sta VERA_data1
	bra .pgbt_r
.pgbt_lkeep
	lda VERA_data0			; not covered: keep the text that is there
	sta VERA_data1
	lda VERA_data0
	sta VERA_data1
.pgbt_r
	lda .pic_tmp
	and #2
	beq .pgbt_rkeep
	lda VERA_data0
	lda #$20
	sta VERA_data1
	lda VERA_data0
	and #$0f
	sta VERA_data1
	bra .pgbt_next
.pgbt_rkeep
	lda VERA_data0
	sta VERA_data1
	lda VERA_data0
	sta VERA_data1
.pgbt_next
	inc .pfo_m
	bra .pgbt_cell
.pgbt_done
	rts
.pfo_drawn !fill 44, 0		; per-boundary-cell "was drawn" flags for one row

.pfc_blank_text
	; Blank the text cells over the row's written picture cells: a space
	; with the background nybble cleared, so the cell is transparent and the
	; picture shows. Cells the picture leaves alone ($ffff) keep their text.
	; One layer 0 cell covers two text cells. Ports 0 and 1 walk the text
	; row in step, as the map fill did.
	jsr .pic_start_row		; reset the visible count for this row
	lda #1
	sta VERA_ctrl
	jsr .pfc_text_addr
	stz VERA_ctrl
	jsr .pfc_text_addr
	ldx #0
.pbt_cell
	lda .pic_vis
	beq .pbt_done
	dec .pic_vis
	lda .pfc_rowbuf + 1,x	; $ffff = untouched cell: keep its text
	cmp #$ff
	beq .pbt_leave
	ldy #2					; two text cells to blank
-	lda VERA_data0			; the character, replaced by a space
	lda #$20
	sta VERA_data1
	lda VERA_data0			; the colour: keep the foreground, clear the
	and #$0f				; background to transparent
	sta VERA_data1
	dey
	bne -
	bra .pbt_next
.pbt_leave
	ldy #4					; copy the two cells through unchanged
-	lda VERA_data0
	sta VERA_data1
	dey
	bne -
.pbt_next
	inx
	inx
	dec .pic_cols_left
	bne .pbt_cell
.pbt_done
	rts

.pfc_text_addr
	; Point the selected VERA port at the text cell (.pic_row + .pic_y,
	; .pic_lx * 2): the text map row is 256 bytes at $1b000 + row * 256, a
	; cell two bytes.
	lda #$11				; stride 1, address bit 16
	sta VERA_addr_bank
	lda .pic_row
	clc
	adc .pic_y
	clc
	adc #$b0
	sta VERA_addr_high
	lda .pic_lx
	asl						; layer 0 cell -> text column -> byte offset
	asl
	sta VERA_addr_low
	rts

.pfc_rowbuf !fill 80, 0		; one map row: 40 cells, two bytes each

.pfc_save_ports
	; Remember where both VERA ports point (the address registers read
	; back), so a detour through the tile store can put them back.
	lda #1
	sta VERA_ctrl
	lda VERA_addr_low
	sta .pfc_port1_addr
	lda VERA_addr_high
	sta .pfc_port1_addr + 1
	lda VERA_addr_bank
	sta .pfc_port1_addr + 2
	stz VERA_ctrl
	lda VERA_addr_low
	sta .pfc_port0_addr
	lda VERA_addr_high
	sta .pfc_port0_addr + 1
	lda VERA_addr_bank
	sta .pfc_port0_addr + 2
	rts

.pfc_restore_ports
	lda #1
	sta VERA_ctrl
	lda .pfc_port1_addr
	sta VERA_addr_low
	lda .pfc_port1_addr + 1
	sta VERA_addr_high
	lda .pfc_port1_addr + 2
	sta VERA_addr_bank
	stz VERA_ctrl
	lda .pfc_port0_addr
	sta VERA_addr_low
	lda .pfc_port0_addr + 1
	sta VERA_addr_high
	lda .pfc_port0_addr + 2
	sta VERA_addr_bank
	rts

.pfc_port0_addr !byte 0,0,0
.pfc_port1_addr !byte 0,0,0

; ---------------------------------------------------------------------------
.pcf_make_tile
	; Composite our cell's tile (index .pfc_lo/.pfc_hi in our run) over the
	; tile already in the cell (map entry .pcf_under_lo/hi): our opaque pixels
	; win, our transparent (0) pixels keep what was behind. A fresh tile is
	; allocated for the result and its map entry returned in
	; .pcf_newcode_lo/hi. The store's pixels are doubled, so both nybbles of
	; a byte are the same pixel and the work runs a byte at a time.
	;
	; A map entry carries one palette bank, ours, so the pixels kept from
	; behind are translated into our bank: exact colour match when the banks
	; share one, else the nearest colour by RGB distance.
	lda .pfc_lo				; our source tile
	clc
	adc .pic_slot
	sta .pcf_newcode_lo		; if the cell turns out fully opaque, our own
	lda .pfc_hi				; entry is the answer and no composite is baked
	adc .pic_slot + 1
	and #3
	sta .pic_tmp
	ora .pic_entry_hi
	sta .pcf_newcode_hi
	lda .pcf_newcode_lo
	ldx .pic_tmp
	ldy #0
	jsr .pic_tile_addr		; port 0 -> our tile
	ldy #0
	ldx #0					; x counts transparent pixels
-	lda VERA_data0
	sta .pcf_buf,y
	bne +
	inx
+	iny
	cpy #64
	bne -
	; A fully opaque cell hides what is behind it completely: use our own
	; tile directly and allocate nothing.
	cpx #0
	bne +
	rts
+	jsr .pcf_build_xlat
	jsr .pcf_composite_under	; fill our transparent pixels from the tile behind
	jsr .pcf_alloc_and_write ; a fresh tile holds the composite; entry in .pcf_newcode
	; If the store was full nothing was baked and carry is clear, but
	; .pcf_newcode still holds our own tile's entry from the top of this
	; routine: the cell shows our pixels un-composited, losing only the
	; show-through of what was behind. Do not seed .pcf_newcode any later
	; than that without handling the failure here.
	rts

.pcf_composite_under
	; Where .pcf_buf is transparent (0), take the pixel from the tile behind
	; (.pcf_under), translated into our bank through .pcf_xlat (built by
	; .pcf_build_xlat). Port 0 walks the underlying tile. Shared by the even and
	; odd draw paths.
	lda .pcf_under_lo
	sta .pic_tmp
	lda .pcf_under_hi
	and #3
	tax
	lda .pic_tmp
	ldy #0
	jsr .pic_tile_addr		; port 0 -> it
	ldy #0					; where we are transparent, take its pixel,
-	lda .pcf_buf,y			; translated into our bank
	bne +
	lda VERA_data0
	and #$0f				; both nybbles are the same pixel
	phx
	tax
	lda .pcf_xlat,x
	plx
	sta .pcf_buf,y
	bra ++
+	lda VERA_data0			; keep the ports in step
++	iny
	cpy #64
	bne -
	rts

.pcf_alloc_and_write
	; Allocate a fresh store tile from pic_next_tile, write the 64-byte .pcf_buf
	; into it, and return its map entry in .pcf_newcode. Shared by the
	; compositing (even) and the boundary (odd) draw paths. Returns carry set on
	; success, carry clear when the store is full and nothing was baked.
	;
	; These tiles are baked mid-draw and belong to no window's run: .pic_alloc
	; reserved the picture's own tiles and nothing more, so the store really can
	; run out here. It must never wrap to the bottom. Everything below is live -
	; the picture's own run, and the frame the game keeps on screen for the whole
	; game - so a wrap lands straight on it. Worse, wrapping leaves pic_next_tile
	; low, which convinces .pic_alloc the store is nearly empty, so .pic_gc never
	; runs again and the allocator marches up through the frame unchecked. That
	; was the Arthur X16 bug: the frame's tiles were overwritten a few rooms
	; after the wrap, once the march reached them.
	;
	; So the allocator saturates instead: pic_next_tile stops at PIC_MAX_TILES
	; and further bakes fail. That is self-correcting - a pic_next_tile of
	; PIC_MAX_TILES fails .pic_alloc's fit check, so the next picture drawn
	; compacts the store and the bakes have room again. The caller degrades for
	; the cells it could not bake (see the three call sites); the cost is
	; cosmetic and confined to a nearly-full store, where the alternative was
	; corruption. See todo.txt for the accounting fix that would avoid the
	; degradation altogether.
	lda pic_next_tile + 1
	cmp #>PIC_MAX_TILES
	bcc .paw_have
	bne .paw_full
	lda pic_next_tile
	cmp #<PIC_MAX_TILES
	bcc .paw_have
.paw_full
	clc						; nothing baked; .pcf_newcode is untouched
	rts
.paw_have
	lda pic_next_tile
	sta .pcf_newcode_lo
	lda pic_next_tile + 1
	and #3
	ora .pic_entry_hi
	sta .pcf_newcode_hi
	lda pic_next_tile
	ldx pic_next_tile + 1
	ldy #1
	jsr .pic_tile_addr		; port 1 -> the fresh tile
	inc pic_next_tile		; saturates at PIC_MAX_TILES; never wraps
	bne +
	inc pic_next_tile + 1
+	ldy #0					; write the buffer out to the fresh tile
-	lda .pcf_buf,y
	sta VERA_data1
	iny
	cpy #64
	bne -
	sec
	rts

; The index in the drawing bank whose colour is the current window's background,
; so a picture's transparent (0) pixels can be filled with it - the way a
; transparent FCM pixel shows the MEGA65's $d021. 0 means leave them transparent
; (window background is black/the VERA backdrop, or the bank has no such colour).
pic_bg_index	!byte 0
.pcbi_gb		!byte 0
.pcbi_0r		!byte 0
.pcbi_addr		!byte 0, 0
.pic_direct		!byte 1		; 1 = own palette bank (may inject); 0 = adaptive (shared)
pic_used		!fill 16, 0	; which palette indices the drawn picture's pixels use

.pic_compute_bg_index
	; Work out pic_bg_index for the picture about to be drawn (.pic_bank). Called
	; once per draw_picture, after the palette is loaded. The colour a picture's
	; transparent pixels should show is the screen background (as a transparent
	; FCM pixel shows the MEGA65's global $d021), not the picture's own window:
	; games draw an inset into a throwaway window (set_window, draw, set_window 0)
	; whose background is the default, while the text around it is another
	; window's colour. x16_screen_bg tracks the last set_colour background, like
	; $d021, and set_window leaves it be.
	stz pic_bg_index
	lda x16_screen_bg		; the screen background as a VERA colour 0..15
	beq .pcbi_done			; 0 = black = the backdrop already: nothing to do
	asl						; N * 2 -> the base palette entry ($1fa00 + N*2)
	tay
	stz VERA_ctrl
	lda #$11				; stride 1, address bit 16 ($1fa00 is in bank 1)
	sta VERA_addr_bank
	lda #$fa
	sta VERA_addr_high
	sty VERA_addr_low
	lda VERA_data0			; the window background's colour, VERA order
	sta .pcbi_gb
	lda VERA_data0
	sta .pcbi_0r
	; point .pic_tmp at the bank's CPU palette copy (pic_bank_pal + bank * 32)
	lda .pic_bank
	asl
	asl
	asl
	asl
	asl						; low byte of bank * 32
	sta .pic_tmp
	lda .pic_bank
	lsr
	lsr
	lsr						; high byte (bank * 32 / 256)
	sta .pic_tmp + 1
	lda .pic_tmp
	clc
	adc #<pic_bank_pal
	sta .pic_tmp
	lda .pic_tmp + 1
	adc #>pic_bank_pal
	sta .pic_tmp + 1
	ldx #1					; search indices 1..15 (0 is transparent)
.pcbi_search
	txa
	asl
	tay						; y = index * 2
	lda (.pic_tmp),y
	cmp .pcbi_gb
	bne .pcbi_next
	iny
	lda (.pic_tmp),y
	cmp .pcbi_0r
	bne .pcbi_next
	stx pic_bg_index		; a match: fill transparent pixels with this index
	rts
.pcbi_next
	inx
	cpx #16
	bne .pcbi_search
	; the bank has no such colour. Only inject one into a direct picture's own
	; bank - an adaptive picture shares the direct picture's bank, and adding a
	; colour to it could disturb that picture.
	lda .pic_direct
	beq .pcbi_done
	; inject the background into a free index (one the picture's pixels do not
	; use, from pic_used) so transparent pixels can still show it.
	ldx #1
.pcbi_free
	lda pic_used,x
	beq .pcbi_inject		; index x is unused: take it
	inx
	cpx #16
	bne .pcbi_free
.pcbi_done
	rts						; no free index either: leave transparent
.pcbi_inject
	stx pic_bg_index
	; CPU-side palette copy (.pic_tmp already -> pic_bank_pal + bank*32)
	txa
	asl
	tay
	lda .pcbi_gb
	sta (.pic_tmp),y
	iny
	lda .pcbi_0r
	sta (.pic_tmp),y
	; VERA palette RAM: $1fa00 + bank * 32 + x * 2
	lda .pic_bank
	asl
	asl
	asl
	asl
	asl						; low byte of bank * 32
	sta .pcbi_addr
	lda .pic_bank
	lsr
	lsr
	lsr						; high byte
	sta .pcbi_addr + 1
	txa
	asl						; x * 2
	clc
	adc .pcbi_addr
	sta .pcbi_addr
	bcc +
	inc .pcbi_addr + 1
+	stz VERA_ctrl
	lda #$11
	sta VERA_addr_bank
	lda .pcbi_addr + 1
	clc
	adc #$fa
	sta VERA_addr_high
	lda .pcbi_addr
	sta VERA_addr_low
	lda .pcbi_gb
	sta VERA_data0
	lda .pcbi_0r
	sta VERA_data0
	rts

.pcf_fill_bg
	; Fill .pcf_buf's transparent (0) bytes with the window background
	; (pic_bg_index doubled into both nybbles, as store pixels are doubled).
	; Caller guarantees pic_bg_index is nonzero.
	lda pic_bg_index
	sta .pic_tmp
	asl
	asl
	asl
	asl
	ora .pic_tmp
	sta .pic_tmp			; the index in both nybbles
	ldy #0
-	lda .pcf_buf,y
	bne +
	lda .pic_tmp
	sta .pcf_buf,y
+	iny
	cpy #64
	bne -
	rts

.pcf_bake_bg
	; The "nothing behind" even-path cell, but the window has a background we can
	; show: load our tile into .pcf_buf; if fully opaque, our own tile is the
	; answer (.pcf_newcode); else fill its transparent pixels with the window
	; background and write a fresh tile (entry in .pcf_newcode).
	lda .pfc_lo
	clc
	adc .pic_slot
	sta .pcf_newcode_lo
	lda .pfc_hi
	adc .pic_slot + 1
	and #3
	sta .pic_tmp
	ora .pic_entry_hi
	sta .pcf_newcode_hi
	lda .pcf_newcode_lo
	ldx .pic_tmp
	ldy #0
	jsr .pic_tile_addr		; port 0 -> our tile
	ldy #0
	ldx #0					; count transparent
-	lda VERA_data0
	sta .pcf_buf,y
	bne +
	inx
+	iny
	cpy #64
	bne -
	cpx #0
	bne +
	rts						; fully opaque: use our own tile, allocate nothing
+	jsr .pcf_fill_bg
	; As in .pcf_make_tile: a full store bakes nothing and returns carry clear,
	; leaving .pcf_newcode as our own tile's entry, seeded above - the cell keeps
	; our pixels and its transparent ones stay the backdrop.
	jmp .pcf_alloc_and_write	; fresh tile, entry in .pcf_newcode

.pcf_build_xlat
	; Build the 16-entry table translating the underlying picture's colour
	; indices into our palette bank. Identity when the banks are the same;
	; otherwise, for each underlying colour, the nearest of our bank's
	; colours by |dr| + |dg| + |db| over the CPU-side palette copies (a
	; transparent 0 stays 0 either way). The two palette bases go into the
	; absolute loads below, self-modified as this codebase does elsewhere.
	lda .pcf_under_hi
	lsr
	lsr
	lsr
	lsr						; the underlying bank
	cmp .pic_bank
	bne .bx_differ
	ldx #15					; same bank: identity, but doubled (both nybbles)
-	lda .pic_dub,x			; a store pixel is a byte of two identical nybbles,
	sta .pcf_xlat,x			; so the translation table must be doubled too
	dex
	bpl -
	rts
.bx_differ
	jsr .pcf_pal_ptr		; the underlying bank's palette copy
	lda .pic_tmp
	sta .bx_ugb + 1
	sta .bx_ur + 1
	lda .pic_tmp + 1
	sta .bx_ugb + 2
	sta .bx_ur + 2
	inc .bx_ur + 1			; entry byte 1 holds the red nybble
	bne +
	inc .bx_ur + 2
+	lda .pic_bank			; and our bank's
	jsr .pcf_pal_ptr
	lda .pic_tmp
	sta .bx_ogb + 1
	sta .bx_or + 1
	lda .pic_tmp + 1
	sta .bx_ogb + 2
	sta .bx_or + 2
	inc .bx_or + 1
	bne +
	inc .bx_or + 2
+	stz .pcf_xlat
	ldx #1					; for each underlying colour 1..15
.bx_under
	txa
	asl
	tay
.bx_ugb	lda $ffff,y			; GGGGBBBB (self-modified)
	pha
	and #$0f
	sta .bx_b
	pla
	lsr
	lsr
	lsr
	lsr
	sta .bx_g
.bx_ur	lda $ffff,y			; 0000RRRR (self-modified)
	and #$0f
	sta .bx_r
	lda #$ff
	sta .bx_best
	ldy #2					; for each of our colours 1..15 (index * 2)
.bx_our
.bx_ogb	lda $ffff,y			; (self-modified)
	pha
	and #$0f				; |db|
	sec
	sbc .bx_b
	bcs +
	eor #$ff
	adc #1
+	sta .bx_d
	pla
	lsr
	lsr
	lsr
	lsr						; |dg|
	sec
	sbc .bx_g
	bcs +
	eor #$ff
	adc #1
+	clc
	adc .bx_d
	sta .bx_d
.bx_or	lda $ffff,y			; (self-modified)
	and #$0f				; |dr|
	sec
	sbc .bx_r
	bcs +
	eor #$ff
	adc #1
+	clc
	adc .bx_d
	cmp .bx_best
	bcs .bx_next
	sta .bx_best
	tya
	lsr
	sta .bx_bestj
.bx_next
	iny
	iny
	cpy #32
	bne .bx_our
	ldy .bx_bestj			; store the mapped colour doubled (both nybbles),
	lda .pic_dub,y			; to match the store's two-pixels-a-byte format
	sta .pcf_xlat,x
	inx
	cpx #16
	bne .bx_under
	rts
.bx_b     !byte 0
.bx_g     !byte 0
.bx_r     !byte 0
.bx_d     !byte 0
.bx_best  !byte 0
.bx_bestj !byte 0

.pcf_pal_ptr
	; .pic_tmp = pic_bank_pal + a * 32
	sta .pic_tmp
	lda #0
	sta .pic_tmp + 1
	ldx #5
-	asl .pic_tmp
	rol .pic_tmp + 1
	dex
	bne -
	lda .pic_tmp
	clc
	adc #<pic_bank_pal
	sta .pic_tmp
	lda .pic_tmp + 1
	adc #>pic_bank_pal
	sta .pic_tmp + 1
	rts

; ---------------------------------------------------------------------------
.pic_erase
	; Blank the rectangle the picture in .pic_index occupies at .pic_y,
	; .pic_x: clear its layer 0 map cells back to the transparent tile 0.
	; The text layer in front is left alone. A picture drawn off the tile grid
	; covers a cell more on each shifted axis (.pic_gen_fill), and those EDGE
	; cells hold part of the picture beside part of whatever it was drawn over
	; (a frame border, for Arthur's scenes composited into the frame's hole), so
	; clearing them whole would strip the frame - and it is never redrawn, so
	; the gap persists. Erase only the interior cells, which are fully the
	; picture, and leave the edges: the next scene re-composites its part over
	; them, keeping the frame's. A picture standing on plain background loses
	; nothing from this - its edge parts are transparent there.
	; The size comes from the assembled-in tables, so erasing never has to
	; load the picture from disk.
	jsr .pic_size
	lda .pic_w
	lsr
	sta .pic_cw
	lda .pic_h
	sta .pic_ch
	jsr .pic_map_pos		; .pic_lx, and the offsets it was drawn with
	lda .pic_shift
	beq +
	inc .pic_lx				; skip the left edge column...
	dec .pic_cw				; ...and the right: cw+1 spanned - 2 edges = cw-1
+	lda #0
	sta .pic_row
	lda .pic_shift_y
	beq +
	inc .pic_y				; and the same down the other axis. .pic_y is the
	dec .pic_ch				; engine's own copy, reset on the next draw.
+	lda .pic_cw				; a picture only one cell across or down has no
	beq .pic_erase_done		; interior once its edges are left alone - and a
	lda .pic_ch				; zero cell count would run .pic_start_row's
	beq .pic_erase_done		; counter all the way round
.pic_erase_row
	lda .pic_row			; clip to the screen, exactly as .pic_fill_cells does
	clc
	adc .pic_y
	cmp #SCREEN_HEIGHT
	bcs .pic_erase_done
	jsr .pic_start_row
	ldy #1
	jsr .pic_map_row_addr	; port 1 writes the cleared entries
.pic_erase_cell
	lda .pic_vis
	beq .pic_erase_text
	dec .pic_vis
	lda #0
	sta VERA_data1
	sta VERA_data1
	dec .pic_cols_left
	bne .pic_erase_cell
.pic_erase_text
	; the text cells the picture blanked go back to opaque spaces in the
	; window's colours, as an erased picture leaves window background behind
	jsr .pic_start_row
	lda #1
	sta VERA_ctrl
	jsr .pfc_text_addr
	stz VERA_ctrl
.pic_erase_text_cell
	lda .pic_vis
	beq .pic_erase_next
	dec .pic_vis
	ldy #2					; two text cells a picture cell
-	lda #$20
	sta VERA_data1
	lda vera_composite_colour
	sta VERA_data1
	dey
	bne -
	dec .pic_cols_left
	bne .pic_erase_text_cell
.pic_erase_next
	inc .pic_row
	lda .pic_ch
	cmp .pic_row
	bne .pic_erase_row
.pic_erase_done
	rts

; ---------------------------------------------------------------------------
.pic_draw
	; Draw the picture in .pic_index with its top left cell at .pic_y, .pic_x.
	; Only the layer 0 map and the tile store are touched; the text layer in
	; front never changes, so text over a picture stays until its window
	; scrolls or is erased.
	jsr .pic_stage
	jsr .pic_open
	jsr .pic_att_next
	sta .pic_cw
	jsr .pic_att_next
	sta .pic_ch
	jsr .pic_att_next
	sta .pic_ftiles
	sta .pic_ntiles
	jsr .pic_att_next
	sta .pic_ftiles + 1
	sta .pic_ntiles + 1

	jsr .pic_map_pos		; the first map cell, and the offsets inside it
	jsr .pic_gen_size		; how many cells the picture covers, and can it fit

	; .pic_w/.pic_h in text cells (.pic_h is .pic_gc's rectangle height)
	lda .pic_cw
	asl
	sta .pic_w
	lda .pic_ch
	sta .pic_h

	jsr .pic_alloc			; picks the tile run and the palette bank
	; An adaptive picture is shown in the last direct picture's bank; a
	; direct one uses its own bank and makes it the current palette.
	lda #<pic_adaptive
	ldx #>pic_adaptive
	jsr .pic_addr
	lda (.pi_ptr)
	beq .pd_direct
	lda #0
	sta .pic_direct			; adaptive: reuse the direct bank, do not inject into it
	lda pic_direct_bank
	jsr .pa_set_bank
	clc						; step over our own 32 palette bytes unread: we
	lda .pic_att			; keep the current picture's palette loaded instead
	adc #32
	sta .pic_att
	bcc +
	inc .pic_att + 1
	lda .pic_att + 1
	cmp #$c0
	bne +
	lda #$a0
	sta .pic_att + 1
	inc .pic_att + 2
	jmp +
.pd_direct
	lda #1
	sta .pic_direct
	lda .pic_bank
	sta pic_direct_bank
	jsr .pic_read_palette	; the picture's palette, into its bank
+

	; .pic_att now points at the cell map. Remember it, then skip over it.
	lda .pic_att
	sta .pic_map
	lda .pic_att + 1
	sta .pic_map + 1
	lda .pic_att + 2
	sta .pic_map + 2
	jsr .pic_cells			; a,x = cw * ch
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
	; the skip may cross one or more bank boundaries
-	lda .pic_att + 1
	cmp #$c0
	bcc +
	sec
	sbc #$20				; $c0.. -> $a0.., one bank up
	sta .pic_att + 1
	inc .pic_att + 2
	bra -
+
	; .pic_att now points at the tile block. The aligned path streams it into
	; the reserved run; the off-grid one never copies it, and reads the tiles it
	; needs back out of staging as it builds each cell, so remember where it is.
	lda .pic_att
	sta .gen_tiles
	lda .pic_att + 1
	sta .gen_tiles + 1
	lda .pic_att + 2
	sta .gen_tiles + 2

!ifdef DEBUG_PIC_GEN {
	jsr .dbg_record
}
	lda .pic_shift
	ora .pic_shift_y
	bne .dp_generate
	jsr .pic_copy_tiles		; also records pic_used as it goes
	jsr .pic_compute_bg_index ; fill transparent pixels with the window background
	jmp .pic_fill_cells
.dp_generate
	jsr .pic_scan_used		; what .pic_copy_tiles would have recorded
	jsr .pic_compute_bg_index
	jmp .pic_gen_fill

.pic_scan_used
	; Read the tile block for the palette indices the picture uses, without
	; writing anything. The aligned path gets this free inside .pic_copy_tiles,
	; but .pic_compute_bg_index has to run before the first generated cell is
	; built, so the off-grid path pays for one pass over the block - still far
	; less than the copy it is replacing.
	ldx #15
	lda #0
-	sta pic_used,x
	dex
	bpl -
	lda .pic_ftiles			; bytes = ntiles * 32
	sta .pic_count
	lda .pic_ftiles + 1
	sta .pic_count + 1
	ldx #5
-	asl .pic_count
	rol .pic_count + 1
	dex
	bne -
	lda .pic_count
	ora .pic_count + 1
	beq .psc_done
.psc_loop
	jsr .pic_att_next
	pha
	lsr
	lsr
	lsr
	lsr
	tax
	lda #$ff
	sta pic_used,x
	pla
	and #$0f
	tax
	lda #$ff
	sta pic_used,x
	lda .pic_count
	bne +
	dec .pic_count + 1
+	dec .pic_count
	lda .pic_count
	ora .pic_count + 1
	bne .psc_loop
.psc_done
	rts

.pic_map_pos
	; Split the picture's art-pixel corner (.pic_px 0..319, .pic_py 0..199) into
	; the first layer 0 map cell and the offsets inside it. A map cell is 8 art
	; pixels each way, so this is a divide by 8 and its remainder on both axes -
	; and the remainder is the natural one, "the picture starts this far into
	; the cell", because .gen_tile addresses source pixels directly.
	;
	; Only the column is worked out here: the row is already .pic_y, which
	; .pic_place_cursor set and .pic_py was derived from, so .pic_py >> 3 would
	; only give it back.
	lda .pic_px
	and #7
	sta .pic_shift
	lda .pic_px + 1
	lsr
	lda .pic_px
	ror						; (px >> 1), the high bit carried down
	lsr
	lsr
	sta .pic_lx
	lda .pic_py
	and #7
	sta .pic_shift_y
!ifdef DEBUG_PIC_GEN {
	lda .pic_shift
	sta dbg_req
	lda .pic_shift_y
	sta dbg_req + 1
}
	rts

!ifdef DEBUG_PIC_GEN {
.dbg_record
	; Append this draw to dbg_ring: what was asked for, what it became, and
	; where in the store it landed.
	lda dbg_ring_at
	asl
	asl
	asl
	asl
	tax						; x = entry * 16
	lda .pic_index
	sta dbg_ring,x
	lda .pic_index + 1
	sta dbg_ring + 1,x
	lda .pic_cw
	sta dbg_ring + 2,x
	lda .pic_ch
	sta dbg_ring + 3,x
	lda dbg_req
	sta dbg_ring + 4,x
	lda dbg_req + 1
	sta dbg_ring + 5,x
	lda .pic_shift
	sta dbg_ring + 6,x
	lda .pic_shift_y
	sta dbg_ring + 7,x
	lda .gen_mw
	sta dbg_ring + 8,x
	lda .gen_mh
	sta dbg_ring + 9,x
	lda .pic_slot
	sta dbg_ring + 10,x
	lda .pic_slot + 1
	sta dbg_ring + 11,x
	lda pic_next_tile
	sta dbg_ring + 12,x
	lda pic_next_tile + 1
	sta dbg_ring + 13,x
	lda .pic_lx
	sta dbg_ring + 14,x
	lda .pic_y
	sta dbg_ring + 15,x
	lda dbg_ring_at
	clc
	adc #1
	and #31
	sta dbg_ring_at
	rts
}

.pic_gen_size
	; .gen_mw / .gen_mh: the map cells the picture covers, one more than its own
	; art cells on an axis it is shifted along. .pic_ntiles becomes that product
	; - the run .pic_alloc must reserve, since every covered cell is generated
	; into a tile of its own - while .pic_ftiles keeps the file's own count for
	; .pic_scan_used. On the tile grid nothing is generated and the reservation
	; stays the file's count.
	lda .pic_cw
	sta .gen_mw
	lda .pic_ch
	sta .gen_mh
	lda .pic_shift
	ora .pic_shift_y
	beq .pgs_done
	lda .pic_shift
	beq +
	inc .gen_mw
+	lda .pic_shift_y
	beq +
	inc .gen_mh
+	lda #0					; .pic_count = mw * mh
	sta .pic_count
	sta .pic_count + 1
	ldx .gen_mh
	beq .pgs_fits
-	lda .pic_count
	clc
	adc .gen_mw
	sta .pic_count
	bcc +
	inc .pic_count + 1
+	dex
	bne -
.pgs_fits
	; A picture needing more cells than the whole store cannot be generated at
	; all. That is only the full-screen ones (40x25 -> 1066 cells against 1023
	; tiles), which every game draws at the origin and never shifts, so this
	; falls back to the tile grid - an error of under half a text cell on a
	; picture that covers the screen. tools/tilebudget.py has the numbers.
	lda .pic_count + 1
	cmp #>PIC_MAX_TILES		; the store's high byte; its low byte is zero
	bcc .pgs_take
	lda #0					; too big: snap to the grid and copy as usual
	sta .pic_shift
	sta .pic_shift_y
	lda .pic_cw
	sta .gen_mw
	lda .pic_ch
	sta .gen_mh
	rts
.pgs_take
	lda .pic_count
	sta .pic_ntiles
	lda .pic_count + 1
	sta .pic_ntiles + 1
.pgs_done
	rts

; ---------------------------------------------------------------------------
; The text layer cannot bury a picture the way the MEGA65's one-plane screen
; does, so erasing text must erase the layer 0 cells under it explicitly.

pic_erase_win_rect
	; x = window number: clear the layer 0 map cells the window's rectangle
	; covers completely, so erase_window leaves no picture behind. The
	; boundary half-cells of an odd-column window survive, as .pic_erase's do.
	lda window_y,x
	sta .pic_y
	lda window_y_size,x
	sta .pic_ch
	lda window_x,x
	clc
	adc #1
	lsr
	sta .pic_lx
	lda window_x,x
	clc
	adc window_x_size,x
	lsr						; the first map column past the window
	sec
	sbc .pic_lx
	beq .pewr_done			; no whole cells inside
	bcc .pewr_done
	sta .pic_cw
	lda #0
	sta .pic_row
.pewr_row
	lda .pic_row
	clc
	adc .pic_y
	cmp #SCREEN_HEIGHT
	bcs .pewr_done
	ldy #1
	jsr .pic_map_row_addr	; port 1 writes the cleared entries
	ldx .pic_cw
	lda #0
-	sta VERA_data1
	sta VERA_data1
	dex
	bne -
	inc .pic_row
	lda .pic_row
	cmp .pic_ch
	bne .pewr_row
.pewr_done
	rts

pic_scroll_win_up
	; The current window has just scrolled up one line on the text layer
	; (.s_scroll_vera). The pictures behind it live on layer 0, which the text
	; scroll does not touch, so a drop-cap initial or any picture under the
	; text would stay put while its paragraph moved up. Scroll the layer 0 map
	; the same way and blank the new last row, so the picture travels with the
	; text as it does on the MEGA65 (where the tiles are in screen RAM).
	;
	; The window's rectangle is recomputed from current_window and clamped to
	; the screen, the way .calc_window_rect does for the text scroll. A map
	; cell spans two text columns and one text row, so a text row is a map row
	; and a text column is map column * 2. Only whole map cells inside the
	; window move - the same boundary rule pic_erase_win_rect keeps for an
	; odd-column window.
	ldx current_window
	lda window_x,x
	clc
	adc #1
	lsr						; first whole map column inside the window
	sta .psu_col0
	lda window_x,x
	clc
	adc window_x_size,x
	cmp s_screen_width		; clamp the right edge to the screen
	bcc +
	lda s_screen_width
+	lsr						; first map column past the window
	sec
	sbc .psu_col0
	beq .psu_done			; no whole cells inside: nothing to scroll
	bcc .psu_done
	sta .psu_cw				; whole map cells across the window
	lda window_y,x
	sta .psu_dst			; the window's top row
	clc
	adc window_y_size,x
	cmp s_screen_height		; clamp the bottom edge to the screen
	bcc +
	lda s_screen_height
+	sec
	sbc #1
	sta .psu_bottom			; the window's last (on-screen) row
	lda #0
	sta .pic_y				; .pic_map_row_addr adds .pic_y to .pic_row
	lda .psu_col0
	sta .pic_lx
.psu_row
	lda .psu_dst
	cmp .psu_bottom
	beq .psu_blank			; the last row is blanked, not copied into
	bcs .psu_done			; a zero-height window: nothing to scroll
	clc
	adc #1
	sta .pic_row
	ldy #0
	jsr .pic_map_row_addr	; port 0 reads the source row (dst + 1)
	lda .psu_dst
	sta .pic_row
	ldy #1
	jsr .pic_map_row_addr	; port 1 writes the destination row
	ldx .psu_cw
-	lda VERA_data0			; two bytes a cell
	sta VERA_data1
	lda VERA_data0
	sta VERA_data1
	dex
	bne -
	inc .psu_dst
	bne .psu_row			; always (rows are well under 256)
.psu_blank
	lda .psu_bottom
	sta .pic_row
	ldy #1
	jsr .pic_map_row_addr	; port 1 writes the new last row
	ldx .psu_cw
	lda #0					; transparent tile 0, palette offset 0
-	sta VERA_data1
	sta VERA_data1
	dex
	bne -
.psu_done
	stz VERA_ctrl			; leave port 0 selected, as the screen code expects
	rts

.psu_col0   !byte 0
.psu_cw     !byte 0
.psu_dst    !byte 0
.psu_bottom !byte 0

pic_clear_map_rows
	; a = first text row, x = the row past the last. Clear the layer 0 map
	; across those rows, full width. Used when window 1 grows downwards and
	; takes rows off window 0 (split_window): the pictures behind window 0's
	; text stay on layer 0, and window 0 will never scroll or erase those rows
	; again, so anything left there shows through window 1 for ever. The
	; MEGA65 has no such case - its tiles are in screen RAM, so the status
	; line's own text overwrites them.
	; The rows are cleared edge to edge, so unlike pic_erase_win_rect there is
	; no half-cell boundary to preserve.
	sta .pcmr_row
	stx .pcmr_end
	lda #0
	sta .pic_y				; .pic_map_row_addr adds .pic_y to .pic_row
	sta .pic_lx				; from map column 0
.pcmr_loop
	lda .pcmr_row
	cmp .pcmr_end
	bcs .pcmr_done
	cmp #SCREEN_HEIGHT		; never past the bottom of the screen
	bcs .pcmr_done
	sta .pic_row
	ldy #1
	jsr .pic_map_row_addr	; port 1 writes the row
	ldx #64					; every map cell in a 64-wide map row
	lda #0					; transparent tile 0, palette offset 0
-	sta VERA_data1
	sta VERA_data1
	dex
	bne -
	inc .pcmr_row
	bne .pcmr_loop			; always (rows are well under 256)
.pcmr_done
	stz VERA_ctrl			; leave port 0 selected, as the screen code expects
	rts

.pcmr_row !byte 0
.pcmr_end !byte 0

pic_erase_line_cells
	; a = text row, x = start text column, y = count of text columns. Clear the
	; whole layer 0 map cells the run [x, x + y) covers, so erase_line leaves no
	; picture showing on that row - erase_window clears its rectangle the same
	; way. A map cell spans two text columns, so only the whole cells inside the
	; run die; the boundary half-cell of an odd start or end column survives, as
	; pic_erase_win_rect's do. Only port 1 is touched, so the screen code's
	; port 0 is left exactly as it was.
	sta .pelc_row
	stx .pelc_start
	tya
	clc
	adc .pelc_start			; end column (exclusive) = start + count
	lsr						; first map column past the run
	sta .pelc_end
	lda .pelc_start
	clc
	adc #1
	lsr						; first whole map column inside the run
	sta .pelc_c0
	lda .pelc_end
	sec
	sbc .pelc_c0
	beq .pelc_done			; no whole cells inside: nothing to clear
	bcc .pelc_done
	sta .pelc_cw
	lda #0
	sta .pic_y				; .pic_map_row_addr adds .pic_y to .pic_row
	lda .pelc_c0
	sta .pic_lx
	lda .pelc_row
	sta .pic_row
	ldy #1
	jsr .pic_map_row_addr	; port 1 -> the run's first whole map cell
	ldx .pelc_cw
	lda #0					; transparent tile 0, palette offset 0
-	sta VERA_data1
	sta VERA_data1
	dex
	bne -
.pelc_done
	stz VERA_ctrl			; leave port 0 selected, as the screen code expects
	rts

.pelc_row   !byte 0
.pelc_start !byte 0
.pelc_end   !byte 0
.pelc_c0    !byte 0
.pelc_cw    !byte 0

pic_erase_screen
	; The whole screen is being cleared: blank the layer 0 map and start the
	; tile store over, since nothing on it is shown any more.
	stz VERA_ctrl
	lda #$11				; port 0, stride 1, the map is in VRAM bank 1
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
	lda #PIC_FIRST_TILE
	sta pic_next_tile
	lda #0
	sta pic_next_tile + 1
	ldx #15					; no window's run survives a cleared screen
	lda #$ff
-	sta pic_win_number,x
	dex
	bpl -
	rts
