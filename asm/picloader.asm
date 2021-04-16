; !to "picload.prg", cbm

!ifdef TARGET_MEGA65 {
	TARGET_ASSIGNED = 1
	* = $801
}
!ifdef TARGET_PLUS4 {
	TARGET_PLUS4_OR_C128 = 1
	TARGET_ASSIGNED = 1
	* = $1001
	bitmap_source = loader_pic_start + $800
	bitmap_target = $c000
	bitmap_end_highbyte = $e0
	screen_source = loader_pic_start
	screen_target = $0800
	colour_source = loader_pic_start + $400
	colour_target = $0c00
	loader_start  = $332
	character_colour = $53b
}
!ifdef TARGET_C64 {
	TARGET_ASSIGNED = 1
}
!ifdef TARGET_C128 {
	TARGET_PLUS4_OR_C128 = 1
	TARGET_ASSIGNED = 1
	* = $1c01
}

!ifndef TARGET_ASSIGNED {
	; No target given. C64 is the default target
	TARGET_C64 = 1
}

!ifdef TARGET_C64 {
	* = $801
	bitmap_source = loader_pic_start
	bitmap_target = $e000
	bitmap_end_highbyte = $00
	screen_source = loader_pic_start + 8000
	screen_target = $cc00
	colour_source = loader_pic_start + 9000
	colour_target = $d800
	loader_start  = $334
	character_colour = 646
}


interrupt_vector = $314


!ifdef TARGET_C128 {
!source "constants-c128.asm"
} else {
!source "constants.asm"
}

!ifdef TARGET_C64 {
; Basic line: "1 sys2061"
!byte $0b, $08, $01,$00, $9e, $32, $30, $36, $31, 0, 0, 0
} 
!ifdef TARGET_PLUS4 {
; Basic line: "1 sys4109"
!byte $0b, $08, $01,$00, $9e, $34, $31, $30, $39, 0, 0, 0
} 

!zone picloader {

; Copy background colour
!ifdef TARGET_C64 {	
	ldx loader_pic_start + 10000
	stx reg_bordercolour
	stx reg_backgroundcolour
}
!ifdef TARGET_PLUS4 {
	lda loader_pic_start + $3fe
	lsr
	lsr
	lsr
	lsr
	sta .temp
	lda loader_pic_start + $3fe
	asl
	asl
	asl
	asl
	ora .temp
	sta $ff16
	lda loader_pic_start + $3ff
	lsr
	lsr
	lsr
	lsr
	sta .temp
	lda loader_pic_start + $3ff
	asl
	asl
	asl
	asl
	ora .temp
	sta reg_bordercolour
	sta reg_backgroundcolour
}
; Copy bitmap data

	ldx #0
.copy_bitmap
	lda bitmap_source,x
	sta bitmap_target,x
	inx
	bne .copy_bitmap
	inc .copy_bitmap + 2
	inc .copy_bitmap + 5
	lda .copy_bitmap + 5
	cmp #bitmap_end_highbyte
	bne .copy_bitmap ; Copies to $e000-$ffff, stops when target address is $0000
	
; Copy screen RAM and colour RAM

.copy_screen
	lda screen_source,x
	sta screen_target,x
	lda screen_source + 250,x
	sta screen_target + 250,x
	lda screen_source + 500,x
	sta screen_target + 500,x
	lda screen_source + 750,x
	sta screen_target + 750,x
	lda colour_source,x
	sta colour_target,x
	lda colour_source + 250,x
	sta colour_target + 250,x
	lda colour_source + 500,x
	sta colour_target + 500,x
	lda colour_source + 750,x
	sta colour_target + 750,x
	inx
	cpx #250
	bcc .copy_screen


; Show image

!ifdef TARGET_C64 {

	; Set bank
	lda $dd00
	and #%11111100
	sta $dd00
	
	lda $d018
	; Set bitmap address to $e000
	ora #%00001000
	; Set screen address to $cc00
	and #%00001111
	ora #%00110000
	sta $d018

; Set graphics mode

	lda $d011
	and #%10011111
	ora #%00100000
	sta $d011
	lda $d016
	and #%11101111
	ora #%00010000
	sta $d016
}
!ifdef TARGET_PLUS4 {

;	sta $ff3f

	LDA #$3B
	STA $FF06
	
; Set bitmap address to $c000
	lda #$30
	sta $ff12
	
; Set luminance/colour address to $e000/$e400
;	lda #$e0
;	sta $ff14

; Set graphics mode

	lda $ff07
	and #$40
	ora #%00011000
	sta $ff07

}

; Wait for <SPACE>
; .getchar
	; jsr kernal_getchar
	; cmp #32
	; bne .getchar

; Copy loader

	ldx #.end_of_loader - .loader - 1
-	lda .loader,x
	sta loader_start,x
	dex
	bpl -

!ifdef FLICKER {
; Copy background colour to loader code
!ifdef TARGET_C64 {
	lda loader_pic_start + 10000
	and #15 ; Make sure we don't have any noise in the high nybble
	tax
	lda .alt_col,x
	sta .load_alt_col + 1
}
!ifdef TARGET_PLUS4 {
	lda loader_pic_start + $3fe
	eor #$ff
	sta .load_alt_col + 1
}
	
; Setup interrupt
	sei
	lda interrupt_vector
	sta .jmp_kernal_interrupt + 1
	lda interrupt_vector + 1
	sta .jmp_kernal_interrupt + 2
	lda #<.interrupt
	sta interrupt_vector
	lda #>.interrupt
	sta interrupt_vector + 1
	cli
}
	
	jmp loader_start;

.loader
!pseudopc loader_start {
	lda #filename_length
	ldx #<.filename
	ldy #>.filename
	jsr kernal_setnam
	lda #1      ; file number
	ldx CURRENT_DEVICE ; Device#
	ldy #1      ; $01 means: load to address stored in file
	jsr kernal_setlfs
	lda #$00      ; $00 means: load to memory (not verify)
	jsr kernal_load
	lda #1 
	jsr kernal_close

!ifdef FLICKER {
; Clear interrupt

	sei
	lda .jmp_kernal_interrupt + 1
	sta interrupt_vector
	lda .jmp_kernal_interrupt + 2
	sta interrupt_vector + 1
	cli
}
; Hide image and set default graphics bank


!ifdef TARGET_C64 {
; Set graphics mode

	lda $d011
	and #%10011111
	sta $d011
	lda $d016
	and #%11101111
	sta $d016

	; Set bank
	lda $dd00
	and #%11111100
	ora #%00000011
	sta $dd00

	; Set screen address to $0400 and charmem to $d000 
	lda #%00010100
	sta $d018
}
!ifdef TARGET_PLUS4 {
;	sta $ff3e
	lda #$1B
	sta $FF06

	lda $ff07
	and #$40
	ora #%00001000
	sta $ff07
}

	; Clear screen
	lda #147
	jsr kernal_printchar
	
	; Add keys to run program into keyboard buffer
	lda #$52 ; r
	sta keyboard_buff
	lda #$d5 ; U
	sta keyboard_buff + 1
	lda #13 ;  Enter
	sta keyboard_buff + 2
	lda #3  ; 3 chars are now in keyboard buffer
	sta keyboard_buff_len
	
	; Set text colour to background colour
	lda reg_backgroundcolour
	sta character_colour

	rts

!ifdef FLICKER {
.interrupt
	ldx reg_bordercolour
.load_alt_col
	lda #0
	sta reg_bordercolour
	nop
	nop
	stx reg_bordercolour
.jmp_kernal_interrupt
	jmp $ea31
}
	
.filename
!source "file_name.asm"
filename_length = * - .filename
}
.end_of_loader

.temp !byte 0

!ifdef FLICKER {
.alt_col
	!byte 1, 0, 10, 14, 14, 13, 14, 0, 9, 8, 2, 12, 15, 5, 6, 12
}

} ; zone picloader

loader_pic_start
	
; !binary "loaderpic.kla",,2 
