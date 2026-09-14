; k_diag.asm - is the KERNAL read path returning bad data, and does it say so?
; Reads track 17 in gap-4 order, checks each block against its known checksum,
; records ST (READST) per block, and prints the drive's error channel at the end.
!cpu 6510
!to "k_diag.prg", cbm

setnam = $ffbd
setlfs = $ffba
kopen  = $ffc0
kchkin = $ffc6
kchrin = $ffcf
kclose = $ffc3
kclrchn= $ffcc
readst = $ffb7
chrout = $ffd2
device = 8
zp     = $fb

* = $0801
	!byte $0c,$08,$0a,$00,$9e,$32,$30,$36,$31,$00,$00,$00

start
	jsr $ffe7
	lda #<m_title
	ldy #>m_title
	jsr print_str

	lda #$ff
	sta first_bad
	lda #0
	sta st_acc
	sta idx
	sta nbad

.next
	ldx idx
	lda tracks,x
	bmi .done
	sta trk
	lda sectors,x
	sta sct
	jsr read_block

	jsr readst		; does the kernal admit anything went wrong?
	ora st_acc
	sta st_acc

	ldx sct			; compare against the known-good checksum
	lda blk_lo
	cmp cks_lo,x
	bne .bad
	lda blk_hi
	cmp cks_hi,x
	beq .ok
.bad
	inc nbad
	lda first_bad
	cmp #$ff
	bne .ok
	lda idx
	sta first_bad
	lda sct
	sta bad_sec
	lda blk_lo
	sta bad_lo
	lda blk_hi
	sta bad_hi
	jsr readst
	sta bad_st
.ok
	inc idx
	jmp .next

.done
	lda #<m_bad
	ldy #>m_bad
	jsr print_str
	lda nbad
	jsr print_hex
	lda #<m_first
	ldy #>m_first
	jsr print_str
	lda first_bad
	jsr print_hex
	lda #<m_sec
	ldy #>m_sec
	jsr print_str
	lda bad_sec
	jsr print_hex
	lda #<m_got
	ldy #>m_got
	jsr print_str
	lda bad_hi
	jsr print_hex
	lda bad_lo
	jsr print_hex
	lda #<m_want
	ldy #>m_want
	jsr print_str
	ldx bad_sec
	lda cks_hi,x
	jsr print_hex
	ldx bad_sec
	lda cks_lo,x
	jsr print_hex
	lda #<m_st
	ldy #>m_st
	jsr print_str
	lda bad_st
	jsr print_hex
	lda #<m_stacc
	ldy #>m_stacc
	jsr print_str
	lda st_acc
	jsr print_hex
	lda #13
	jsr chrout

	jsr drive_status
	rts

; ---- read one block the way Ozmoo does, checksum into blk_lo/blk_hi --------
read_block
	lda #0
	sta blk_lo
	sta blk_hi
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
	adc blk_lo
	sta blk_lo
	bcc +
	inc blk_hi
+	iny
	bne -
.err
	lda #15
	jsr kclose
	lda #2
	jsr kclose
	jmp kclrchn

; ---- print the drive's error channel ---------------------------------------
drive_status
	lda #<m_drv
	ldy #>m_drv
	jsr print_str
	lda #0
	jsr setnam
	lda #15
	ldx #device
	ldy #15
	jsr setlfs
	jsr kopen
	bcs .none
	ldx #15
	jsr kchkin
	ldy #0
-	jsr kchrin
	cmp #13
	beq +
	jsr chrout
	iny
	cpy #40
	bne -
+	lda #15
	jsr kclose
	jmp kclrchn
.none	rts

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
.nyb	cmp #10
	bcc +
	adc #6
+	adc #$30
	jmp chrout

trk      !byte 0
sct      !byte 0
tmpx     !byte 0
idx      !byte 0
nbad     !byte 0
first_bad !byte 0
bad_sec  !byte 0
bad_lo   !byte 0
bad_hi   !byte 0
bad_st   !byte 0
st_acc   !byte 0
blk_lo   !byte 0
blk_hi   !byte 0

n_hash   !text "#"
ucmd     !text "U1 2 0 "
ucmd_t   !text "00 "
ucmd_s   !text "00"
ucmd_len = * - ucmd

m_title !pet 147,"kernal read path diagnostic",13,0
m_bad   !pet "bad blocks=$",0
m_first !pet "  first=$",0
m_sec   !pet " sec=$",0
m_got   !pet 13,"got=$",0
m_want  !pet " want=$",0
m_st    !pet " st=$",0
m_stacc !pet " stacc=$",0
m_drv   !pet 13,"drive: ",0

!source "cks_table.inc"

tracks
	!fill 21, 17
	!byte $ff
sectors
	!byte 0,4,8,12,16,20,3,7,11,15,19,2,6,10,14,18,1,5,9,13,17
	!byte 0
