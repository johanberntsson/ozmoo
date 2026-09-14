; fltest.asm - the suspend/resume pair of documentation/fastloader-notes.md,
; exercised on real hardware against the SHIPPED asm/fastloader.asm rather than
; a copy of it, so the test cannot drift from the code.
;
;   fastloader_init      detect a 1541, install the drive code
;   fastloader_readblock read t18 s0, checksum it
;   kernal_open          the OPEN shim: suspends, then a normal DOS channel
;                        answers - this is what coexist.asm hung on
;   fastloader_readblock again: re-installs, same checksum
;
; Assemble from asm/ so !source and !binary resolve:
;   acme --cpu 6510 --format cbm -DTARGET_C64=1 -DFASTLOADER=1 \
;        -o fltest.prg ../tools/fastloader/test/fltest.asm
!cpu 6510
!to "fltest.prg", cbm

; --- the handful of Ozmoo symbols asm/fastloader.asm expects ---------------
CURRENT_DEVICE    = $ba
zp_mempos         = $fb
kernal_readst     = $ffb7
kernal_setlfs     = $ffba
kernal_setnam     = $ffbd
kernal_open_raw   = $ffc0
kernal_close      = $ffc3
kernal_chkin      = $ffc6
kernal_clrchn     = $ffcc
kernal_readchar   = $ffcf
kernal_load_raw   = $ffd5
kernal_save_raw   = $ffd8
kernal_reset_raw  = $fce2
chrout            = $ffd2

; constants.asm routes these through the shims; do the same here.
kernal_open       = fl_kernal_open
kernal_load       = fl_kernal_load
kernal_save       = fl_kernal_save
kernal_reset      = fl_kernal_reset

TRACK  = 18
SECTOR = 0

* = $0801
	!byte $0c,$08,$0a,$00,$9e,$32,$30,$36,$31,$00,$00,$00

start
	jsr $ffe7			; CLALL - no files open
	lda #<m_title
	ldy #>m_title
	jsr print_str

	jsr fastloader_init

	lda #<m_sig
	ldy #>m_sig
	jsr print_str
	lda fl_sig
	jsr print_hex
	lda fl_sig + 1
	jsr print_hex
	lda #<m_act
	ldy #>m_act
	jsr print_str
	lda fastloader_enabled
	jsr print_hex
	lda fastloader_active
	jsr print_hex
	jsr newline

	lda fastloader_active
	bne +
	lda #<m_noinst
	ldy #>m_noinst
	jmp print_str
+
	; --- first read ---
	jsr read_block
	bcc +
	jmp .read_failed
+	jsr checksum
	lda #<m_ck1
	ldy #>m_ck1
	jsr print_str
	jsr print_cksum
	lda cksum
	sta cksum_ref
	lda cksum + 1
	sta cksum_ref + 1

	; --- the OPEN shim has to hand the drive back first ---
	lda #<m_dos
	ldy #>m_dos
	jsr print_str
	lda #0
	jsr kernal_setnam		; length 0: the command channel itself
	lda #15
	ldx fastloader_device
	tay						; secondary address 15
	jsr kernal_setlfs
	jsr kernal_open			; -> fl_kernal_open
	bcc +
	lda #<m_openfail
	ldy #>m_openfail
	jmp print_str
+	ldx #15
	jsr kernal_chkin
	ldy #0
-	jsr kernal_readst
	bne +
	jsr kernal_readchar
	cmp #13
	beq +
	jsr chrout
	iny
	cpy #40
	bne -
+	jsr kernal_clrchn
	lda #15
	jsr kernal_close
	jsr newline

	; --- second read: fastloader_readblock must re-install ---
	jsr read_block
	bcc +
	jmp .read_failed
+	jsr checksum
	lda #<m_ck2
	ldy #>m_ck2
	jsr print_str
	jsr print_cksum

	lda cksum
	cmp cksum_ref
	bne .mismatch
	lda cksum + 1
	cmp cksum_ref + 1
	bne .mismatch
	jsr fastloader_shutdown
	lda #<m_pass
	ldy #>m_pass
	jmp print_str
.mismatch
	lda #<m_mismatch
	ldy #>m_mismatch
	jmp print_str
.read_failed
	lda #<m_readfail
	ldy #>m_readfail
	jmp print_str

; --- read TRACK/SECTOR into buffer through the real entry point ------------
read_block
	lda #<buffer
	sta readblocks_mempos
	lda #>buffer
	sta readblocks_mempos + 1
	ldx #TRACK
	ldy #SECTOR
	lda fastloader_device
	jmp fastloader_readblock

checksum
	lda #0
	sta cksum
	sta cksum + 1
	ldy #0
-	clc
	lda cksum
	adc buffer,y
	sta cksum
	bcc +
	inc cksum + 1
+	iny
	bne -
	rts

print_cksum
	lda cksum + 1
	jsr print_hex
	lda cksum
	jsr print_hex
newline
	lda #13
	jmp chrout

; fastloader_init reports a missing 1541 through this; Ozmoo has its own.
printstring_raw
	; A = high byte of string, X = low byte
	sta strptr + 1
	stx strptr
	ldy #0
-	lda (strptr),y
	beq +
	jsr chrout
	iny
	bne -
+	rts

print_str
	sta strptr
	sty strptr + 1
	ldy #0
-	lda (strptr),y
	beq +
	jsr chrout
	iny
	bne -
+	rts

print_hex
	pha
	lsr
	lsr
	lsr
	lsr
	jsr .nyb
	pla
	and #$0f
.nyb
	cmp #10
	bcc +
	adc #6
+	adc #$30
	jmp chrout

strptr     = $fd
readblocks_mempos !byte 0, 0
cksum      !byte 0, 0
cksum_ref  !byte 0, 0

m_title    !pet 147,"fastloader suspend/resume",13,0
m_sig      !pet "rom sig=$",0
m_act      !pet "  enabled/active=$",0
m_noinst   !pet "not installed - no 1541?",13,0
m_ck1      !pet "read 1 cksum=$",0
m_dos      !pet 13,"dos status: ",0
m_ck2      !pet "read 2 cksum=$",0
m_openfail !pet "OPEN FAILED",13,0
m_readfail !pet "READ FAILED",13,0
m_mismatch !pet 13,"MISMATCH - resume broken",13,0
m_pass     !pet 13,"PASS - suspend and resume work",13,0

buffer     = $c000

!source "fastloader.asm"
