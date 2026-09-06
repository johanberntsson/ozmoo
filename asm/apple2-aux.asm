; ---------------------------------------------------------------------------
; Ozmoo Apple IIe: the auxiliary bank as a vmem cache
;
; A 128K IIe is two 64K banks. Everything Ozmoo does runs in the main one; the
; auxiliary bank is reachable only through the soft switches, a page at a time,
; and $0800-$BFFF of it - 184 pages, 46K - is free for us. That is bigger than
; the whole main-RAM cache and smaller than any story, so it is a cache and not
; a copy of the game: a2_aux_preload fills it with the first 184 pages of paged
; story at boot, and readblock (disk.asm) copies from it instead of reading the
; disk whenever the page it wants is one of them.
;
; The mapping needs no table. The cached pages are a prefix of the paged story
; data, so paged page i lives at aux page A2_AUX_FIRST_PAGE + i, and "is it in
; the cache?" is "is i below a2_aux_pages?".
;
; This file is assembled into the language card, with the rest of the
; interpreter's upper half (see the end of ozmoo.asm), and that is not a
; convenience - it is what makes the read possible at all. RAMRD sends every
; read of $0200-$BFFF to the auxiliary bank, and that includes instruction
; fetch, so a copy loop living down there would read its own next instruction
; out of aux. $D000-$FFFF is switched by ALTZP and not by RAMRD, as are the
; zero page and the stack, so code up here goes on executing normally with
; either switch set. RAMWRT alone is harmless anywhere (it moves writes only),
; but both routines are here so there is one rule rather than two.
; ---------------------------------------------------------------------------

!zone a2_aux {

; How many pages of the cache hold story data. Zero until the preload has run,
; and zero again after a restart, because this byte is part of the image
; a2_lc_init copies up from the disk every time the machine boots.
a2_aux_pages !byte 0

; ---------------------------------------------------------------------------
; a2_aux_read_page: copy 256 bytes out of the auxiliary bank.
;   a = aux source page, y = main destination page.
; ---------------------------------------------------------------------------
a2_aux_read_page
	sta .ar_src + 2
	sty .ar_dst + 2
	sta A2_SETRAMRD                 ; reads of $0200-$BFFF come from aux...
	ldy #0
.ar_loop
.ar_src
	lda $ff00,y
.ar_dst
	sta $ff00,y                     ; ...but writes still go to main
	iny
	bne .ar_loop
	sta A2_CLRRAMRD
	rts

; ---------------------------------------------------------------------------
; a2_aux_write_page: copy 256 bytes into the auxiliary bank.
;   a = main source page, y = aux destination page.
; ---------------------------------------------------------------------------
a2_aux_write_page
	sta .aw_src + 2
	sty .aw_dst + 2
	sta A2_SETRAMWRT                ; writes to $0200-$BFFF go to aux...
	ldy #0
.aw_loop
.aw_src
	lda $ff00,y                     ; ...and reads still come from main
.aw_dst
	sta $ff00,y
	iny
	bne .aw_loop
	sta A2_CLRRAMWRT
	rts

; ---------------------------------------------------------------------------
; a2_aux_detect: is there a whole auxiliary bank behind the switches?
;   a = a page of main RAM to test with, whose byte at +$78 is destroyed.
;   Carry set if there is one.
;
; A IIe with the small 1K 80 column card has aux RAM for the screen at
; $0400-$07FF and nothing else, so the test has to answer three questions, and
; the order matters because the second and third write to aux addresses that
; would be real memory if the first were wrong.
;
;   1. Does the switch do anything? Write one value to main and a different one
;      to aux at the caller's page, and require main to have kept its own. A
;      machine that ignores RAMWRT answers with the aux value.
;   2. Is it a whole 64K or the small card's 1K mirrored over the address
;      space? Two pages 1K apart, written differently and read back: a mirror
;      gives the same byte for both. This is not hypothetical - MAME's std80
;      card mirrors, and without this test a base IIe preloads 46K of story
;      into its own screen.
;   3. Is the top of our range there at all? A card that decodes only the
;      bottom of memory leaves $BF78 floating.
;
; Everything is probed at offset $78 within a page, which is a screen hole -
; not displayed, and not written by anything of ours - so that a machine that
; does mirror is scribbled on where it cannot show.
; ---------------------------------------------------------------------------
a2_aux_detect
	sta zp_temp + 1
	lda #$78
	sta zp_temp
	ldy #0
	lda #$a5
	sta (zp_temp),y                 ; main
	lda #$5a
	sta A2_SETRAMWRT
	sta (zp_temp),y                 ; aux, if there is one
	sta A2_CLRRAMWRT
	lda (zp_temp),y
	cmp #$a5                        ; did main keep its own byte?
	bne .ad_no

	sta A2_SETRAMWRT
	lda #A2_AUX_FIRST_PAGE
	sta zp_temp + 1
	lda #$a5
	sta (zp_temp),y
	lda #A2_AUX_FIRST_PAGE + 4      ; 1K further on, so a mirror would alias
	sta zp_temp + 1
	lda #$5a
	sta (zp_temp),y
	lda #A2_AUX_FIRST_PAGE + A2_AUX_PAGES - 1
	sta zp_temp + 1
	lda #$c3
	sta (zp_temp),y
	sta A2_CLRRAMWRT

	sta A2_SETRAMRD
	lda (zp_temp),y                 ; still the top page
	sta .ad_top
	lda #A2_AUX_FIRST_PAGE
	sta zp_temp + 1
	lda (zp_temp),y
	sta .ad_first
	lda #A2_AUX_FIRST_PAGE + 4
	sta zp_temp + 1
	lda (zp_temp),y
	sta A2_CLRRAMRD
	cmp #$5a
	bne .ad_no
	lda .ad_first
	cmp #$a5                        ; a mirror would have given us $5a here
	bne .ad_no
	lda .ad_top
	cmp #$c3
	bne .ad_no
	sec
	rts
.ad_no
	clc
	rts

.ad_first !byte 0
.ad_top   !byte 0

; ---------------------------------------------------------------------------
; a2_aux_preload: fill the auxiliary bank with the first A2_AUX_PAGES pages of
; paged story data, and say so in a2_aux_pages, which is what readblock reads.
;
; Called once at boot, after insert_disks_at_boot has made sure the story disk
; is in a drive and before load_suggested_pages fills the main cache - so that
; preload is served out of aux rather than off the disk, and costs nothing.
; A machine with no auxiliary bank (a IIe with only the 1K 80 column card)
; leaves a2_aux_pages at zero and plays exactly as it did before.
;
; It is boot-only code and by rights belongs in the deletable init zone, which
; is the z-stack's space and costs no resident RAM - but that zone is nearly
; full on this target (it is stack_size, 1K, and a z5 build was already close
; enough that this routine would not fit). The card has 3K spare and nothing
; else asking for it, so it lives here instead. If step 9 wants that back, this
; is the first thing to move, and STACK_PAGES is the other lever.
; ---------------------------------------------------------------------------
!zone a2_aux_preload
a2_aux_preload
	; A page of the main cache is the staging buffer - readblock can only read
	; into main - and the same page is what the detect scribbles on. Nothing
	; else is using the cache yet.
	lda vmap_first_ram_page
	sta .staging
	jsr a2_aux_detect
	bcs +
	rts
+
	; How many pages of paged story there are: the running total in the last
	; disk's config entry, which is the number readblock measures a block
	; against, so the two cannot disagree.
	ldx #0
	ldy disk_info + 2               ; number of disks
	bne +
	rts
+
-	lda disk_info + 5,x
	sta .total + 1
	lda disk_info + 6,x
	sta .total
	txa
	clc
	adc disk_info + 3,x             ; bytes this entry takes
	tax
	dey
	bne -

	lda .total + 1
	bne +                           ; more than 255 pages: take the lot
	lda .total
	cmp #A2_AUX_PAGES
	bcc ++
+	lda #A2_AUX_PAGES
++	sta .count
	bne +
	rts
+

	; The progress bar, drawn the way load_suggested_pages draws its own: the
	; whole bar first, then one character rubbed out per few pages loaded.
	lda #13
	jsr s_printchar
	lda .count
	lsr
	lsr
	lsr
	tax
	inx
	stx .ticks_left
-	lda #47
	jsr s_printchar
	dex
	bne -
	lda #8
	sta .tick

	; Read them, one page at a time, staging each through main.
	lda nonstored_pages
	sta readblocks_currentblock
	lda #0
	sta readblocks_currentblock + 1
	lda #A2_AUX_FIRST_PAGE
	sta .auxpage
.loop
	lda #0
	sta readblocks_mempos
	lda .staging
	sta readblocks_mempos + 1
	jsr readblock
	lda .staging
	ldy .auxpage
	jsr a2_aux_write_page
	inc .auxpage
	inc readblocks_currentblock
	bne +
	inc readblocks_currentblock + 1
+	inc a2_aux_pages                ; valid for one more page, from now on
	dec .tick
	bne +
	lda #8
	sta .tick
	ldx .ticks_left
	beq +
	dec .ticks_left
	lda #20                         ; rub one out of the bar
	jsr s_printchar
+	lda a2_aux_pages
	cmp .count
	bne .loop
	rts

.staging    !byte 0
.auxpage    !byte 0
.count      !byte 0
.total      !byte 0, 0
.tick       !byte 0
.ticks_left !byte 0

}
