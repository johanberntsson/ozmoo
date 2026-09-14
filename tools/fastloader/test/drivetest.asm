; drivetest.asm - can we upload and EXECUTE 6502 code inside the drive?
; M-W four bytes, M-R them back, then M-W a routine, M-E it, and M-R its result.
!cpu 6510
!to "drivetest.prg", cbm

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

* = $0801
	!byte $0c,$08,$0a,$00,$9e,$32,$30,$36,$31,$00,$00,$00

start
	jsr $ffe7			; CLALL
	lda #<m_title
	ldy #>m_title
	jsr print_str

	lda #0				; open 15,8,15
	jsr setnam
	lda #15
	ldx #device
	ldy #15
	jsr setlfs
	jsr kopen
	bcs .fail

	; --- 1. M-W four bytes to $0500 --------------------------------------
	ldx #15
	jsr kchkout
	ldy #0
-	lda mw_cmd,y
	jsr chrout
	iny
	cpy #mw_len
	bne -
	lda #13
	jsr chrout
	jsr kclrchn

	; --- 2. M-R them back ------------------------------------------------
	lda #<m_wrote
	ldy #>m_wrote
	jsr print_str
	lda #0			; $0500
	ldx #5
	ldy #4
	jsr mem_read

	; --- 3. M-W a routine, M-E it ----------------------------------------
	ldx #15
	jsr kchkout
	ldy #0
-	lda me_cmd,y
	jsr chrout
	iny
	cpy #me_len
	bne -
	lda #13
	jsr chrout
	jsr kclrchn

	ldx #15			; M-E $0510
	jsr kchkout
	ldy #0
-	lda exec_cmd,y
	jsr chrout
	iny
	cpy #exec_len
	bne -
	lda #13
	jsr chrout
	jsr kclrchn

	; --- 4. M-R the byte the drive code wrote ----------------------------
	lda #<m_exec
	ldy #>m_exec
	jsr print_str
	lda #$20		; $0520
	ldx #5
	ldy #1
	jsr mem_read

	lda #15
	jsr kclose
	jsr kclrchn
	rts
.fail
	lda #<m_fail
	ldy #>m_fail
	jmp print_str

; A=lo, X=hi, Y=count : send M-R and print the bytes returned
mem_read
	sta mr_lo
	stx mr_hi
	sty mr_cnt
	ldx #15
	jsr kchkout
	ldy #0
-	lda mr_cmd,y
	jsr chrout
	iny
	cpy #mr_len
	bne -
	lda #13
	jsr chrout
	jsr kclrchn

	ldx #15
	jsr kchkin
	ldy #0
-	jsr kchrin
	sty ytmp
	jsr print_hex
	ldy ytmp
	iny
	cpy mr_cnt
	bne -
	jsr kclrchn
	lda #13
	jmp chrout

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
	adc #6
+	adc #$30
	jmp chrout

ytmp   !byte 0

mw_cmd !text "M-W"
	!byte $00,$05,$04		; $0500, 4 bytes
	!byte $de,$ad,$be,$ef
mw_len = * - mw_cmd

; drive code at $0510:  lda #$a5 : sta $0520 : rts
me_cmd !text "M-W"
	!byte $10,$05,$06
	!byte $a9,$a5,$8d,$20,$05,$60
me_len = * - me_cmd

exec_cmd !text "M-E"
	!byte $10,$05
exec_len = * - exec_cmd

mr_cmd !text "M-R"
mr_lo  !byte 0
mr_hi  !byte 0
mr_cnt !byte 0
mr_len = * - mr_cmd

m_title !pet 147,"drive code upload test",13,0
m_wrote !pet "m-r of m-w bytes (want deadbeef): $",0
m_exec  !pet "m-e result (want a5): $",0
m_fail  !pet "open failed",13,0
