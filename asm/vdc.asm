; VDC info
; https://en.wikipedia.org/wiki/MOS_Technology_8563
; http://john.seikdel.net/vdcmadeeasy01.htm
; http://commodore128.mirkosoft.sk/vdc.html
; https://devdef.blogspot.com/2018/03/commodore-128-assembly-part-3-80-column.html

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
VDC_DSP_HI   = 12
VDC_DSP_LO   = 13
VDC_DATA_HI  = 18
VDC_DATA_LO  = 19
VDC_VSCROLL  = 24
VDC_HSCROLL  = 25
VDC_COLORS   = 26
VDC_CSET     = 28
VDC_COUNT    = 30
VDC_DATA     = 31

VDCSetSourceAddr
	; sets the current address of the VDC
	; input: a low, y = high
	pha
	tya
	ldx     #VDC_DATA_HI
	jsr     VDCWriteReg
	pla
	ldx     #VDC_DATA_LO
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

!ifdef VDC_INCLUDE_CLEARSCREEN {
VDCClearScreen
	lda     #0
	ldy     #0
	jsr     VDCSetSourceAddr
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

