; ---------------------------------------------------------------------------
; Ozmoo Apple II: KERNAL routines
;
; Every other target calls a CBM-style KERNAL for GETIN, RDTIM, LOAD/SAVE and
; the rest. The Apple II has none of that so this file exports it under
; the same names the shared code already calls:
;
;   kernal_getchar    a keypress, or 0 - the GETIN analogue, and the only
;                     thing on this machine that runs often enough to be used
;                     as a clock, so it is also where the jiffy count and the
;                     random seed come from
;   kernal_readtime   the software jiffy count, in RDTIM's a/x/y order
;   kernal_settime    set it
;
; ---------------------------------------------------------------------------

; How many passes through the poll below make a sixtieth of a second. The
; machine has no timer and no readable vertical blank, so the input loop is the
; clock. The timing was measured using tools/apple2-clock.rb
!ifndef A2_POLLS_PER_JIFFY {
A2_POLLS_PER_JIFFY = 128
}

; ---------------------------------------------------------------------------
; kernal_getchar: the ASCII of a key that has been pressed, or 0 if none has.
; Never blocks, exactly like GETIN, which is what every caller assumes.
;
; The Apple II keyboard is two soft switches: bit 7 of $C000 says a key is
; waiting and the low seven bits are its ASCII, and touching $C010 clears the
; strobe so the next key can arrive.
; ---------------------------------------------------------------------------
!zone kernal_getchar
kernal_getchar
	; A free running counter, sampled when a key is pressed: this is the
	; entropy source that replaces the C64's CIA and SID reads, and it works
	; for the same reason theirs does - what is unpredictable is when the
	; player presses the key, not the counter.
	inc a2_entropy
	bne +
	inc a2_entropy + 1
+

	; The clock. A 16 bit down counter, because a jiffy is more than 256 polls.
	lda a2_jiffy_sub
	bne .dec_low
	dec a2_jiffy_sub + 1
.dec_low
	dec a2_jiffy_sub
	lda a2_jiffy_sub
	ora a2_jiffy_sub + 1
	bne .no_tick
	lda #<A2_POLLS_PER_JIFFY
	sta a2_jiffy_sub
	lda #>A2_POLLS_PER_JIFFY
	sta a2_jiffy_sub + 1
	inc a2_jiffy
	bne .no_tick
	inc a2_jiffy + 1
	bne .no_tick
	inc a2_jiffy + 2
.no_tick

	lda KEYBOARD
	bpl .no_key
	sta KEYBOARD_STROBE
	and #$7f
	; Fold lower case up. A real II+ keyboard cannot send it at all, but a IIe
	; with SHIFT-LOCK off can, and the MEGA65's Apple II core does.
	cmp #$61
	bcc .no_fold
	cmp #$7b
	bcs .no_fold
	and #$df
.no_fold
	rts
.no_key
	lda #0
	rts

; ---------------------------------------------------------------------------
; kernal_readtime / kernal_settime: the jiffy count in a, x, y - low, middle,
; high, which is the order the C64's RDTIM hands it over in (A is $A2, the low
; byte of the big-endian TIME) and the order the shared code adds to it in.
; ---------------------------------------------------------------------------
!zone kernal_readtime
kernal_readtime
	lda a2_jiffy
	ldx a2_jiffy + 1
	ldy a2_jiffy + 2
	rts

!zone kernal_settime
kernal_settime
	sta a2_jiffy
	stx a2_jiffy + 1
	sty a2_jiffy + 2
	rts

; ---------------------------------------------------------------------------
; a2_init: called once, before anything reads the clock or the keyboard.
; ---------------------------------------------------------------------------
!zone a2_init
a2_init
	lda #0
	sta a2_jiffy
	sta a2_jiffy + 1
	sta a2_jiffy + 2
	sta a2_entropy
	sta a2_entropy + 1
	lda #<A2_POLLS_PER_JIFFY
	sta a2_jiffy_sub
	lda #>A2_POLLS_PER_JIFFY
	sta a2_jiffy_sub + 1
	; Text, page 1, no mixed graphics. The boot chain has done this already,
	; but a restart comes back through here without going through the boot.
	lda TXTSET
	lda MIXCLR
	lda LOWSCR
	lda HIRESOFF
	; Drain any keypress left over from the boot.
	lda KEYBOARD_STROBE
	rts

; ---------------------------------------------------------------------------
; kernal_readchar: block until a key is pressed, and return it. The shared code
; uses this to wait for acknowledgement after a fatal error, nothing more.
; ---------------------------------------------------------------------------
kernal_readchar
-	jsr kernal_getchar
	beq -
	rts

; ---------------------------------------------------------------------------
; kernal_reset: reboot. There is no BASIC to fall back into, so the honest exit
; from a fatal error is the machine's own reset vector, which on an autostart
; ROM boots whatever is in the drive.
; ---------------------------------------------------------------------------
kernal_reset
	jmp ($fffc)

; ---------------------------------------------------------------------------
; kernal_delay_1ms: one millisecond, near enough (200 * 5 = 1000 cycles at
; 1.023 MHz). Preserves a, x and y, as the CBM ROM routines this stands in for
; do; the callers count milliseconds in x and y around it.
; ---------------------------------------------------------------------------
kernal_delay_1ms
	pha
	tya
	pha
	ldy #200
-	dey
	bne -
	pla
	tay
	pla
	rts
