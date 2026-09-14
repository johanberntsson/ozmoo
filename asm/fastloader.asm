; fastloader.asm - use DreamLoad for Ozmoo's block reads on the C64.
;
; DreamLoad is by The Dreams (the-dreams.de), released under the WTFPL.
; Only the 1541/1571 protocol is used here.
;
; Rather than shipping DreamLoad's 4.2 KB installer, Ozmoo carries the
; post-install state directly: the 786-byte drive code is written into the
; drive's RAM at $0300 with M-W, and the 512-byte resident loader - already
; patched for the 1541 - is copied to $cd00. That costs ~1.3 KB of program
; image instead of 4.2 KB. The resident KB at $cc00-$cfff is reserved by
; VMEM_END_PAGE in ozmoo.asm - vmem in RAM is one linear run of pages and
; cannot skip a hole, so the loader has to sit above the end of it.
;
; Resident loader jump table:
;   $cd03  LoadTS     X=track, Y=sector -> sector at $cf00, carry set on error
;   $cd0f  SwitchOff  put the drive back in normal DOS
;
; DreamLoad is a CAPTIVE loader: while it is installed the drive no longer
; answers the DOS protocol, so any kernal file operation on it would hang. The
; shims at the bottom of this file put the drive back in DOS before OPEN, LOAD,
; SAVE and the reset that ends the game; fastloader_readblock re-installs it on
; the next block read. constants.asm points the kernal_* symbols at the shims,
; so every call site in Ozmoo - saves, restores, the directory, disk swaps - is
; covered in one place.
;
; The install talks to the command channel with the low-level bus routines
; (LISTEN/SECOND/CIOUT, TALK/TKSA/ACPTR) rather than OPEN/CHKOUT. That leaves
; no entry in the kernal's file table, so there is nothing to close once the
; drive has gone captive, and no logical file number to collide with the ones
; read_track_sector and the save code use.

!ifdef FASTLOADER {
!zone fastloader {

fl_loader      = $cd00
fl_loadts      = fl_loader + 3
fl_switchoff   = fl_loader + 15
fl_buffer      = $cf00
fl_stub_addr   = $0700		; scratch buffer in drive RAM
fl_cmd_channel = $6f		; secondary address 15, as LISTEN/TALK want it

; Low-level kernal bus routines, not otherwise used by Ozmoo.
kernal_listen  = $ffb1
kernal_second  = $ff93
kernal_unlsn   = $ffae
kernal_ciout   = $ffa8
kernal_talk    = $ffb4
kernal_tksa    = $ff96
kernal_untlk   = $ffab
kernal_acptr   = $ffa5
kernal_open_file_count = $98	; kernal LDTND: how many logical files are open

fastloader_active  !byte 0	; 1 = drive code installed and the drive is ours
fastloader_enabled !byte 0	; 1 = a 1541 was found, so re-installing is allowed
fastloader_device  !byte 0
.fl_dstlo      !byte 0
.fl_dsthi      !byte 0
.fl_cnt        !byte 0
.fl_req_track  !byte 0
.fl_req_sector !byte 0
.fl_remain     !byte 0, 0
fl_sig         !byte 0, 0	; public so the hardware test can print it
.fl_a          !byte 0
.fl_x          !byte 0
.fl_y          !byte 0

; ---------------------------------------------------------------------------
; Install. Safe to fail: fastloader_enabled stays 0 and every read then takes
; the ordinary kernal path.
; ---------------------------------------------------------------------------
fastloader_init
	lda #0
	sta fastloader_active
	sta fastloader_enabled
	lda CURRENT_DEVICE		; whatever the boot file was loaded from
	sta fastloader_device
	cmp #8
	bcc .fl_give_up			; only real drive numbers
	cmp #12
	bcs .fl_give_up
	jsr .fl_is_1541
	bcs .fl_give_up			; not a 1541: the drive code would be wrong
	lda #1
	sta fastloader_enabled
	jsr .fl_install
	lda fastloader_enabled
	bne +				; installed - nothing to report
.fl_give_up
	; Say so. Every other way this can fail is silent, and the only symptom is
	; that a build made with -fl is no faster than one without it, which looks
	; like the flag did nothing rather than like an unsupported drive.
	lda #>.fl_no_loader_msg
	ldx #<.fl_no_loader_msg
	jsr printstring_raw
	jsr wait_a_sec			; the game clears the screen right after this
+	rts
.fl_no_loader_msg
	!pet 13,"Fast loader off: no 1541 found.",13,0

; ---------------------------------------------------------------------------
; Read one block. In: X=track, Y=sector, A=device.
; Out: carry clear = done, sector copied to readblocks_mempos.
;      carry set   = not handled, caller must use the kernal path.
; ---------------------------------------------------------------------------
fastloader_readblock
	stx .fl_req_track
	sty .fl_req_sector
	cmp fastloader_device		; only the drive we installed into
	bne .fl_not_handled
	lda fastloader_enabled
	beq .fl_not_handled
	lda fastloader_active
	bne .fl_have_drive
	; Suspended by a kernal file operation. Take it back - but not while a
	; logical file is open, because re-installing talks to the bus and would
	; cut across whatever that file is doing.
	lda kernal_open_file_count
	bne .fl_not_handled
	jsr .fl_install
	lda fastloader_active
	beq .fl_not_handled
.fl_have_drive
	jsr .fl_zp_stash
	ldx .fl_req_track
	ldy .fl_req_sector
	jsr fl_loadts
	jsr .fl_zp_fetch		; lda/sta only - the carry from LoadTS survives
	bcs .fl_not_handled		; read error: let the kernal path retry it

	lda readblocks_mempos
	sta zp_mempos
	lda readblocks_mempos + 1
	sta zp_mempos + 1
	ldy #0
-	lda fl_buffer,y
	sta (zp_mempos),y
	iny
	bne -
	clc
	rts
.fl_not_handled
	sec
	rts

; ---------------------------------------------------------------------------
; Hand the drive back for good - the game is quitting or restarting.
; ---------------------------------------------------------------------------
fastloader_shutdown
	lda #0
	sta fastloader_enabled
	; fall through

; Hand the drive back until the next block read needs it.
fastloader_suspend
	lda fastloader_active
	beq +
	lda #0
	sta fastloader_active
	jsr .fl_zp_stash
	jsr fl_switchoff
	jsr .fl_zp_fetch
	jmp .fl_wait_for_dos
+	rts

; DreamLoad's resident loader keeps its working variables in zero page:
; LdLAE = $ae/$af, LdGZp = $fc, LdChk = $fd (user_cfg/dload.cfg in its source,
; and the binary here does write all four). On a C64 $fc and $fd are Ozmoo's
; zp_temp + 1 and + 2, and a block read happens in the middle of running
; Z-code, so whatever the interpreter had there has to come back untouched.
; Without this the sectors arrive perfectly and the interpreter still wanders
; off and executes QUIT a few hundred reads later.
.fl_zp !byte 0, 0, 0, 0
.fl_zp_stash
	lda $ae
	sta .fl_zp
	lda $af
	sta .fl_zp + 1
	lda $fc
	sta .fl_zp + 2
	lda $fd
	sta .fl_zp + 3
	rts
.fl_zp_fetch
	lda .fl_zp
	sta $ae
	lda .fl_zp + 1
	sta $af
	lda .fl_zp + 2
	sta $fc
	lda .fl_zp + 3
	sta $fd
	rts

; SwitchOff is not a handshake, it is a command the drive answers with
; jmp ($fffc): the 1541 resets itself, and holds DATA low from then until its
; DOS is ready - measured at ~1 s on an Ultimate 64's 1541. A kernal OPEN
; issued during that window does not fail, it HANGS: the drive is pulling DATA,
; so the kernal believes a device answered its LISTEN and then waits forever
; for a handshake the drive is in no state to give. So wait for DATA ($dd00
; bit 7, 1 = released) to come back and stay back. Give up after ~4 s and let
; the kernal report whatever it finds rather than hang here.
.fl_wait_for_dos
	lda #6				; ~4 s cap; in practice it is out in about 1 s
	sta .fl_cnt
.fl_wfd_tick
	ldx #0
.fl_wfd_outer
	ldy #0
.fl_wfd_inner
	lda $dd00
	bmi .fl_wfd_maybe
	dey
	bne .fl_wfd_inner
	dex
	bne .fl_wfd_outer
	dec .fl_cnt
	bne .fl_wfd_tick
	rts				; gave up - the kernal will report what it finds
.fl_wfd_maybe
	; The line has to stay released for a whole ~2.8 ms pass, so that a glitch
	; during the drive's own reset is not read as "ready".
	ldy #0
.fl_wfd_confirm
	lda $dd00
	bpl .fl_wfd_inner
	dey
	bne .fl_wfd_confirm
	rts

; ---------------------------------------------------------------------------
; Kernal shims. constants.asm routes OPEN, LOAD, SAVE and the reset here.
; ---------------------------------------------------------------------------
fl_kernal_open
	; OPEN takes no register arguments and destroys A, X and Y anyway.
	jsr .fl_suspend_for_device
	jmp kernal_open_raw

fl_kernal_load
	; A = load/verify flag, X/Y = alternate load address.
	jsr .fl_stash_axy
	jsr .fl_suspend_for_device
	jsr .fl_fetch_axy
	jmp kernal_load_raw

fl_kernal_save
	; A = zero page offset of the start pointer, X/Y = end address.
	jsr .fl_stash_axy
	jsr .fl_suspend_for_device
	jsr .fl_fetch_axy
	jmp kernal_save_raw

fl_kernal_reset
	jsr fastloader_shutdown
	jmp kernal_reset_raw

.fl_stash_axy
	sta .fl_a
	stx .fl_x
	sty .fl_y
	rts
.fl_fetch_axy
	lda .fl_a
	ldx .fl_x
	ldy .fl_y
	rts

; Only step aside for the drive we actually hold - a printer or the screen is
; none of our business, and suspending for one would cost a 1.4 s re-install.
.fl_suspend_for_device
	lda fastloader_active
	beq +
	lda CURRENT_DEVICE
	cmp fastloader_device
	bne +
	jmp fastloader_suspend
+	rts

; ---------------------------------------------------------------------------
; Drive detection. DreamLoad's own installer identifies a 1541 by its ROM:
; $fea0 = $0d and $e5c6 = $34 $b1. Anything else - a 1581, an sd2iec - would
; be given drive code it cannot run. Carry clear = a 1541.
; ---------------------------------------------------------------------------
.fl_is_1541
	lda #$a0
	ldx #$fe
	ldy #1
	jsr .fl_memread
	bcs .fl_not_1541
	lda fl_sig
	cmp #$0d
	bne .fl_not_1541
	lda #$c6
	ldx #$e5
	ldy #2
	jsr .fl_memread
	bcs .fl_not_1541
	lda fl_sig
	cmp #$34
	bne .fl_not_1541
	lda fl_sig + 1
	cmp #$b1
	bne .fl_not_1541
	clc
	rts
.fl_not_1541
	sec
	rts

; A=address low, X=address high, Y=byte count (max 2) -> fl_sig.
; Carry set if the drive did not answer.
.fl_memread
	sta .fl_dstlo
	stx .fl_dsthi
	sty .fl_cnt
	jsr .fl_cmd_start
	lda #$52			; "M-R"
	jsr .fl_m_header
	jsr kernal_unlsn
	jsr kernal_readst
	bmi .fl_memread_fail
	lda fastloader_device
	jsr kernal_talk
	lda #fl_cmd_channel
	jsr kernal_tksa
	ldy #0
-	jsr kernal_acptr
	sta fl_sig,y
	iny
	cpy .fl_cnt
	bne -
	jsr kernal_untlk
	jsr kernal_readst
	bmi .fl_memread_fail
	clc
	rts
.fl_memread_fail
	sec
	rts

; ---------------------------------------------------------------------------
; Upload the drive code and start it. Sets fastloader_active on success; a
; failure disables the fast loader for the rest of the session.
; ---------------------------------------------------------------------------
.fl_install
	; The resident loader keeps state of its own, and SwitchOff left the drive
	; reset, so start it from the master copy every time: a LoadTS through a
	; resident that thinks it is still talking to the pre-reset drive hangs.
	ldx #0
-	lda .fl_resident,x
	sta fl_loader,x
	lda .fl_resident + 256,x
	sta fl_loader + 256,x
	inx
	bne -
	jsr .fl_upload
	jsr .fl_repair_cr
	jsr .fl_start
	jsr .fl_settle
	jsr kernal_readst
	bmi .fl_install_failed
	lda #1
	sta fastloader_active
	rts
.fl_install_failed
	lda #0
	sta fastloader_active
	sta fastloader_enabled
	rts

; --- M-W the drive code to $0300 in 32-byte chunks -------------------------
.fl_upload
	lda #<.fl_drivecode
	sta .fl_src
	lda #>.fl_drivecode
	sta .fl_src + 1
	lda #$00
	sta .fl_dstlo
	lda #$03
	sta .fl_dsthi
	lda #<.fl_drivecode_len
	sta .fl_remain
	lda #>.fl_drivecode_len
	sta .fl_remain + 1
.fl_chunk
	lda .fl_remain + 1
	bne .fl_full
	lda .fl_remain
	beq .fl_upload_done
	cmp #32
	bcs .fl_full
	sta .fl_cnt
	jmp .fl_send
.fl_full
	lda #32
	sta .fl_cnt
.fl_send
	jsr .fl_write_chunk

	lda .fl_src
	clc
	adc .fl_cnt
	sta .fl_src
	bcc +
	inc .fl_src + 1
+	lda .fl_dstlo
	clc
	adc .fl_cnt
	sta .fl_dstlo
	bcc +
	inc .fl_dsthi
+	lda .fl_remain
	sec
	sbc .fl_cnt
	sta .fl_remain
	bcs +
	dec .fl_remain + 1
+	jmp .fl_chunk
.fl_upload_done
	rts

; M-W .fl_cnt bytes from (.fl_src) to .fl_dsthi/.fl_dstlo in drive RAM.
.fl_write_chunk
	jsr .fl_cmd_start
	lda #$57			; "M-W"
	jsr .fl_m_header
	ldy #0
	; The source pointer lives in the operand below: zero page is not free
	; here, since a re-install can happen in the middle of the game.
.fl_copy_loop
	lda $ffff,y
.fl_src = .fl_copy_loop + 1
	jsr kernal_ciout
	iny
	cpy .fl_cnt
	bne .fl_copy_loop
	lda #13
	jsr kernal_ciout
	jmp kernal_unlsn

; Open the command channel for writing.
.fl_cmd_start
	lda fastloader_device
	jsr kernal_listen
	lda #fl_cmd_channel
	jmp kernal_second

; A holds the command letter ("R", "W" or "E"): send "M-<a>" and, for the two
; that need them, the address and count that always follow.
.fl_m_header
	tax
	lda #$4d			; "M"
	jsr kernal_ciout
	lda #$2d			; "-"
	jsr kernal_ciout
	txa
	jsr kernal_ciout
	lda .fl_dstlo
	jsr kernal_ciout
	lda .fl_dsthi
	jsr kernal_ciout
	cpx #$45			; "M-E" takes no count
	beq +
	lda .fl_cnt
	jsr kernal_ciout
+	rts

; The drive code holds one $0d byte at $05fd, which would end the M-W command
; early. It is shipped as $0c and repaired here by a stub containing no $0d.
.fl_repair_cr
	ldx #<.fl_fixstub
	ldy #>.fl_fixstub
	lda #.fl_fixstub_len
	jsr .fl_send_stub
	jmp .fl_run_stub

; Enter the drive code the way DreamLoad's own bootstrap does: interrupts off
; and both IEC lines released. A plain M-E enters via the DOS and hangs.
.fl_start
	ldx #<.fl_entrystub
	ldy #>.fl_entrystub
	lda #.fl_entrystub_len
	jsr .fl_send_stub
	jmp .fl_run_stub

; The drive needs a moment after the M-E that starts the loader: it turns the
; motor off and then waits for BOTH bus lines to be released before it will
; take a command. A LoadTS issued inside that window pulls DATA while the drive
; is still waiting for DATA to go free, and the two deadlock - the drive holding
; CLK, the host waiting for CLK. DreamLoad's own installer has the same delay in
; the same place (dload.src, the Sys7 loop). ~50 ms, once per install.
.fl_settle
	ldx #40
.fl_settle_outer
	ldy #0
.fl_settle_inner
	dey
	bne .fl_settle_inner
	dex
	bne .fl_settle_outer
	rts

; A=length, X/Y=pointer: M-W a stub to fl_stub_addr
.fl_send_stub
	sta .fl_cnt
	stx .fl_src
	sty .fl_src + 1
	lda #<fl_stub_addr
	sta .fl_dstlo
	lda #>fl_stub_addr
	sta .fl_dsthi
	jmp .fl_write_chunk

.fl_run_stub
	jsr .fl_cmd_start
	lda #$45			; "M-E"
	jsr .fl_m_header
	lda #13
	jsr kernal_ciout
	jmp kernal_unlsn

.fl_fixstub
	!byte $a9,$0c			; lda #$0c
	!byte $8d,$fd,$05		; sta $05fd
	!byte $ee,$fd,$05		; inc $05fd -> $0d
	!byte $60			; rts
.fl_fixstub_len = * - .fl_fixstub

.fl_entrystub
	!byte $78			; sei
	!byte $a9,$00			; lda #0
	!byte $8d,$00,$18		; sta $1800 - release CLK and DATA
	!byte $4c,$11,$03		; jmp $0311 - T41_LdrStart
.fl_entrystub_len = * - .fl_entrystub

.fl_drivecode
	!binary "fastloader-drivecode.bin"
.fl_drivecode_len = * - .fl_drivecode
.fl_resident
	!binary "fastloader-resident.bin"

} ; zone fastloader
} ; ifdef FASTLOADER
