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
PIC_ATTIC_HEADER_PAGE = $3000	; $08300000: just the 8-byte signature now
PIC_ATTIC_PAGE = PIC_ATTIC_HEADER_PAGE + 1	; pictures decrunch one page up
; The picture disks each hold one exomizer archive of that disk's pictures,
; page-padded and concatenated; pic_load_all decrunches them into attic here,
; disk after disk. pic_page_lo/hi are computed at boot from the assembled-in
; pic_pages (each picture's attic size), so no page table is kept in attic and
; the header is just the signature. The crunched archive being decrunched is
; staged high in attic, clear of the picture area ($08300000 up, at most ~2 MB
; for the largest shipped set) and the undo buffer ($08600000).
PIC_STAGE_BYTE2 = $51			; one disk's crunched archive staged at $08510000
; The disk read (the slow part on a real 1581) drives a "loading graphics"
; progress bar: one slash per PIC_PROGRESS_STEP pages staged, scaled so the bar
; is about 30 slashes wide whatever the picture set's size.
PIC_PROGRESS_STEP = picture_crunched_pages / 30 + 1
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

; Off-grid placement (.pic_gen_fill). A screen cell holds GEN_CELL_W art pixels
; across - half an art cell on the 80-column screen, where the art is doubled,
; and a whole one on the 40-column screen, where it is not - and its tile takes
; GEN_TILE_BYTES in attic, two art pixels a byte.
!ifdef Z6_FCM_40 {
GEN_CELL_W = 8
GEN_TILE_SHIFT = 5			; * 32 bytes
} else {
GEN_CELL_W = 4
GEN_TILE_SHIFT = 4			; * 16 bytes
}
.pic_shift   !byte 0		; art pixels the picture starts INTO its first cell,
.pic_shift_y !byte 0		; across and down (both zero: it is on the grid)
.gen_mw      !byte 0		; cells it covers, across and down
.gen_mh      !byte 0
.gen_next    !byte 0,0		; the next unused tile of the reserved run
.gen_base    !byte 0,0,0	; what .pic_seek offsets from
.gen_tiles   !byte 0,0,0	; where the tile block starts in attic RAM
.gen_buf     !fill 64, 0	; one source cell, unpacked to a byte an art pixel
.gen_art     !fill 64, 0	; the cell being assembled, in the same form
.gen_cx      !byte 0		; the source cell being fetched; $ff, or past
.gen_cy      !byte 0		; .pic_w / .pic_h, means "off the picture"
.gen_sr      !byte 0		; .gen_blit's rectangle
.gen_sc      !byte 0
.gen_dr      !byte 0
.gen_dc      !byte 0
.gen_nr      !byte 0
.gen_nc      !byte 0
.gen_rows    !byte 0
.gen_cols    !byte 0
.gen_si      !byte 0		; .gen_blit's running source and destination
.gen_di      !byte 0		; indices (the X16 engine borrows zero page here)
.pfo_m       !byte 0		; the fill's cell counter across a row

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
.gc_y0       !byte 0		; the incoming rectangle in screen cells: only the
.gc_y1       !byte 0		; cells it covers COMPLETELY die with it, so a
.gc_x0       !byte 0		; shifted picture's shared edge row and column are
.gc_x1       !byte 0		; outside it
.gc_next     !byte 0,0		; the compacted store's next free tile
.gc_old      !byte 0,0		; the survivor being moved
.gc_byi      !byte 0		; bitmap byte index being walked
.gc_t        !byte 0
.gc_t2       !byte 0


pic_next_tile  !byte 0,0
pic_win_base   !fill 16, 0	; two bytes a window
pic_win_count  !fill 16, 0
pic_win_shift  !fill 8, 0	; the placement each window's run was built for
							; (.pa_pack_shift), one byte a window
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
; Which picture's palette each bank currently holds ($ffff = none), entry
; (bank - 1). A picture drawn again gets the bank it is already in, wherever
; and however it is placed and whatever window it goes to: a picture's palette
; is a property of the picture, so this is always right, and it is what keeps
; the fourteen banks from running out. Arthur's F2 map is the case that needs
; it - it redraws the same handful of pictures (paper, room boxes, connectors)
; dozens of times, and one bank per DRAW wrapped the allocator round onto banks
; the paper's own cells were still baked against, which turned the map's brown
; background black on the second turn. Here it also keeps a picture's baked
; tiles consistent, since they carry absolute palette indices.
pic_bank_pic   !fill PIC_PAL_BANKS * 2, $ff
; The palette an adaptive picture (Blorb APal) draws in: the pixel base and
; matching pal offset of the last direct picture drawn. Seeded with bank 1 in
; case an adaptive picture is somehow drawn before any direct one.
pic_direct_base !byte 16
pic_direct_off  !byte 0

; ---------------------------------------------------------------------------
pic_file_name !text "PICS0"	; one archive per disk; make.rb upper-cases the name
PIC_FILE_NAME_LEN = 5

; .pic_num (a 2-byte scratch defined with the number-printing helper below) is
; reused here to search pic_number.
.pic_dev       !byte 0		; device holding the picture disk being read
.cur_disk      !byte 0		; which picture disk .pic_dev holds (0 = none yet)
.err_digit     !byte 0		; first digit read back from a drive's error channel
.pic_next_page !byte 0,0
.pic_prog      !byte 0		; pages left until the next progress-bar slash

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
	; Load every picture into attic RAM. Called at boot, next to the sound
	; effects, and for the same reason: the pictures are far too big to assemble
	; into the interpreter. Each picture disk holds one exomizer archive of that
	; disk's pictures, page-padded and concatenated; each is decrunched into
	; attic here, disk after disk, so attic holds the pictures ready to draw.
	;
	; With two drives the second disk can sit in the second drive, so each disk
	; is looked for there and in the boot drive before the player is ever asked
	; to swap.
	;
	; A restart reboots the machine and reloads the interpreter, so this runs
	; again - but attic still holds the pictures. The page table is rebuilt from
	; the assembled-in pic_pages every time (below), so the only thing that has
	; to survive is the answer to "are the pictures still there?": if the
	; header's signature is this story's, skip the disks. The header is readable
	; by now: deletable_init loads the story before z_init runs.
	jsr .pic_compute_pages
	jsr .pic_make_signature
	jsr .pic_attic_header
	ldx #0
-	jsr .pic_att_next
	cmp .pic_sig,x
	bne .pla_load			; another story, or cold-boot garbage: load
	inx
	cpx #PIC_SIG_BYTES
	bne -
	rts						; ours: the pictures are already in attic

.pla_load
	lda #<PIC_ATTIC_PAGE	; the disks decrunch here, one after another
	sta .pic_next_page
	lda #>PIC_ATTIC_PAGE
	sta .pic_next_page + 1
	lda #13					; a label, then the loading bar on the next line
	jsr s_printchar
	lda #>.loading_msg
	ldx #<.loading_msg
	jsr printstring_raw
	lda #13
	jsr s_printchar
	lda #1					; the first page staged prints the first slash
	sta .pic_prog

	lda #1					; picture disks are numbered from 1
	sta .cur_disk
.pla_disk
	lda .cur_disk			; open PICS<n> on whichever drive holds this disk
	jsr .pic_set_archive_name
	jsr .pic_locate_disk	; sets .pic_dev
	jsr .pic_open_current

	jsr .exo_stage_archive	; stream the crunched archive into attic staging

	lda #2
	jsr kernal_close
	jsr kernal_clrchn

	; Decrunching a whole disk's archive takes a few seconds with nothing to
	; show for it, so say what is happening. No progress bar: the decruncher
	; walks a crunched stream, so it has no cheap measure of how far along it
	; is, unlike the staging read that counts pages.
	lda #13
	jsr s_printchar
	lda #>.unpacking_msg
	ldx #<.unpacking_msg
	jsr printstring_raw

	lda #0					; decrunch it onto the running attic write pointer
	sta .pic_att
	lda .pic_next_page
	sta .pic_att + 1
	lda .pic_next_page + 1
	sta .pic_att + 2
	lda #$08
	sta .pic_att + 3
	jsr .pic_deexo
	lda #13					; so a further disk's progress bar starts on its own line
	jsr s_printchar

	; .pic_att now points just past this disk's pictures - page aligned, since
	; every picture is page padded - which is where the next disk continues.
	lda .pic_att + 1
	sta .pic_next_page
	lda .pic_att + 2
	sta .pic_next_page + 1

	inc .cur_disk
	lda .cur_disk
	cmp #picture_disk_count + 1
	bcc .pla_disk

	; Every picture is in attic now. Stamp the signature last, so a load
	; interrupted before this point leaves none claiming they are good.
	jsr .pic_attic_header
	ldx #0
-	lda .pic_sig,x
	ldz #0
	sta [.pic_att],z
	inc .pic_att
	inx
	cpx #PIC_SIG_BYTES
	bne -
	; The label, the bar and the unpacking notes have done their job; the game
	; should open on a clean screen. Only this path prints anything - the
	; pictures-already-in-attic path above returns without a word - so the
	; erase belongs here rather than at the top of pic_load_all.
	jsr s_erase_window
	rts

.pic_compute_pages
	; pic_page_lo/hi[i] = PIC_ATTIC_PAGE + sum(pic_pages[0..i-1]). Every picture
	; is page padded in its archive, so this is exactly where the decruncher puts
	; each one. Raw sizes are known at build time, so this needs no disk access
	; and runs on every boot, restart or not.
	lda #<PIC_ATTIC_PAGE
	sta .pcp_page
	lda #>PIC_ATTIC_PAGE
	sta .pcp_page + 1
	lda #0
	sta .pic_index
	sta .pic_index + 1
.pcp_loop
	lda #<pic_page_lo		; pic_page_lo[i] = running page low
	ldx #>pic_page_lo
	jsr .pic_addr
	ldy #0
	lda .pcp_page
	sta (.pi_ptr),y
	lda #<pic_page_hi		; pic_page_hi[i] = running page high
	ldx #>pic_page_hi
	jsr .pic_addr
	ldy #0
	lda .pcp_page + 1
	sta (.pi_ptr),y
	lda #<pic_pages			; running page += pic_pages[i]
	ldx #>pic_pages
	jsr .pic_addr
	ldy #0
	clc
	lda (.pi_ptr),y
	adc .pcp_page
	sta .pcp_page
	bcc +
	inc .pcp_page + 1
+	inc .pic_index
	bne +
	inc .pic_index + 1
+	lda .pic_index
	cmp #<picture_count
	lda .pic_index + 1
	sbc #>picture_count
	bcc .pcp_loop
	rts
.pcp_page !byte 0, 0

.pic_set_archive_name
	; a = disk number (1..9). pic_file_name becomes "PICS<n>".
	ora #$30
	sta pic_file_name + 4
	rts

.exo_stage_archive
	; Read the open file into the attic staging buffer. The decruncher reads it
	; forwards and self-terminates at the stream's end marker, so no length is
	; needed; leave .exo_cr pointing at the first byte.
	lda #0
	sta .pic_att			; reuse .pic_att as the staging write pointer
	sta .pic_att + 1
	lda #PIC_STAGE_BYTE2
	sta .pic_att + 2
	lda #$08
	sta .pic_att + 3
.esa_loop
	jsr kernal_readst
	bne .esa_done
	jsr kernal_readchar
	ldz #0
	sta [.pic_att],z
	inc .pic_att
	bne .esa_loop			; no page boundary crossed
	inc .pic_att + 1
	bne +
	inc .pic_att + 2
+	jsr .pic_progress_tick	; a page was staged: advance the loading bar
	bra .esa_loop
.esa_done
	lda #0					; .exo_cr = staging base (first crunched byte)
	sta .exo_cr
	sta .exo_cr + 1
	lda #PIC_STAGE_BYTE2
	sta .exo_cr + 2
	lda #$08
	sta .exo_cr + 3
	rts

.pic_progress_tick
	; One page has been staged; every PIC_PROGRESS_STEP pages, print a slash.
	; s_printchar writes screen RAM directly (it does no disk I/O, so the open
	; file is undisturbed), but it may use z_temp, so save the staging pointer.
	dec .pic_prog
	beq +
	rts
+	ldx #3
-	lda .pic_att,x
	sta .pic_prog_save,x
	dex
	bpl -
	lda #47					; "/"
	jsr s_printchar
	ldx #3
-	lda .pic_prog_save,x
	sta .pic_att,x
	dex
	bpl -
	lda #PIC_PROGRESS_STEP
	sta .pic_prog
	rts
.pic_prog_save !byte 0,0,0,0

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
	; Find the picture disk .cur_disk. Try the boot drive, then the second
	; drive; if neither holds it, ask the player to insert it and try both
	; again - the disk may have been put in either drive. pic_file_name already
	; names one of this disk's files, and is the probe.
	;
	; The boot drive comes first because the pictures now usually live on the
	; boot disk itself (make.rb puts the archive there whenever it fits), and a
	; drive that isn't there answers a probe with a KERNAL timeout, not a quick
	; "file not found". It is also the safer order: a picture disk from another
	; Ozmoo game left in the second drive holds a PICS<n> of its own.
.pld_try
	lda boot_device
	sta .pic_dev
	jsr .pic_probe
	bcs .pld_found
	lda boot_device
	clc
	adc #1					; the second drive (e.g. 9 when booting from 8)
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
.unpacking_msg !pet "unpacking pictures",0

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

; ---------------------------------------------------------------------------
; The exomizer decruncher: a faithful port of exomizer's reference decoder
; (exodec.c) for the -P0 (exomizer-2) stream format. It reads the crunched
; archive FORWARDS from attic staging and writes the plaintext forwards to the
; picture area (.pic_att); back-references are read straight from that output,
; so no ring buffer is needed. pics2asm.py crunches with the matching flags
; (raw -C -P0 -c -m 4096).
;
;   .exo_cr  ($16) reads the crunched archive forwards from attic staging
;   .exo_src ($1e) reads a back-reference from the plaintext already written
;   .pic_att is the running output pointer (.pic_store advances it)
;
; The zero-page pointers borrow the z-machine operand-value arrays, free during
; boot (pic_load_all runs before the interpreter's main loop). Each is a 32-bit
; attic pointer for the 45GS02's [zp],z addressing.
.exo_cr  = z_operand_value_high_arr			; $16, crunched read (forwards)
.exo_src = z_operand_value_low_arr			; $1e, back-reference read

.exo_bitbuf   !byte 0
.exo_bits_lo  !byte 0		; get_bits result, low
.exo_bits_hi  !byte 0		; get_bits result, high (lengths/offsets are 16 bit)
.exo_count    !byte 0		; get_bits countdown
.exo_len_lo   !byte 0
.exo_len_hi   !byte 0
.exo_a_lo     !byte 0		; table_init accumulator a
.exo_a_hi     !byte 0
.exo_b        !byte 0		; table_init: last 4-bit field
.exo_t_lo     !byte 0		; scratch: 1 << b
.exo_t_hi     !byte 0
.exo_c_lo     !byte 0		; cooked-code result
.exo_c_hi     !byte 0
.exo_idx      !byte 0		; offset-table index i, kept across get_bits
.exo_table    !fill 156, 0			; tabl_lo(52), tabl_hi(52), tabl_bi(52)
.exo_tabl_lo  = .exo_table
.exo_tabl_hi  = .exo_table + 52
.exo_tabl_bi  = .exo_table + 104
.exo_tabl_bit !byte 2, 4, 4			; static bit counts / offsets for lengths 1-3
.exo_tabl_off !byte 48, 32, 16

.pic_deexo
	; Decrunch the staged archive (.exo_cr) onto .pic_att until the end marker.
	jsr .exo_init
.dx_loop
	ldx #1					; one flag bit: 1 = literal, 0 = sequence
	jsr .exo_get_bits
	beq .dx_seq
	jsr .exo_get_crunched	; literal byte, straight to the output
	jsr .pic_store
	bra .dx_loop
.dx_seq
	ldy #0					; gamma: count leading zero bits into y
.dx_gamma
	ldx #1
	jsr .exo_get_bits
	bne +
	iny
	bra .dx_gamma
+	cpy #16					; gamma 16 is the end-of-stream marker
	bne +
	jmp .dx_done
+	tya						; length = cooked(gamma)
	tax
	jsr .exo_cooked
	lda .exo_c_lo
	sta .exo_len_lo
	lda .exo_c_hi
	sta .exo_len_hi
	; i = min(length, 3) - 1: which of the three offset tables to use.
	lda .exo_len_hi
	bne .dx_i2
	lda .exo_len_lo
	cmp #3
	bcs .dx_i2
	sec						; length is 1 or 2: i = length - 1
	sbc #1
	tax
	bra .dx_havei
.dx_i2
	ldx #2
.dx_havei
	stx .exo_idx			; keep i across the get_bits below
	lda .exo_tabl_bit,x
	tax
	jsr .exo_get_bits		; v2 = tabl_off[i] + get_bits(tabl_bit[i])
	ldx .exo_idx
	clc
	adc .exo_tabl_off,x
	tax
	jsr .exo_cooked			; offset = cooked(v2)
	; src = out - offset (a 32-bit attic subtract; .pic_att+3 stays $08)
	sec
	lda .pic_att
	sbc .exo_c_lo
	sta .exo_src
	lda .pic_att + 1
	sbc .exo_c_hi
	sta .exo_src + 1
	lda .pic_att + 2
	sbc #0
	sta .exo_src + 2
	lda .pic_att + 3
	sbc #0
	sta .exo_src + 3
.dx_copy
	ldz #0					; copy length bytes forward from src to the output
	lda [.exo_src],z
	jsr .pic_store
	inc .exo_src
	bne +
	inc .exo_src + 1
	bne +
	inc .exo_src + 2
+	lda .exo_len_lo			; length -= 1
	bne +
	dec .exo_len_hi
+	dec .exo_len_lo
	lda .exo_len_lo
	ora .exo_len_hi
	bne .dx_copy
	jmp .dx_loop			; too far for a relative branch back
.dx_done
	rts

.exo_init
	; Seed the bit buffer and build the 52-entry decode table (exodec.c
	; table_init): a = 1 at each 16-entry boundary, else a += 1 << b, where b is
	; the previous entry's 4-bit field.
	jsr .exo_get_crunched
	sta .exo_bitbuf
	lda #0
	sta .exo_a_lo
	sta .exo_a_hi
	sta .exo_b
	ldy #0
.ei_loop
	tya
	and #$0f
	bne .ei_add
	lda #1					; boundary: a = 1
	sta .exo_a_lo
	lda #0
	sta .exo_a_hi
	bra .ei_store
.ei_add
	lda .exo_b				; a += 1 << b
	jsr .exo_shift_add
.ei_store
	lda .exo_a_lo
	sta .exo_tabl_lo,y
	lda .exo_a_hi
	sta .exo_tabl_hi,y
	ldx #4					; b = get_bits(4)
	jsr .exo_get_bits
	sta .exo_b
	sta .exo_tabl_bi,y
	iny
	cpy #52
	bne .ei_loop
	rts

.exo_shift_add
	; .exo_a += 1 << a, where a (0..15) is the shift count.
	tax
	lda #1
	sta .exo_t_lo
	lda #0
	sta .exo_t_hi
	cpx #0
	beq +
-	asl .exo_t_lo
	rol .exo_t_hi
	dex
	bne -
+	clc
	lda .exo_a_lo
	adc .exo_t_lo
	sta .exo_a_lo
	lda .exo_a_hi
	adc .exo_t_hi
	sta .exo_a_hi
	rts

.exo_cooked
	; Cooked code: base = tabl_lo/hi[x], result = base + get_bits(tabl_bi[x]).
	; x = index in, 16-bit result in .exo_c_lo/.exo_c_hi.
	lda .exo_tabl_lo,x
	sta .exo_c_lo
	lda .exo_tabl_hi,x
	sta .exo_c_hi
	lda .exo_tabl_bi,x
	tax
	jsr .exo_get_bits
	clc
	adc .exo_c_lo
	sta .exo_c_lo
	lda .exo_bits_hi
	adc .exo_c_hi
	sta .exo_c_hi
	rts

.exo_get_crunched
	; a = next crunched byte, read forwards from staging. Advances .exo_cr.
	ldz #0
	lda [.exo_cr],z
	inc .exo_cr
	bne +
	inc .exo_cr + 1
	bne +
	inc .exo_cr + 2
+	rts

.exo_get_bits
	; get x bits (0..16) MSB-first into a / .exo_bits_lo / .exo_bits_hi. Many
	; table entries ask for 0 bits, which must return 0 without touching the
	; stream - the loop below is a do-while, so guard the zero case up front.
	stx .exo_count
	lda #0
	sta .exo_bits_lo
	sta .exo_bits_hi
	cpx #0
	beq .egb_ret
.egb_loop
	lsr .exo_bitbuf			; rot(0): carry = bit0, bitbuf >>= 1 (0 into top)
	lda .exo_bitbuf
	bne .egb_shift			; buffer not empty: carry is the data bit
	jsr .exo_get_crunched	; empty: refill and rot(1)
	lsr						; carry = new byte bit0, a = byte >> 1
	ora #$80				; rot(1) sets the top bit; ora keeps carry
	sta .exo_bitbuf
.egb_shift
	rol .exo_bits_lo		; val = (val << 1) | carry
	rol .exo_bits_hi
	dec .exo_count
	bne .egb_loop
.egb_ret
	lda .exo_bits_lo
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
	jsr .pa_pack_shift		; ...and placed the same way? A generated run holds
	cmp pic_win_shift,y		; tiles that are only right at THAT position, so a
	bne .pa_fresh			; redraw elsewhere must build its own - reusing it
							; would rewrite the tiles the first placement's
							; cells still point at. (Before the cells were
							; generated this could not happen: a run held the
							; picture's own tiles wherever it was put.)
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
	jsr .pa_pack_shift		; and where it was placed - see the reuse test
	sta pic_win_shift,y
	; give it the bank its palette is already in, or the next one round
	jsr .pa_pick_bank
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
	; picture covers completely are left alone: it is about to overwrite them,
	; and if their tiles are shared with cells outside (Arthur's borders
	; repeat) the sharing marks them survivors anyway. A cell the picture only
	; half covers - a shifted placement's edge row and column - counts as
	; outside: the draw still has to composite against what is there. Tiles
	; keep their absolute palette pixels, so moving one never changes its
	; colours.

	; pass 1: which tiles are still needed?
	ldx #0
	txa
-	sta .gc_bitmap,x
	inx
	bne -
	; The incoming rectangle, interior only. A picture shifted along an axis
	; spans one cell more there (.pic_x .. .pic_x + .pic_w), and both edge
	; cells hold part of it beside part of whatever it was drawn over - a
	; frame border, for a scene composited into a frame's hole - so they count
	; as OUTSIDE and their tiles must survive. Either way the exclusive end is
	; origin + size.
	lda .pic_y
	sta .gc_y0
	clc
	adc .pic_h
	sta .gc_y1
	lda .pic_x
	sta .gc_x0
	clc
	adc .pic_w
	sta .gc_x1
	lda .pic_shift
	beq +
	inc .gc_x0
+	lda .pic_shift_y
	beq +
	inc .gc_y0
+	lda #<SCREEN_ADDRESS
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
	cmp .gc_y0
	bcc .gc_mark_keep		; above the rectangle
	cmp .gc_y1
	bcs .gc_mark_keep		; below it
	lda .gc_col
	cmp .gc_x0
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
	; bakes a composite for every cell and burns through the store for nothing.
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
	; This composite belongs to no window's run - .pic_alloc reserved only the
	; picture's own tiles - so the store can genuinely run out here, mid-draw,
	; with half the picture's cells already written and no chance to compact.
	; SATURATE rather than wrap. Everything below pic_next_tile is live: the
	; picture's own run and the frame, which is drawn once at boot and never
	; redrawn, so it sits at the very bottom - exactly where a wrap lands. Worse,
	; a wrap leaves pic_next_tile low, which convinces .pic_alloc the store is
	; nearly empty, so .pic_gc never runs again and the allocator marches back up
	; through the frame. That was the Arthur *X16* bug (see .pcf_alloc_and_write
	; there); this engine had the same wrap and got away with it only for having
	; 2048 tiles and half the X16's per-picture cost. Saturating is
	; self-correcting: a full pic_next_tile fails .pic_alloc's fit check above,
	; so the next picture compacts the store and the bakes have room again.
	lda pic_next_tile + 1
	cmp #>PIC_MAX_TILES
	bcc .pmt_have
	bne .pmt_full
	lda pic_next_tile
	cmp #<PIC_MAX_TILES
	bcc .pmt_have
.pmt_full
	rts						; nothing baked. .pcf_newcode still holds OUR own
							; tile from the seed at the top of this routine, so
							; the cell shows us un-composited - it loses only the
							; show-through of what was behind, a cosmetic cost
							; confined to a nearly-full store. Do not seed
							; .pcf_newcode any later than that top.
.pmt_have
	lda pic_next_tile		; allocate a fresh tile for the composite
	sta .pcf_newcode_lo
	lda pic_next_tile + 1
	clc
	adc #FCM_TILE_CODE_HI	; its screen code
	sta .pcf_newcode_hi
	inc pic_next_tile		; at most PIC_MAX_TILES now; never wraps
	bne +
	inc pic_next_tile + 1
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

; ---------------------------------------------------------------------------
; Off-grid placement, the MEGA65 half of phase 0b (see pictures-x16.asm for the
; other and todo.txt for why). A screen cell is 8 pixel rows down and, across,
; GEN_CELL_W art pixels - 4 on the 80-column screen, where the art is doubled
; and a cell is half an art cell, and 8 on the 40-column one, where a cell is a
; whole art cell. A picture whose corner does not land on that grid shows parts
; of up to four source art cells in every cell it covers, so those cells are
; GENERATED here, straight out of the picture in attic RAM, and .pic_copy_tiles
; is skipped: the unshifted run is never copied at all.
;
; Note the 80-column screen never needed this before the pixel-units work: a
; text column IS a map cell there, so any cell position was already on the grid.
; What forces it now is that a game may ask for a position between them -
; Arthur's map lattice is 18 art pixels, which lands 2 rows or 2 pixels into a
; cell more often than not.

.pic_seek
	; Point the attic cursor .pic_att at .gen_base + the 16-bit offset in
	; .pic_count. Attic is flat, so this is a plain 24-bit add; a picture is
	; capped at 255 pages, so the offset always fits 16 bits.
	lda .gen_base
	clc
	adc .pic_count
	sta .pic_att
	lda .gen_base + 1
	adc .pic_count + 1
	sta .pic_att + 1
	lda .gen_base + 2
	adc #0
	sta .pic_att + 2
	lda #$08				; attic RAM starts at $08000000
	sta .pic_att + 3
	rts

.gen_load_cell
	; Unpack source cell (.gen_cx, .gen_cy) into .gen_buf, a byte an art pixel
	; and still a raw palette index - the window's bank is added later, when the
	; assembled cell is expanded into store form. A cell off the edge of the
	; picture, or one the file marks fully transparent ($ffff), reads as zeroes,
	; which is what transparent means everywhere downstream.
	lda .gen_cx
	cmp #$ff
	beq .glc_far
	cmp .pic_w
	bcs .glc_far
	lda .gen_cy
	cmp #$ff
	beq .glc_far
	cmp .pic_h
	bcc .glc_inside
.glc_far
	jmp .glc_blank
.glc_inside
	lda #0					; cell map offset = (cy * w + cx) * 2
	sta .pic_count
	sta .pic_count + 1
	ldx .gen_cy
	beq .glc_addx
-	lda .pic_count
	clc
	adc .pic_w
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
	sta .pic_count
	jsr .pic_att_next
	sta .pic_count + 1
	cmp #$ff
	bne .glc_have
	lda .pic_count
	cmp #$ff
	beq .glc_blank
.glc_have
	ldx #GEN_TILE_SHIFT		; tile offset = index * GEN_TILE_BYTES
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
	ldy #0					; two art pixels a byte, high nybble first
-	jsr .pic_att_next
	pha
	lsr
	lsr
	lsr
	lsr
	sta .gen_buf,y
	iny
	pla
	and #$0f
	sta .gen_buf,y
	iny
	cpy #(GEN_CELL_W * 8)
	bne -
	rts
.glc_blank
	lda #0
	ldy #(GEN_CELL_W * 8) - 1
-	sta .gen_buf,y
	dey
	bpl -
	rts

.gen_blit
	; Move the .gen_nr x .gen_nc rectangle at (.gen_sr, .gen_sc) in .gen_buf to
	; (.gen_dr, .gen_dc) in .gen_art. Both are 8 rows of GEN_CELL_W.
	lda .gen_nr
	beq .gb_done
	lda .gen_nc
	beq .gb_done
	lda .gen_sr
	jsr .gb_rowbase
	clc
	adc .gen_sc
	sta .gen_si			; running source index
	lda .gen_dr
	jsr .gb_rowbase
	clc
	adc .gen_dc
	sta .gen_di		; running destination index
	lda .gen_nr
	sta .gen_rows
.gb_row
	ldx .gen_si
	ldy .gen_di
	lda .gen_nc
	sta .gen_cols
-	lda .gen_buf,x
	sta .gen_art,y
	inx
	iny
	dec .gen_cols
	bne -
	lda .gen_si
	clc
	adc #GEN_CELL_W
	sta .gen_si
	lda .gen_di
	clc
	adc #GEN_CELL_W
	sta .gen_di
	dec .gen_rows
	bne .gb_row
.gb_done
	rts
.gb_rowbase
	; a = a row number -> its offset into a GEN_CELL_W-wide cell buffer
	asl
	asl
!if GEN_CELL_W = 8 {
	asl
}
	rts

.gen_tile
	; Build the cell at map position (.pfo_m, .pic_row) into .gen_art, out of
	; the up to four source cells that can reach it, and return x = the count of
	; transparent pixels in it. The picture's own cell always contributes; the
	; one above only when the picture is shifted down, the one to the left only
	; when it is shifted right, and the diagonal one only when it is both.
	lda #0
	ldy #(GEN_CELL_W * 8) - 1
-	sta .gen_art,y
	dey
	bpl -

	lda .pic_shift_y
	beq .gt_bottom			; on the row grid: nothing from the row above
	lda .pic_shift
	beq .gt_topright
	jsr .gt_left			; up and left
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
	jsr .gt_right			; up
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
	jsr .gt_left			; left
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
	jsr .gt_right			; the picture's own cell
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
	jsr .gen_blit
	ldx #0					; count the transparent pixels
	ldy #0
-	lda .gen_art,y
	bne +
	inx
+	iny
	cpy #(GEN_CELL_W * 8)
	bne -
	rts

.gt_left
	ldx .pfo_m				; the source cell left of this one ($ff when there
	dex						; is none - .gen_load_cell reads that as blank)
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
	lda #GEN_CELL_W			; the rightmost .pic_shift columns of the cell left
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
	lda #GEN_CELL_W
	sec
	sbc .pic_shift
	sta .gen_nc
	rts

.gen_expand
	; .gen_art -> .pcf_buf in the store's form: this window's palette bank added
	; to every non-zero pixel, and on the 80-column screen each art pixel
	; written twice, which is the doubling .pic_emit_pixel does for the copied
	; path. A cell is 64 store pixels either way.
	ldx #0
	ldy #0
.ge_loop
	lda .gen_art,x
	beq +
	clc
	adc .pic_pixel_base
+	sta .pcf_buf,y
	iny
!if GEN_CELL_W = 4 {
	sta .pcf_buf,y
	iny
}
	inx
	cpy #64
	bne .ge_loop
	rts

.gen_composite
	; Where the generated cell is transparent, take the pixel of the tile that
	; was already in the cell, so a picture drawn over a scene shows the scene
	; through - the same thing .pcf_make_tile does for the copied path.
	lda .pcf_under_lo
	ldx .pcf_under_hi
	jsr .pcf_code_addr		; .pic_dst -> the tile behind
	ldy #0
	ldz #0
-	lda .pcf_buf,y
	bne +
	lda [.pic_dst],z
	sta .pcf_buf,y
+	inz
	iny
	cpy #64
	bne -
	rts

.gen_write_slot
	; Write .pcf_buf into the next tile of the run .pic_alloc reserved and leave
	; its screen code in .pcf_newcode. Unlike .pcf_make_tile's mid-draw
	; allocation there is no way to run out, and nothing to wrap: the run was
	; reserved for exactly the cells this picture covers.
	lda .pic_slot
	clc
	adc .gen_next
	sta .pcf_newcode_lo
	lda .pic_slot + 1
	adc .gen_next + 1
	adc #FCM_TILE_CODE_HI
	sta .pcf_newcode_hi
	inc .gen_next
	bne +
	inc .gen_next + 1
+	lda .pcf_newcode_lo
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

.pic_gen_fill
	; The off-grid equivalent of .pic_fill_cells: build and write every cell the
	; picture covers, .gen_mw across and .gen_mh down. Clipping, compositing and
	; the screen-code write are the aligned path's; only where the pixels come
	; from is different.
	lda #0
	sta .gen_next
	sta .gen_next + 1
	sta .pic_row
	jsr .pic_point_at_row
.pgf_row
	lda .pic_row
	clc
	adc .pic_y
	cmp #SCREEN_HEIGHT		; this row past the bottom edge? the rest are too
	bcc +
	jmp .pgf_done
+	lda .gen_mw
	sta .pic_cols_left
	lda .pic_x
	asl
	sta .pic_col2
	lda #0
	rol
	sta .pic_col2_hi
	sta .pfo_m
.pgf_cell
	jsr .gen_tile			; -> .gen_art, x = transparent pixels
	cpx #(GEN_CELL_W * 8)
	beq .pgf_advance		; nothing of the picture here: leave the cell alone
	lda .pic_col2_hi		; past the right edge? drop the write
	bne .pgf_advance
	ldy .pic_col2
	cpy #SCREEN_ROW_BYTES
	bcs .pgf_advance
	phx
	jsr .gen_expand
	plx
	ldy .pic_col2
	lda (.pic_ptr),y		; what is already in this cell?
	sta .pcf_under_lo
	iny
	lda (.pic_ptr),y
	sta .pcf_under_hi
	beq .pgf_write			; text or nothing behind: our 0 pixels stay
	cpx #0					; fully opaque: nothing to take from behind
	beq .pgf_write
	jsr .gen_composite
.pgf_write
	jsr .gen_write_slot
	ldy .pic_col2
	lda .pcf_newcode_lo
	sta (.pic_ptr),y
	iny
	lda .pcf_newcode_hi
	sta (.pic_ptr),y
.pgf_advance
	lda .pic_col2
	clc
	adc #2
	sta .pic_col2
	bcc +
	inc .pic_col2_hi
+	inc .pfo_m
	dec .pic_cols_left
	beq +
	jmp .pgf_cell
+	lda .pic_ptr
	clc
	adc #SCREEN_ROW_BYTES
	sta .pic_ptr
	bcc +
	inc .pic_ptr + 1
+	inc .pic_row
	lda .pic_row
	cmp .gen_mh
	beq .pgf_done
	jmp .pgf_row
.pgf_done
	rts

.pic_map_pos
	; Split the picture's art-pixel corner into the first cell and the offsets
	; into it. A cell is GEN_CELL_W art pixels across and 8 rows down, so this
	; is a divide and its remainder on each axis; the remainder is the natural
	; one, "the picture starts this far in", because .gen_tile addresses source
	; pixels directly.
	lda .pic_px
	and #GEN_CELL_W - 1
	sta .pic_shift
	lda .pic_px + 1
	lsr
	lda .pic_px
	ror						; px >> 1, the ninth bit carried down
	lsr
!if GEN_CELL_W = 8 {
	lsr
}
	sta .pic_x
	lda .pic_py
	and #7
	sta .pic_shift_y
	rts

.pic_gen_size
	; .gen_mw / .gen_mh: the cells the picture covers, one more than its own on
	; an axis it is shifted along. .pic_ntiles becomes that product - the run
	; .pic_alloc must reserve, since every covered cell gets a tile of its own.
	; On the grid nothing is generated and the reservation stays the file's own
	; tile count.
	lda .pic_w
	sta .gen_mw
	lda .pic_h
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
	; A picture needing more cells than the whole store cannot be generated.
	; That is only the full-screen ones, which are drawn at the origin and never
	; shifted, so they fall back to the cell grid.
	lda .pic_count + 1
	cmp #>PIC_MAX_TILES		; the store's low byte is zero
	bcc .pgs_take
	lda #0
	sta .pic_shift
	sta .pic_shift_y
	lda .pic_w
	sta .gen_mw
	lda .pic_h
	sta .gen_mh
	rts
.pgs_take
	lda .pic_count
	sta .pic_ntiles
	lda .pic_count + 1
	sta .pic_ntiles + 1
.pgs_done
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
	ldx #>pic_adaptive		; picture's palette (.pic_draw sets it again below),
	jsr .pic_addr			; so it needs no bank of its own and must not claim
	ldy #0					; one - Arthur's frame and side bars are adaptive,
	lda (.pi_ptr),y			; and they were costing three banks a room
	beq .pab_direct
	lda pic_direct_base		; base = bank * 16
	lsr
	lsr
	lsr
	lsr
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
	; new picture spoiled a live one.
	;
	; Unlike the X16, where the map entry names the cell's palette, this engine
	; bakes ABSOLUTE indices (bank * 16 + colour) into the tile pixels, so the
	; only place the bank is written down is the pixels themselves. Every byte
	; of every tile a cell shows therefore has to be looked at - a composite
	; tile legitimately mixes two pictures' banks, so the first opaque pixel is
	; not enough. That is up to 80 * 25 * 64 reads, but it happens only when a
	; new picture arrives and all fourteen banks are claimed, which is rare.
	ldx #15
	lda #0
-	sta .pab_live,x
	dex
	bpl -
	lda pic_direct_base		; never free the adaptive base: the next adaptive
	lsr						; picture draws in it and may have no cells yet
	lsr
	lsr
	lsr
	tax
	lda #1
	sta .pab_live,x
	lda #<SCREEN_ADDRESS
	sta .pic_ptr
	lda #>SCREEN_ADDRESS
	sta .pic_ptr + 1
	lda #0
	sta .gc_row
.parb_row
	lda #0
	sta .gc_col
.parb_cell
	lda .gc_col
	asl
	tay
	iny						; the cell's high byte
	lda (.pic_ptr),y
	sec
	sbc #FCM_TILE_CODE_HI
	cmp #>PIC_MAX_TILES
	bcs .parb_next			; text, or no store code at all
	dey
	lda (.pic_ptr),y		; the screen code, low then high
	pha
	iny
	lda (.pic_ptr),y
	tax
	pla
	jsr .pcf_code_addr		; .pic_dst -> the tile
	ldz #0
-	lda [.pic_dst],z
	beq +
	lsr						; bank * 16 + colour -> bank
	lsr
	lsr
	lsr
	phz
	tax
	lda #1
	sta .pab_live,x
	plz
+	inz
	cpz #64
	bne -
.parb_next
	inc .gc_col
	lda .gc_col
	cmp #SCREEN_WIDTH
	bcc .parb_cell
	lda .pic_ptr
	clc
	adc #SCREEN_ROW_BYTES
	sta .pic_ptr
	bcc +
	inc .pic_ptr + 1
+	inc .gc_row
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
	; straight from pic_win_bank, and its tiles are baked for that bank's
	; indices. The run is dead anyway - its picture is off screen, which is why
	; the bank was freed.
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
	; the low nybble, the vertical in the high. y holds the window on entry and
	; still does on exit.
	lda .pic_shift_y
	asl
	asl
	asl
	asl
	ora .pic_shift
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

	jsr .pic_map_pos		; the first cell, and the offsets inside it
	jsr .pic_gen_size		; how many cells it covers, and can they fit

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
	; .pic_att now points at the tile block. The aligned path streams it into
	; the reserved run; the off-grid one never copies it, and reads the tiles it
	; needs back out of attic as it builds each cell, so remember where it is.
	lda .pic_att
	sta .gen_tiles
	lda .pic_att + 1
	sta .gen_tiles + 1
	lda .pic_att + 2
	sta .gen_tiles + 2

	lda .pic_shift
	ora .pic_shift_y
	bne +
	jsr .pic_copy_tiles
	jmp .pic_fill_cells
+	jmp .pic_gen_fill

.pic_erase
	; Blank the rectangle the picture in .pic_index occupies at .pic_y, .pic_x,
	; by putting a space in every cell it covered. s_printchar would do it, but
	; it would also wrap, scroll and move the cursor.
	jsr .pic_open
	jsr .pic_att_next
	sta .pic_w
	jsr .pic_att_next
	sta .pic_h
	; A picture drawn off the grid covers a cell more on each shifted axis, and
	; those EDGE cells hold part of the picture beside part of whatever it was
	; drawn over, so clearing them whole would strip that. Erase the interior
	; only, as the X16 engine does.
	jsr .pic_map_pos
	lda .pic_shift
	beq +
	inc .pic_x
	dec .pic_w
+	lda .pic_shift_y
	beq +
	inc .pic_y
	dec .pic_h
+	lda .pic_w				; a picture one cell across or down has no interior
	beq .pic_erase_done		; left, and a zero count would run .pic_start_row's
	lda .pic_h				; counter all the way round
	beq .pic_erase_done
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
