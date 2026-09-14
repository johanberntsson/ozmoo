; bench.asm - measure Ozmoo's block-read path, exactly as asm/disk.asm does it:
; OPEN "#", OPEN 15 with "U1 2 0 t s", CHKIN, 256x CHRIN, CLOSE, CLOSE.
; Prints blocks read, elapsed jiffies, and a 16-bit checksum of every byte.
!cpu 6510
!to "bench.prg", cbm

setnam = $ffbd
setlfs = $ffba
kopen  = $ffc0
kchkin = $ffc6
kchrin = $ffcf
kclose = $ffc3
kclrchn= $ffcc
chrout = $ffd2

device = 8
zp     = $fb

* = $0801
	!byte $0c,$08,$0a,$00,$9e,$32,$30,$36,$31,$00,$00,$00   ; 10 SYS 2061

start
	jsr $ffe7		; CLALL - a previous run_prg leaves files open
	lda #<m_title
	ldy #>m_title
	jsr print_str

	lda #0
	sta cksum
	sta cksum+1
	sta nblocks

	lda $a2			; jiffy clock low
	sta t0
	lda $a1
	sta t0+1

	ldx #0
.next
	lda tracks,x
	bmi .done
	sta trk
	lda sectors,x
	sta sct
	txa
	pha
	jsr read_block
	pla
	tax
	inx
	inc nblocks
	jmp .next

.done
	lda $a2
	sec
	sbc t0
	sta elapsed
	lda $a1
	sbc t0+1
	sta elapsed+1

	lda #<m_blocks
	ldy #>m_blocks
	jsr print_str
	lda nblocks
	jsr print_hex

	lda #<m_jiffies
	ldy #>m_jiffies
	jsr print_str
	lda elapsed+1
	jsr print_hex
	lda elapsed
	jsr print_hex

	lda #<m_cksum
	ldy #>m_cksum
	jsr print_str
	lda cksum+1
	jsr print_hex
	lda cksum
	jsr print_hex
	lda #13
	jsr chrout
	rts

; --- one block, the way Ozmoo does it today -------------------------------
read_block
	lda #1
	ldx #<n_hash
	ldy #>n_hash
	jsr setnam
	lda #2
	ldx #device
	ldy #2
	jsr setlfs
	jsr kopen
	bcs .err

	lda trk
	ldx #0
	jsr put_dec
	lda sct
	ldx #3
	jsr put_dec

	lda #ucmd_len
	ldx #<ucmd
	ldy #>ucmd
	jsr setnam
	lda #15
	ldx #device
	ldy #15
	jsr setlfs
	jsr kopen
	bcs .err

	ldx #2
	jsr kchkin
	ldy #0
-	jsr kchrin
	clc
	adc cksum
	sta cksum
	bcc +
	inc cksum+1
+	iny
	bne -
.err
	lda #15
	jsr kclose
	lda #2
	jsr kclose
	jmp kclrchn

; value in A, X = offset into ucmd_t; writes two PETSCII digits
put_dec
	stx tmpx
	ldy #0
-	cmp #10
	bcc +
	sbc #10
	iny
	jmp -
+	pha
	tya
	clc
	adc #$30
	ldx tmpx
	sta ucmd_t,x
	pla
	clc
	adc #$30
	ldx tmpx
	inx
	sta ucmd_t,x
	rts

print_str
	sta zp
	sty zp+1
	ldy #0
-	lda (zp),y
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
	adc #6			; carry set: +7 total
+	adc #$30
	jmp chrout

trk      !byte 0
sct      !byte 0
tmpx     !byte 0
nblocks  !byte 0
cksum    !byte 0,0
t0       !byte 0,0
elapsed  !byte 0,0

n_hash   !text "#"
ucmd     !text "U1 2 0 "
ucmd_t   !text "00 "
ucmd_s   !text "00"
ucmd_len = * - ucmd

m_title   !pet 147,"ozmoo block-read benchmark",13,0
m_blocks  !pet 13,"blocks=$",0
m_jiffies !pet "  jiffies=$",0
m_cksum   !pet "  cksum=$",0

tracks
	!fill 21, 17
	!fill 19, 18
	!byte $ff
sectors
	!byte 0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20
	!byte 0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18
	!byte 0
