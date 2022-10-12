!zone smoothscroll {

; When 1, smooth scrolling is active.
; Call smoothscroll_off and smoothscroll_on to change it.
smoothscrolling	!byte 0

; how many top lines to protect
.reserve = window_start_row + 1

;-------------------
; storage for internal "variables"
.smoothmode !byte 0     ; 1 = enabled
.init_done !byte 0
.screen_width_half !byte 0
.vicmode !byte $00      ; original value of VIC mode-bits from $d011
.filled  !byte $00      ; temporary storage for VIC idle-mode value
.orgscrl !byte $00      ; original fine-scroll value
.shifted !byte $00      ; count of all line shifts on the screen so far
.fld     !byte $00      ; raster lines to move text down during the frame

; table of screen row address offsets, 2 bytes per entry (lo, hi)
.rowoffset	!fill SCREEN_HEIGHT * 2, 0

;-------------------
; Initialization (called automatically when smoothscroll is first enabled)
.init
	lda s_screen_width
	lsr
	sta .screen_width_half

	; build the .rowoffset table
	ldx #$00
-	inx
	inx
	lda .rowoffset-2,x      ; previous lb
	clc
	adc s_screen_width
	sta .rowoffset,x        ; lb
	lda .rowoffset-1,x      ; previous hb
	adc #0
	sta .rowoffset+1,x      ; hb
	txa
	lsr
	cmp s_screen_height_minus_one
	bne -
	inc .init_done
	rts

;-------------------
; Enable/disable smooth scrolling
toggle_smoothscroll
	lda .smoothmode
	eor #$01
	sta .smoothmode
	sta smoothscrolling
	beq ++

	; Enable
	lda .init_done
	bne +
	jsr .init
+	jmp .enable_irq

++	; Disable
	; wait for in-progress smooth scroll
-	lda .fld
	bne -

	sei
	
	; disable raster interrupt
	lda $d01a
	and #$fe
	sta $d01a

	; enable CIA#1 timer A IRQ (keyboard)
	lda #$81
	sta $dc0d

	; restore original IRQ vector
	lda .vector + 1
	sta $0314
	lda .vector + 2
	sta $0315

	cli
	rts

;-------------------
; Wait for any in-progress smooth-scrolling to complete.
wait_smoothscroll
	pha
	lda smoothscrolling
	beq +++
-	lda .fld
	bne -
+++	pla
	rts

;-------------------
; Activate smooth scrolling, if enabled
smoothscroll_on
	pha
	lda .smoothmode
	beq +++
	lda smoothscrolling
	bne +++
	inc smoothscrolling
+++	pla
	rts

;-------------------
; Deactivate smooth scrolling
smoothscroll_off
	pha
	lda smoothscrolling
	beq +++

	; wait for in-progress smooth scroll
-	lda .fld
	bne -

	dec smoothscrolling

	; reset scroll position just in case it's wrong
	lda .orgscrl
	ora .vicmode
	sta $d011

+++	pla
	rts

;-------------------
disable_smoothscroll
	pha
	lda .smoothmode
	beq +++
	jsr toggle_smoothscroll
+++	pla
	rts

;-------------------
enable_smoothscroll
	pha
	lda .smoothmode
	bne +++
	jsr toggle_smoothscroll
+++	pla
	rts

;-------------------
; Scroll the screen by one text line.
smoothscroll
	; The loop addresses are stale and must be reinitialized.
	ldy #>SCREEN_ADDRESS
	sty .chrdst + 2
	sty .chrsrc + 2
	sty .chrdst + 8
	sty .chrsrc + 8
	ldy #>COLOUR_ADDRESS
	sty .clrdst + 2
	sty .clrsrc + 2
	sty .clrdst + 8
	sty .clrsrc + 8

	lda .reserve
	asl
	tax
	lda .rowoffset,x
	sta .chrdst + 1
	sta .clrdst + 1
	clc
	adc .screen_width_half
	sta .chrdst + 7
	sta .clrdst + 7
	adc .screen_width_half
	sta .chrsrc + 1
	sta .clrsrc + 1
	adc .screen_width_half
	sta .chrsrc + 7
	sta .clrsrc + 7

	; wait for in-progress smooth scroll
-	lda .fld
	bne -
	lda smoothscrolling
	beq ++
	; wait for raster to pass the reserved area
	lda .reserve
	asl
	asl
	asl
	adc #51
-	cmp $d012
	bne -
	; skip the mid-screen interrupt(s)
	lda #0
	sta $d012

	; set up smooth scroll offset
	lda #7
	sta .fld
++
	; move screen data (jump-scroll)
	lda s_screen_height_minus_one
	sec
	sbc .reserve
	tax
.dorows ldy .screen_width_half
	dey
.docols
.chrsrc lda SCREEN_ADDRESS,y
.chrdst sta SCREEN_ADDRESS,y
	lda SCREEN_ADDRESS,y
	sta SCREEN_ADDRESS,y
.clrsrc lda COLOUR_ADDRESS,y
.clrdst sta COLOUR_ADDRESS,y
	lda COLOUR_ADDRESS,y
	sta COLOUR_ADDRESS,y
	dey
	bpl .docols

	; advance dst & src addresses
	ldy #6
.loop   lda .chrsrc+1,y
	sta .chrdst+1,y
	sta .clrdst+1,y
	clc
	adc s_screen_width
	sta .chrsrc+1,y
	sta .clrsrc+1,y
	lda .chrsrc+2,y
	sta .chrdst+2,y
	lda .clrsrc+2,y
	sta .clrdst+2,y
	bcc .nocary
	adc #0
	sta .clrsrc+2,y
	lda .chrsrc+2,y
	adc #1
	sta .chrsrc+2,y
.nocary tya
	sec
	sbc #6
	tay
	bpl .loop
	dex
	bne .dorows

	; clear bottom row
	lda .chrdst + 2
	sta .clear + 2
	lda .chrdst + 1
	sta .clear + 1
	lda #$20 ; space
	ldy s_screen_width_minus_one
.clear  sta $0000,y
	dey
	bpl .clear
	rts

;-------------------
; Set up and enable the raster interrupt.
.enable_irq
	sei

	; Wait until off-screen to avoid a brief visual glitch.
-	lda $d012
	bne -

	lda $d01a       ; enable raster interrupts
	ora #$01
	sta $d01a

	lda #$7f
	sta $dc0d       ; disable CIA#1 interrupts

	lda $d011       ; trigger at top of screen
	and #$7f
	sta $d011
	and #$f8        ; save vic mode
	sta .vicmode
	lda #$00
	sta $d012

	lda $d011       ; save original finescroll
	and #$07
	sta .orgscrl

	lda $0315
	cmp #>.vidirq
	beq .skip

	lda $0314       ; save existing interrupt vector
	sta .vector + 1
	lda $0315
	sta .vector + 2

	lda #<.vidirq   ; change the interrupt vector
	sta $0314
	lda #>.vidirq
	sta $0315

.skip   cli
	rts

;-------------------
; Raster interrupt routine
.vidirq
	; we have 19-27 cycles until raster line advances
	; 8 cycles
	lda $d019       ; triggered by raster position?
	and #$01
	beq .vector

	; 9 cycles
	ldx $d012
	cpx #246
	bcc +
	jmp .fillbottom
+
	; 5 cycles
	; An extra do-nothing interrupt mid-screen allows more closely
	; matching (on average) the 60/sec average kernal interrupt
	; schedule, for games which use the clock.
	cpx #150
	bcc +
	ldx #0          ; next interrupt raster
	beq .setirq
+
	; 5 cycles (to .effect)
	cpx #48
	bcs .effect

.tos	lda .orgscrl    ; top of screen--set default scroll
	ora .vicmode
	sta $d011
	ldx #150        ; next interrupt raster if nothing to do

	lda .fld
	beq .setirq     ; nothing to do
	dec .fld
	beq .setirq     ; done--nothing to do
	lda #0
	sta .shifted

	; Calculate the raster line to interrupt.
	; The target line to modify is 48+Yscroll+reserve*8.
	; We need to interrupt 3 lines before that, in order to:
	; 1. use the remaining time in the interrupted line
	; 2. use some of the next line (#1 is not enough time)
	; 3. wait for the start of the next line in order to avoid causing
	;    visual artifacts.
	; The modification finally takes effect on the next line.
	lda .reserve
	asl
	asl
	asl
	adc #45
	adc .orgscrl
	tax
.setirq
	stx $d012
	lda #$01	; unlatch raster IRQ flag
	sta $d019
	lda #$7f
	sta $dc0d       ; disable CIA#1 IRQ (in case it's been re-enabled)

	lda $dc0d       ; need a kernal interrupt?
	beq .return
.vector jmp $ea31

.effect
	; 8 cycles
	ldy .fld
	; The regular TOS interrupt can get delayed to an unexpected time
	; during disk I/O, so check for this and avoid doing anything..
	beq .reset
	iny

	; 14 cycles
	lda .filler
	sta .filled
	lda #$00
	sta .filler

	; 4 cycles
	ldx $d012

	; 8 cycles
.next   txa
	and #$07        ; prevent vic badline
	ora .vicmode

-	cpx $d012       ; wait for next line
	beq -

	; 4 cycles
	sta $d011

	; 11 cycles
	inx
	cpx #$f7        ; f7 is last possible badline
	bcs +
	dey
	bne .next

	; 14 cycles
+	inx	        ; set up badline condition
	txa
	and #$07
	ora .vicmode
	sta $d011

	; 22 cycles
	lda .shifted
	clc
	adc .fld
	bcc +
	lda #$f0
+	sta .shifted

	; 8 cycles
	lda .filled     ; restore the fill value
	sta .filler

.reset  lda #246
.nextirq
	sta $d012

	lda #$01        ; unlatch raster IRQ flag
	sta $d019

.return	pla             ; restore Y, X, A
	tay
	pla
	tax
	pla
	rti

.fillbottom
	; Prevent garbage in the "gap" at the bottom of the
	; screen which exists at certain scroll positions.
	ldx .filler
	lda #$00
	sta .filler

	lda #250
-	cmp $d012
	bcs -

	stx .filler
	lda #0
	jmp .nextirq

.filler = SCREEN_ADDRESS + $3bff    ; =$3fff
} ; zone smoothscroll

