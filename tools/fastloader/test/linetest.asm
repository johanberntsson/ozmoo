; linetest.asm - verify IEC line bit positions empirically instead of trusting
; a table. Drive code holds one line low for ~100ms; the C64 samples $dd00
; throughout and reports which bits changed.
!cpu 6510
!to "linetest.prg", cbm

setnam = $ffbd
setlfs = $ffba
kopen  = $ffc0
kchkout= $ffc9
kclose = $ffc3
kclrchn= $ffcc
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

	lda #0
	jsr setnam
	lda #15
	ldx #device
	ldy #15
	jsr setlfs
	jsr kopen

	; --- test DATA ($1800 bit 1) -----------------------------------------
	lda #$02
	sta drv_bit
	lda #<m_data
	ldy #>m_data
	jsr print_str
	jsr run_drive_test

	; --- test CLK ($1800 bit 3) ------------------------------------------
	lda #$08
	sta drv_bit
	lda #<m_clk
	ldy #>m_clk
	jsr print_str
	jsr run_drive_test

	lda #15
	jsr kclose
	jsr kclrchn
	rts

; upload the hold-line-low routine with the current mask, execute, and sample
run_drive_test
	lda drv_bit
	sta drv_code_set		; ora #mask
	eor #$ff
	sta drv_code_clr		; and #~mask

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

	; sample $dd00 for roughly 200 ms
	lda #$ff
	sta and_acc
	lda #$00
	sta or_acc
	ldx #$c0
.outer	ldy #$ff
.inner	lda $dd00
	ora or_acc
	sta or_acc
	lda $dd00
	and and_acc
	sta and_acc
	dey
	bne .inner
	dex
	bne .outer

	lda #<m_or
	ldy #>m_or
	jsr print_str
	lda or_acc
	jsr print_hex
	lda #<m_and
	ldy #>m_and
	jsr print_str
	lda and_acc
	jsr print_hex
	lda #<m_chg
	ldy #>m_chg
	jsr print_str
	lda or_acc
	eor and_acc
	jsr print_hex
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
.nyb	cmp #10
	bcc +
	adc #6
+	adc #$30
	jmp chrout

drv_bit !byte 0
or_acc  !byte 0
and_acc !byte 0

; drive routine: pull line low, delay ~100ms, release, rts
mw_cmd !text "M-W"
	!byte $00,$05,27
	!byte $ad,$00,$18		; lda $1800
drv_code_set = * + 1
	!byte $09,$02			; ora #mask
	!byte $8d,$00,$18		; sta $1800
	!byte $a2,$50			; ldx #$50
	!byte $a0,$ff			; ldy #$ff
	!byte $88			; dey
	!byte $d0,$fd			; bne -3
	!byte $ca			; dex
	!byte $d0,$f8			; bne -8
	!byte $ad,$00,$18		; lda $1800
drv_code_clr = * + 1
	!byte $29,$fd			; and #~mask
	!byte $8d,$00,$18		; sta $1800
	!byte $60			; rts
mw_len = * - mw_cmd

me_cmd !text "M-E"
	!byte $00,$05
me_len = * - me_cmd

m_title !pet 147,"iec line mapping test",13,0
m_data  !pet "drive pulls DATA: ",0
m_clk   !pet "drive pulls CLK : ",0
m_or    !pet "or=$",0
m_and   !pet " and=$",0
m_chg   !pet " changed=$",0
