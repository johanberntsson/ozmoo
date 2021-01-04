; VDC info
; https://en.wikipedia.org/wiki/MOS_Technology_8563
; http://john.seikdel.net/vdcmadeeasy01.htm
; http://commodore128.mirkosoft.sk/vdc.html
; https://devdef.blogspot.com/2018/03/commodore-128-assembly-part-3-80-column.html
; http://www.oxyron.de/html/registers_vdc.html
; https://c-128.freeforums.net/thread/32/vdc-right-left-scrolling-demo

MMUCR =  $FF00
MMU_RAM0 =         %00111111  ; no roms, RAM0
MMU_RAM1 =         %01111111  ; no roms, RAM1
MMI_RAM0_KERNAL =  %00000110  ; int.function ROM, Kernal and IO, RAM0
MMU_RAM0_ALLROMS = %00000001 ; all roms, char ROM, RAM0
MMU_DEFAULT =      %00000000  ; all roms, RAM0. default setting.
MMU_48K =          %00001110  ; IO, kernal, RAM0. 48K RAM.

VDC_ADDR_REG = $D600                 ; VDC address
VDC_DATA_REG = $D601                 ; VDC data

; VDC registers
VDC_VDISP     = 6  ; $06
VDC_DSP_HI    = 12 ; $0c
VDC_DSP_LO    = 13 ; $0d
VDC_DATA_HI   = 18 ; $12
VDC_DATA_LO   = 19 ; $13
VDC_ATTR_HI   = 20 ; $14
VDC_ATTR_LO   = 21 ; $15
VDC_VSCROLL   = 24 ; $18
VDC_HSCROLL   = 25 ; $19
VDC_COLORS    = 26 ; $1a
VDC_CSET      = 28 ; $1c
VDC_COUNT     = 30 ; $1e
VDC_DATA      = 31 ; $1f
VDC_CPYSRC_HI = 32 ; $20
VDC_CPYSRC_LO = 33 ; $21

VDCInit
	; set the default VDC configuration
	; screen $0000 (reg 12,13)
	lda #$00  ; 7f
	ldx #VDC_DSP_HI
	jsr VDCWriteReg
	lda #$00
	ldx #VDC_DSP_LO
	jsr VDCWriteReg
	; attributes/colour $0800 (reg 20,21)
	lda #$08
	ldx #VDC_ATTR_HI
	jsr VDCWriteReg
	lda #$00
	ldx #VDC_ATTR_LO
	jsr VDCWriteReg
	; char mem
	lda #$2f
	ldx #VDC_CSET
	jsr VDCWriteReg
	; colours
	lda #$f0
	ldx #VDC_COLORS
	jsr VDCWriteReg
	; number of lines
	lda #$19
	ldx #VDC_VDISP
	jsr VDCWriteReg
	rts
	
VDCSetAddress
	; sets the current address of the VDC
	; input: a low, y = high
	pha
	tya
	ldx     #VDC_DATA_HI
	jsr     VDCWriteReg
	pla
	ldx     #VDC_DATA_LO
	bne     VDCWriteReg

VDCSetCopySourceAddress
	; sets the copy source address of the VDC
	; input: a low, y = high
	pha
	tya
	ldx     #VDC_CPYSRC_HI
	jsr     VDCWriteReg
	pla
	ldx     #VDC_CPYSRC_LO
	bne     VDCWriteReg

VDCReadByte
	; reads a byte from the current VDC address
	ldx     #VDC_DATA ; read data (byte)
VDCReadReg
	; reads from a VDC register
	stx     VDC_ADDR_REG
-   bit     VDC_ADDR_REG
	bpl     -
	lda     VDC_DATA_REG
	rts

VDCWriteByte
	; writes a byte (character) from the current VDC address
	ldx     #VDC_DATA ; write data (byte/character)
VDCWriteReg
	; reads to a VDC register
	stx     VDC_ADDR_REG
-   bit     VDC_ADDR_REG
	bpl     -
	sta     VDC_DATA_REG
	rts

VDCCopyFont
	; set VDC to start address
	; we are not using the first character set ($2000-$3000)
	lda #$00
	ldy #$30
	jsr VDCSetAddress
	; set pointer to start of data ($1800)
	lda #$00
	sta z_temp
	lda #$18
	sta z_temp + 1
	lda #$20
	; high byte of data end
	sta z_temp + 2  
	; start copying data
.loop
	ldy #0
-	lda (z_temp),y
	jsr VDCWriteByte
	iny
	cpy #8
	bne -
	lda #0     ; add 8 bytes as padding
-	jsr VDCWriteReg
	dey
	bne -
	clc
	lda z_temp
	adc #8
	sta z_temp
	bcc .loop
	inc z_temp + 1
	lda z_temp + 1
	cmp z_temp + 2  ; done all?
	bne .loop
	rts

!ifdef VDC_INCLUDE_CLEARSCREEN {
VDCClearScreen
	lda     #0
	ldy     #0
	jsr     VDCSetAddress
	lda     #0
	ldx     #VDC_VSCROLL   ; fill mode (blitter)
	jsr     VDCWriteReg
	lda     #32            ; space character
	jsr     VDCWriteByte   ; put first byte (fill value)
	ldy     #7             ; 7 times
	lda     #0             ; 256 bytes (since 80*25=7*256+208)
	ldx     #VDC_COUNT
-   jsr     VDCWriteReg
	dey
	bne     -
	lda     #208           ; the remainder
	jmp     VDCWriteReg
}

