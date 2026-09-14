; flbench.asm - the same 40 blocks bench.asm reads, but through the SHIPPED
; asm/fastloader.asm instead of the kernal. Run the two back to back to get the
; per-block ratio; the block list, the checksum and the output format are
; identical, so the only difference is the transfer.
;
; Assemble from asm/ so !source and !binary resolve:
;   acme --cpu 6510 --format cbm -DTARGET_C64=1 -DFASTLOADER=1 \
;        -o flbench.prg ../tools/fastloader/test/flbench.asm
!cpu 6510
!to "flbench.prg", cbm

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

* = $0801
	!byte $0c,$08,$0a,$00,$9e,$32,$30,$36,$31,$00,$00,$00   ; 10 SYS 2061

start
	jsr $ffe7			; CLALL - run_prg leaves files open
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
	sta cksum
	sta cksum + 1
	sta nblocks

	lda $a2				; jiffy clock low
	sta t0
	lda $a1
	sta t0 + 1

	ldx #0
	stx idx
.next
	ldx idx
	lda tracks,x
	bmi .done
	sta trk
	lda sectors,x
	sta sct

	lda #<buffer
	sta readblocks_mempos
	lda #>buffer
	sta readblocks_mempos + 1
	ldx trk
	ldy sct
	lda fastloader_device
	jsr fastloader_readblock
	bcs .readfail
	jsr checksum
	inc nblocks
	inc idx
	jmp .next

.done
	lda $a2
	sec
	sbc t0
	sta elapsed
	lda $a1
	sbc t0 + 1
	sta elapsed + 1

	lda #<m_blocks
	ldy #>m_blocks
	jsr print_str
	lda nblocks
	jsr print_hex

	lda #<m_jiffies
	ldy #>m_jiffies
	jsr print_str
	lda elapsed + 1
	jsr print_hex
	lda elapsed
	jsr print_hex

	lda #<m_cksum
	ldy #>m_cksum
	jsr print_str
	lda cksum + 1
	jsr print_hex
	lda cksum
	jsr print_hex
	lda #13
	jmp chrout

.readfail
	lda #<m_readfail
	ldy #>m_readfail
	jsr print_str
	lda trk
	jsr print_hex
	lda #'/'
	jsr chrout
	lda sct
	jsr print_hex
	lda #13
	jmp chrout

; Sum all 256 bytes into cksum, exactly as bench.asm does, so the two runs are
; comparable byte for byte and not just in elapsed time.
checksum
	ldy #0
-	lda buffer,y
	clc
	adc cksum
	sta cksum
	bcc +
	inc cksum + 1
+	iny
	bne -
	rts

; VICE's 1541 steps the head twice for a single $1c00 write when the drive has
; not seeked yet (src/drive/iecieee/via2d.c, store_prb, the "#if 1" fix for
; VICE bug #1083), parking it on an unformatted half track; DreamLoad's
; wait-for-SYNC loop then spins for ever and the machine hangs. One kernal
; directory read first puts the head on a real track with the stepper phase
; agreeing. Harmless on hardware, and Ozmoo itself never needs it: the kernal
; has loaded the boot file long before fastloader_init.
seek_the_head_first
	; An injected PRG (VICE's -autostartprgmode 1) never went through a kernal
	; LOAD, so $ba is still 0 and every bus call below would talk to device 0.
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
	ldy #0				; secondary 0 - load at the address in X/Y
	jsr kernal_setlfs
	lda #0				; LOAD, not VERIFY
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
	adc #6				; carry set: +7 total
+	adc #$30
	jmp chrout

strptr     = $fd
readblocks_mempos !byte 0, 0
trk        !byte 0
sct        !byte 0
idx        !byte 0
nblocks    !byte 0
cksum      !byte 0, 0
t0         !byte 0, 0
elapsed    !byte 0, 0

m_title    !pet 147,"fast loader block benchmark",13,0
m_noinst   !pet "not installed - no 1541?",13,0
m_blocks   !pet 13,"blocks=$",0
m_jiffies  !pet "  jiffies=$",0
m_cksum    !pet "  cksum=$",0
m_readfail !pet 13,"read failed at t/s $",0

; The same 40 blocks bench.asm reads.
tracks
	!fill 21, 17
	!fill 19, 18
	!byte $ff
sectors
	!byte 0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20
	!byte 0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18
	!byte 0

buffer     = $c000

!source "fastloader.asm"
