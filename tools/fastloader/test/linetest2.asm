; linetest2.asm - reverse direction: C64 pulls a line, drive samples $1800.
; Drive code waits ~50ms (so the kernal has finished with the bus), samples
; $1800 into $0520, and returns. The C64 holds the line low across that window.
!cpu 6510
!to "linetest2.prg", cbm

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

	lda #$00		; nothing pulled
	sta pull_mask
	lda #<m_none
	ldy #>m_none
	jsr print_str
	jsr one_test

	lda #$10		; C64 CLK OUT
	sta pull_mask
	lda #<m_clk
	ldy #>m_clk
	jsr print_str
	jsr one_test

	lda #$20		; C64 DATA OUT
	sta pull_mask
	lda #<m_data
	ldy #>m_data
	jsr print_str
	jsr one_test

	lda #15
	jsr kclose
	jsr kclrchn
	rts

one_test
	ldx #15			; upload sampler
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

	ldx #15			; start it
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

	lda $dd00		; pull the line and hold it across the sample
	ora pull_mask
	sta $dd00
	ldx #$80
.o	ldy #$ff
.i	dey
	bne .i
	dex
	bne .o
	lda $dd00
	and #$cf
	sta $dd00

	lda #$20		; M-R $0520
	ldx #5
	ldy #1
	jsr mem_read
	lda #13
	jmp chrout

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
	jmp kclrchn

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

pull_mask !byte 0
ytmp      !byte 0

mw_cmd !text "M-W"
	!byte $00,$05,17
	!byte $a2,$40			; ldx #$40   (delay ~50ms)
	!byte $a0,$ff			; ldy #$ff
	!byte $88			; dey
	!byte $d0,$fd			; bne -3
	!byte $ca			; dex
	!byte $d0,$f8			; bne -8
	!byte $ad,$00,$18		; lda $1800
	!byte $8d,$20,$05		; sta $0520
	!byte $60			; rts
mw_len = * - mw_cmd

me_cmd !text "M-E"
	!byte $00,$05
me_len = * - me_cmd

mr_cmd !text "M-R"
mr_lo  !byte 0
mr_hi  !byte 0
mr_cnt !byte 0
mr_len = * - mr_cmd

m_title !pet 147,"reverse line test ($1800 seen by drive)",13,0
m_none  !pet "c64 pulls nothing: $",0
m_clk   !pet "c64 pulls CLK    : $",0
m_data  !pet "c64 pulls DATA   : $",0
