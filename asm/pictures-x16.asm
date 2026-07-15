; The z6 picture engine for the Commander X16: the same job as the MEGA65
; engine in screen-z6.asm (which this is a port of), done with VERA instead
; of the VIC-IV.
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
; A picture may be placed at an odd text column (Arthur centres scenes),
; which the 16-pixel tile grid cannot express. For now the column is
; rounded down to the even one, an 8-pixel error; the true half-cell
; compositing path is still to do. See todo.txt.

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
.pic_odd     !byte 0		; 1 if placed at an odd text column (boundary tiles)
.bd_left     !byte 0,0		; boundary tile source: left art cell's index ($ffff none)
.bd_right    !byte 0,0		; and the right art cell's
.pfo_m       !byte 0		; the odd fill's map cell counter, 0..cw
.pfo_vis     !byte 0		; cells of the odd row still on screen
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
.gc_y1       !byte 0		; the incoming rectangle in layer 0 map cells:
.gc_x0       !byte 0		; only cells it covers completely die with it
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
	; already doomed
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
	; a = palette bank 1..PIC_PAL_BANKS. It rides in the top nybble of every
	; map entry the picture writes.
	sta .pic_bank
	asl
	asl
	asl
	asl
	sta .pic_entry_hi
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
	; marks them survivors anyway. A cell the picture only half covers (an
	; odd column) counts as outside: its tile must survive.

	; The incoming rectangle in map cells, interior only
	lda .pic_x
	clc
	adc #1
	lsr
	sta .gc_x0
	lda .pic_x
	clc
	adc .pic_w
	lsr
	sta .gc_x1
	lda .pic_y
	clc
	adc .pic_h
	sta .gc_y1

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
	cmp .pic_y
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
	lda .pic_dub,x
	sta VERA_data0
	pla
	and #$0f
	tax
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
	beq .pfc_rowdone		; the rest of the row is right of the screen
	dec .pic_vis
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
	; nothing behind: write our own tile, its 0 pixels transparent
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
; Odd-column placement. A 16x8 tile spans two text columns, so a picture placed
; at an odd text column is shifted half a tile right: each of the cw+1 map cells
; it now spans shows the right half of one art cell beside the left half of the
; next. These boundary tiles are baked fresh from the picture's own stored tiles
; (their left/right 8-pixel halves), so no new picture data is needed - only up
; to ~+1% more tiles than the even placement, since Arthur's art repeats
; horizontally and the boundary patterns recur. A boundary cell with an opaque
; tile behind it is composited exactly as the even path does.

.pic_bake_boundary_buf
	; Build a 16x8 boundary tile in .pcf_buf: the right half of the store tile
	; .pic_slot+.bd_left (art pixels 4-7 = bytes 4-7 of each 8-byte store row)
	; beside the left half of .pic_slot+.bd_right (bytes 0-3). A $ffff index means
	; that half is transparent (zeroes). Returns x = the count of transparent (0)
	; bytes, so the caller can skip compositing when the tile is fully opaque.
	lda .bd_left + 1
	cmp #$ff
	bne .bbb_left
	ldy #0					; left half transparent: zero buf bytes n*8+0..3
-	lda #0
	sta .pcf_buf,y
	sta .pcf_buf + 1,y
	sta .pcf_buf + 2,y
	sta .pcf_buf + 3,y
	tya
	clc
	adc #8
	tay
	cpy #64
	bne -
	beq .bbb_right			; always
.bbb_left
	lda .bd_left			; store tile = .pic_slot + .bd_left
	clc
	adc .pic_slot
	sta .pic_tmp
	lda .bd_left + 1
	adc .pic_slot + 1
	sta .pic_tmp + 1
	lda .pic_tmp
	ldx .pic_tmp + 1
	ldy #0
	jsr .pic_tile_addr		; port 0 -> the left source tile
	ldy #0
-	lda VERA_data0			; skip bytes 0-3 (the source's own left half)
	lda VERA_data0
	lda VERA_data0
	lda VERA_data0
	lda VERA_data0			; bytes 4-7 -> buf[row+0..3]
	sta .pcf_buf,y
	lda VERA_data0
	sta .pcf_buf + 1,y
	lda VERA_data0
	sta .pcf_buf + 2,y
	lda VERA_data0
	sta .pcf_buf + 3,y
	tya
	clc
	adc #8
	tay
	cpy #64
	bne -
.bbb_right
	lda .bd_right + 1
	cmp #$ff
	bne .bbb_rtile
	ldy #4					; right half transparent: zero buf bytes n*8+4..7
-	lda #0
	sta .pcf_buf,y
	sta .pcf_buf + 1,y
	sta .pcf_buf + 2,y
	sta .pcf_buf + 3,y
	tya
	clc
	adc #8
	tay
	cpy #68
	bne -
	beq .bbb_count			; always
.bbb_rtile
	lda .bd_right
	clc
	adc .pic_slot
	sta .pic_tmp
	lda .bd_right + 1
	adc .pic_slot + 1
	sta .pic_tmp + 1
	lda .pic_tmp
	ldx .pic_tmp + 1
	ldy #0
	jsr .pic_tile_addr		; port 0 -> the right source tile
	ldy #4
-	lda VERA_data0			; bytes 0-3 -> buf[row+4..7]
	sta .pcf_buf,y
	lda VERA_data0
	sta .pcf_buf + 1,y
	lda VERA_data0
	sta .pcf_buf + 2,y
	lda VERA_data0
	sta .pcf_buf + 3,y
	lda VERA_data0			; skip bytes 4-7 (the source's own right half)
	lda VERA_data0
	lda VERA_data0
	lda VERA_data0
	tya
	clc
	adc #8
	tay
	cpy #68
	bne -
.bbb_count
	ldx #0					; count transparent (0) bytes
	ldy #0
-	lda .pcf_buf,y
	bne +
	inx
+	iny
	cpy #64
	bne -
	rts

.pic_fill_cells_odd
	; The odd-placement equivalent of .pic_fill_cells: cw+1 boundary cells a row.
	lda .pic_map
	sta .pic_att
	lda .pic_map + 1
	sta .pic_att + 1
	lda .pic_map + 2
	sta .pic_att + 2
	lda #0
	sta .pic_row
.pfo_row
	lda .pic_row
	clc
	adc .pic_y
	cmp #SCREEN_HEIGHT
	bcc +
	jmp .pfo_done
+	lda .pic_cw				; buffer this row's cw cell-map entries
	asl
	sta .pic_tmp
	ldx #0
-	phx
	jsr .pic_att_next
	plx
	sta .pfc_rowbuf,x
	inx
	cpx .pic_tmp
	bne -
	ldy #0					; port 0 reads what is there, port 1 writes anew
	jsr .pic_map_row_addr
	ldy #1
	jsr .pic_map_row_addr
	lda #SCREEN_WIDTH / 2
	sec
	sbc .pic_lx				; cells from .pic_lx to the right edge
	sta .pfo_vis
	ldx #0					; x = 2 * m into .pfc_rowbuf
	stz .pfo_m
.pfo_cell
	lda .pfo_vis
	bne +
	jmp .pfo_rowdone
+	dec .pfo_vis
	lda .pfo_m				; left index = art cell m-1 (none when m = 0)
	bne +
	lda #$ff
	sta .bd_left
	sta .bd_left + 1
	bra .pfo_getright
+	lda .pfc_rowbuf - 2,x
	sta .bd_left
	lda .pfc_rowbuf - 1,x
	sta .bd_left + 1
.pfo_getright
	lda .pfo_m				; right index = art cell m (none when m = cw)
	cmp .pic_cw
	bcc +
	lda #$ff
	sta .bd_right
	sta .bd_right + 1
	bra .pfo_have
+	lda .pfc_rowbuf,x
	sta .bd_right
	lda .pfc_rowbuf + 1,x
	sta .bd_right + 1
.pfo_have
	lda .bd_left + 1		; both halves transparent? leave the cell alone
	and .bd_right + 1
	cmp #$ff
	bne .pfo_draw
	ldy .pfo_m
	lda #0
	sta .pfo_drawn,y
	lda VERA_data0			; keep what is under; both ports step
	sta VERA_data1
	lda VERA_data0
	sta VERA_data1
	jmp .pfo_next
.pfo_draw
	lda #0					; record which halves are opaque, for the text blank
	ldy .bd_left + 1
	cpy #$ff
	beq +
	ora #1					; left half opaque
+	ldy .bd_right + 1
	cpy #$ff
	beq +
	ora #2					; right half opaque
+	ldy .pfo_m
	sta .pfo_drawn,y
	lda VERA_data0			; what is behind, for compositing
	sta .pcf_under_lo
	lda VERA_data0
	sta .pcf_under_hi
	phx
	jsr .pfc_save_ports
	jsr .pic_bake_boundary_buf	; -> .pcf_buf, x = transparent count
	cpx #0
	beq .pfo_write			; fully opaque: no compositing
	lda .pcf_under_lo		; is there a tile behind? index != 0
	sta .pic_tmp
	lda .pcf_under_hi
	and #3
	ora .pic_tmp
	beq .pfo_write			; nothing behind: our transparent pixels stay 0
	jsr .pcf_build_xlat
	jsr .pcf_composite_under
.pfo_write
	jsr .pcf_alloc_and_write	; -> .pcf_newcode
	jsr .pfc_restore_ports
	plx
	lda .pcf_newcode_lo
	sta VERA_data1
	lda .pcf_newcode_hi
	sta VERA_data1
.pfo_next
	inx
	inx
	inc .pfo_m
	lda .pfo_m
	cmp .pic_cw
	beq .pfo_celljmp		; m == cw: the final boundary cell is still valid
	bcs .pfo_rowdone		; m > cw: the row is done
.pfo_celljmp
	jmp .pfo_cell
.pfo_rowdone
	jsr .pfo_blank_text
	inc .pic_row
	lda .pic_ch
	cmp .pic_row
	beq .pfo_done
	jmp .pfo_row
.pfo_done
	rts

.pfo_blank_text
	; Blank the text over the odd row's drawn boundary cells (two text cells
	; each), leaving fully-transparent cells' text; .pfo_drawn was filled by the
	; fill pass. The mirror of .pfc_blank_text for the cw+1 boundary cells.
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
.pfobt_cell
	lda .pfo_vis
	beq .pfobt_done
	dec .pfo_vis
	ldy .pfo_m
	lda .pfo_drawn,y		; bit 0 = left half opaque, bit 1 = right half
	sta .pic_tmp
	and #1					; the left text cell sits over the tile's left half
	beq .pfobt_lkeep
	lda VERA_data0			; opaque half: blank (space, keep fg, clear bg)
	lda #$20
	sta VERA_data1
	lda VERA_data0
	and #$0f
	sta VERA_data1
	bra .pfobt_r
.pfobt_lkeep
	lda VERA_data0			; transparent half: keep the text background there
	sta VERA_data1
	lda VERA_data0
	sta VERA_data1
.pfobt_r
	lda .pic_tmp
	and #2					; the right text cell over the tile's right half
	beq .pfobt_rkeep
	lda VERA_data0
	lda #$20
	sta VERA_data1
	lda VERA_data0
	and #$0f
	sta VERA_data1
	bra .pfobt_next
.pfobt_rkeep
	lda VERA_data0
	sta VERA_data1
	lda VERA_data0
	sta VERA_data1
.pfobt_next
	inc .pfo_m
	lda .pfo_m
	cmp .pic_cw
	beq +					; m == cw still valid
	bcs .pfobt_done
+	bra .pfobt_cell
.pfobt_done
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
	; Allocate a fresh store tile from pic_next_tile (wrapping at the store end,
	; as .pic_alloc does), write the 64-byte .pcf_buf into it, and return its map
	; entry in .pcf_newcode. Shared by the compositing (even) and the boundary
	; (odd) draw paths.
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
	inc pic_next_tile
	bne +
	inc pic_next_tile + 1
+	lda pic_next_tile + 1	; wrap at the end of the store, as .pic_alloc does
	cmp #>PIC_MAX_TILES
	bcc +
	bne ++
	lda pic_next_tile
	cmp #<PIC_MAX_TILES
	bcc +
++	lda #PIC_FIRST_TILE
	sta pic_next_tile
	lda #0
	sta pic_next_tile + 1
+	ldy #0					; write the buffer out to the fresh tile
-	lda .pcf_buf,y
	sta VERA_data1
	iny
	cpy #64
	bne -
	rts

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
	; The text layer in front is left alone. An odd-column picture was drawn
	; across cw+1 boundary cells (.pic_fill_cells_odd); its two EDGE cells each
	; hold half the picture beside half of whatever it was drawn over (a frame
	; border, for Arthur's scenes composited into the frame's hole), so clearing
	; them whole would strip the frame - and it is never redrawn, so the gap
	; persists. Erase only the cw-1 interior cells (fully the picture) and leave
	; the two edges: the next scene re-composites its half over them, keeping
	; the frame's half. A picture standing on plain background loses nothing
	; from this - its edge halves are transparent there.
	; The size comes from the assembled-in tables, so erasing never has to
	; load the picture from disk.
	jsr .pic_size
	lda .pic_w
	lsr
	sta .pic_cw
	lda .pic_x
	lsr
	sta .pic_lx
	lda .pic_x
	and #1
	beq +
	inc .pic_lx				; skip the left edge cell...
	dec .pic_cw				; ...and the right one: cw+1 spanned - 2 edges = cw-1
+	lda .pic_h
	sta .pic_ch
	lda #0
	sta .pic_row
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
	sta .pic_ntiles
	jsr .pic_att_next
	sta .pic_ntiles + 1

	; A 16x8 tile spans two text columns, so an even .pic_x aligns with the
	; tile grid and an odd one is placed half a tile right via boundary tiles
	; (.pic_fill_cells_odd). Either way the first map column is .pic_x / 2.
	lda .pic_x
	lsr
	sta .pic_lx
	lda .pic_x
	and #1
	sta .pic_odd

	; .pic_w/.pic_h in text cells, for .pic_gc's rectangle
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
	jsr .pic_copy_tiles
	lda .pic_odd
	beq .dp_even
	jsr .dp_odd_fits		; clears .pic_odd if the boundary tiles would overflow
	lda .pic_odd
	beq .dp_even
	jmp .pic_fill_cells_odd
.dp_even
	jmp .pic_fill_cells

.dp_odd_fits
	; The odd path bakes up to (cw+1)*ch boundary tiles above the picture's own
	; copied run (pic_next_tile is now just past it). If they would run off the
	; end of the 1024-tile store they must not wrap - that would overwrite the
	; source tiles the bake reads and the frame under the picture - so a picture
	; too big for a boundary redraw falls back to even placement, which reuses
	; the copied tiles at the rounded column (an 8px shift, invisible on the
	; full-screen frames that hit this). Small centred scenes fit and stay exact.
	lda #0
	sta .pic_count
	sta .pic_count + 1
	ldx .pic_ch
	beq .dof_done
	lda .pic_cw
	clc
	adc #1					; cw + 1 boundary cells a row (<= 41, one byte)
	sta .pic_tmp
-	lda .pic_count
	clc
	adc .pic_tmp
	sta .pic_count
	bcc +
	inc .pic_count + 1
+	dex
	bne -
	lda pic_next_tile		; pic_next_tile + (cw+1)*ch >= PIC_MAX_TILES ?
	clc
	adc .pic_count
	lda pic_next_tile + 1
	adc .pic_count + 1
	cmp #>PIC_MAX_TILES		; the store's high byte; low byte is 0
	bcc .dof_done			; sum's high byte < it: fits
	lda #0
	sta .pic_odd			; would overflow: round to even instead
.dof_done
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
