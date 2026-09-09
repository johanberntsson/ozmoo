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
; clock. The timing was measured using tools/apple2/apple2-clock.rb
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

!ifdef TARGET_APPLE2GS {
	jsr a2_clock_tick
} else {
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
}

	lda KEYBOARD
	bpl .no_key
	sta KEYBOARD_STROBE
	and #$7f
	; Handle the delete key. There is no one key for it across the family: a 
	; II+ has no DEL at all and its LEFT ARROW sends $08, which is also what a
	; both emulators send if Backspace is pressed. However, a IIe's DELETE sends
 	; $7f. Both should become PETSCII $14 (delete in the z-machine).
	cmp #$08
	beq .delete
	cmp #$7f
	bne .no_delete
.delete
	lda #$14
	rts
.no_delete
	; Both cases of a letter onto PETSCII's UNSHIFTED range, $41-$5a. That is
	; what a C64 keyboard produces when nothing is held down, and it is what
	; every screen in the tree draws as lower case - including the IIe's, once
	; ALTCHARSET is on. So this is a normalisation, not the II+ workaround it
	; looks like: a II+ cannot send lower case at all, but a IIe can, and the
	; answer has to be the same either way.
	;
	; The reason it cannot be a case-preserving translation is the keyboard: on
	; an Apple IIe a letter key sends the same code whether SHIFT is held or
	; CAPS LOCK is down, and there is no soft switch to tell them apart. Keep
	; the case and the echo follows CAPS LOCK - a machine-wide latch that most
	; IIe owners leave down out of II+ habit - so a player types `look` and the
	; screen answers `LOOK` in the middle of the game's own mixed case text.
	; Folding also puts ZSCII in lower case, which is what z-spec 10.2 asks of
	; a `read`; the parser lowercases anyway, so nothing is lost but the ability
	; to put a capital in a save comment.
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

!ifdef TARGET_APPLE2GS {
; ---------------------------------------------------------------------------
; a2_clock_tick: look at the vertical blank once and advance the jiffy count if
; a frame has ended since the last look.
;
; A IIgs has a readable vertical blank, so a jiffy is a frame the hardware
; counted rather than a number of times we happened to look - which matters
; here more than on a II+, because this machine runs at 2.8 MHz and the poll
; counter it replaces was calibrated at 1.02. Bit 7 of $C019 toggles once a
; frame; counting only its 0->1 edges gives 60 a second whichever way round the
; machine drives it, so the IIe's inverted sense of the same bit costs nothing.
;
; It is a routine of its own rather than inline in kernal_getchar because
; wait_a_jiffy calls it too (see disk.asm): the [More] prompt waits a frame
; between polls, and if the wait spun on $C019 by itself it would hand the
; poll back at the same phase every time and the edge detector would never see
; a change - the clock would stop dead at exactly the prompt where a player is
; most likely to be watching it. Going through here instead, a [More] prompt
; keeps time as well as anything else does.
; ---------------------------------------------------------------------------
!zone a2_clock_tick
a2_clock_tick
	lda A2_VBL
	and #$80
	sta a2_vbl_now
	eor a2_vbl_last
	beq +                      ; same phase as last time
	lda a2_vbl_now
	sta a2_vbl_last
	beq +                      ; a 1->0 edge is half a frame, not a whole one
	inc a2_jiffy
	bne +
	inc a2_jiffy + 1
	bne +
	inc a2_jiffy + 2
+	rts
}

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
!ifdef TARGET_APPLE2GS {
	sta a2_vbl_last
	sta a2_vbl_now
} else {
	lda #<A2_POLLS_PER_JIFFY
	sta a2_jiffy_sub
	lda #>A2_POLLS_PER_JIFFY
	sta a2_jiffy_sub + 1
}
	; Text, page 1, no mixed graphics. The boot chain has done this already,
	; and on a IIe a2_screen_init has since turned the 80 column screen on -
	; so LOWSCR here means "the main half", not "display page 1", and the two
	; happen to want the same switch.
	lda TXTSET
	lda MIXCLR
	lda LOWSCR
	lda HIRESOFF
	; Drain any keypress left over from the boot.
	lda KEYBOARD_STROBE
	rts

!ifdef A2_80COL {
; Which Apple this is, filled in once at boot by a2_identify
A2_MACHINE_IIE          = 0     ; unenhanced IIe: no MouseText
A2_MACHINE_IIE_ENHANCED = 1     ; enhanced IIe, and a IIgs answers as one
A2_MACHINE_IIC          = 2
a2_machine !byte A2_MACHINE_IIE
}

!ifdef TARGET_APPLE2GS {
; The ROM version $FE1F handed back, kept because it is the one number that
; says which IIgs this is - ROM 00/01 machines differ from a ROM 3 in firmware
; and in how much RAM they were sold with, and on a machine we cannot debug the
; rule is to have a number to read rather than a verdict.
a2gs_rom_version !byte 0

; ---------------------------------------------------------------------------
; Colour.
;
; The shared screen code hands out C64 hardware colour numbers (the zcolours
; table in screenkernal.asm), so the translation to this machine's sixteen
; happens here rather than at thirty call sites. The pair lives in TBCOLOR and
; applies to the whole screen; see constants-apple2gs.asm for why that is the
; right model rather than a limitation.
;
; All three routines preserve a, x and y. That is not politeness: the macros
; below are called from the middle of init_screen_colours, which loads the
; background colour once and then expects it still to be in a when it sets the
; border from the same value.
; ---------------------------------------------------------------------------
a2gs_colours
	!byte $00       ; 0  black         -> black
	!byte $0f       ; 1  white         -> white
	!byte $01       ; 2  red           -> deep red
	!byte $0e       ; 3  cyan          -> aquamarine
	!byte $03       ; 4  purple        -> purple
	!byte $04       ; 5  green         -> dark green
	!byte $02       ; 6  blue          -> dark blue
	!byte $0d       ; 7  yellow        -> yellow
	!byte $09       ; 8  orange        -> orange
	!byte $08       ; 9  brown         -> brown
	!byte $0b       ; 10 light red     -> pink
	!byte $05       ; 11 dark grey     -> dark grey
	!byte $05       ; 12 medium grey   -> dark grey
	!byte $0c       ; 13 light green   -> light green
	!byte $07       ; 14 light blue    -> light blue
	!byte $0a       ; 15 light grey    -> light grey

a2gs_fg !byte $f0   ; kept already shifted into TBCOLOR's high nybble
a2gs_bg !byte $00

!zone a2gs_colour
a2gs_set_background
	sta .saved_a
	stx .saved_x
	and #$0f
	tax
	lda a2gs_colours,x
	sta a2gs_bg
	jsr a2gs_apply_colours
	ldx .saved_x
	lda .saved_a
	rts

a2gs_set_foreground
	sta .saved_a
	stx .saved_x
	and #$0f
	tax
	lda a2gs_colours,x
	asl
	asl
	asl
	asl
	sta a2gs_fg
	jsr a2gs_apply_colours
	ldx .saved_x
	lda .saved_a
	rts

; The border shares CLOCKCTL with the battery clock, so only the low nybble is
; ours: read, mask, write back. Storing the whole byte would talk to the clock.
a2gs_set_border
	sta .saved_a
	stx .saved_x
	and #$0f
	tax
	lda a2gs_colours,x
	sta .saved_border
	lda A2_BORDER
	and #$f0
	ora .saved_border
	sta A2_BORDER
	ldx .saved_x
	lda .saved_a
	rts

a2gs_apply_colours
	lda a2gs_fg
	ora a2gs_bg
	sta A2_TBCOLOR
	rts

.saved_a !byte 0
.saved_x !byte 0
.saved_border !byte 0
}

; ---------------------------------------------------------------------------
; kernal_readchar: block until a key is pressed, and return it. The shared code
; uses this to wait for acknowledgement after a fatal error, nothing more.
; ---------------------------------------------------------------------------
kernal_readchar
-	jsr kernal_getchar
	beq -
	rts

; ---------------------------------------------------------------------------
; kernal_reset: reboot. This is the exit from a fatal error, where restarting
; the machine is the honest thing to do, so it deliberately leaves the power-up
; byte alone and lets the autostart ROM cold start - which boots whatever is in
; the drive. A deliberate @quit wants the opposite and goes through
; a2_quit_to_basic below.
; ---------------------------------------------------------------------------
kernal_reset
!ifdef A2_LANGCARD {
	jmp a2_reset_stub
} else {
	jmp ($fffc)
}

!ifdef A2_LANGCARD {
; ---------------------------------------------------------------------------
; a2_reset_stub: put the ROM back and go through its own reset vector.
;
; With the language card banked in, $FFFA-$FFFF are our RAM rather than the
; ROM's vectors, so a reset - Ctrl-Reset, which is a real 6502 RESET - would
; vector wherever those six bytes happened to say. a2_lc_init therefore points
; all three vectors here, and here we bank the ROM back before reading $FFFC,
; which is then the ROM's own. NMI and IRQ land here too and reboot: this
; machine has no interrupt source, and a reboot beats a jump into whatever the
; interpreter left at $FFFE.
;
; It is also how kernal_reset exits, since the same two instructions are what a
; deliberate reset needs.
a2_reset_stub
	lda A2_LC_ROM
	jmp ($fffc)
}

; ---------------------------------------------------------------------------
; a2_quit_to_basic: what @quit does on this family.
;
; It used to be kernal_reset, i.e. a jump through $FFFC - and on an autostart
; ROM that is a COLD start, which boots whatever is in the drive, so quitting
; restarted the game instead of ending it. The fix is the power-up byte: with
; $3F4 holding $3F3 EOR $A5 the ROM's reset routine treats the reset as warm
; and jumps through $3F2 instead of booting. Going through the reset rather
; than jumping straight to Applesoft is deliberate - the ROM's own routine puts
; the text window, the character output hook and the monitor's zero page back,
; and Ozmoo has trashed all of it.
; ---------------------------------------------------------------------------
!zone a2_quit_to_basic
a2_quit_to_basic
	; Stop the drive. The RWTS leaves the motor running for the whole session
	; because a game pages more or less continuously, but a BASIC prompt with
	; the drive still spinning is untidy - and on a IIgs it is also what keeps
	; the machine at 1 MHz.
!ifndef A2_SMARTPORT {
	ldx A2_SLOT
	lda A2_MOTOR_OFF,x
}
	; Clear the text page, because neither the ROM's reset nor Applesoft does:
	; without this BASIC comes up on a screenful of the game's last screen. On
	; the 80 column screen half of what is there is in the other bank, so the
	; aux half has to go first, while 80STORE still means "pick a bank".
!ifdef A2_80COL {
	sta A2_AUX_HALF
	jsr .clear_page
	sta A2_MAIN_HALF
}
	jsr .clear_page
!ifdef A2_80COL {
	; Back to the 40 column screen, which is the state BASIC expects: the same
	; three switches z_ins_restart puts back before it reboots.
	sta A2_CLR80VID
	sta A2_CLRALTCHAR
	sta A2_CLR80STORE
}
!ifdef A2_LANGCARD {
	; $D000-$FFFF is the interpreter's upper half; Applesoft and the monitor
	; are in the ROM underneath it. Nothing below runs from the card.
	lda A2_LC_ROM
}
	; The colour registers are deliberately NOT put back: TBCOLOR and the
	; border are the machine's own settings, and the firmware's reset restores
	; them from the control panel a moment from now. So a IIgs comes back to
	; whatever its owner chose rather than to whatever Ozmoo was printing in -
	; which is why BASIC appears on the firmware's blue and not on our black.
	; Johan's call, September 2026: keep the firmware default, do not force
	; white on black.
	lda #<A2_BASIC_COLD
	sta A2_SOFTEV
	lda #>A2_BASIC_COLD
	sta A2_SOFTEV + 1
	eor #$a5
	sta A2_PWREDUP
	jmp ($fffc)

; The rows go through the same table the screen code uses, rather than filling
; $0400-$07FF flat: that would write over the four screen holes in each block,
; which are not on screen and belong to the peripheral cards.
.clear_page
	ldx #SCREEN_HEIGHT - 1
.clear_row
	lda a2_row_lo,x
	sta .clear_store + 1
	lda a2_row_hi,x
	sta .clear_store + 2
	ldy #A2_ROW_BYTES - 1
	lda #SPACE_SCREENCODE
.clear_store
	sta $ffff,y
	dey
	bpl .clear_store
	dex
	bpl .clear_row
	rts

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
