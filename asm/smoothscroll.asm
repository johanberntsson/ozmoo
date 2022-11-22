!zone smoothscroll {

; When $ff, smooth scrolling is active (0 = inactive).
; Call smoothscroll_off and smoothscroll_on to change it.
smoothscrolling !byte 0

!ifndef TARGET_C128 {
; When $ff, we're in a critical timing phase and shouldn't do potentially
; expensive things such as calling the kernal's IRQ handler.
smoothcritical !byte 0
}

; The last addressable byte of the VIC-II's 16KB bank is used as the
; pixel data value in idle state.
.filler = SCREEN_ADDRESS & $c000 | $3fff

; how many top lines to protect (address containing the status area size)
.reserve = window_start_row + 1

;--------------------
; key raster positions
.raster_top =  48   ; base top of screen (first text raster when Yscroll=0)
.raster_bot !byte 0 ; earliest interrupt line for bottom-of-screen handling
.raster_border !byte 0 ; first raster line of bottom border (computed)

;--------------------
; storage for internal variables
.smoothmode !byte 0     ; $ff = smooth-scrolling enabled (0 = disabled)
.vicmode !byte $00      ; original value of VIC-II mode-bits from $d011
.orgscrl !byte $00      ; original fine-scroll value
.fld     !byte $ff      ; lines to shift text down during the frame, -1
.irqline !byte 0        ; current raster IRQ line when scrolling
!ifdef TARGET_C128 {
.need_kernal_irq !byte 0 ; $ff = IRQ handler should perform kernal actions
}

;--------------------
; Wait for any in-progress smooth-scrolling to complete.
; This should be called before any activity which could disable
; interrupts, to avoid irregular screen movement.
; If printing to the screen (and thus scrolling) might occur while
; interrupts are disabled, use smoothscroll_off instead.
wait_smoothscroll
-	bit .fld
	bpl -
	rts

!ifdef TARGET_C128 {
;--------------------
; Quick routines can call this before disabling interrupts to wait until
; there is no risk of disrupting an in-progress smooth-scroll.  This is
; better than calling wait_smoothscroll if it is known that interrupts will
; be disabled only for a very short time.
wait_smoothscroll_min
	bit .fld
	bmi +++         ; not scrolling
	bit $d011
	bmi +++         ; raster > 255
	pha
	txa

	ldx $d012
	inx
	beq ++          ; raster = 255
	cpx .irqline
	bcc ++          ; raster < target line - 1

	; wait until raster is past the target line
	ldx .irqline
-	cpx $d012
	bcs -
++
	tax
	pla
+++	rts
}

;--------------------
; Activate smooth scrolling, if enabled.
; Call this to turn on smooth scrolling again after calling
; smoothscroll_off.
smoothscroll_on
	bit .smoothmode
	bpl +
	dec smoothscrolling
+	rts

;--------------------
; Deactivate smooth scrolling.
; Call this to temporarily turn off smooth scrolling, usually in
; preparation to disable interrupts while still keeping it safe to
; print to the screen.
; If printing will not occur, wait_smoothscroll can be used instead.
smoothscroll_off
	bit smoothscrolling
	bpl +
	jsr wait_smoothscroll
	inc smoothscrolling
+	rts

;--------------------
; Put the "smooth" in scrolling.
; This should be called just before moving screen data.
smoothscroll
	jsr wait_smoothscroll

!ifdef TARGET_C128 {
	; interrupt at bottom-of-screen for the speedup
	ldx .raster_border
	; interrupting there will decrement fld earlier, so compensate
	ldy #7 ; smooth-scroll offset
} else {
	ldx #0 ; skip interrupts until the next frame
	ldy #6 ; smooth-scroll offset (7 - 1)
}

	; A SuperCPU in fast mode can easily move all the data
	; while off-screen.  ($D0B8 bit 6 indicates 1MHz vs. fast mode.)
	; http://www.elysium.filety.pl/tools/supercpu/superprog.html
	; wait_smoothscroll will typically release at .raster_border, with
	; the next frame needing to be drawn before scrolling again.  So
	; wait for .raster_bot (which is higher) in order to let that happen.
	lda .raster_bot
	bit $d0b8
	bvc +

	; wait for raster to pass the reserved area
	lda .reserve
	asl
	asl
	asl
	adc #.raster_top + 1
	adc .orgscrl
+
-	cmp $d012
	bne -
	bit $d011
	bmi -

	stx $d012
!ifndef TARGET_C128 {
	dex
	stx smoothcritical
}

	sty .fld
	rts

;--------------------
; This should be used after moving screen data.
!macro done_smoothscroll {
!ifndef TARGET_C128 {
	lda #0
	sta smoothcritical
}
}

;--------------------
; Enable/disable smooth scrolling.
; Call this to switch the enabled state (at the user's request).
; (See smoothscroll_off for the program's own needs.)
toggle_smoothscroll
!ifdef TARGET_C128 {
	; only available in 40-column mode
	bit COLS_40_80
	bmi +++
}
	lda .smoothmode
	eor #$ff
	sta .smoothmode
	sta smoothscrolling
	bne +
	; Disable
	jmp wait_smoothscroll

+	; Enable
	lda .raster_border
	bne +++
	; Calculate the bottom border position.
	lda s_screen_height
	asl
	asl
	asl
	adc #.raster_top
	tax
	dex
!ifdef TARGET_C128 {
	; The 128 seems to take a little longer to process the interrupt.
	dex
}
	stx .raster_bot
	adc #3
	sta .raster_border

	sei

	lda #$7f
!ifdef TARGET_C64 {
	sta $dc0d       ; disable CIA#1 interrupts
}

	and $d011       ; clear raster interrupt MSB
	sta $d011
	and #$78        ; save vic mode
	sta .vicmode

	lda $d011       ; save original Yscroll
	and #$07
	sta .orgscrl

	lda $0314       ; save the original interrupt vector
	sta .vector + 1
	lda $0315
	sta .vector + 2

	lda #<.vidirq   ; change the interrupt vector
	sta $0314
	lda #>.vidirq
	sta $0315

	lda .raster_border ; set first IRQ for bottom of screen
	sta $d012

	lda $d01a       ; enable raster interrupts
	ora #$01
	sta $d01a

	cli
+++	rts

!ifdef TARGET_C128 {
;--------------------
; Revert to 1MHz speed just before the text area.
.slowdown
	; 6 (3) cycles
	lda #$00
	sta reg_2mhz

	; 12 cycles
	lda #<.vidirq   ; re-set the interrupt vector
	sta $0314
	lda #>.vidirq
	sta $0315

	; 6 cycles
	lda .reserve
	bne .setup
}

;--------------------
; Raster interrupt handler
.vidirq
	; We have 19-27 cycles until the raster line advances.
	; 8 cycles
	lda $d019       ; triggered by raster position?
	and #$01
!ifdef TARGET_C128 {
	; 2 cycles
	bne +
.vector
	jmp $fa65
+
} else {
	beq .stdirq
}

	; 15 cycles (to .shift_screen)
	ldx $d012
	cpx #.raster_top
	bcc .tos
	cpx .raster_bot
	bcc .shift_screen
.bos                    ; raster >= .raster_bot
	; Hide the idle-state gap at the bottom of the screen.
	; 10 cycles
	ldx .filler
	lda #$00
	sta .filler

	; 10 cycles
	ldy .raster_border
	dey
-	cpy $d012
	bcs -

!ifdef TARGET_C128 {
	; in the border now, so speed it up
	lda allow_2mhz_in_40_col
	sta reg_2mhz
	; C128 kernal interrupts are raster-based and once per frame, so
	; always perform one at bottom of screen.
	dec .need_kernal_irq
}

	stx .filler

	bit .fld
	bmi +
	dec .fld
+
	; Past the text area, so perform top-of-screen handling now.
.tos                    ; raster < .raster_top
	lda .orgscrl    ; top of screen--set default scroll
	ora .vicmode
	sta $d011

!ifdef TARGET_C128 {
	; slow it back down to draw the text again
	lda #<.slowdown
	sta $0314
	lda #>.slowdown
	sta $0315

	lda .reserve
	beq .setup

	; set IRQ for just above the text area
	lda #.raster_top - 1
	clc
	adc .orgscrl
	tax
	bne .setirq     ; always
}

.setup
	; Calculate the raster line to interrupt for scrolling update.
	; The target bad line to defer is reserve*8+48+Yscroll.
	; We need to interrupt 2 lines before that, in order to:
	; 1. [t-2] use the remaining time in the interrupted line
	; 2. [t-1] use some of the next line (#1 is not enough time)
	; 3. [t-1] set Yscroll to prevent the bad-line condition in t-0
	lda .reserve
	asl
	asl
	asl
	adc #.raster_top - 2
	adc .orgscrl
	sta .irqline    ; stash it for reference
	tax
!ifdef TARGET_C128 {
	; Special case: When reserve is zero we'll enter at .slowdown and
	; need a little more time for its actions.
	lda .reserve
	bne +
	dex
+
}
!ifdef TARGET_C64 {
	bit .fld
	bpl .setirq     ; scrolling in progress
	; Need a second IRQ in the frame for the clock, but a bit later
	; in order to avoid colliding with the wait-loop in smoothscroll.
	inx
	inx
	inx
}
.setirq
	stx $d012
	lda #$01        ; unlatch raster IRQ flag
	sta $d019
!ifdef TARGET_C64 {
	lda #$7f
	sta $dc0d       ; disable CIA#1 IRQ (in case it's been re-enabled)

	lda $dc0d       ; need a kernal interrupt?
	bne .stdirq
	lda .fld
	bne .return     ; once per scroll, make up the skipped IRQ
}
.stdirq
!ifdef TARGET_C128 {
	bit .need_kernal_irq
	bpl .return
	inc .need_kernal_irq
	jsr $c22c       ; flash VIC cursor, etc.
	jmp $fa6b       ; update jiffy clock, etc. and return from IRQ
} else {
	bit smoothcritical
	bmi .return
.vector
	jmp $ea31
}

.shift_screen
	; 6 cycles
	ldy .fld
	; Interrupts can get delayed to unexpected times during disk I/O,
	; so make sure we're really supposed to be scrolling.
	bmi .reset

	; 13 cycles
	; Hide the gap we're about to create.
	lda .filler
	pha
	lda #$00
	sta .filler

	; With a fast CPU (e.g. SuperCPU) we may have to wait for the
	; raster to reach where it needs to be.
	; 12 cycles
	ldx .irqline
	inx
-	cpx $d012
	bne -

	; 2 cycles
	dex

.next
	; 14 cycles
	txa
	and #$07        ; prevent vic bad-line
	ora .vicmode
	sta $d011
	inx

	; 4 cycles
	dey
	bmi +

-	cpx $d012       ; wait for next line
	beq -

	; 3 cycles
	bne .next ; always
+
	; 16 cycles
	inx             ; set up bad-line condition
	inx
	txa
	and #$07
	ora .vicmode
	sta $d011

-	cpx $d012       ; wait to reach the "bad" line
	bne -

	; 7 cycles
	pla             ; restore the fill value
	sta .filler

.reset
	; set up bottom-of-screen interrupt
	lda $d011
	and #$07
	cmp #$03
	bcc +
	lda #$03
	clc
+	adc .raster_bot
	tax
	bne .setirq ; always

.return
!ifdef TARGET_C128 {
	jmp $ff33
} else {
	pla             ; restore Y, X, A
	tay
	pla
	tax
	pla
	rti
}
} ; zone smoothscroll
