; The z6 picture engine for the Commodore MEGA65: draws the games' pictures on
; the VIC-IV full colour (-fcm) screen. The X16 has its own port of this in
; pictures-x16.asm; the two engines are mutually exclusive (sourced in the two
; branches of !ifdef TARGET_X16 in screen-z6.asm) and expose the same entry
; points (pic_load_all, .pic_find, .pic_draw, .pic_erase, ...) so the picture
; opcodes and screen-model hooks in screen-z6.asm stay target-agnostic.
;
; This file is sourced only under !ifdef Z6_PICTURES and only for non-X16
; targets, so the guards that split MEGA65 from X16 inside it are implicit here.

; The pictures are files on the disk, preloaded into attic RAM at boot the same
; way the sound effects are. Drawing one copies its tiles down into the tile
; store, shifting every pixel index into the drawing window's palette bank,
; loads its palette, and fills its cells in screen RAM.
;
; A window holds at most one picture, so each window owns a run of the tile
; store and a bank of 16 palette entries above the 16 text colours.
;
; The X16 draws its pictures on a VERA tile layer instead, with its own copy
; of this machinery in pictures-x16.asm (sourced below); only the state and
; engine split per target, the opcodes further down are common.

; Attic RAM survives the machine reset that z_ins_restart reboots through, so a
; restart (the "restart" command, or dying) can reuse the pictures already
; preloaded there instead of reading every file off the picture disks again.
; What does NOT survive is the interpreter's RAM: the reboot reloads it from
; disk, zeroing the pic_page_lo/hi tables that say where each picture landed.
; Those cannot be recomputed - a picture's page depends on its decompressed
; size, known only by reading it - so they are kept in attic too, in a header
; below the pictures, behind a signature. Same idea as reu_filled in disk.asm: a
; signature that outlives the reboot says the data is already there. reu_filled
; uses game_id, which is !ifdef VMEM and so does not exist on the MEGA65; the
; story's serial and checksum identify the story file just as well, and Ozmoo
; never rewrites either (unlike flags_2 or the screen dimensions).
PIC_SIG_BYTES = 8				; header_serial (6) then header_checksum (2)
PIC_ATTIC_HEADER_PAGE = $3000	; $08300000: past the story, sounds and scrollback
PIC_ATTIC_HEADER_BYTES = PIC_SIG_BYTES + 2 * picture_count
PIC_ATTIC_PAGE = PIC_ATTIC_HEADER_PAGE + (PIC_ATTIC_HEADER_BYTES + 255) / 256
; PIC_MAX_TILES, FCM_TILE_STORE and FCM_TILE_CODE_HI are in constants.asm:
; where the store can live depends on what else is in the target's fast RAM.

.pic_ptr = z_temp			; 2 bytes, the screen row being written
.pic_att = z_temp + 2		; 4 bytes, a 32 bit pointer into attic RAM
.pic_dst = z_temp + 6		; 4 bytes, a 32 bit pointer into the tile store
.pi_ptr  = z_temp + 10		; 2 bytes, indexes the pic_* tables by .pic_index

.pic_index   !byte 0,0		; word: a game may have more than 255 pictures
.pic_w       !byte 0		; cells across
.pic_h       !byte 0		; cells down
.pic_ntiles  !byte 0,0
.pic_slot    !byte 0,0		; the picture's first tile in the store
.pic_pal_off   !byte 0		; 16 * the window being drawn into
.pic_pixel_base !byte 0		; 16 + .pic_pal_off: what a colour index of 1 becomes
.pic_row     !byte 0
.pic_col2    !byte 0
.pic_col2_hi !byte 0		; ninth bit of the doubled column: set = past the edge
.pic_cols_left !byte 0		; cells left on the row being filled or erased
.pic_map     !byte 0,0,0	; where the cell map starts in attic RAM
.pic_count   !byte 0,0		; a general 16 bit counter
.pfc_lo      !byte 0		; a cell's tile index low byte while drawing
.pfc_hi      !byte 0		; and high byte
.pcf_under_lo !byte 0		; the screen code already in the cell (what's behind)
.pcf_under_hi !byte 0
.pcf_newcode_lo !byte 0		; the composited tile's screen code
.pcf_newcode_hi !byte 0
.pcf_buf     !fill 64, 0	; one tile being composited, a byte a pixel

; Tile-store compaction (.pic_gc): a bit per tile for "a cell outside the
; incoming picture still shows this", the survivor count below each bitmap
; byte, and the byte-arithmetic helper tables.
.gc_bitmap   !fill 256, 0
.gc_pref_lo  !fill 256, 0
.gc_pref_hi  !fill 256, 0
.gc_bit      !byte 1, 2, 4, 8, 16, 32, 64, 128
.gc_below    !byte 0, 1, 3, 7, 15, 31, 63, 127
.gc_pop						; how many bits a byte has set
!for i, 0, 255 {
	!byte (i&1) + ((i>>1)&1) + ((i>>2)&1) + ((i>>3)&1) + ((i>>4)&1) + ((i>>5)&1) + ((i>>6)&1) + ((i>>7)&1)
}
.gc_row      !byte 0
.gc_col      !byte 0
.gc_y1       !byte 0		; .pic_y + .pic_h
.gc_x1       !byte 0		; .pic_x + .pic_w
.gc_next     !byte 0,0		; the compacted store's next free tile
.gc_old      !byte 0,0		; the survivor being moved
.gc_byi      !byte 0		; bitmap byte index being walked
.gc_t        !byte 0
.gc_t2       !byte 0


pic_next_tile  !byte 0,0
pic_win_base   !fill 16, 0	; two bytes a window
pic_win_count  !fill 16, 0
pic_win_number !fill 16, $ff ; the picture index (a word, so two bytes a window)
							; resident in each window's run; $ffff = none. A
							; window's run may only be reused for the same picture;
							; a different one must not overwrite tiles the resident
							; picture's still-visible cells use.
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

; .pic_num (a 2-byte scratch defined with the number-printing helper below) is
; reused here to turn a picture number into a filename and to search pic_number.
.pic_dev       !byte 0		; device holding the picture disk being read
.cur_disk      !byte 0		; which picture disk .pic_dev holds (0 = none yet)
.err_digit     !byte 0		; first digit read back from a drive's error channel
.pic_next_page !byte 0,0
.pic_progress  !byte 0		; countdown to the next slash in the loading bar

; Loading the pictures takes a noticeable moment, so pic_load_all draws a slash
; bar like the story preloader's. Scale it to the picture count so it is about
; 30 slashes wide however many pictures there are, rather than one per picture.
PIC_PROGRESS_STEP = picture_count / 32 + 1

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
	; Preload every picture into attic RAM. Called at boot, next to the sound
	; effects, and for the same reason: the files are far too big to assemble
	; into the interpreter. They are RLE compressed, and are expanded on the way
	; in, so attic holds them ready to draw.
	;
	; The pictures are spread over one or more picture disks (pic_disk), packed
	; to fill one d81 before the next. With two drives the second disk can sit
	; in the second drive, so each disk is looked for there and in the boot
	; drive before the player is ever asked to swap.
	;
	; A restart reboots the machine and reloads the interpreter, so this runs
	; again - but attic still holds the pictures. If the header's signature is
	; this game's, take the page tables back out of it and skip the load; see
	; the PIC_ATTIC_HEADER_PAGE comment above. The header is readable by now:
	; deletable_init loads the story before z_init runs.
	jsr .pic_make_signature
	jsr .pic_attic_header
	ldx #0
-	jsr .pic_att_next
	cmp .pic_sig,x
	bne .pla_load			; another story, or cold-boot garbage: load
	inx
	cpx #PIC_SIG_BYTES
	bne -
	lda #0					; ours: restore the tables and skip the disk
	sta .pic_header_write
	jsr .pic_header_tables
	rts
.pla_load
	lda #<PIC_ATTIC_PAGE
	sta .pic_next_page
	lda #>PIC_ATTIC_PAGE
	sta .pic_next_page + 1
	lda #0
	sta .pic_index
	sta .pic_index + 1
	sta .cur_disk			; no picture disk located yet
	lda #13					; a label, then the loading bar on the next line
	jsr s_printchar
	lda #>.loading_msg
	ldx #<.loading_msg
	jsr printstring_raw
	lda #13
	jsr s_printchar
	lda #1					; first picture prints the first slash
	sta .pic_progress
.pla_loop
	dec .pic_progress		; a slash every PIC_PROGRESS_STEP pictures
	bne +
	lda #47					; "/"
	jsr s_printchar
	lda #PIC_PROGRESS_STEP
	sta .pic_progress
+	lda #<pic_number_lo		; build this picture's filename from its number
	ldx #>pic_number_lo
	jsr .pic_addr
	ldy #0
	lda (.pi_ptr),y
	sta .pic_num
	lda #<pic_number_hi
	ldx #>pic_number_hi
	jsr .pic_addr
	ldy #0
	lda (.pi_ptr),y
	sta .pic_num + 1
	jsr .pic_set_filename

	lda #<pic_disk			; still on the located disk, or find the next one?
	ldx #>pic_disk
	jsr .pic_addr
	ldy #0
	lda (.pi_ptr),y
	cmp .cur_disk
	beq +
	sta .cur_disk
	jsr .pic_locate_disk	; sets .pic_dev to the drive holding this disk
+
	jsr .pic_open_current	; open the file on .pic_dev, ready to read

	lda #<pic_page_lo		; the picture starts on the next free page
	ldx #>pic_page_lo
	jsr .pic_addr
	ldy #0
	lda .pic_next_page
	sta (.pi_ptr),y
	sta .pic_att + 1
	lda #<pic_page_hi
	ldx #>pic_page_hi
	jsr .pic_addr
	ldy #0
	lda .pic_next_page + 1
	sta (.pi_ptr),y
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
	bne +
	inc .pic_index + 1
+	lda .pic_index			; loop while .pic_index < picture_count (16 bit)
	cmp #<picture_count
	lda .pic_index + 1
	sbc #>picture_count
	bcs +					; the loop body is too long for a direct branch back
	jmp .pla_loop
+
	; Every picture is in attic now. Write the header so a restart can skip all
	; of the above: the page tables first, then the signature last, so a load
	; interrupted before this point leaves no signature claiming the tables are
	; good.
	lda #1
	sta .pic_header_write
	jsr .pic_header_tables
	jsr .pic_attic_header
	ldx #0
-	lda .pic_sig,x
	ldz #0
	sta [.pic_att],z
	inc .pic_att
	inx
	cpx #PIC_SIG_BYTES
	bne -
	rts

.pic_make_signature
	; .pic_sig = the story's serial (6 bytes) then its checksum (2). Ozmoo does
	; not write either, so they still identify the story file at restart.
	; read_header_word returns the word at y as a = high byte, x = low.
	ldy #header_serial
	jsr read_header_word
	sta .pic_sig
	stx .pic_sig + 1
	ldy #header_serial + 2
	jsr read_header_word
	sta .pic_sig + 2
	stx .pic_sig + 3
	ldy #header_serial + 4
	jsr read_header_word
	sta .pic_sig + 4
	stx .pic_sig + 5
	ldy #header_checksum
	jsr read_header_word
	sta .pic_sig + 6
	stx .pic_sig + 7
	rts

.pic_sig !fill PIC_SIG_BYTES, 0

.pic_attic_header
	; .pic_att -> the attic header at PIC_ATTIC_HEADER_PAGE.
	lda #0
	sta .pic_att
	lda #<PIC_ATTIC_HEADER_PAGE
	sta .pic_att + 1
	lda #>PIC_ATTIC_HEADER_PAGE
	sta .pic_att + 2
	lda #$08				; attic RAM starts at $08000000
	sta .pic_att + 3
	rts

.pic_header_tables
	; Copy pic_page_lo and pic_page_hi between RAM and the attic header, which
	; way round depending on .pic_header_write. The tables run to picture_count
	; bytes each (up to 999), so the index is 16 bit and .pic_addr does the
	; addressing, exactly as the rest of this file indexes the pic_* tables.
	jsr .pic_attic_header
	lda #PIC_SIG_BYTES		; the signature sits in front of the tables
	clc
	adc .pic_att
	sta .pic_att
	lda #<pic_page_lo
	ldx #>pic_page_lo
	jsr .pht_one
	lda #<pic_page_hi
	ldx #>pic_page_hi
.pht_one
	; a,x = the RAM table's base. Walks .pic_att on to the next table.
	sta .pht_base
	stx .pht_base + 1
	lda #0
	sta .pic_index
	sta .pic_index + 1
.pht_loop
	lda .pht_base
	ldx .pht_base + 1
	jsr .pic_addr			; .pi_ptr -> the table's entry for .pic_index
	lda .pic_header_write
	bne .pht_write
	ldz #0					; reading: attic -> RAM
	lda [.pic_att],z
	ldy #0
	sta (.pi_ptr),y
	bra .pht_next
.pht_write
	ldy #0					; writing: RAM -> attic
	lda (.pi_ptr),y
	ldz #0
	sta [.pic_att],z
.pht_next
	inc .pic_att			; attic is written a byte at a time; the tables are
	bne +					; small and this runs twice a boot at most
	inc .pic_att + 1
	bne +
	inc .pic_att + 2
+	inc .pic_index
	bne +
	inc .pic_index + 1
+	lda .pic_index
	cmp #<picture_count
	lda .pic_index + 1
	sbc #>picture_count
	bcc .pht_loop
	rts

.pht_base !byte 0, 0
.pic_header_write !byte 0	; 0 = attic -> RAM, 1 = RAM -> attic

.pic_open_current
	; Open pic_file_name as logical file 2 on .pic_dev for reading. The disk is
	; known to hold it (.pic_locate_disk just checked), so a failure is fatal.
	lda #PIC_FILE_NAME_LEN
	ldx #<pic_file_name
	ldy #>pic_file_name
	jsr kernal_setnam
	lda #2					; logical file 2
	ldx .pic_dev
	ldy #2					; secondary 2: a SEQ file, opened for reading
	jsr kernal_setlfs
	jsr kernal_open
	bcs +
	ldx #2
	jmp kernal_chkin
+	lda #ERROR_FLOPPY_READ_ERROR
	jmp fatalerror

.pic_locate_disk
	; Find the picture disk .cur_disk. Try the second drive, then the boot
	; drive; if neither holds it, ask the player to insert it and try both
	; again - the disk may have been put in either drive. pic_file_name already
	; names one of this disk's files, and is the probe.
.pld_try
	lda boot_device
	clc
	adc #1					; the second drive (e.g. 9 when booting from 8)
	sta .pic_dev
	jsr .pic_probe
	bcs .pld_found
	lda boot_device
	sta .pic_dev
	jsr .pic_probe
	bcs .pld_found
	jsr .pic_prompt_swap
	jmp .pld_try
.pld_found
	rts

.pic_probe
	; Is pic_file_name present on .pic_dev? A missing file OPENs "successfully"
	; but leaves error 62 on the drive, and reading it hands back a stale buffer
	; page rather than a clean EOF - so the status byte can't be trusted and the
	; drive error channel must be read. Carry set = the file is really there.
	lda #PIC_FILE_NAME_LEN
	ldx #<pic_file_name
	ldy #>pic_file_name
	jsr kernal_setnam
	lda #2
	ldx .pic_dev
	ldy #2
	jsr kernal_setlfs
	jsr kernal_open
	bcs .probe_absent		; device not present, or open failed outright
	jsr .pic_read_errchan	; .err_digit = first digit of the error code
	lda #2
	jsr kernal_close
	jsr kernal_clrchn
	lda .err_digit
	cmp #'0'				; "00, OK" -> present; "62,FILE NOT FOUND" -> absent
	bne +
	sec
	rts
+	clc
	rts
.probe_absent
	lda #2
	jsr kernal_close
	jsr kernal_clrchn
	clc
	rts

.pic_read_errchan
	; Open the command channel on .pic_dev, read the error code's first digit
	; into .err_digit, drain the rest of the line, close the channel.
	lda #0
	jsr kernal_setnam		; empty name
	lda #15
	ldx .pic_dev
	ldy #15
	jsr kernal_setlfs
	jsr kernal_open
	ldx #15
	jsr kernal_chkin
	jsr kernal_readchar
	sta .err_digit
-	jsr kernal_readst
	bne +					; end of the error line
	jsr kernal_readchar
	jmp -
+	lda #15
	jsr kernal_close
	jmp kernal_clrchn

.pic_prompt_swap
	; Ask the player to insert picture disk .cur_disk, then wait for a key.
	lda #>.swap_msg
	ldx #<.swap_msg
	jsr printstring_raw
	lda .cur_disk
	clc
	adc #'0'				; a handful of picture disks at most
	jsr s_printchar
	lda #>.swap_msg2
	ldx #<.swap_msg2
	jsr printstring_raw
-	jsr kernal_getchar
	beq -
	rts
.swap_msg  !pet 13,"insert picture disk ",0
.swap_msg2 !pet " and press a key ",0
.loading_msg !pet "loading graphics",0

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
	sta pic_file_name + 1
	lda .pic_num				; now < 100, low byte only: tens then units
	ldx #$2f					; '0' - 1
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
	ldy #0
	lda (.pi_ptr),y
	cmp .pic_num
	bne .pf_next
	lda #<pic_number_hi
	ldx #>pic_number_hi
	jsr .pic_addr
	ldy #0
	lda (.pi_ptr),y
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
	lda #0
	sta .pic_att			; the file starts on a page boundary
	lda #<pic_page_lo
	ldx #>pic_page_lo
	jsr .pic_addr
	ldy #0
	lda (.pi_ptr),y
	sta .pic_att + 1
	lda #<pic_page_hi
	ldx #>pic_page_hi
	jsr .pic_addr
	ldy #0
	lda (.pi_ptr),y
	sta .pic_att + 2
	lda #$08				; attic RAM starts at $08000000
	sta .pic_att + 3
	rts

.pic_size
	; Set .pic_w and .pic_h for the picture in .pic_index (the first two bytes
	; of its file in attic RAM), for picture_data.
	jsr .pic_open
	jsr .pic_att_next		; cells across
	sta .pic_w
	jsr .pic_att_next		; cells down
	sta .pic_h
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
	bcc .pa_place
	bne .pa_compact
	cpy #<PIC_MAX_TILES
	bcc .pa_place
.pa_compact
	; Out of store. Before wrapping over tiles that cells still on screen
	; point at (Arthur draws the Merlin scene centred over the full-screen
	; sword picture, whose frame stays visible), compact the survivors to
	; the bottom of the store and try again. x still indexes the window
	; tables, and the sweep needs every register.
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
	lda #0
	sta pic_next_tile
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

.pic_gc
	; The store must take a picture bigger than the space left, and wrapping
	; would overwrite tiles that cells still on screen point at. Keep those:
	; mark every tile a cell outside the incoming picture's rectangle shows,
	; copy the survivors to the bottom of the store in ascending index order
	; (safe in place: a survivor can only move down), and repoint their
	; cells. pic_next_tile comes back as the survivor count, so the caller's
	; run and the composites baked over it land above them. Cells the new
	; picture covers are left alone: it is about to overwrite them, and if
	; their tiles are shared with cells outside (Arthur's borders repeat)
	; the sharing marks them survivors anyway. Tiles keep their absolute
	; palette pixels, so moving one never changes its colours.

	; pass 1: which tiles are still needed?
	ldx #0
	txa
-	sta .gc_bitmap,x
	inx
	bne -
	lda .pic_y
	clc
	adc .pic_h
	sta .gc_y1
	lda .pic_x
	clc
	adc .pic_w
	sta .gc_x1
	lda #<SCREEN_ADDRESS
	sta .pic_ptr
	lda #>SCREEN_ADDRESS
	sta .pic_ptr + 1
	lda #0
	sta .gc_row
.gc_mark_row
	lda #0
	sta .gc_col
.gc_mark_cell
	lda .gc_row
	cmp .pic_y
	bcc .gc_mark_keep		; above the rectangle
	cmp .gc_y1
	bcs .gc_mark_keep		; below it
	lda .gc_col
	cmp .pic_x
	bcc .gc_mark_keep		; left of it
	cmp .gc_x1
	bcc .gc_mark_next		; inside: dies with the old picture
.gc_mark_keep
	lda .gc_col
	asl
	tay
	iny						; the cell's high byte
	lda (.pic_ptr),y
	sec
	sbc #FCM_TILE_CODE_HI
	cmp #>PIC_MAX_TILES
	bcs .gc_mark_next		; text, or no store code at all
	asl						; bitmap byte = index high * 32 + index low / 8
	asl
	asl
	asl
	asl
	sta .gc_t
	dey
	lda (.pic_ptr),y
	pha
	lsr
	lsr
	lsr
	clc
	adc .gc_t
	tay
	pla
	and #7
	tax
	lda .gc_bit,x
	ora .gc_bitmap,y
	sta .gc_bitmap,y
.gc_mark_next
	inc .gc_col
	lda .gc_col
	cmp #SCREEN_WIDTH
	bcc .gc_mark_cell
	lda .pic_ptr
	clc
	adc #SCREEN_ROW_BYTES
	sta .pic_ptr
	bcc +
	inc .pic_ptr + 1
+	inc .gc_row
	lda .gc_row
	cmp #SCREEN_HEIGHT
	bcc .gc_mark_row

	; pass 2: count the survivors below each bitmap byte, and move each one
	; down to its new home as it is passed
	lda #0
	sta .gc_next
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
	bne .gc_sweep_byte

	; pass 3: point the surviving cells at the tiles' new homes
	lda #<SCREEN_ADDRESS
	sta .pic_ptr
	lda #>SCREEN_ADDRESS
	sta .pic_ptr + 1
	lda #0
	sta .gc_row
.gc_fix_row
	lda #0
	sta .gc_col
.gc_fix_cell
	lda .gc_col
	asl
	tay
	iny
	lda (.pic_ptr),y
	sec
	sbc #FCM_TILE_CODE_HI
	cmp #>PIC_MAX_TILES
	bcs .gc_fix_next
	asl
	asl
	asl
	asl
	asl
	sta .gc_t
	dey
	lda (.pic_ptr),y
	sta .gc_t2
	lsr
	lsr
	lsr
	clc
	adc .gc_t
	tax						; x = the code's bitmap byte
	lda .gc_t2
	and #7
	tay						; y = its bit
	lda .gc_bitmap,x
	and .gc_bit,y
	beq .gc_fix_next		; covered by the new picture: leave it be
	lda .gc_bitmap,x
	and .gc_below,y
	tay
	lda .gc_pop,y			; survivors below it within its own byte...
	clc
	adc .gc_pref_lo,x		; ...plus those below its byte = its new index
	sta .gc_t
	lda .gc_pref_hi,x
	adc #0
	clc
	adc #FCM_TILE_CODE_HI	; and back into a screen code
	pha
	lda .gc_col
	asl
	tay
	lda .gc_t
	sta (.pic_ptr),y
	iny
	pla
	sta (.pic_ptr),y
.gc_fix_next
	inc .gc_col
	lda .gc_col
	cmp #SCREEN_WIDTH
	bcc .gc_fix_cell
	lda .pic_ptr
	clc
	adc #SCREEN_ROW_BYTES
	sta .pic_ptr
	bcc +
	inc .pic_ptr + 1
+	inc .gc_row
	lda .gc_row
	cmp #SCREEN_HEIGHT
	bcc .gc_fix_row

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
	; zp_colour_src/dst go back to being colour RAM pointers
	lda #$f8
	sta zp_colour_src + 2
	sta zp_colour_dst + 2
	lda #$0f
	sta zp_colour_src + 3
	sta zp_colour_dst + 3
	rts

.gc_copy_tile
	; move tile .gc_old down to tile .gc_next, 64 bytes. When nothing below
	; has been freed yet they are the same slot, and there is nothing to do.
	lda .gc_old
	cmp .gc_next
	bne +
	lda .gc_old + 1
	cmp .gc_next + 1
	bne +
	rts
+	txa
	pha
	lda .gc_old + 1
	clc
	adc #FCM_TILE_CODE_HI
	tax
	lda .gc_old
	jsr .pcf_code_addr		; .pic_dst = the tile's old home
	ldx #3
-	lda .pic_dst,x
	sta zp_colour_src,x
	dex
	bpl -
	lda .gc_next + 1
	clc
	adc #FCM_TILE_CODE_HI
	tax
	lda .gc_next
	jsr .pcf_code_addr		; .pic_dst = its new one
	ldx #3
-	lda .pic_dst,x
	sta zp_colour_dst,x
	dex
	bpl -
	ldz #0
-	lda [zp_colour_src],z
	sta [zp_colour_dst],z
	inz
	cpz #64
	bne -
	pla
	tax
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
	; source bytes = ntiles * 32 on the 40-column screen, ntiles * 16 on the
	; 80-column one, where a tile on disk is 4 source pixels a row and each
	; pixel is written twice as it is baked, doubling it. Neither product can
	; overflow: the store itself holds at most 2048 tiles.
	lda .pic_ntiles
	sta .pic_count
	lda .pic_ntiles + 1
	sta .pic_count + 1
!ifdef Z6_FCM_40 {
	ldx #5
} else {
	ldx #4
}
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
	jsr .pic_emit_pixel
	pla
	and #$0f
	jsr .pic_emit_pixel
	lda .pic_count
	bne +
	dec .pic_count + 1
+	dec .pic_count
	lda .pic_count
	ora .pic_count + 1
	bne .pct_loop
	rts

.pic_emit_pixel
	; a = a colour index of 0..15, written once on the 40-column screen and
	; twice -- a doubled pixel -- on the 80-column one
!ifdef Z6_FCM_40 {
	jmp .pic_put_pixel
} else {
	pha
	jsr .pic_put_pixel
	pla
	jmp .pic_put_pixel
}

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

.pic_start_row
	; Start a row of .pic_fill_cells or .pic_erase: count down the picture's
	; cells with .pic_cols_left, and set the doubled column .pic_col2. The
	; column needs nine bits: on the 80-column screen 2*(x + w) can pass 256,
	; and an eight-bit column that wrapped would look on-screen again and
	; scribble over the wrong cells. .pic_col2_hi holds the ninth bit.
	lda .pic_w
	sta .pic_cols_left
	lda .pic_x
	asl
	sta .pic_col2
	lda #0
	rol
	sta .pic_col2_hi
	rts

.pic_step_cell
	; step .pic_col2 one cell to the right; z set when the row is done
	lda .pic_col2
	clc
	adc #2
	sta .pic_col2
	bcc +
	inc .pic_col2_hi
+	dec .pic_cols_left
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
	bcc +
	jmp .pfc_done
+	jsr .pic_start_row
.pfc_cell
	jsr .pic_att_next		; index, low byte
	sta .pfc_lo
	jsr .pic_att_next		; index, high byte
	sta .pfc_hi
	cmp #$ff				; $ffff marks a fully transparent cell: leave what
	beq .pfc_advance		; is under it, so a picture behind shows through
	lda .pic_col2_hi		; column past the right edge? drop the write, but
	bne .pfc_advance		; keep consuming the map so the next row stays aligned
	ldy .pic_col2
	cpy #SCREEN_ROW_BYTES
	bcs .pfc_advance
	lda (.pic_ptr),y		; what is already in this cell (the picture behind)?
	sta .pcf_under_lo
	iny
	lda (.pic_ptr),y
	sta .pcf_under_hi
	bne .pfc_composite		; a non-zero high byte means a full colour tile is
							; here: composite over it so our transparent pixels
							; show it through, not the screen background
	; nothing (or text) behind: draw our tile as is, its 0 pixels transparent
	ldy .pic_col2
	lda .pfc_lo
	clc
	adc .pic_slot
	sta (.pic_ptr),y		; screen code low byte = index low + slot low
	iny
	lda .pfc_hi
	adc .pic_slot + 1
	adc #FCM_TILE_CODE_HI	; screen code high; carry clear, never reaches $4000
	sta (.pic_ptr),y
	jmp .pfc_advance
.pfc_composite
	jsr .pcf_make_tile		; bake a fresh tile of us over what was behind
	ldy .pic_col2
	lda .pcf_newcode_lo
	sta (.pic_ptr),y
	iny
	lda .pcf_newcode_hi
	sta (.pic_ptr),y
.pfc_advance
	jsr .pic_step_cell
	beq +
	jmp .pfc_cell			; body is too long now for a direct branch back
+	lda .pic_ptr
	clc
	adc #SCREEN_ROW_BYTES
	sta .pic_ptr
	bcc +
	inc .pic_ptr + 1
+	inc .pic_row
	lda .pic_h
	cmp .pic_row
	beq .pfc_done
	jmp .pfc_row
.pfc_done
	rts

.pcf_code_addr
	; a,x = a cell's screen code (low, high). Set .pic_dst to the tile it points
	; at in the store: the tile's address is its screen code times 64.
	sta .pic_dst
	stx .pic_dst + 1
	lda #0
	sta .pic_dst + 2
	sta .pic_dst + 3
	ldx #6
-	asl .pic_dst
	rol .pic_dst + 1
	rol .pic_dst + 2
	dex
	bne -
	rts

.pcf_make_tile
	; Composite our cell's tile (index .pfc_lo/.pfc_hi in our run) over the tile
	; already in the cell (.pcf_under_lo/hi): our opaque pixels win, our
	; transparent (0) pixels keep what was behind. A fresh tile is allocated for
	; the result and its screen code returned in .pcf_newcode_lo/hi. This is what
	; lets a small picture drawn over a scene show the scene through its
	; transparent pixels, not the screen background.
	lda .pfc_lo				; our source tile: (slot + index) is its screen code
	clc
	adc .pic_slot
	pha
	lda .pfc_hi
	adc .pic_slot + 1
	adc #FCM_TILE_CODE_HI
	tax
	pla
	sta .pcf_newcode_lo		; if the cell turns out fully opaque, this code is
	stx .pcf_newcode_hi		; the answer and no composite is baked
	jsr .pcf_code_addr		; .pic_dst -> our tile in the store
	ldy #0					; copy its 64 pixels into the work buffer
	ldz #0
	ldx #0					; x counts transparent pixels
-	lda [.pic_dst],z
	sta .pcf_buf,y
	bne +
	inx
+	inz
	iny
	cpy #64
	bne -
	; A fully opaque cell hides what is behind it completely, so the composite
	; would be a copy of our own tile: use it directly and allocate nothing.
	; Without this, a full-screen picture drawn over another (Arthur's intro)
	; bakes a composite for every cell, wraps pic_next_tile into its own run
	; and overwrites source tiles that later, deduplicated cells still need.
	cpx #0
	bne +
	rts
+	lda .pcf_under_lo		; the tile that was behind us
	ldx .pcf_under_hi
	jsr .pcf_code_addr		; .pic_dst -> it in the store
	ldy #0					; where we are transparent, take its pixel instead
	ldz #0
-	lda .pcf_buf,y
	bne +
	lda [.pic_dst],z
	sta .pcf_buf,y
+	inz
	iny
	cpy #64
	bne -
	lda pic_next_tile		; allocate a fresh tile for the composite
	sta .pcf_newcode_lo
	lda pic_next_tile + 1
	clc
	adc #FCM_TILE_CODE_HI	; its screen code
	sta .pcf_newcode_hi
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
++	lda #0
	sta pic_next_tile
	sta pic_next_tile + 1
+	lda .pcf_newcode_lo		; write the buffer out to the fresh tile
	ldx .pcf_newcode_hi
	jsr .pcf_code_addr
	ldy #0
	ldz #0
-	lda .pcf_buf,y
	sta [.pic_dst],z
	inz
	iny
	cpy #64
	bne -
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
	lda #<pic_adaptive
	ldx #>pic_adaptive
	jsr .pic_addr
	ldy #0
	lda (.pi_ptr),y
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
	jsr .pic_start_row
.pic_erase_cell
	lda .pic_col2_hi
	bne .pic_erase_next
	ldy .pic_col2
	cpy #SCREEN_ROW_BYTES
	bcs .pic_erase_next
	lda #$20				; a space, which is a text character, not a tile
	sta (.pic_ptr),y
	iny
	lda #0					; and so its high byte must go back to zero
	sta (.pic_ptr),y
.pic_erase_next
	jsr .pic_step_cell
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
