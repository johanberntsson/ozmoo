; ---------------------------------------------------------------------------
; Ozmoo Apple II: the boot-time hardware report (A2_HW_REPORT)
;
; make.rb with -a2hw produces a hardware report for Apple computers after
; the splash screen. It is called once from deletable_init_start, after
; a2_aux_preload, so; everything it reports has already been decided.
; ---------------------------------------------------------------------------

!ifndef A2_REPORT_ID {
A2_REPORT_ID = 0
}

!zone a2_hw_report {

!macro say .msg {
	ldx #<.msg
	lda #>.msg
	jsr printstring_raw
}

a2_hw_report
	; A clean screen: the aux cache's progress bar is still on the line above,
	; and this is meant to be photographed and sent back to us.
	jsr clear_screen_raw

	; --- line 1: which build is this? ---------------------------------------
	; The same question the write spike's ID answers: on a machine with no
	; filesystem, "did the copy take?" is otherwise unanswerable. make.rb
	; prints the number this must match.
	+say .m_title
	lda #A2_REPORT_ID
	jsr .hexbyte
	jsr .newline

	; --- line 2: what machine does it say it is? ----------------------------
!ifdef TARGET_APPLE2GS {
	+say .m_rom
	lda a2gs_rom_version
	jsr .hexbyte
}
	+say .m_id
!ifdef A2_LANGCARD {
	; From a2_id_bytes, not from the ROM: on a language card build the ROM is
	; banked out by now and this code is running in its place, so reading
	; $FBB3 here answers $00 - measured, and it read exactly like a IIgs
	; failing an identification it had in fact passed at boot.
	lda a2_id_bytes
	jsr .hexbyte
	lda #'/'
	jsr s_printchar
	lda a2_id_bytes + 1
} else {
	lda A2_ID_MACHINE
	jsr .hexbyte
	lda #'/'
	jsr s_printchar
	lda A2_ID_SUBMODEL
}
	jsr .hexbyte
!ifdef A2_80COL {
	+say .m_mach
	lda a2_machine
	jsr .hexbyte
}
	jsr .newline

	; --- line 3: the disk it came off, and the cache it will play out of ----
	+say .m_slot
	lda A2_SLOT
	jsr .hexbyte
	+say .m_disk
	+say .m_vmem
	lda vmap_max_entries
	jsr .hexbyte
!ifdef A2_AUX_CACHE {
	+say .m_aux
	lda a2_aux_pages
	jsr .hexbyte
	+say .m_why
	lda a2_aux_why
	jsr .hexbyte
}
	jsr .newline

!ifdef TARGET_APPLE2GS {
	; --- line 4: the registers only this machine has ------------------------
	; All four are read/write registers rather than toggling soft switches, so
	; reading them here has no side effect. CYAREG is the interesting one: bit
	; 7 is 2.8 MHz and the low nybble is "slow down while a disk motor is on in
	; slots 4-7", which is why a 5.25" build runs the whole session at 1 MHz.
	; MONOCHROME is the one to watch: MAME models neither the read nor the
	; write, and its bit 7 reads back SET here whatever a2_identify wrote,
	; while the screen stays in colour - so a real machine is the only thing
	; that can say whether the clear takes.
	+say .m_cya
	lda A2_SPEED
	jsr .hexbyte
	+say .m_tbcol
	lda A2_TBCOLOR
	jsr .hexbyte
	+say .m_clk
	lda A2_BORDER
	jsr .hexbyte
	+say .m_mono
	lda A2_MONOCHROME
	jsr .hexbyte
	jsr .newline
}

	; --- line 5: two measurements rather than two switch readings -----------
!ifdef A2_LANGCARD {
	; Did the language card copy arrive intact? The z-machine core runs from
	; up there, so a card that did not work at all cannot reach this line -
	; but a single page not copied would, and would go wrong later. Compare
	; the sum against the same build under MAME at the same point in the boot;
	; a handful of bytes up there are self-modified as the interpreter runs,
	; so it is only stable at a fixed moment, which this is.
	+say .m_lc
	jsr .lc_checksum
	lda .sum + 1
	jsr .hexbyte
	lda .sum
	jsr .hexbyte
}
	; How many times round the input loop the machine gets in a jiffy. On a
	; IIgs the jiffy is the hardware's own vertical blank, so this is a
	; measure of the CPU: 2.8 MHz reads about 2.7x what 1 MHz does. On a IIe
	; the jiffy IS a count of polls, so it should read A2_POLLS_PER_JIFFY and
	; anything else means the counter is mis-wired - which is exactly the bug
	; phase 1 shipped for a month.
	+say .m_polls
	jsr .measure_polls
	bcc +
	+say .m_stopped     ; the clock never ticked at all
	jmp .prompt
+	lda .count + 1
	jsr .hexbyte
	lda .count
	jsr .hexbyte

.prompt
	jsr .newline
	+say .m_press
	jsr kernal_readchar
	cmp #$54            ; 't', either case: kernal_getchar folds to $41-$5a
	bne .done
	jsr .clock_test
	jsr kernal_readchar
.done
	lda #13
	jsr s_printchar
	rts

; ---------------------------------------------------------------------------
; The 30 second test: an asterisk a second, for the tester to time against a
; wall clock or a phone. It is the only way to learn the jiffy's real rate -
; there is no second time source on the machine to check it against, and the
; human with the stopwatch is it. Thirty of them rather than one because a
; single interval is noisy: the clock only advances while something is polling,
; so a block paged in from disk is time that does not count. This is how the
; MEGA65 core's Apple II clock was confirmed in phase 1.
; ---------------------------------------------------------------------------
.clock_test
	jsr .newline
	+say .m_timing
	; Seed .mark, or the first wait sees a jiffy count that moved while the
	; report was sitting at its prompt and returns at once - a sixtieth of a
	; second off the thirty, but the same mistake in a longer wait would matter.
	lda a2_jiffy
	sta .mark
	ldx #30
.ct_second
	stx .seconds_left
	ldy #60
.ct_jiffy
	jsr .wait_jiffy
	bcs .ct_stopped
	dey
	bne .ct_jiffy
	lda #'*'
	jsr s_printchar
	ldx .seconds_left
	dex
	bne .ct_second
	jsr .newline
	+say .m_stopwatch
	rts
.ct_stopped
	+say .m_stopped
	rts

; ---------------------------------------------------------------------------
; .wait_jiffy: poll until the jiffy count changes. Carry clear if it did,
; carry SET if 65536 polls went by and it did not - which on a IIgs means the
; vertical blank is not toggling, and is the one failure here that would
; otherwise hang a machine we cannot debug. .guard is left holding the number
; of polls it took, which is what .measure_polls sums.
; ---------------------------------------------------------------------------
.wait_jiffy
	lda #0
	sta .guard
	sta .guard + 1
.wj_poll
	jsr kernal_getchar
	inc .guard
	bne +
	inc .guard + 1
	beq .wj_timeout
+	lda a2_jiffy
	cmp .mark
	beq .wj_poll
	sta .mark
	clc
	rts
.wj_timeout
	sec
	rts

; Sixteen jiffies and divide, because one jiffy alone is a poll or two out.
.measure_polls
	lda a2_jiffy
	sta .mark
	jsr .wait_jiffy     ; sync to an edge first, and discard that count
	bcs .mp_timeout
	lda #0
	sta .count
	sta .count + 1
	ldy #16
.mp_loop
	jsr .wait_jiffy
	bcs .mp_timeout
	clc
	lda .count
	adc .guard
	sta .count
	lda .count + 1
	adc .guard + 1
	sta .count + 1
	dey
	bne .mp_loop
	ldx #4
.mp_div
	lsr .count + 1
	ror .count
	dex
	bne .mp_div
	clc
	rts
.mp_timeout
	sec
	rts

!ifdef A2_LANGCARD {
; A plain 16 bit sum of the language card half, read at the addresses it runs
; at. Self-modified rather than through a zero page pointer: the zero page is
; the interpreter's and this is a diagnostic, so it borrows nothing.
.lc_checksum
	lda #0
	sta .sum
	sta .sum + 1
	lda #<A2_LC_CODE_START
	sta .lc_read + 1
	lda #>A2_LC_CODE_START
	sta .lc_read + 2
.lc_loop
	clc
.lc_read
	lda $ffff
	adc .sum
	sta .sum
	bcc +
	inc .sum + 1
+	inc .lc_read + 1
	bne +
	inc .lc_read + 2
+	lda .lc_read + 1
	cmp #<a2_lc_code_end
	bne .lc_loop
	lda .lc_read + 2
	cmp #>a2_lc_code_end
	bne .lc_loop
	rts
}

.hexbyte
	pha
	lsr
	lsr
	lsr
	lsr
	jsr .hexdigit
	pla
	and #$0f
.hexdigit
	cmp #10
	bcc +
	clc
	adc #7
+	clc
	adc #$30
	jmp s_printchar

.newline
	lda #13
	jmp s_printchar

.mark          !byte 0
.guard         !byte 0, 0
.count         !byte 0, 0
.seconds_left  !byte 0
!ifdef A2_LANGCARD {
.sum           !byte 0, 0
}

.m_title     !pet "ozmoo hw report  build $",0
!ifdef TARGET_APPLE2GS {
.m_rom       !pet "gs rom $",0
}
!ifdef TARGET_APPLE2GS {
.m_id        !pet "  id $",0
} else {
.m_id        !pet "id $",0
}
!ifdef A2_80COL {
.m_mach      !pet "  mach $",0
}
.m_slot      !pet "slot $",0
!ifdef A2_SMARTPORT {
.m_disk      !pet "  disk 3.5",0
} else {
.m_disk      !pet "  disk 5.25",0
}
.m_vmem      !pet "  vmem $",0
!ifdef A2_AUX_CACHE {
.m_aux       !pet "  aux $",0
.m_why       !pet " why $",0
}
!ifdef TARGET_APPLE2GS {
.m_cya       !pet "cyareg $",0
.m_tbcol     !pet " tbcol $",0
.m_clk       !pet " clk $",0
.m_mono      !pet " mono $",0
}
!ifdef A2_LANGCARD {
.m_lc        !pet "lc sum $",0
}
!ifdef A2_LANGCARD {
.m_polls     !pet "  polls/jiffy $",0
} else {
.m_polls     !pet "polls/jiffy $",0
}
.m_stopped   !pet "  CLOCK STOPPED",0
.m_press     !pet "t = 30 second clock test, any key plays",0
.m_timing    !pet "timing 30 seconds: ",0
.m_stopwatch !pet "...that should have taken 30 seconds",0

}
