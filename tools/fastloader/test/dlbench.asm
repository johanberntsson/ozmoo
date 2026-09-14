; dlbench.asm - same 40-block benchmark as bench.asm, but via DreamLoad's
; LoadTS instead of the kernal. Directly comparable: same blocks, same
; checksum, same jiffy timing.
;
; DreamLoad (WTFPL, The Dreams) - installer at $1000, loader jump table at
; $cd00, sector buffer at $cf00. LoadTS: X=track, Y=sector, carry=error.
!cpu 6510
!to "dlbench.prg", cbm

chrout   = $ffd2
DEVICE   = $ba			; kernal device number, read by DLoad_Install
INSTALL  = $1000
LDLOC    = $cd00
LOADTS   = LDLOC + 3
SWITCHOFF= LDLOC + 15
LDBF     = $cf00
zp       = $fb

* = $0801
	!byte $0c,$08,$0a,$00,$9e,$32,$30,$36,$31,$00,$00,$00

start
	jsr $ffe7
	lda #<m_title
	ldy #>m_title
	jsr print_str

	lda #8
	sta DEVICE
	jsr INSTALL
	sta inst_a
	lda #0
	rol
	sta inst_c

	lda #<m_inst
	ldy #>m_inst
	jsr print_str
	lda inst_a
	jsr print_hex
	lda #<m_carry
	ldy #>m_carry
	jsr print_str
	lda inst_c
	jsr print_hex
	lda #13
	jsr chrout

	lda #0
	sta cksum
	sta cksum+1
	sta nblocks
	sta idx

	lda $a2
	sta t0
	lda $a1
	sta t0+1

.next
	ldx idx
	lda tracks,x
	bmi .done
	lda sectors,x
	tay				; Y = sector
	lda tracks,x
	tax				; X = track
	jsr LOADTS
	bcs .ioerr

	ldy #0
-	lda LDBF,y
	clc
	adc cksum
	sta cksum
	bcc +
	inc cksum+1
+	iny
	bne -

	inc nblocks
.ioerr
	inc idx
	jmp .next

.done
	lda $a2
	sec
	sbc t0
	sta elapsed
	lda $a1
	sbc t0+1
	sta elapsed+1

	jsr SWITCHOFF		; DreamLoad is captive - release the drive

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
.nyb	cmp #10
	bcc +
	adc #6
+	adc #$30
	jmp chrout

idx     !byte 0
inst_a  !byte 0
inst_c  !byte 0
nblocks !byte 0
cksum   !byte 0,0
t0      !byte 0,0
elapsed !byte 0,0

m_title   !pet 147,"dreamload block benchmark",13,0
m_inst    !pet "install: a=$",0
m_carry   !pet " c=$",0
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

* = INSTALL
	!binary "dload.prg", , 2
