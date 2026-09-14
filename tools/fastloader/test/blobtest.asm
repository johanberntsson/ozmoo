; blobtest.asm - install DreamLoad WITHOUT its 4.2K installer:
;   M-W the 786-byte drive blob to $0300, M-E $0311, copy the 512-byte
;   patched resident loader to $cd00. Then run the same 40-block benchmark.
; If this reports cksum $7fb0 the compact install works.
!cpu 6510
!to "blobtest.prg", cbm

setnam = $ffbd
setlfs = $ffba
kopen  = $ffc0
kchkin = $ffc6
kchkout= $ffc9
kchrin = $ffcf
kclose = $ffc3
kclrchn= $ffcc
chrout = $ffd2
device = 8
zp     = $fb
src    = $fd

LDLOC    = $cd00
LOADTS   = LDLOC + 3
SWITCHOFF= LDLOC + 15
LDBF     = $cf00

* = $0801
	!byte $0c,$08,$0a,$00,$9e,$32,$30,$36,$31,$00,$00,$00

start
	jsr $ffe7
	lda #<m_title
	ldy #>m_title
	jsr print_str

	; resident loader into place
	ldx #0
-	lda resident,x
	sta LDLOC,x
	lda resident+256,x
	sta LDLOC+256,x
	inx
	bne -

	lda #0			; command channel
	jsr setnam
	lda #15
	ldx #device
	ldy #15
	jsr setlfs
	jsr kopen
	bcc +
	jmp .fail
+
	jsr upload_drive
	jsr fix_cr_byte
	jsr start_drive

	lda #<m_inst
	ldy #>m_inst
	jsr print_str

	; ---- same 40-block benchmark as dlbench -------------------------------
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
	tay
	lda tracks,x
	tax
	jsr LOADTS
	bcs .skip
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
.skip
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
	jsr SWITCHOFF

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
	lda #15
	jsr kclose
	jmp kclrchn
.fail
	lda #<m_fail
	ldy #>m_fail
	jmp print_str

; ---- M-W the drive blob to $0300 in 32-byte chunks -------------------------
upload_drive
	lda #<drive
	sta src
	lda #>drive
	sta src+1
	lda #$00
	sta dstlo
	lda #$03
	sta dsthi
	lda #<drivelen
	sta remain
	lda #>drivelen
	sta remain+1
.chunk
	lda remain+1
	bne .full
	lda remain
	beq .done2
	cmp #32
	bcs .full
	sta cnt
	jmp .go
.full	lda #32
	sta cnt
.go
	ldx #15
	jsr kchkout
	lda #$4d
	jsr chrout
	lda #$2d
	jsr chrout
	lda #$57
	jsr chrout
	lda dstlo
	jsr chrout
	lda dsthi
	jsr chrout
	lda cnt
	jsr chrout
	ldy #0
-	lda (src),y
	jsr chrout
	iny
	cpy cnt
	bne -
	lda #13
	jsr chrout
	jsr kclrchn

	lda src
	clc
	adc cnt
	sta src
	bcc +
	inc src+1
+	lda dstlo
	clc
	adc cnt
	sta dstlo
	bcc +
	inc dsthi
+	lda remain
	sec
	sbc cnt
	sta remain
	bcs +
	dec remain+1
+	jmp .chunk
.done2	rts

; The blob's byte at $05fd is $0d, which would terminate the M-W command, so it
; was uploaded as $0c. This stub (containing no $0d itself) repairs it.
fix_cr_byte
	ldx #15
	jsr kchkout
	lda #$4d
	jsr chrout
	lda #$2d
	jsr chrout
	lda #$57
	jsr chrout
	lda #$00		; to $0700
	jsr chrout
	lda #$07
	jsr chrout
	lda #9			; 9 bytes
	jsr chrout
	ldy #0
-	lda stub,y
	jsr chrout
	iny
	cpy #9
	bne -
	lda #13
	jsr chrout
	jsr kclrchn
	ldx #15			; M-E $0700
	jsr kchkout
	lda #$4d
	jsr chrout
	lda #$2d
	jsr chrout
	lda #$45
	jsr chrout
	lda #$00
	jsr chrout
	lda #$07
	jsr chrout
	lda #13
	jsr chrout
	jmp kclrchn

stub	!byte $a9,$0c		; lda #$0c
	!byte $8d,$fd,$05	; sta $05fd
	!byte $ee,$fd,$05	; inc $05fd  -> $0d
	!byte $60		; rts

start_drive
	ldx #15			; M-W the entry stub to $0700
	jsr kchkout
	lda #$4d
	jsr chrout
	lda #$2d
	jsr chrout
	lda #$57
	jsr chrout
	lda #$00
	jsr chrout
	lda #$07
	jsr chrout
	lda #9
	jsr chrout
	ldy #0
-	lda entry_stub,y
	jsr chrout
	iny
	cpy #9
	bne -
	lda #13
	jsr chrout
	jsr kclrchn

	ldx #15			; M-E $0700
	jsr kchkout
	lda #$4d
	jsr chrout
	lda #$2d
	jsr chrout
	lda #$45
	jsr chrout
	lda #$00
	jsr chrout
	lda #$07
	jsr chrout
	lda #13
	jsr chrout
	jmp kclrchn

entry_stub
	!byte $78		; sei
	!byte $a9,$00		; lda #0
	!byte $8d,$00,$18	; sta $1800   (release CLK and DATA)
	!byte $4c,$11,$03	; jmp $0311   (T41_LdrStart)

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

dstlo   !byte 0
dsthi   !byte 0
cnt     !byte 0
remain  !byte 0,0
idx     !byte 0
nblocks !byte 0
cksum   !byte 0,0
t0      !byte 0,0
elapsed !byte 0,0

m_title   !pet 147,"blob install (no 4k installer)",13,0
m_inst    !pet "installed",13,0
m_blocks  !pet "blocks=$",0
m_jiffies !pet "  jiffies=$",0
m_cksum   !pet "  cksum=$",0
m_fail    !pet "open failed",13,0

tracks
	!fill 21, 17
	!fill 19, 18
	!byte $ff
sectors
	!byte 0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20
	!byte 0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18
	!byte 0

drive
	!binary "t41_nocr.bin"
drivelen = * - drive
resident
	!binary "resident_cd00.bin"
