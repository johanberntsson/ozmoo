; flverify.asm - read 200 sectors spread across the disk through the SHIPPED
; asm/fastloader.asm and check each one against a checksum taken from the d64
; itself (asm/flverify-table.asm, made by tools/fastloader/gen_verify.rb).
;
; Reading one sector twice only shows the loader is deterministic. This shows it
; fetches the sector that was asked for, across seeks, which is the property a
; game depends on.
;
; Assemble from asm/ so !source and !binary resolve:
;   acme --cpu 6510 --format cbm -DTARGET_C64=1 -DFASTLOADER=1 \
;        -o flverify.prg ../tools/fastloader/test/flverify.asm
!cpu 6510
!to "flverify.prg", cbm

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
kernal_open       = fl_kernal_open
kernal_load       = fl_kernal_load
kernal_save       = fl_kernal_save
kernal_reset      = fl_kernal_reset

* = $0801
	!byte $0c,$08,$0a,$00,$9e,$32,$30,$36,$31,$00,$00,$00

start
	jsr $ffe7
	lda #<m_title
	ldy #>m_title
	jsr print_str
	jsr seek_the_head_first
	jsr fastloader_init
	lda fastloader_active
	bne +
	lda #<m_noinst
	ldy #>m_noinst
	jmp print_str
+
	lda #0
	sta nbad
	sta ngood
	sta idx
.loop
	ldx idx
	cpx #NSECTORS
	bcc +
	jmp .done
+

	lda #<buffer
	sta readblocks_mempos
	lda #>buffer
	sta readblocks_mempos + 1
	ldx idx
	lda tracks,x
	sta want_t
	lda sectors,x
	sta want_s
	ldx want_t
	ldy want_s
	lda fastloader_device
	jsr fastloader_readblock
	bcc +
	jmp .readfail
+
	jsr checksum
	ldx idx
	lda cksum
	cmp cksums_lo,x
	bne +
	lda cksum + 1
	cmp cksums_hi,x
	beq .good
+	jmp .mismatch
.good
	inc ngood
	jmp .next
.mismatch
	inc nbad
	lda nbad
	cmp #4				; report the first three in full
	bcs .next
	lda #<m_bad
	ldy #>m_bad
	jsr print_str
	lda want_t
	jsr print_dec
	lda #'/'
	jsr chrout
	lda want_s
	jsr print_dec
	lda #<m_want
	ldy #>m_want
	jsr print_str
	ldx idx
	lda cksums_hi,x
	jsr print_hex
	lda cksums_lo,x
	jsr print_hex
	lda #<m_got
	ldy #>m_got
	jsr print_str
	lda cksum + 1
	jsr print_hex
	lda cksum
	jsr print_hex
	jsr newline
.next
	inc idx
	jmp .loop
.done
	jsr fastloader_shutdown
	lda #<m_result
	ldy #>m_result
	jsr print_str
	lda ngood
	jsr print_dec
	lda #<m_of
	ldy #>m_of
	jsr print_str
	lda nbad
	jsr print_dec
	lda #<m_bad2
	ldy #>m_bad2
	jmp print_str
.readfail
	lda #<m_readfail
	ldy #>m_readfail
	jsr print_str
	lda want_t
	jsr print_dec
	lda #'/'
	jsr chrout
	lda want_s
	jsr print_dec
	jmp newline

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

newline
	lda #13
	jmp chrout

; VICE's 1541 steps the head twice for a single $1c00 write when the drive has
; not seeked yet (src/drive/iecieee/via2d.c, store_prb, the "#if 1" fix for
; VICE bug #1083), parking it on an unformatted half track; DreamLoad's
; wait-for-SYNC loop then spins for ever and the machine hangs. One kernal
; directory read first puts the head on a real track with the stepper phase
; agreeing, and the run completes. Harmless on hardware, and Ozmoo itself never
; needs it: the kernal has loaded the boot file long before fastloader_init.
seek_the_head_first
	; An injected PRG (VICE's -autostartprgmode 1) never went through a kernal
	; LOAD, so $ba is still 0 and every bus call below would talk to device 0.
	; Booting from a disk sets it; default it here so the test can be run
	; either way.
	lda CURRENT_DEVICE
	cmp #8
	bcc +
	cmp #12
	bcc ++
+	lda #8
	sta CURRENT_DEVICE
++
	lda #1
	ldx #<.dirname
	ldy #>.dirname
	jsr kernal_setnam
	lda #1
	ldx CURRENT_DEVICE
	ldy #0			; secondary 0 - load at the address in X/Y
	jsr kernal_setlfs
	lda #0			; LOAD, not VERIFY
	ldx #<buffer
	ldy #>buffer
	jsr kernal_load_raw
	rts
.dirname !pet "$"

; fastloader_init pauses after the "no 1541" message so the player can read it
; before Ozmoo clears the screen. Nothing clears the screen here, and the test
; stops at that point anyway, so the pause has no job to do.
wait_a_sec
	rts

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

print_dec				; A = 0..255
	ldx #0
-	cmp #100
	bcc +
	sbc #100
	inx
	bne -
+	pha
	txa
	beq +
	ora #$30
	jsr chrout
+	pla
	ldx #0
-	cmp #10
	bcc +
	sbc #10
	inx
	bne -
+	pha
	txa
	ora #$30
	jsr chrout
	pla
	ora #$30
	jmp chrout

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
idx        !byte 0
ngood      !byte 0
nbad       !byte 0
want_t     !byte 0
want_s     !byte 0

m_title    !pet 147,"fast loader read verification",13,0
m_noinst   !pet "not installed - no 1541?",13,0
m_bad      !pet "bad t/s ",0
m_want     !pet " want $",0
m_got      !pet " got $",0
m_result   !pet 13,"result: ",0
m_of       !pet " ok, ",0
m_bad2     !pet " bad",13,0
m_readfail !pet "read failed at t/s ",0

buffer     = $c000

!source "flverify-table.asm"
!source "fastloader.asm"
