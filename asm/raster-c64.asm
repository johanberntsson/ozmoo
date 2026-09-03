; Raster interrupt for C64, testing dividing the screen into three fields:
; a status line, a hires picture, and the text window

!zone rastersplit {

.raster_row0 = 51
.first_row = 2
.last_row = 12

.raster_top = .raster_row0 + .first_row * 8
.raster_bottom = .raster_row0 + (.last_row + 1) * 8

.col_gfx = 0
.col_text = 1

.old_irq !byte 0, 0

;--------------------
; Install the raster IRQ.  Call once, after loading is done.
raster_init
	sei
	lda #$7f
	sta $dc0d
	lda $dc0d
	lda $0314 ; save the old vector
	sta .old_irq
	lda $0315
	sta .old_irq + 1
	lda #<.irq_top
	sta $0314
	lda #>.irq_top
	sta $0315
	lda $d011
	and #$7f
	sta $d011
	lda #.raster_top - 1
	sta $d012
	lda #$01
	sta $d019; acknowledge pending IRQ
	sta $d01a
	cli
	rts

raster_off
	sei
	lda #0
	sta $d01a ; disable raster
	lda #$01
	sta $d019
	lda .old_irq
	sta $0314
	lda .old_irq + 1
	sta $0315
	lda #$81
	sta $dc0d; re-enable CIA #1 timer IRQ
	lda $dc0d
	cli
	rts

!macro wait_for_raster .line {
-	bit $d011
	bmi +           ; raster >= 256: far too late already
	lda $d012
	cmp #.line
	bcc -
+
}

.irq_top
	+wait_for_raster .raster_top
	lda #.col_gfx
	sta $d020
	lda #<.irq_bottom
	sta $0314
	lda #>.irq_bottom
	sta $0315
	lda #.raster_bottom - 1
	sta $d012
	lda #$01
	sta $d019
	pla             ; restore Y, X, A and return
	tay
	pla
	tax
	pla
	rti

.irq_bottom
	+wait_for_raster .raster_bottom
	lda #.col_text
	sta $d020
	lda #<.irq_top
	sta $0314
	lda #>.irq_top
	sta $0315
	lda #.raster_top - 1
	sta $d012
	lda #$01
	sta $d019
	jmp (.old_irq)

} ; zone rastersplit
