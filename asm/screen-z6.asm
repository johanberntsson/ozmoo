; Z6 version of screen.asm (used when the Z6 window model is active).
; Kept as close to screen.asm as possible; differences:
; - the z6 window model: 8 windows with property arrays (window_y etc.,
;   laid out as required by get_wind_prop/put_wind_prop, see z-spec 8.8.3.2)
; - window_start_row replaced: +1 -> window_y (top row of window 0),
;   +2 -> window_y + 1, bare -> s_screen_height
; - implementations/stubs for the z6 opcodes (draw_picture, move_window, ...)

; --- the unit the screen model counts in -------------------------------------
; Ozmoo has always counted in whole character cells: the header says the screen
; is SCREEN_WIDTH x SCREEN_HEIGHT units and a character is 1 x 1, so a v6 game's
; layout arithmetic happens in cells and every picture snaps to the cell grid.
; Z6_PIXEL_UNITS reports the 320x200 art pixel space Infocom authored for
; instead, with a character cell 320 / SCREEN_WIDTH pixels wide (4 at 80
; columns, 8 at 40, where the art is not doubled) and 8 tall.
;
; The conversions are shifts, and both shifts are zero without the flag, so
; every site below reduces to the code that was there. Text stays on the cell
; grid - a game only ever moves the cursor in font-size steps - so the text
; engine keeps counting cells and the opcodes convert at the boundary. Only
; PICTURES carry the remainder, which is what the two picture engines can now
; place (see .pic_place_cursor and todo.txt).
!ifdef Z6_PIXEL_UNITS {
	!if SCREEN_WIDTH = 80 {
Z6_UNIT_W_SHIFT = 2
	} else {
Z6_UNIT_W_SHIFT = 3
	}
Z6_UNIT_H_SHIFT = 3
} else {
Z6_UNIT_W_SHIFT = 0
Z6_UNIT_H_SHIFT = 0
}
Z6_UNIT_W = 1 << Z6_UNIT_W_SHIFT
Z6_UNIT_H = 1 << Z6_UNIT_H_SHIFT

; screen update routines

!macro init_screen_model {
    ; default values (see z-spec 8.8.3.3)
    ; all coordinates are stored 0-based internally; the opcodes
    ; convert from/to the 1-based coordinates the z-machine uses
	lda #0
	sta current_window
	; clear all 16 window property arrays, plus the line count's and the
	; newline routine's high bytes behind them: 18 * 8 = 144 bytes, done in
	; two halves because an index past 127 looks negative to bpl (the old
	; single loop stopped after one byte, which only a restart ever noticed)
	ldx #(9 * 8) - 1
-	sta window_y,x
	sta window_y + 9 * 8,x
	dex
	bpl -
	ldx #6
	lda #WIN_BUFFERED ; windows 1-7 start with buffering only
-   sta window_attributes + 1,x
	dex
	bpl -
	ldx #7
	lda #1 ; every window uses font 1, the normal font
-   sta window_font,x
	dex
	bpl -
	jsr init_window_colours
	; window 0 fills the whole screen; wrapping, scrolling,
	; transcripting and buffering all on
	lda #15
	sta window_attributes
	lda s_screen_height
	sta window_y_size
	lda s_screen_width
	sta window_x_size
!ifdef Z6_ECM_MODE {
	jsr ecm_init
}
    lda #147 ; clear screen
    jsr s_printchar
}

WIN_WRAPPING = 1
WIN_SCROLLING = 2
WIN_TRANSCRIPT = 4
WIN_BUFFERED = 8

; the props must be defined as for put/get_wind_prop to work (8.8.3.2)
window_y               !byte 0,0,0,0,0,0,0,0
window_x               !byte 0,0,0,0,0,0,0,0
window_y_size          !byte 0,0,0,0,0,0,0,0
window_x_size          !byte 0,0,0,0,0,0,0,0
window_y_cursor        !byte 0,0,0,0,0,0,0,0
window_x_cursor        !byte 0,0,0,0,0,0,0,0
window_left_margin     !byte 0,0,0,0,0,0,0,0
window_right_margin    !byte 0,0,0,0,0,0,0,0
window_newline_routine !byte 0,0,0,0,0,0,0,0
window_newline_countd  !byte 0,0,0,0,0,0,0,0
window_style           !byte 0,0,0,0,0,0,0,0
window_colour          !byte 0,0,0,0,0,0,0,0
window_font            !byte 0,0,0,0,0,0,0,0
; Property 13 is the font size, and it is the only property that is a real
; word: height in the high byte, width in the low one. It cannot be held in a
; byte per window like the rest, so get_wind_prop answers it directly (1,1, one
; unit each way, as the header promises) and nothing reads these bytes. They
; stay because the properties are indexed as window_y + 8 * property + window,
; so removing them would move window_attributes and window_linecount.
window_font_size_slot  !byte 0,0,0,0,0,0,0,0
window_attributes      !byte 0,0,0,0,0,0,0,0
window_linecount       !byte 0,0,0,0,0,0,0,0
; The line count is game-visible as a signed word (property 15): games park
; it at -999 to postpone [More] and 999 means never (z-spec 8.8.3.2.6 --
; Arthur resets window 0 with -999 after its intro keypresses). So it cannot
; be a bare byte. This is its high byte; it lives past the 16 properties,
; which keeps the window_y + 8 * property indexing undisturbed.
window_linecount_hi    !byte 0,0,0,0,0,0,0,0
; Property 8, the newline interrupt routine, is a packed address - a word,
; like the line count. The low byte sits in the property slot above; this is
; its high byte, placed here for the same reason as window_linecount_hi.
window_newline_routine_hi !byte 0,0,0,0,0,0,0,0

; Font 3 (z-spec 16, character graphics). We have no such charset, but the v6
; games (Journey's command-menu dividers) use only its box-drawing glyphs:
; horizontal/vertical lines and the four corners. When the current window is in
; font 3, map those glyph codes to the equivalent PETSCII box-drawing character
; so the ordinary convert_petscii_to_screencode path renders them natively on
; every screen target (C64/C128 VDC/Plus4/MEGA65 FCM text/X16). Codes we do not
; render (Journey uses none of them) pass through unchanged.
;   input:  a = ZSCII glyph code
;   output: carry set  -> a = PETSCII replacement (handled)
;           carry clear -> a = original code (not font 3, or not a mapped glyph)
font3_translate
	sta .f3_char
	ldx current_window
	lda window_font,x
	cmp #3
	bne .f3_passthrough
	lda .f3_char
	sec
	sbc #38            ; the mapped glyphs are codes 38..57
	cmp #(font3_to_petscii_end - font3_to_petscii)
	bcs .f3_passthrough
	tax
	lda font3_to_petscii,x
	beq .f3_passthrough ; 0 = a gap in the table, not rendered
	sec
	rts
.f3_passthrough
	lda .f3_char
	clc
	rts
.f3_char !byte 0

; Indexed by font-3 code - 38. Values are PETSCII (fed to
; convert_petscii_to_screencode). 0 marks a code we do not map.
;                     38   39   40   41   42 43 44 45   46   47   48   49
font3_to_petscii !byte $c0, $c0, $dd, $dd, 0, 0, 0, 0, $ad, $b0, $ae, $bd
;                     50 51 52 53 54 55 56   57
                 !byte 0, 0, 0, 0, 0, 0, 0, $a1
font3_to_petscii_end
;  38/39 horizontal line, 40/41 vertical line, 46 corner up+right, 47 down+right,
;  48 down+left, 49 up+left, 57 solid left block (Journey's selected-command bar).

!ifdef Z6_PICTURES {
!source "../temp/pictures.asm"

!ifdef TARGET_X16 {
!source "pictures-x16.asm"
} else {
!source "pictures-mega65.asm"
}
}

!ifdef DEBUG_SCREENLOG {
; A ring buffer of the v6 screen opcodes and their operands, for reading out
; with the xemu monitor when a game's layout goes wrong. 8 bytes an entry:
; id, current_window, op0 lo, op1 lo, op1 hi, op2 lo, extra lo, extra hi.
; The extra word is the result (get_wind_prop) or the width (stream 3 close).
screenlog_buf  !fill 8 * 128, 0
screenlog_pos  !byte 0, 0		; entry index 0..127, and a wrap counter
screenlog_hook					; a = id; logs the current operands
	stx .slog_x + 1
	sty .slog_y + 1
	pha
	lda screenlog_pos
	asl
	asl
	asl
	tay						; y = entry offset (0..1016, but 8*128 wraps at 1024:
	lda screenlog_pos		; offsets 0..127*8 fit a byte times... they don't: use
	and #$e0				; a split index: low 5 bits * 8 = offset in page,
	lsr						; high 2 bits = page
	lsr
	lsr
	lsr
	lsr
	sta .slog_page
	lda screenlog_pos
	and #$1f
	asl
	asl
	asl
	tay
	pla
	pha
	jsr .slog_put			; id
	lda current_window
	jsr .slog_put
	lda z_operand_value_low_arr
	jsr .slog_put
	lda z_operand_value_low_arr + 1
	jsr .slog_put
	lda z_operand_value_high_arr + 1
	jsr .slog_put
	lda z_operand_value_low_arr + 2
	jsr .slog_put
	lda #0
	jsr .slog_put
	jsr .slog_put
	inc screenlog_pos
	lda screenlog_pos
	cmp #128
	bcc +
	lda #0
	sta screenlog_pos
	inc screenlog_pos + 1
+	pla
.slog_x	ldx #0
.slog_y	ldy #0
	rts
.slog_page !byte 0
.slog_put
	sty .slog_put_y + 1
	pha
	lda .slog_page
	clc
	adc #>screenlog_buf
	sta .slog_sta + 2
	pla
.slog_sta
	sta screenlog_buf,y
	iny
	bne +
	inc .slog_page
+
.slog_put_y
	ldy #0
	iny
	sty .slog_put_y + 1
	rts

screenlog_extra					; a,x = a result word for the previous entry
	pha
	stx .slog_ex + 1
	lda screenlog_pos
	sec
	sbc #1
	and #$1f
	asl
	asl
	asl
	clc
	adc #6
	tay
	lda screenlog_pos
	sec
	sbc #1
	and #$60
	lsr
	lsr
	lsr
	lsr
	lsr
	clc
	adc #>screenlog_buf
	sta .slog_exs + 2
	sta .slog_exs2 + 2
.slog_ex
	lda #0
.slog_exs
	sta screenlog_buf,y
	iny
	pla
.slog_exs2
	sta screenlog_buf,y
	rts
}

z_ins_draw_picture
!ifdef DEBUG_SCREENLOG {
	lda #12
	jsr screenlog_hook
}
	; draw_picture picture-number y x
	; Where we have the picture (MEGA65, -fcm, -pics) it is blitted from bank
	; 1. Otherwise Ozmoo will never draw pictures on this machine, so instead
	; of leaving a hole in the layout it writes a "pic:N" note where the
	; picture belongs. The note goes straight to the screen, so it never
	; reaches the transcript, and the game's cursor is put back afterwards.
!ifdef TRACE_SCREEN {
	jsr print_following_string
	!pet "z_ins_draw_picture ",0
	jsr newline
}
!ifdef Z6_PICTURES {
	lda z_operand_value_high_arr
	ldx z_operand_value_low_arr
	jsr .pic_find
	bcc .dp_not_image
	jsr .pic_place_cursor
	jsr .pic_draw
	jmp restore_cursor
.dp_not_image
	ldx z_operand_value_low_arr
	jsr .rect_find		; a Rect placeholder is invisible: nothing to draw
	bcc +
	rts
+
}
	jsr .pic_place_cursor
	lda #>.pic_prefix
	ldx #<.pic_prefix
	jsr printstring_raw
	lda z_operand_value_high_arr
	ldx z_operand_value_low_arr
	jsr .pic_print_number
	jmp restore_cursor

.pic_prefix !pet "pic:",0

z_ins_picture_data
	; picture_data picture-number array ?(label)
	; Where we have the picture, report its size and branch. Picture 0 asks for
	; the number of pictures available and the release number of the picture
	; file instead of a size.
	;
	; The spec calls the two words a height and a width "in pixels", but a
	; pixel here is whatever unit the rest of the screen model counts in, and
	; Ozmoo counts characters: the header reports a 40x25 screen and
	; get_wind_prop answers 1x1 for the font size. A game divides one by the
	; other, so the size must come back in cells too. Arthur centres a picture
	; with (get_wind_prop 3 - width) / 2, straight against the window's column
	; count, and would put it off screen eightfold otherwise.
!ifdef TRACE_SCREEN {
	jsr print_following_string
	!pet "z_ins_picture_data ",0
	jsr newline
}
	lda z_operand_value_low_arr
	ora z_operand_value_high_arr
	bne .pd_picture
	; picture 0: the number of pictures (a word), then the file's release number
	jsr .pd_set_array
!ifdef Z6_PICTURES {
	lda #>picture_count
} else {
	lda #0
}
	jsr write_next_byte
!ifdef Z6_PICTURES {
	lda #<picture_count
} else {
	lda #0
}
	jsr write_next_byte
	lda #0
	jsr write_next_byte
	jsr write_next_byte
	jmp make_branch_false ; picture 0 never branches
.pd_picture
!ifdef Z6_PICTURES {
	lda z_operand_value_high_arr
	ldx z_operand_value_low_arr
	jsr .pic_find
	bcc .pd_try_rect
!ifdef Z6_PIXEL_UNITS {
	; report the picture's NATIVE art-pixel size, not its size rounded up to
	; whole text cells: Zork Zero's compass overlay is 45x40, and 48x40 is
	; exactly the snapping the pixel model exists to remove. pics2asm emits
	; these tables only when the flag is set (--pixel-units).
	lda #<pic_px_width_lo
	ldx #>pic_px_width_lo
	jsr .pd_px_lookup
	sta .pd_w
	lda #<pic_px_width_hi
	ldx #>pic_px_width_hi
	jsr .pd_px_lookup
	sta .pd_w + 1
	lda #<pic_px_height
	ldx #>pic_px_height
	jsr .pd_px_lookup
	sta .pd_h
	jmp .pd_report_px
}
	jsr .pic_size ; sets .pic_w and .pic_h for the picture in .pic_index
	jmp .pd_report
.pd_try_rect
	; Not a real picture. A Rect placeholder has no image, only a size, which
	; the game reads to lay real pictures out; Arthur's frame is built this way.
	; .pic_find clobbered x, so reload the picture number before the rect search
	; (as draw_picture's .dp_not_image does); .rect_find takes it in x.
	ldx z_operand_value_low_arr
	jsr .rect_find
	bcc +
!ifdef Z6_PIXEL_UNITS {
	lda rect_px_width_lo,y
	sta .pd_w
	lda rect_px_width_hi,y
	sta .pd_w + 1
	lda rect_px_height,y
	sta .pd_h
	jmp .pd_report_px
}
	lda rect_width,y
	sta .pic_w
	lda rect_height,y
	sta .pic_h
.pd_report
	jsr .pd_set_array
	lda #0
	jsr write_next_byte
	lda .pic_h ; the height is word 0
	jsr write_next_byte
	lda #0
	jsr write_next_byte
	lda .pic_w ; and the width word 1
	jsr write_next_byte
	jmp make_branch_true
!ifdef Z6_PIXEL_UNITS {
.pd_report_px
	jsr .pd_set_array
	lda #0
	jsr write_next_byte
	lda .pd_h ; the height is word 0; 200 fits a byte
	jsr write_next_byte
	lda .pd_w + 1 ; and the width word 1, which needs both bytes
	jsr write_next_byte
	lda .pd_w
	jsr write_next_byte
	jmp make_branch_true

.pd_px_lookup
	; a,x = the low and high byte of a table's address -> a = its entry for the
	; picture in .pic_index. Both engines index their tables this way.
	jsr .pic_addr
	ldy #0
	lda (.pi_ptr),y
	rts

.pd_w !byte 0,0
.pd_h !byte 0
}
+
}
	jmp make_branch_false

!ifdef Z6_PICTURES {
.rect_find
	; Picture number in x (low byte) and z_operand_value_high_arr (high). Return
	; its index in y with carry set, or carry clear if it is not a rect.
!if rect_count > 0 {
	ldy #0
-	txa
	cmp rect_number_lo,y
	bne +
	lda z_operand_value_high_arr
	cmp rect_number_hi,y
	beq ++
+	iny
	cpy #rect_count
	bne -
}
	clc
	rts
!if rect_count > 0 {
++	sec
	rts
}
}

.pd_set_array
	; Point the write cursor at the array in operand 1.
	ldx z_operand_value_low_arr + 1
	lda z_operand_value_high_arr + 1
	jmp set_z_address

z_ins_erase_picture
	; erase_picture picture-number y x
	; Where we drew a real picture, blank its rectangle. Otherwise paint over
	; the note draw_picture wrote, so that a game which erases a picture leaves
	; clean screen behind either way.
!ifdef TRACE_SCREEN {
	jsr print_following_string
	!pet "z_ins_erase_picture ",0
	jsr newline
}
!ifdef Z6_PICTURES {
	lda z_operand_value_high_arr
	ldx z_operand_value_low_arr
	jsr .pic_find
	bcc +
	jsr .pic_place_cursor
	jsr .pic_erase
	jmp restore_cursor
+
}
	jsr .pic_place_cursor
	lda z_operand_value_high_arr
	ldx z_operand_value_low_arr
	jsr .pic_number_width
	clc
	adc #4 ; the "pic:" prefix
	tay
-	lda #$20
	jsr s_printchar
	dey
	bne -
	jmp restore_cursor

.pic_place_cursor
	; Put the live cursor where the picture belongs. y and x are 1-based and
	; relative to the current window; zero, or a missing operand, means "the
	; cursor's own y or x" (see the draw_picture entry in the spec).
!ifdef Z6_PIXEL_UNITS {
	jmp .ppc_units
}
	jsr printchar_flush ; anything buffered belongs on screen first
	jsr save_cursor
	lda #0
	sta .pic_y
	sta .pic_x
	ldx z_operand_count
	cpx #2
	bcc +
	lda z_operand_value_low_arr + 1
	sta .pic_y
	cpx #3
	bcc +
	lda z_operand_value_low_arr + 2
	sta .pic_x
+	ldy current_window
	ldx .pic_y
	beq +
	dex ; 1-based to 0-based
	txa
	clc
	adc window_y,y
	jmp ++
+	lda window_y_cursor,y
++	sta .pic_y
	ldx .pic_x
	beq +
	dex
	txa
	clc
	adc window_x,y
	jmp ++
+	lda window_x_cursor,y
++	sta .pic_x ; keep the absolute column: the picture blitter needs it too
	jsr .pic_pixel_pos
.ppc_placed
	lda .pic_x
	tay ; y = column
	ldx .pic_y ; x = row
	jmp set_cursor

!ifdef Z6_PIXEL_UNITS {
.ppc_units
	; The same, with the operands read as ART PIXELS rather than cells. This is
	; where the whole refactor pays off: the position keeps its sub-cell part
	; all the way to the picture engine, which can now draw it (phases 0b/4).
	; .pic_x / .pic_y are still derived, in cells, because the cursor and the
	; "pic:N" note on the targets that draw no pictures live on the cell grid.
	jsr printchar_flush
	jsr save_cursor
	ldy current_window
	; --- the row: units, one byte, 0..199
	lda #0
	sta .pic_py + 1
	ldx z_operand_count
	cpx #2
	bcc .ppcu_cursor_y
	lda z_operand_value_low_arr + 1
	ora z_operand_value_high_arr + 1
	beq .ppcu_cursor_y		; 0 means "the cursor's own row"
	lda z_operand_value_low_arr + 1
	sec
	sbc #1					; 1-based to 0-based, in units
	pha
	lda window_y,y
	jsr cells_to_units_y	; the window's own top, in units
	sta .pic_py
	pla
	clc
	adc .pic_py
	sta .pic_py
	jmp .ppcu_column
.ppcu_cursor_y
	lda window_y_cursor,y
	jsr cells_to_units_y
	sta .pic_py
.ppcu_column
	; --- the column: units, a word, 0..319
	lda #0
	sta .pic_px
	sta .pic_px + 1
	ldx z_operand_count
	cpx #3
	bcc .ppcu_cursor_x
	lda z_operand_value_low_arr + 2
	ora z_operand_value_high_arr + 2
	beq .ppcu_cursor_x
	lda z_operand_value_low_arr + 2
	sec
	sbc #1
	sta .pic_px
	lda z_operand_value_high_arr + 2
	sbc #0
	sta .pic_px + 1
	lda window_x,y
	jsr cells_to_units_x	; a = low, x = high
	clc
	adc .pic_px
	sta .pic_px
	txa
	adc .pic_px + 1
	sta .pic_px + 1
	jmp .ppcu_cells
.ppcu_cursor_x
	lda window_x_cursor,y
	jsr cells_to_units_x
	sta .pic_px
	stx .pic_px + 1
.ppcu_cells
	; the cell the picture starts in, for the cursor and the note path
	lda .pic_py
	jsr units_to_cells_y
	sta .pic_y
	lda .pic_px
	ldx .pic_px + 1
	jsr units_to_cells_x
	sta .pic_x
	jmp .ppc_placed
}

.pic_pixel_pos
	; .pic_px / .pic_py = the picture's top left corner in the 320x200 art pixel
	; space. A character cell is 8 art pixels down, and 320 / SCREEN_WIDTH
	; across - 4 on an 80-column screen, 8 on a 40-column one, where the art is
	; not doubled. While the screen model reports character units that is all
	; the resolution a game can ask for, so these are just the cell position
	; scaled. They exist because the games really place pictures in art
	; pixels: a position can fall inside a cell on either axis, which the cell
	; grid cannot express and which both picture engines can now draw. Without
	; Z6_PIXEL_UNITS a cell is one unit and these are just the cell position.
	; Z6_PIC_XSUB and Z6_PIC_YSUB add a fixed offset, positive or negative, to
	; exercise the placement on its own - that is how it was built and verified,
	; before the reporting change made the games ask for it. Arthur's map is the
	; one that needs BOTH axes: its 18-unit lattice puts rows and columns 2, 4
	; or 6 pixels into a cell (see todo.txt).
	lda .pic_x
	asl
	sta .pic_px
	lda #0
	rol
	sta .pic_px + 1
	asl .pic_px
	rol .pic_px + 1
!if SCREEN_WIDTH < 80 {
	asl .pic_px				; a 40-column cell is 8 art pixels, not 4
	rol .pic_px + 1
}
!ifdef Z6_PIC_XSUB {
	lda .pic_px
	clc
	adc #<Z6_PIC_XSUB
	sta .pic_px
	lda .pic_px + 1
	adc #>Z6_PIC_XSUB
	sta .pic_px + 1
	bpl +
	lda #0			; a negative test offset off the left edge: clamp to 0
	sta .pic_px
	sta .pic_px + 1
+
}
	lda .pic_y
	sta .pic_py
	lda #0
	sta .pic_py + 1
	ldx #3
-	asl .pic_py
	rol .pic_py + 1
	dex
	bne -
!ifdef Z6_PIC_YSUB {
	lda .pic_py
	clc
	adc #<Z6_PIC_YSUB
	sta .pic_py
	lda .pic_py + 1
	adc #>Z6_PIC_YSUB
	sta .pic_py + 1
	bpl +
	lda #0			; likewise off the top edge
	sta .pic_py
	sta .pic_py + 1
+
}
	rts

.pic_print_number
	; a,x = high,low byte of an unsigned number: print it on the screen
	jsr .pic_split_number ; y = digit count, .pic_buf holds them backwards
-	dey
	lda .pic_buf,y
	jsr s_printchar
	cpy #0
	bne -
	rts

.pic_number_width
	; a,x = high,low byte of an unsigned number: return its length in a
	jmp .pic_split_number

.pic_split_number
	; a,x = high,low byte of an unsigned number. Store its digits in
	; .pic_buf, least significant first, and return the count in a and y.
	sta .pic_num + 1
	stx .pic_num
	ldy #0
-	jsr .pic_div10
	clc
	adc #$30 ; '0'
	sta .pic_buf,y
	iny
	lda .pic_num
	ora .pic_num + 1
	bne -
	tya
	rts

.pic_div10
	; .pic_num /= 10, remainder returned in a
	lda #0
	sta .pic_rem
	ldx #16
-	asl .pic_num
	rol .pic_num + 1
	rol .pic_rem
	lda .pic_rem
	cmp #10
	bcc +
	sbc #10
	sta .pic_rem
	inc .pic_num ; the quotient's bit 0, just vacated by the shift
+	dex
	bne -
	lda .pic_rem
	rts

.pic_y   !byte 0
.pic_x   !byte 0
.pic_px  !byte 0,0 ; the same corner in 320x200 art pixels (see .pic_place_cursor)
.pic_py  !byte 0,0

!if Z6_UNIT_W_SHIFT > 0 {
.unit_tmp !byte 0,0

cells_to_units_x
	; a = a column or a width in cells -> a,x = it in units, a word because
	; 320 does not fit a byte. Only assembled with Z6_PIXEL_UNITS: without it a
	; unit IS a cell and every caller is compiled out.
	sta .unit_tmp
	lda #0
	sta .unit_tmp + 1
!for .i, 1, Z6_UNIT_W_SHIFT {
	asl .unit_tmp
	rol .unit_tmp + 1
}
	lda .unit_tmp
	ldx .unit_tmp + 1
	rts

units_to_cells_x_up
	; a,x = a 0-based column in units -> a = the first cell at or after it: the
	; position is rounded UP to a character boundary, not down.
	;
	; Text lives on the cell grid and only a picture can carry the sub-cell
	; remainder, so a position part-way into a cell has to be snapped to a cell
	; edge - and the edge to snap to is the one that keeps the text INSIDE the
	; rectangle the game asked for. Flooring puts it up to a whole cell to the
	; left of the window's own left edge: a window moved to unit 160, the
	; middle of a 320 pixel screen and where the games put things, began at
	; column 19 - eight pixels outside itself - and its text with it
	; (fredrik.inf). Rounding up gives 158 and 160 column 20, and 162 column
	; 21. The canonical cell * font-width + 1 coordinates the commercial games
	; compute have no remainder and are unchanged.
	;
	; Sizes still round down (z_ins_window_size), so both edges move inwards
	; and a window can only ever lose the odd part cell, never claim one.
	clc
	adc #Z6_UNIT_W - 1
	bcc units_to_cells_x
	inx					; the carry belongs in the high byte
units_to_cells_x
	; a,x = a column or a width in units -> a = it in cells, rounded down. A
	; game that asks for a text position between cells gets the cell it starts
	; in; only pictures carry the remainder.
	sta .unit_tmp
	stx .unit_tmp + 1
!for .i, 1, Z6_UNIT_W_SHIFT {
	lsr .unit_tmp + 1
	ror .unit_tmp
}
	lda .unit_tmp
	rts

cells_to_units_y
	; a = a row or a height in cells -> a in units; 200 fits a byte
	asl
	asl
	asl
	rts

units_to_cells_y_up
	; a = a 0-based row in units -> a = the first row at or after it. The y
	; axis of units_to_cells_x_up; 199 + a cell still fits a byte.
	clc
	adc #Z6_UNIT_H - 1
units_to_cells_y
	; a = a row or a height in units -> a in cells, rounded down
	lsr
	lsr
	lsr
	rts
}
.pic_num !byte 0,0
.pic_rem !byte 0
.pic_buf !byte 0,0,0,0,0 ; at most five digits

window_from_operand
	; x = which operand holds a window number. Returns that window in a and y.
	; The z-machine writes the current window as -3 (z-spec 8.8.3), and Arthur
	; does so constantly: 22 of its get_wind_prop calls and 5 of its
	; window_style calls name the window that way. Anything else is masked to
	; the eight windows that exist.
	lda z_operand_value_high_arr,x
	cmp #$ff
	bne +
	lda z_operand_value_low_arr,x
	cmp #$fd
	bne +
	lda current_window
	tay
	rts
+	lda z_operand_value_low_arr,x
	and #7
	tay
	rts

z_ins_set_margins
!ifdef DEBUG_SCREENLOG {
	lda #4
	jsr screenlog_hook
}
	; set_margins left right [window]
	; The margins are in pixels, and a character is one pixel wide here, so
	; they are simply column counts. Text wraps between them.
!ifdef TRACE_SCREEN {
	jsr print_following_string
	!pet "z_ins_set_margins ",0
	jsr newline
}
	; pending buffered text belongs inside the old margins, and the buffer's
	; start column must move with the cursor below: Zork Zero sets the left
	; margin beside its drop-cap initial and prints straight away, and the
	; stale start column put the paragraph's first line over the picture
	jsr printchar_flush
	ldy current_window
	lda z_operand_count
	cmp #3
	bcc +
	ldx #2
	jsr window_from_operand
+
!ifdef Z6_PIXEL_UNITS {
	lda z_operand_value_low_arr
	ldx z_operand_value_high_arr
	jsr units_to_cells_x
	sta window_left_margin,y
	lda z_operand_value_low_arr + 1
	ldx z_operand_value_high_arr + 1
	jsr units_to_cells_x
	sta window_right_margin,y
} else {
	lda z_operand_value_low_arr
	sta window_left_margin,y
	lda z_operand_value_low_arr + 1
	sta window_right_margin,y
}
	; "If the cursor is overtaken and now lies outside the margins
	; altogether, move it back to the left margin of the current line."
	sty .sm_window
	jsr save_cursor ; clobbers y with the current window
	ldy .sm_window
	lda window_x,y
	clc
	adc window_left_margin,y
	sta .sm_left
	lda window_x,y
	clc
	adc window_x_size,y
	sec
	sbc window_right_margin,y
	bcs +
	lda window_x,y ; a margin wider than the window leaves no room at all
+	sta .sm_right
	lda window_x_cursor,y
	cmp .sm_left
	bcc .sm_outside
	cmp .sm_right
	bcc .sm_inside
.sm_outside
	lda .sm_left
	sta window_x_cursor,y
.sm_inside
	cpy current_window
	bne +
	jsr restore_cursor
	jmp start_buffering ; the buffer restarts at the (possibly moved) cursor
+	rts

!ifdef Z6_PIXEL_UNITS {
.sc_tmp !byte 0		; set_cursor's column while it is converted out of units
}
.sm_left   !byte 0
.sm_right  !byte 0
.sm_window !byte 0

z_ins_move_window
!ifdef DEBUG_SCREENLOG {
	lda #2
	jsr screenlog_hook
}
	; move_window window y x
!ifdef TRACE_SCREEN {
	jsr print_following_string
	!pet "z_ins_move_window ",0
	jsr newline
}
	ldx #0
	jsr window_from_operand
!ifdef Z6_PIXEL_UNITS {
	; y and x are 1-based positions in units. A zero means the same as a one -
	; the top or left edge - so it must still be stored, not skipped.
	lda z_operand_value_low_arr + 1
	beq .mw_row_zero
	sec
	sbc #1					; 1-based units to 0-based
!ifdef Z6_FCM_TEXT_BAKE {
	jsr units_to_cells_y	; floor: the remainder below is drawn, not lost
} else {
	jsr units_to_cells_y_up
}
.mw_row_zero
	sta window_y,y
	sta window_y_cursor,y
!ifdef Z6_FCM_TEXT_BAKE {
	; the window origin's sub-cell y remainder, for baked transparent text; the
	; cursor sits at the origin, so text_y_sub takes it too (additive, so a
	; non-bake pixel build is byte-identical above)
	lda z_operand_value_low_arr + 1
	beq .mw_sub_zero
	sec
	sbc #1
	and #7
	jmp .mw_sub_store
.mw_sub_zero
	lda #0
.mw_sub_store
	sta window_y_sub,y
	sta text_y_sub,y
}
	lda z_operand_value_low_arr + 2
	ldx z_operand_value_high_arr + 2
	bne .mw_col			; a column of 256 or more is certainly not zero
	cmp #0
	beq .mw_col_zero
.mw_col
	sec
	sbc #1					; the word minus one, borrowing into the high byte
	bcs +
	dex
+	jsr units_to_cells_x_up
	jmp .mw_store_col
.mw_col_zero
	lda #0
.mw_store_col
	sta window_x,y
	sta window_x_cursor,y
} else {
	ldx z_operand_value_low_arr + 1
	beq +
	dex ; z-machine uses 1-based coordinates, we use 0-based
+	txa
	sta window_y,y
	sta window_y_cursor,y
	ldx z_operand_value_low_arr + 2
	beq +
	dex
+	txa
	sta window_x,y
	sta window_x_cursor,y
}
	cpy current_window
	bne +
	jsr restore_cursor ; the current window moved: update the live cursor
+	rts
 
z_ins_window_size
!ifdef DEBUG_SCREENLOG {
	lda #3
	jsr screenlog_hook
}
	; window_size window y x
!ifdef TRACE_SCREEN {
	jsr print_following_string
	!pet "z_ins_window_size ",0
	jsr newline
}
	ldx #0
	jsr window_from_operand
!ifdef Z6_PIXEL_UNITS {
	lda z_operand_value_low_arr + 1		; a height in units
	jsr units_to_cells_y
	sta window_y_size,y
	lda z_operand_value_low_arr + 2		; a width in units, a word
	ldx z_operand_value_high_arr + 2
	jsr units_to_cells_x
	sta window_x_size,y
} else {
	lda z_operand_value_low_arr + 1
	sta window_y_size,y
	lda z_operand_value_low_arr + 2
	sta window_x_size,y
}
	rts
 
z_ins_window_style
!ifdef DEBUG_SCREENLOG {
	lda #7
	jsr screenlog_hook
}
	; window_style window flags operation
!ifdef TRACE_SCREEN {
	jsr print_following_string
	!pet "z_ins_window_style ",0
	jsr newline
}
	ldx #0
	jsr window_from_operand
	; the operation operand is optional and the operand array keeps stale
	; values between instructions: Journey styles window 0 with two operands
	; right after a three-operand window_size, whose width read as operation
	; 3 (xor) and switched all of window 0's attributes off, so its intro
	; text neither wrapped nor scrolled. A missing operation means 0 (set).
	ldx #0
	lda z_operand_count
	cmp #3
	bcc .ws_have_operation
	ldx z_operand_value_low_arr + 2
.ws_have_operation
	cpx #0
	bne +
	; set to these settings
	lda z_operand_value_low_arr + 1
	jmp ++
+   cpx #1
	bne +
	; set the bits supplied
	lda window_attributes,y
	ora z_operand_value_low_arr + 1
	jmp ++
+   cpx #2
	bne +
	; clear the bits supplied
	lda z_operand_value_low_arr + 1
	eor #$ff
	and window_attributes,y
	jmp ++
+   ; reverse the bits supplied (xor)
	lda window_attributes,y
	eor z_operand_value_low_arr + 1
++
	sta window_attributes,y
	rts
 
z_ins_get_wind_prop
!ifdef DEBUG_SCREENLOG {
	lda #8
	jsr screenlog_hook
}
	; get_wind_prop window property-number -> (result)
!ifdef TRACE_SCREEN {
	jsr print_following_string
	!pet "z_ins_window_size ",0
	jsr newline
	lda #99
	jsr printa
	jsr newline
}
	lda z_operand_value_low_arr + 1
	cmp #13
	bne +
	; Property 13 is the font size: height in the high byte, width in the low
	; one. It is the only property that is a real word, so it cannot live in
	; the byte-per-window arrays below. It must agree with what the header
	; says a unit is - a character cell without Z6_PIXEL_UNITS, an art pixel
	; with it. Arthur takes the height from here and divides by it, so a zero
	; is fatal, and both are non-zero either way.
	lda #Z6_UNIT_H
	ldx #Z6_UNIT_W
!ifdef DEBUG_SCREENLOG {
	jsr screenlog_extra
}
	jmp z_store_result
+
	; return value at window_y + property-number * 8 + window
	ldx #0
	jsr window_from_operand
	sta .gwp_window
	lda z_operand_value_low_arr + 1
	asl
	asl
	asl
	clc
	adc .gwp_window
	tay
	ldx window_y,y
	; convert 0-based internal values to what the z-machine expects
	ldy .gwp_window
	lda z_operand_value_low_arr + 1
	cmp #2
	bcs +
!if Z6_UNIT_W_SHIFT > 0 {
	jmp .gwp_scale ; property 0/1 (y/x position): .gwp_scale adds the 1-based
					; bias in UNITS, after scaling
} else {
	inx ; property 0/1 (y/x position): 1-based
	bne .gwp_scale ; Always branch
}
+	cmp #4
	beq .gwp_cursor_y
	cmp #5
	beq .gwp_cursor_x
!if Z6_UNIT_W_SHIFT > 0 {
	cmp #8
	bcc .gwp_scale ; 2/3 are sizes and 6/7 margins: counts, so no 1-based bias
}
	cmp #11
	bne +
	; property 11 is the colour pair (8.8.3.2.4): the background in the
	; high byte, the foreground in the low, as z-colour numbers. Arthur
	; reads it and sets the swap of it to print its parser messages in
	; reverse video. set_colour keeps the pair packed in window_colour.
	lda window_colour,y
	and #$0f
	tax
	lda window_colour,y
	lsr
	lsr
	lsr
	lsr
	jmp .gwp_store_high_in_a
+	cmp #15
	bne +
	; the line count (property 15) is a signed word (8.8.3.2.6)
	lda window_linecount_hi,y
	jmp .gwp_store_high_in_a
+	cmp #8
	bne .gwp_store
	; the newline interrupt routine (property 8) is a packed address, a word
	lda window_newline_routine_hi,y
	jmp .gwp_store_high_in_a
.gwp_cursor_x
	; property 5 (x cursor): stored absolute, return window-relative 1-based.
	; The current window's cursor lives in zp while text is printed and is
	; only written back on a window switch, so the stored value is stale:
	; Shogun reads the cursor back after every centred line it prints.
	cpy current_window
	bne +
	ldx zp_screencolumn
+	txa
	sec
	sbc window_x,y
	tax
!if Z6_UNIT_W_SHIFT > 0 {
	jmp .gwp_scale ; the 1-based bias is a unit, added after scaling
} else {
	inx
	bne .gwp_scale ; Always branch
}
.gwp_cursor_y
	; property 4 (y cursor): stored absolute, return window-relative 1-based;
	; live in zp for the current window, as above
	cpy current_window
	bne +
	ldx zp_screenrow
+	txa
	sec
	sbc window_y,y
	tax
!if Z6_UNIT_W_SHIFT = 0 {
	inx
}
.gwp_scale
	; Properties 0-7 are positions, sizes and margins, all in units: they are
	; kept in cells, so scale on the way out. Which axis a property counts
	; along alternates - 0 y, 1 x, 2 y size, 3 x size, 4 y cursor, 5 x cursor,
	; 6 and 7 margins, which are horizontal - so bit 0 picks it, except for the
	; two margins, which are both across.
!if Z6_UNIT_W_SHIFT > 0 {
	; The four POSITIONS (0, 1, 4, 5) are 1-based, and once a cell is more
	; than one unit "1-based" means cell * font-size + 1, not the (cell + 1)
	; * font-size that biasing in cells produced: the first row of a window
	; is unit 1, not unit 8. It has to be this way round for the position to
	; survive a round trip, since units_to_cells_*_up takes the bias off again
	; - Shogun reads the cursor row back with get_wind_prop 4 and hands it
	; straight to set_cursor for every centred line of its title screen, and
	; the old pair of conventions cancelled out only while positions were
	; floored. Bit 1 of the property number separates them: clear for the four
	; positions, set for the two sizes and the two margins, which are counts
	; and carry no bias.
	lda z_operand_value_low_arr + 1
	and #2
	sta .gwp_bias			; 0 = a position, 2 = a count
	lda z_operand_value_low_arr + 1
	cmp #6
	bcs .gwp_across			; 6 and 7: both margins are horizontal
	and #1
	bne .gwp_across
	txa					; a y coordinate, size or cursor row
	jsr cells_to_units_y
	ldx .gwp_bias
	bne +					; a count: no bias
	clc
	adc #1					; 199 + 1 still fits a byte
+	tax
	jmp .gwp_store		; 'bra' would do, but this file builds for the 6510 too
.gwp_across
	txa
	jsr cells_to_units_x	; a = low, x = high; a column can pass 255
	ldy .gwp_bias
	bne +
	clc
	adc #1
	bcc +
	inx
+	tay
	txa
	pha
	tya
	tax
	pla
	jmp .gwp_store_high_in_a
}
.gwp_store
	lda #0
.gwp_store_high_in_a
!ifdef DEBUG_SCREENLOG {
	jsr screenlog_extra
}
	jmp z_store_result

.gwp_window !byte 0
!if Z6_UNIT_W_SHIFT > 0 {
.gwp_bias !byte 0	; 0 while a 1-based position is being scaled, 2 for a count
}
!ifdef Z6_PIXEL_UNITS {
.rm_col !byte 0		; read_mouse's column while it is scaled into units
}
!ifdef Z6_PIXEL_UNITS {
.gcur_row !byte 0	; get_cursor's answer while it is scaled into units
.gcur_col !byte 0,0	; (.gc_* is the X16 tile-store collector's)
}

z_ins_scroll_window
	; scroll_window window pixels
	; The header tells the game a character is one unit wide and one high, so
	; a pixel here is a character cell. A negative count scrolls the window
	; backwards, that is, down.
!ifdef TRACE_SCREEN {
	jsr print_following_string
	!pet "z_ins_scroll_window ",0
	jsr newline
}
	jsr printchar_flush ; buffered text belongs on screen before it moves
	jsr save_cursor
	ldx #0
	jsr window_from_operand
	sta .swin_window
	lda z_operand_value_high_arr + 1
	bmi .swin_backwards
	; forwards: the count is the operand, clamped to a byte
	beq +
	lda #255
	bne ++ ; always branch
+	lda z_operand_value_low_arr + 1
!ifdef Z6_PIXEL_UNITS {
	jsr units_to_cells_y	; the count is pixel rows, not text rows
}
++	ldx .swin_window
	clc ; scroll up
	jsr s_scroll_window
	jmp restore_cursor
.swin_backwards
	; backwards: the count is the negated operand, clamped to a byte
	lda #0
	sec
	sbc z_operand_value_low_arr + 1
	tay
	lda #0
	sbc z_operand_value_high_arr + 1
	beq +
	lda #255
	bne ++ ; always branch
+	tya
!ifdef Z6_PIXEL_UNITS {
	jsr units_to_cells_y	; the count is pixel rows, not text rows
}
++	ldx .swin_window
	sec ; scroll down
	jsr s_scroll_window
	jmp restore_cursor

.swin_window !byte 0

z_ins_pop_stack
	; pop_stack items [stack]
	; Throw away the top <items> values of the game stack, or, if a user
	; stack is given, just give its slots back.
!ifdef TRACE_SCREEN {
	jsr print_following_string
	!pet "z_ins_pop_stack ",0
	jsr newline
}
	lda z_operand_count
	cmp #2
	bcs .pop_user_stack
	ldx z_operand_value_low_arr
	beq .pop_stack_done
-	txa
	pha
	jsr stack_pull
	pla
	tax
	dex
	bne -
.pop_stack_done
	rts
.pop_user_stack
	; the first word of a user stack is the number of free slots
	jsr .read_user_stack_count
	lda .user_stack_lo
	clc
	adc z_operand_value_low_arr
	tay
	lda .user_stack_hi
	adc z_operand_value_high_arr
	sty .user_stack_lo
	sta .user_stack_hi
	jmp .write_user_stack_count

z_ins_push_stack
	; push_stack value stack ?(label)
	; Push value onto the user stack, branching if there was room.
!ifdef TRACE_SCREEN {
	jsr print_following_string
	!pet "z_ins_push_stack ",0
	jsr newline
}
	jsr .read_user_stack_count
	lda .user_stack_lo
	ora .user_stack_hi
	beq .user_stack_full
	; the value goes in the word at stack + 2 * free slots
	lda .user_stack_lo
	asl
	tay
	lda .user_stack_hi
	rol
	; add that to the address of the user stack
	pha
	tya
	clc
	adc z_operand_value_low_arr + 1
	tax
	pla
	adc z_operand_value_high_arr + 1
	jsr set_z_address
	lda z_operand_value_high_arr
	jsr write_next_byte
	lda z_operand_value_low_arr
	jsr write_next_byte
	; one slot fewer is free
	lda .user_stack_lo
	bne +
	dec .user_stack_hi
+	dec .user_stack_lo
	jsr .write_user_stack_count
	jmp make_branch_true
.user_stack_full
	jmp make_branch_false

.read_user_stack_count
	; read the free slot count from the user stack in operand 2
	ldx z_operand_value_low_arr + 1
	lda z_operand_value_high_arr + 1
	jsr set_z_address
	jsr read_next_byte
	sta .user_stack_hi
	jsr read_next_byte
	sta .user_stack_lo
	rts

.write_user_stack_count
	ldx z_operand_value_low_arr + 1
	lda z_operand_value_high_arr + 1
	jsr set_z_address
	lda .user_stack_hi
	jsr write_next_byte
	lda .user_stack_lo
	jmp write_next_byte

.user_stack_hi !byte 0
.user_stack_lo !byte 0

z_ins_read_mouse
	; read_mouse array: word 0 y, word 1 x, word 2 buttons, word 3 menu word
!ifdef TRACE_SCREEN {
	jsr print_following_string
	!pet "z_ins_read_mouse ",0
	jsr newline
}
	ldx z_operand_value_low_arr
	lda z_operand_value_high_arr
	jsr set_z_address
	lda #0
	jsr write_next_byte
!ifdef Z6_MOUSE {
!ifdef Z6_PIXEL_UNITS {
	; the pointer's cell, reported in units like every other coordinate. The
	; cell is all the mouse layer tracks, so this is the cell's top left
	; corner rather than the exact pixel under the pointer - good enough for
	; the games, which only ever ask which cell was clicked.
	lda mouse_cell_y
	sec
	sbc #1					; the stored cell is 1-based
	jsr cells_to_units_y
	clc
	adc #1
	jsr write_next_byte
	lda mouse_cell_x
	sec
	sbc #1
	jsr cells_to_units_x	; a = low, x = high
	clc
	adc #1
	sta .rm_col
	txa
	adc #0
	jsr write_next_byte		; the column's high byte
	lda .rm_col
	jsr write_next_byte
	lda #0
	jsr write_next_byte
	lda mouse_button	; bit 0 = button one held
	jsr write_next_byte ; buttons
} else {
	lda mouse_cell_y
	jsr write_next_byte ; y coordinate
	lda #0
	jsr write_next_byte
	lda mouse_cell_x
	jsr write_next_byte ; x coordinate
	lda #0
	jsr write_next_byte
	lda mouse_button	; bit 0 = button one held
	jsr write_next_byte ; buttons
}
} else {
	lda #1
	jsr write_next_byte ; y coordinate
	lda #0
	jsr write_next_byte
	lda #1
	jsr write_next_byte ; x coordinate
	lda #0
	jsr write_next_byte
	jsr write_next_byte ; buttons
}
	lda #0
	jsr write_next_byte
	jmp write_next_byte ; menu word

z_ins_mouse_window
	; mouse_window window: -1 (free) or a window number the mouse is confined to
!ifdef TRACE_SCREEN {
	jsr print_following_string
	!pet "z_ins_mouse_window ",0
	jsr newline
}
!ifdef Z6_MOUSE {
	lda z_operand_value_high_arr
	cmp #$ff			; -1 means free
	beq +
	lda z_operand_value_low_arr
	and #7
	sta mouse_window
	rts
+	lda #$ff
	sta mouse_window
}
	rts
 
z_ins_put_wind_prop
!ifdef DEBUG_SCREENLOG {
	lda #9
	jsr screenlog_hook
}
	; put_wind_prop window property-number value
	; Note: a game should only use put_wind_prop to set the
	; newline interrupt routine, the interrupt countdown and
	; the line count, everything else is either set by the
	; interpreter or by specialised opcodes (such as set_font)
!ifdef TRACE_SCREEN {
	jsr print_following_string
	!pet "z_ins_put_wind_prop ",0
	jsr newline
}
	ldx #0
	jsr window_from_operand
	sta .pwp_window
	lda z_operand_value_low_arr + 1
	asl ; * 8
	asl
	asl
	clc
	adc .pwp_window
	tay
	lda z_operand_value_low_arr + 2
!ifdef Z6_PIXEL_UNITS {
	; Properties 0-7 are positions, sizes and margins in units; the arrays keep
	; cells. The mirror of get_wind_prop's .gwp_scale: 0 and 1 are 1-based
	; POSITIONS and need the bias removed, 2-5 are counts, 6 and 7 are both
	; margins and both horizontal. Bit 0 picks the axis for 0-5. Everything
	; from 8 up is stored exactly as it came.
	sta .pwp_val
	lda z_operand_value_high_arr + 2
	sta .pwp_val + 1
	lda z_operand_value_low_arr + 1
	cmp #8
	bcs .pwp_raw
	cmp #6
	bcs .pwp_x				; 6, 7: the margins
	cmp #2
	bcc .pwp_position		; 0, 1: 1-based positions
	and #1
	beq .pwp_y				; 2, 4
	bne .pwp_x				; 3, 5
.pwp_position
	lda .pwp_val			; a zero means the same as a one - the top or left
	ora .pwp_val + 1		; edge - so it must not borrow into a huge number
	beq .pwp_zero
	lda .pwp_val
	sec
	sbc #1
	sta .pwp_val
	lda .pwp_val + 1
	sbc #0
	sta .pwp_val + 1
	lda z_operand_value_low_arr + 1
	and #1
	bne .pwp_pos_x
	; a position, like move_window's: round up to a cell boundary rather than
	; down, so it stays inside the window (see units_to_cells_x_up)
!ifdef Z6_FCM_TEXT_BAKE {
	lda .pwp_val
	jsr units_to_cells_y
} else {
	lda .pwp_val
	jsr units_to_cells_y_up
}
	jmp .pwp_scaled
.pwp_pos_x
	lda .pwp_val
	ldx .pwp_val + 1
	jsr units_to_cells_x_up
	jmp .pwp_scaled
.pwp_zero
	lda #0
	jmp .pwp_scaled
.pwp_y
	lda .pwp_val
	jsr units_to_cells_y
	jmp .pwp_scaled
.pwp_x
	lda .pwp_val
	ldx .pwp_val + 1
	jsr units_to_cells_x
	jmp .pwp_scaled
.pwp_raw
	lda .pwp_val
.pwp_scaled
}
	sta window_y,y
	lda z_operand_value_low_arr + 1
	cmp #15
	bne +
	; the line count (property 15) is a signed word: games park it at
	; -999 / 999 to manipulate [More] (z-spec 8.8.3.2.6)
	ldx .pwp_window
	lda z_operand_value_high_arr + 2
	sta window_linecount_hi,x
	rts
+	cmp #8
	bne +
	; the newline interrupt routine (property 8) is a packed address, a word
	ldx .pwp_window
	lda z_operand_value_high_arr + 2
	sta window_newline_routine_hi,x
+	rts

.pwp_window !byte 0
!ifdef Z6_PIXEL_UNITS {
.pwp_val !byte 0,0	; the value being converted out of units
}
 
z_ins_print_form
	; print_form formatted-table
	; The table is a sequence of lines, terminated by a zero word. Each line
	; is a word holding a character count, followed by that many ZSCII bytes.
!ifdef TRACE_SCREEN {
	jsr print_following_string
	!pet "z_ins_print_form ",0
	jsr newline
}
	lda z_operand_value_high_arr
	ldx z_operand_value_low_arr
	jsr set_z_address
.pf_next_line
	jsr read_next_byte
	sta .pf_count + 1
	jsr read_next_byte
	sta .pf_count
	ora .pf_count + 1
	beq .pf_done ; a zero word ends the table
-	jsr read_next_byte
	jsr streams_print_output
	lda .pf_count
	bne +
	dec .pf_count + 1
+	dec .pf_count
	lda .pf_count
	ora .pf_count + 1
	bne -
	lda #13
	jsr streams_print_output
	jmp .pf_next_line
.pf_done
	rts

.pf_count !byte 0,0

z_ins_make_menu
	; make_menu number table ?(label)
!ifdef TRACE_SCREEN {
	jsr print_following_string
	!pet "z_ins_make_menu ",0
	jsr newline
}
	jmp make_branch_false
 
z_ins_picture_table
	; picture_table table
!ifdef TRACE_SCREEN {
	jsr print_following_string
	!pet "z_ins_picture_table ",0
	jsr newline
}
	rts

;init_screen_colours_invisible
;	lda zcolours + BGCOL
;	bpl + ; Always branch
init_screen_colours
	jsr s_init
	; calculate the position for the more prompt
	; (self modifying code since we don't want to
	; ZP space is limited)
!ifndef TARGET_X16 {
	lda s_screen_size + 1
	clc
	adc #>SCREEN_ADDRESS
	sta .more_access1 + 2
	sta .more_access2 + 2
	sta .more_access4 + 2
!ifndef Z6_FCM_MODE {
	; (under FCM the [More] colour cell goes through zp_more_colour, which
	; .set_more_prompt_pos sets before every use, so there is nothing to
	; initialize here)
	lda s_screen_size + 1
	clc
	adc #>COLOUR_ADDRESS
!ifndef BENCHMARK {
	sta .more_access3 + 2
}
}
	lda s_screen_size
	sec
	sbc #1
	sta .more_access1 + 1
	sta .more_access2 + 1
!ifndef BENCHMARK {
!ifndef Z6_FCM_MODE {
	sta .more_access3 + 1
}
}
	sta .more_access4 + 1
}
	; colours
!ifdef NODARKMODE {
	lda zcolours + FGCOL
!if BORDERCOL_FINAL = 1 {
	+SetBorderColour
}
+	jsr s_set_text_colour
	lda zcolours + BGCOL
	+SetBackgroundColour
!if BORDERCOL_FINAL = 0 {
	+SetBorderColour
} else {
	!if BORDERCOL_FINAL != 1 {
		lda zcolours + BORDERCOL_FINAL
		+SetBorderColour
	}
}
!if CURSORCOL = 1 {
	lda zcolours + FGCOL
} else {
	lda zcolours + CURSORCOL
}
	sta current_cursor_colour
!ifdef Z5PLUS {
	; store default colours in header
	lda #BGCOL ; blue
	ldy #header_default_bg_colour
	jsr write_header_byte
	lda #FGCOL ; white
	ldy #header_default_fg_colour
	jsr write_header_byte
}
} else { ; Darkmode is available
	lda darkmode
	eor #1
	sta darkmode
	jsr toggle_darkmode
}
	lda #147 ; clear screen
	jmp s_printchar
; !ifndef NODARKMODE {
	; lda darkmode
	; beq +
	; dec darkmode
	; jmp toggle_darkmode
; +	
; }
;	rts	

!ifdef Z4PLUS {
z_ins_erase_window
!ifdef DEBUG_SCREENLOG {
	lda #5
	jsr screenlog_hook
}
	; erase_window window (0-7, -1 = unsplit + clear screen, -2 = clear screen)
	jsr printchar_flush
	jsr save_cursor
	ldx z_operand_value_low_arr
	cpx #$fe
	bcs +	; -1 / -2: the whole screen
	; a window: -3 is the current one (z-spec 8.8.3) -- Arthur erases its
	; parser-message window that way; taking the raw $fd used to index the
	; window arrays 253 bytes out
	ldx #0
	jsr window_from_operand
	tax
+
;    jmp erase_window ; Not needed, since erase_window follows
}

erase_window
	; x = window number, $ff (-1) or $fe (-2)
	cpx #$fe
	bcs .erase_whole_screen
	; erase a single window (0-7)
	jsr .erase_window_rect
	ldx .rect_win
!ifdef TARGET_X16 {
!ifdef Z6_PICTURES {
	; the picture layer behind the text must be erased too; the text layer
	; cannot bury it the way a one-plane screen does
	jsr pic_erase_win_rect
	ldx .rect_win
}
}
	jmp .home_cursor
.erase_whole_screen
	cpx #$ff
	bne +
	; -1: unsplit - window 0 fills the screen and is selected
	lda #0
	sta current_window
	sta window_y
	sta window_x
	lda s_screen_height
	sta window_y_size
	lda s_screen_width
	sta window_x_size
+
!ifdef Z6_ECM_MODE {
	jsr ecm_update_bits
}
	lda #147 ; clear screen
	jsr s_printchar
!ifdef TARGET_X16 {
!ifdef Z6_PICTURES {
	jsr pic_erase_screen
}
}
	ldx current_window
.home_cursor
	; move the erased window's cursor to its top left corner, inside the
	; left margin (the cursor always lies between the margins, see 8.8.3.2.2.1)
	lda window_y,x
	sta window_y_cursor,x
	jsr s_window_left_edge
	sta window_x_cursor,x
	lda #0
	sta window_linecount,x ; the window is empty again
	sta window_linecount_hi,x
	; put the live cursor back where the current window wants it
	jsr restore_cursor
	jmp start_buffering

.erase_window_rect
	; erase the screen rectangle of window x (fills it with spaces
	; using s_delete_cursor so all targets work), in that window's own
	; colours - erase_window can name a window that is not the current one
	stx .rect_win
!ifdef Z6_ECM_MODE {
	jsr ecm_set_bits_for_window ; fill with this window's background colour
	ldx .rect_win
}
!ifdef Z6_WINDOW_BG {
	; per-cell backgrounds: erase_window can name a window that is not the
	; current one (a game dressing a window before showing it, which is what
	; set_colour's window operand is for), and it must be filled with its own
	; background, not with whatever the current window prints in. The current
	; window's own pair is already live, so only another window needs this -
	; and .rect_done hands the live colours back.
	cpx current_window
	beq +
	jsr x16_apply_colour_for_window
	ldx .rect_win
+
}
!ifdef Z6_FCM_WINDOW_BG {
	; the same on the full colour screen, where the background is a baked tile
	cpx current_window
	beq +
	jsr fcm_paper_for_window
	ldx .rect_win
+
}
	lda window_y_size,x
	beq .rect_done
	sta .rect_rows_left
	lda window_y,x
	sta zp_screenrow
.rect_row_loop
	lda zp_screenrow
	cmp s_screen_height
	bcs .rect_done
	ldx .rect_win
	lda window_x_size,x
	beq .rect_done
	sta .rect_cols_left
	ldy window_x,x
	ldx zp_screenrow
	clc
	jsr s_plot ; set row/column and update screen pointers
.rect_col_loop
	ldy zp_screencolumn
	jsr s_delete_cursor ; writes a space at the cursor position
	inc zp_screencolumn
	dec .rect_cols_left
	bne .rect_col_loop
	inc zp_screenrow
	dec .rect_rows_left
	bne .rect_row_loop
.rect_done
!ifdef Z6_ECM_MODE {
	jmp ecm_update_bits ; back to the current window's background colour
}
!ifdef Z6_WINDOW_BG {
	lda .rect_win
	cmp current_window
	beq +
	jmp x16_apply_window_colour ; back to the current window's own pair
+
}
!ifdef Z6_FCM_WINDOW_BG {
	lda .rect_win
	cmp current_window
	beq +
	jmp fcm_update_paper ; back to the current window's own background
+
}
	rts

.rect_win       !byte 0
.rect_rows_left !byte 0
.rect_cols_left !byte 0

!ifdef Z4PLUS {
z_ins_erase_line
	; erase_line value
	; Value 1 erases from the cursor to the window's right margin. Any other
	; value erases value-1 pixels - character cells here - to the right of
	; the cursor, clipped at the right margin (8.8.5.2); the cursor does not
	; move. Journey repaints its command menu by erasing each cell this way
	; (erase_line G82) before printing the new command into it, so the old
	; do-nothing left "Enter" printed over "Background".
	jsr printchar_flush ; pending text belongs on screen before the erase
	lda z_operand_value_low_arr
	ora z_operand_value_high_arr
	beq .el_done ; erase_line 0: nothing to erase
	ldx current_window
	jsr s_window_right_edge
	sec
	sbc zp_screencolumn
	beq .el_done
	bcc .el_done ; the cursor already sits past the right margin
	sta .el_count ; the cells from the cursor to the margin
	lda z_operand_value_high_arr
	bne .el_clipped ; 256 units or more always reaches the margin
	ldx z_operand_value_low_arr
	cpx #1
	beq .el_clipped ; 1: all the way to the margin
	dex
	txa ; value - 1 units wanted
!ifdef Z6_PIXEL_UNITS {
	ldx #0					; high byte: the 256-and-over case branched away
	jsr units_to_cells_x
}
	cmp .el_count
	bcs .el_clipped
	sta .el_count
.el_clipped
!ifdef Z6_PICTURES {
!ifdef TARGET_X16 {
	; also clear the layer 0 picture cells under the erased run, so a picture
	; behind the text does not survive the erase (as erase_window already does)
	lda zp_screenrow
	ldx zp_screencolumn
	ldy .el_count
	jsr pic_erase_line_cells
}
}
	; walk the cells with s_delete_cursor, each target's space-writer (it
	; wants the column in y), and put the cursor back where it was
	lda zp_screencolumn
	pha
	tay
	ldx zp_screenrow
	clc
	jsr s_plot ; sync the screen pointers to the cursor
-	ldy zp_screencolumn
	jsr s_delete_cursor
	inc zp_screencolumn
	dec .el_count
	bne -
	pla
	tay
	ldx zp_screenrow
	clc
	jsr s_plot
.el_done
	rts

.el_count !byte 0

!ifdef Z5PLUS {
.pt_cursor = z_temp;  !byte 0,0
.pt_width = z_temp + 2 ; !byte 0
.pt_height = z_temp + 3; !byte 0
.pt_skip = z_temp + 4; !byte 0,0
.current_col = z_temp + 6; !byte 0

z_ins_print_table
	; print_table zscii-text width [height = 1] [skip]
	; ; defaults
	lda #1
	sta .pt_height
	lda #0
	sta .pt_skip
	sta .pt_skip + 1
	; Read args
	lda z_operand_value_low_arr + 1
	beq .print_table_done
	sta .pt_width
	ldy z_operand_count
	cpy #3
	bcc ++
	lda z_operand_value_low_arr + 2
	beq .print_table_done
	sta .pt_height
+   cpy #4
	bcc ++
	lda z_operand_value_low_arr + 3
	sta .pt_skip
	lda z_operand_value_high_arr + 3
	sta .pt_skip + 1
++	lda .pt_height
	cmp #1
	beq .print_table_oneline
; start printing multi-line table
	jsr printchar_flush
	jsr get_cursor ; x=row, y=column
	stx .pt_cursor
	sty .pt_cursor + 1
	lda z_operand_value_high_arr ; Start address
	ldx z_operand_value_low_arr
--	jsr set_z_address
	ldx .pt_cursor + 1
	stx .current_col
	ldy .pt_width
-	jsr read_next_byte
	ldx .current_col
	cpx s_screen_width
	bcs +
	jsr streams_print_output
+	inc .current_col
	dey
	bne -
	dec .pt_height
	beq .print_table_done
; Move cursor to start of next line to print
	inc .pt_cursor
	ldx .pt_cursor
	ldy .pt_cursor + 1
	jsr set_cursor
; Skip the number of bytes requested
	jsr get_z_address
	pha
	txa
	clc
	adc .pt_skip
	tax
	pla
	adc .pt_skip + 1
	bcc -- ; Always jump
.print_table_done	
	rts
.print_table_oneline
	; The characters must go through the stream layer: Shogun measures its
	; menu items by print_table-ing them into stream 3 and reading the width
	; back from the header. Printing straight to the screen here both left
	; the width at zero and leaked the text onto the screen.
	lda z_operand_value_high_arr ; Start address
	ldx z_operand_value_low_arr
	jsr set_z_address
	ldy .pt_width
-	jsr read_next_byte
	sty .pt_cursor ; borrow as scratch: streams_print_output clobbers y
	jsr streams_print_output
	ldy .pt_cursor
	dey
	bne -
	rts
}

z_ins_buffer_mode 
	; buffer_mode flag
	; If buffer mode goes from 0 to 1, remember the start column
	; If buffer mode goes from 1 to 0, flush the buffer 
	
	lda z_operand_value_low_arr
	beq +
	lda #1
+	cmp is_buffered_window
	beq .buffer_mode_done
; Buffer mode changes
	sta is_buffered_window ; set lower window to buffered or unbuffered mode
	cmp #0
	bne start_buffering
	jsr printchar_flush
.buffer_mode_done
	rts

}

start_buffering
	; the buffer always belongs to the current window, and buffer
	; positions are absolute screen columns
	jsr get_cursor ; y = column
	sty first_buffered_column
	sty buffer_index
	ldy #0
	sty last_break_char_buffer_pos
	rts

z_ins_split_window
	; split_window lines
!ifdef DEBUG_SCREENLOG {
	lda #14
	jsr screenlog_hook
}
!ifdef Z6_PIXEL_UNITS {
	; z-spec, split_window: in Version 6 "the line count is in units rather than
	; lines". All three v6 games that use the opcode compute it that way -
	; Arthur and Journey multiply a line count by the font height they read from
	; the header, Zork Zero passes a picture's height in pixels - so the count
	; has to be divided back down to rows here. Left as a row count, an ordinary
	; ten-line split asked for the whole screen: window 1 took all 25 rows,
	; window 0's top row landed on the screen height, and print_line_from_buffer
	; then found "no free line to print on" and threw every buffered line away.
	; Round up, because a size must contain what was asked for, and because a
	; game written to the v5 model (PunyInform's status line asks for 1) would
	; otherwise get no window at all.
	ldx s_screen_height			; more units than the screen holds
	lda z_operand_value_high_arr
	bne +
	lda z_operand_value_low_arr
	clc
	adc #Z6_UNIT_H - 1
	bcs +
	jsr units_to_cells_y
	tax
+
} else {
	ldx z_operand_value_low_arr
}
;    jmp split_window ; Not needed since split_window follows

split_window
!ifdef SMOOTHSCROLL {
	jsr wait_smoothscroll
}
	; x = number of lines for window 1 at the top; 0 = unsplit
	; both windows become full width (v6 behaviour of this opcode)
	cpx s_screen_height
	bcc +
	ldx s_screen_height
+
!ifdef Z6_PICTURES {
!ifdef TARGET_X16 {
	; Window 1 is about to take the top rows off window 0. On the X16 the
	; pictures live behind the text on layer 0, so whatever window 0 had drawn
	; there stays put - and window 0 will never scroll or erase those rows
	; again, so it would show through window 1 for ever. (It shows through even
	; opaque-looking text: a reverse-video field is drawn in the foreground
	; colour, and VERA renders palette index 0 - black - as transparent, which
	; is exactly what a status line prints.) Clear layer 0 under the rows
	; window 1 has just gained. Shrinking window 1 gives rows back to window 0,
	; which erases and scrolls them itself, so only growth needs this.
	stx .spw_new_height
	lda window_y_size + 1	; the old height = the first row newly gained
	cmp .spw_new_height
	bcs .spw_no_clear
	ldx .spw_new_height
	jsr pic_clear_map_rows	; a = first row, x = row past the last
	ldx .spw_new_height
.spw_no_clear
}
}
	stx window_y_size + 1
	stx window_y
	lda #0
	sta window_y + 1
	sta window_x
	sta window_x + 1
	lda s_screen_width
	sta window_x_size
	sta window_x_size + 1
	lda s_screen_height
	sec
	sbc window_y
	sta window_y_size
	lda current_window
	beq .ensure_cursor_in_window
	cmp #1
	bne .do_nothing
	; Window 1 was selected => Reset cursor if outside window
	jsr get_cursor
	cpx window_y ; window 0's top row = bottom edge of window 1
	bcc .do_nothing
	ldx #0
	ldy #0
	jmp set_cursor
.do_nothing
	rts
.ensure_cursor_in_window
	jsr get_cursor
	cpx window_y
	bcs .do_nothing
	ldx window_y
	ldy #0
	jmp set_cursor

!ifdef Z6_PICTURES {
!ifdef TARGET_X16 {
.spw_new_height !byte 0
}
}

z_ins_set_window
!ifdef DEBUG_SCREENLOG {
	lda #6
	jsr screenlog_hook
}
	;  set_window window
	jsr printchar_flush ; the print buffer belongs to the old window
	jsr save_cursor
	lda z_operand_value_low_arr
	and #7
	sta current_window
!ifdef Z6_ECM_MODE {
	jsr ecm_update_bits ; print in the new window's background colour
}
!ifdef Z6_WINDOW_BG {
	jsr x16_apply_window_colour ; each window keeps its own background
}
!ifndef Z6_ECM_MODE {
!ifndef Z6_WINDOW_BG {
	jsr apply_window_swap ; each window keeps its own reverse-video state
}
}
	jsr restore_cursor ; each window keeps its own cursor
	jmp start_buffering

!ifdef Z4PLUS {
z_ins_set_text_style
	lda z_operand_value_low_arr
	bne .t0
	; roman
	lda #146 ; reverse off
	jmp s_printchar
.t0 cmp #1
	bne .do_nothing
	lda #18 ; reverse on
	jmp s_printchar

z_ins_get_cursor
	; get_cursor array
	; returns the cursor position of the current window,
	; window-relative and 1-based
	jsr printchar_flush ; pending text belongs on screen before reading cursor position
	ldx z_operand_value_low_arr
	lda z_operand_value_high_arr
	jsr set_z_address
	jsr get_cursor ; x=row, y=column (absolute, 0-based)
	txa
	ldx current_window
	sec
	sbc window_y,x
	pha
	tya
	sec
	sbc window_x,x
	tay
	iny ; In Z-machine, cursor has position 1+
	pla
	tax
	inx ; In Z-machine, cursor has position 1+
!ifdef Z6_PIXEL_UNITS {
	; the same position in units: the cell scaled, then made 1-based again
	dex
	txa
	jsr cells_to_units_y
	sta .gcur_row
	dey
	tya
	jsr cells_to_units_x	; a = low, x = high; a column can pass 255
	clc
	adc #1
	sta .gcur_col
	txa
	adc #0
	sta .gcur_col + 1
	lda #0
	jsr write_next_byte
	lda .gcur_row
	clc
	adc #1
	jsr write_next_byte
	lda .gcur_col + 1
	jsr write_next_byte
	lda .gcur_col
	jmp write_next_byte
} else {
	lda #0
	jsr write_next_byte
	txa
	jsr write_next_byte
	lda #0
	jsr write_next_byte
	tya
	jmp write_next_byte
}

z_ins_set_cursor
!ifdef DEBUG_SCREENLOG {
	lda #1
	jsr screenlog_hook
}
	; set_cursor line column [window]
	; coordinates are 1-based and relative to the window
	ldy current_window
	lda z_operand_count
	cmp #3
	bcc +
	ldx #2
	jsr window_from_operand ; y = window; handles -3 = the current one
+	; y = window to move the cursor in
	; a negative line selects the cursor's visibility (z-spec 8.7.2.3, v6):
	; -1 hides it, -2 shows it again. Shogun hides it over its menus, where
	; a drawn-and-deleted cursor would eat the selected item's first letter.
	lda z_operand_value_high_arr
	bpl .sc_position
	lda z_operand_value_low_arr
	cmp #$ff
	bne +
	lda #1
	sta cursor_hidden
+	cmp #$fe
	bne ++
	lda #0
	sta cursor_hidden
++	rts
.sc_position
	; pending buffered text belongs where the current window's cursor was,
	; so put it there before the move (Shogun centres every credit line with
	; set_cursor and prints it buffered)
	cpy current_window
	bne +
	jsr printchar_flush
	ldy current_window
+
!ifdef Z6_PIXEL_UNITS {
	lda z_operand_value_low_arr ; the line, in units
	beq +						; 0 is a mistake - they mean line 1
	sec
	sbc #1
!ifdef Z6_FCM_TEXT_BAKE {
	pha							; keep the 0-based line in units for its remainder
	jsr units_to_cells_y	; floor: the remainder below is drawn, not lost
} else {
	jsr units_to_cells_y_up
}
+	clc
	adc window_y,y
	sta window_y_cursor,y
!ifdef Z6_FCM_TEXT_BAKE {
	; the text baseline's sub-cell y = the window origin's remainder plus this
	; line's own, carrying a full cell down into the cursor row when they sum to
	; eight or more (units_to_cells_y floored each separately)
	lda z_operand_value_low_arr
	beq .sc_sub_origin			; line 0/1: sits at the window origin's remainder
	pla
	and #7
	clc
	adc window_y_sub,y
	cmp #8
	bcc .sc_sub_store
	sec
	sbc #8					; carried a full cell: the text is one row lower
	pha
	lda window_y_cursor,y
	clc
	adc #1
	sta window_y_cursor,y	; (no inc abs,y on the 6502)
	pla
	jmp .sc_sub_store
.sc_sub_origin
	lda window_y_sub,y
.sc_sub_store
	sta text_y_sub,y
}
} else {
	ldx z_operand_value_low_arr ; line 1..
	beq + ; If line is 0, it's a mistake - they mean line 1.
	dex ; line 0..
+	txa
	clc
	adc window_y,y
	sta window_y_cursor,y
}
	; The column is a signed word, and a game can legitimately ask for one
	; off the screen: Shogun centres each credit line with
	; set_cursor row, (window_width - measured_width) / 2 + 1, which goes
	; negative when the line is wider than the screen. Two of its title
	; lines measure 54 and 48 units, so at 40 columns it asks for columns
	; -6 and -3. Reading the low byte alone made those columns 250 and 253:
	; buffer positions are absolute screen columns and print_buffer only
	; holds SCREEN_WIDTH + 1 of them, so the credits printed straight
	; through the 6502 stack at $100 and the machine reset. Clamp into the
	; screen instead - the line then starts at the left edge and wraps.
	lda z_operand_value_high_arr + 1
	bmi .sc_column_left ; negative: clamp to the window's left edge
!ifdef Z6_PIXEL_UNITS {
	; A column in units runs to 320, so unlike the cell model a high byte of 1
	; is ordinary rather than out of range - only past the screen is. The
	; clamps either side stay: Shogun centres its credit lines with
	; set_cursor row, (width - measured) / 2 + 1 and legitimately asks for a
	; negative column, which once printed through the 6502 stack (see below).
	cmp #>(SCREEN_WIDTH * Z6_UNIT_W)
	bcc .sc_col_units
	bne .sc_column_right
	lda z_operand_value_low_arr + 1
	cmp #<(SCREEN_WIDTH * Z6_UNIT_W)
	bcs .sc_column_right
.sc_col_units
	lda z_operand_value_low_arr + 1
	ora z_operand_value_high_arr + 1
	beq .sc_column_left		; column 0 is a mistake - they mean column 1
	lda z_operand_value_low_arr + 1
	sec
	sbc #1
	sta .sc_tmp
	lda z_operand_value_high_arr + 1
	sbc #0
	tax
	lda .sc_tmp
	jsr units_to_cells_x_up
	tax
	jmp .sc_column_add
} else {
	bne .sc_column_right ; 256 or more: clamp to the right edge
	ldx z_operand_value_low_arr + 1 ; column 1..
	beq .sc_column_left ; column 0 is a mistake - they mean column 1
	dex ; column 0..
	jmp .sc_column_add
}
.sc_column_left
	ldx #0
.sc_column_add
	txa
	clc
	adc window_x,y
	bcs .sc_column_right ; wrapped past the end of the screen
	cmp s_screen_width
	bcc .sc_column_store
.sc_column_right
	lda s_screen_width_minus_one
.sc_column_store
	sta window_x_cursor,y
	cpy current_window
	bne .do_nothing_2
	jsr restore_cursor ; make the move visible immediately
	jmp start_buffering ; the print buffer starts afresh at the new position
}

init_window_colours
	; every window starts in the default colours (property 11: background
	; in the high nybble, foreground in the low, as z-colour numbers)
	ldx #7
	lda #(BGCOL << 4) | FGCOL
-	sta window_colour,x
	dex
	bpl -
!ifndef Z6_ECM_MODE {
	lda #0
	sta s_colour_swap
	lda #BGCOL
	sta s_bg_zcolour
	lda #FGCOL
	sta s_fg_zcolour	; the screen's own pair; a swap is its exact reverse
!ifndef Z6_WINDOW_BG {
	lda #0
	ldx #7
-	sta window_swap,x ; every window starts un-swapped
	sta window_fg_set,x ; ...and with no foreground colour of its own
!ifdef Z6_FCM_TEXT_BAKE {
	sta window_bake,x ; ...and opaque, until a game asks for transparent text
	sta window_y_sub,x ; ...on the cell grid, no sub-cell y offset yet
	sta text_y_sub,x
}
	dex
	bpl -
}
}
!ifdef Z6_WINDOW_BG {
	jsr x16_apply_window_colour ; window 0's default background, ready to print
!ifdef Z6_PICTURES {
	ldx #BGCOL
	lda zcolours,x
	sta x16_screen_bg ; the default screen background pictures show through
}
}
	rts

clear_num_rows
	; every window counts its own printed lines (property 15)
	lda #0
	ldx current_window
	sta window_linecount,x
	sta window_linecount_hi,x
.do_nothing_2
	rts

.window_rows_minus_one
	; a = number of lines in the current window, minus one
	; y = current window. x is preserved.
	ldy current_window
	lda window_y,y
	clc
	adc window_y_size,y
	cmp s_screen_height
	bcc +
	lda s_screen_height
+	sec
	sbc window_y,y
	sec
	sbc #1
	rts

!ifdef TARGET_C128 {
; The VDC's screen RAM is not in the CPU's address space, so the addresses
; .set_more_prompt_pos patches into .more_access1-4 are useless in 80 columns:
; these two hold the same cell's VDC addresses instead, characters at $0000 and
; attributes at $0800. They are set from the current window's bottom right cell
; by .set_more_prompt_pos; the defaults are the bottom right of the screen.
.vdc_more_char_addr   !byte $cf, $07
.vdc_more_colour_addr !byte $cf, $0f
.vdc_more_text_colour !byte 0

vdc_set_more_char_address
    lda .vdc_more_char_addr
    ldy .vdc_more_char_addr + 1
    jmp VDCSetAddress

vdc_set_more_colour_address
    lda .vdc_more_colour_addr
    ldy .vdc_more_colour_addr + 1
    jmp VDCSetAddress

vdc_save_more_cell
	; Remember what the prompt covered, character and attribute. This must NOT
	; be part of vdc_show_more, which is where it used to live: the blink calls
	; show on every other pass, so the second call saved the '*' it had written
	; itself. The prompt then "blinked" between the asterisk and the asterisk,
	; and vdc_hide_more put an asterisk back when the key was pressed - which is
	; the '*' left in the corner of Arthur's screen on the C128's 80 column
	; screen. (The other targets save the cell once, outside the loop, and the
	; VIC-II ones alternate only the colour.)
	jsr vdc_set_more_char_address
	ldx #VDC_DATA
	jsr VDCReadReg
	sta .more_text_char
	jsr vdc_set_more_colour_address
	ldx #VDC_DATA
	jsr VDCReadReg
	sta .vdc_more_text_colour
	rts

vdc_show_more
	; character
	jsr vdc_set_more_char_address
	lda #128 + $2a ; screen code for reversed "*"
	ldx #VDC_DATA
	jsr VDCWriteReg
	; colour
	jsr vdc_set_more_colour_address
	ldy s_colour
	lda vdc_vic_colours,y
	ldx #VDC_DATA
	jmp VDCWriteReg

vdc_hide_more
	; the other half of the blink, and the last thing the prompt does: the cell
	; exactly as it was, attribute included - vdc_show_more overwrote that with
	; the text colour
	jsr vdc_set_more_char_address
	lda .more_text_char
	ldx #VDC_DATA
	jsr VDCWriteReg
	jsr vdc_set_more_colour_address
	lda .vdc_more_text_colour
	ldx #VDC_DATA
	jmp VDCWriteReg
}

!ifdef TARGET_X16 {

.vera_more_temp !byte 0
; The prompt's cell, set by .set_more_prompt_pos: in z6 it is the bottom right
; cell of the current window, not of the screen.
.vera_more_row !byte 0
.vera_more_col !byte 0
vera_show_more
	sty .vera_more_temp
	lda .vera_more_row
	sta zp_screenline + 1
	lda #$2a + 128
	bne .vera_common_more ; Always branch

.vera_common_more
	ldy .vera_more_col
	jsr VERAPrintChar
	; lda s_colour
	; jsr VERAPrintColourAfterChar
	lda zp_screenrow
	sta zp_screenline + 1
	ldy .vera_more_temp
	rts

vera_save_more_cell
	; Remember the prompt cell's character AND its colour byte. The colour is
	; the point: over a picture, pic_fill_cells leaves the cell's background
	; nybble at 0 - the transparent one that lets layer 0 show through - and
	; VERAPrintChar always writes vera_composite_colour, so the prompt turned
	; the cell into an opaque box of the window's background. Writing a space
	; when the prompt was done left that box behind, which is how Shogun's ship
	; lost the cell the [More] prompt had used.
	jsr .vera_more_address
	lda VERA_data0			; port 0 is selected with stride 1 throughout
	sta .vera_more_char
	lda VERA_data0
	sta .vera_more_colour
	rts

vera_hide_more
	; The other half of the blink, and the last thing the prompt does: put the
	; cell back exactly as it was, so a picture behind it reappears.
	jsr .vera_more_address
	lda .vera_more_char
	sta VERA_data0
	lda .vera_more_colour
	sta VERA_data0
	rts

.vera_more_address
	; Point port 0 at the prompt's cell. A VERA text cell is two bytes and a
	; row is 256 whatever the width, so the row is the address high byte and
	; the column never carries into it (the same arithmetic
	; .convert_screenline_y_to_vera_address does, which is local to
	; screenkernal-z6.asm). The screen code's standing convention leaves port 0
	; selected with stride 1, so the bank register is already right.
	lda .vera_more_col
	asl
	sta VERA_addr_low
	lda .vera_more_row
	adc #$b0				; the carry is clear after the asl
	sta VERA_addr_high
	rts

.vera_more_char   !byte 0
.vera_more_colour !byte 0
}



!ifdef ZORK0_MSDOS_QUIRK {
nl_interrupt_pending !byte 0
nl_fire_pending
	; the countdown ran out earlier in this newline; now that the cursor
	; sits on the new line, call the routine (8.8.3.2.2.1)
	lda nl_interrupt_pending
	beq +
	lda #0
	sta nl_interrupt_pending
	ldx current_window
	jmp fire_newline_interrupt
+	rts
}

fire_newline_interrupt
	; x = the window whose interrupt countdown just reached zero. Call the
	; routine whose packed address is window property 8, exactly like a
	; timed-input interrupt (stack_call_routine mode $80 + z_execute). We
	; are in the middle of printing, so everything the print relies on is
	; saved around the call: the string position and zchar decode state,
	; the operand array (the nested instructions rewrite it), the z_temp
	; scratch, and the print buffer's indices - neutralized so a nested
	; printchar_flush (set_margins does one now) cannot reprint the line
	; being wrapped. The routine must not print (8.8.3.2.2); it exists to
	; meddle with margins, which is all Zork Zero's and Shogun's do.
	lda window_newline_routine,x
	sta .nli_routine
	lda window_newline_routine_hi,x
	sta .nli_routine + 1
	ora .nli_routine
	beq .nli_done ; no routine to call
	ldx #.nli_zp_bytes - 1
-	ldy .nli_zp_list,x
	lda $0000,y
	sta .nli_save,x
	dex
	bpl -
	lda first_buffered_column
	sta .nli_first
	lda buffer_index
	sta .nli_index
	lda first_buffered_column
	sta buffer_index ; an empty buffer: a nested flush is a no-op
	; call the routine and run it to completion, like text.asm's timers
	lda .nli_routine
	sta z_operand_value_low_arr
	lda .nli_routine + 1
	sta z_operand_value_high_arr
	lda #z_exe_mode_return_from_read_interrupt
	ldx #0
	ldy #0
	jsr stack_call_routine
	jsr z_execute
	ldx #.nli_zp_bytes - 1
-	ldy .nli_zp_list,x
	lda .nli_save,x
	sta $0000,y
	dex
	bpl -
	lda .nli_first
	sta first_buffered_column
	lda .nli_index
	sta buffer_index
!ifdef TARGET_X16 {
	jsr x16_bank_z_address ; z_address is restored: rebank, as print_addr does
}
.nli_done
	rts

.nli_zp_list
	!byte z_operand_count
	!byte z_operand_value_high_arr + 0, z_operand_value_high_arr + 1
	!byte z_operand_value_high_arr + 2, z_operand_value_high_arr + 3
	!byte z_operand_value_high_arr + 4, z_operand_value_high_arr + 5
	!byte z_operand_value_high_arr + 6, z_operand_value_high_arr + 7
	!byte z_operand_value_low_arr + 0, z_operand_value_low_arr + 1
	!byte z_operand_value_low_arr + 2, z_operand_value_low_arr + 3
	!byte z_operand_value_low_arr + 4, z_operand_value_low_arr + 5
	!byte z_operand_value_low_arr + 6, z_operand_value_low_arr + 7
	!byte zchar_triplet_cnt
	!byte packed_text, packed_text + 1
	!byte alphabet_offset
	!byte escape_char, escape_char_counter
	!byte abbreviation_command
	!byte z_address, z_address + 1, z_address + 2
	!byte z_address_temp
	!byte zchars, zchars + 1, zchars + 2
	!byte z_temp + 0, z_temp + 1, z_temp + 2,  z_temp + 3
	!byte z_temp + 4, z_temp + 5, z_temp + 6,  z_temp + 7
	!byte z_temp + 8, z_temp + 9, z_temp + 10, z_temp + 11
	!byte last_break_char_buffer_pos
.nli_zp_bytes = * - .nli_zp_list

.nli_save    !fill .nli_zp_bytes, 0
.nli_routine !byte 0, 0
.nli_first   !byte 0
.nli_index   !byte 0

increase_num_rows
	; 8.8.3.2.2: a nonzero interrupt countdown is decremented on each
	; new-line, and when it reaches zero the routine in property 8 is called
	; before printing resumes - Zork Zero and Shogun roll their text around
	; a picture this way, resetting the margins from the routine once the
	; picture's rows are past.
	ldx current_window
	lda window_newline_countd,x
	beq +
	dec window_newline_countd,x
	bne +
!ifdef ZORK0_MSDOS_QUIRK {
	; interpreter 6 running Zork Zero r393.890714 must fire only after the
	; cursor has moved to the new line (8.8.3.2.2.1) - the game sets its
	; countdown one lower on this interpreter and expects the late margins
	lda #1
	sta nl_interrupt_pending
} else {
	jsr fire_newline_interrupt
	ldx current_window
}
+
	lda window_attributes,x
	and #WIN_BUFFERED
	beq .inr_done ; An unbuffered window never shows [More]
	inc window_linecount,x
	bne +
	inc window_linecount_hi,x
+	lda window_attributes,x
	and #WIN_SCROLLING
	beq .inr_done ; only a scrolling window pauses with [More]: nothing
	              ; is carried off one that stays put (Arthur's one-line
	              ; parser message window used to [More] here)
	lda is_buffered_window
	beq .inr_done
	; the line count is a signed word the game manipulates (8.8.3.2.6):
	; negative means a screenful is still far off, 999 means never
	lda window_linecount_hi,x
	bmi .inr_done
	bne .lc_large
	jsr .window_rows_minus_one
	cmp window_linecount,y
	bcs .inr_done
	bcc show_more_prompt ; always
.lc_large
	; 256 lines or more unread: always a screenful, except the magic 999
	cmp #>999
	bne show_more_prompt
	lda window_linecount,x
	cmp #<999
	bne show_more_prompt
.inr_done
	rts
show_more_prompt
	; time to show [More]
	jsr clear_num_rows
	jsr .set_more_prompt_pos
	lda #$ff ; the first pass below INCs this to 0 (even = the prompt is shown)
	sta .more_blink_phase

!ifdef TARGET_C128 {
    bit COLS_40_80
    bpl +
    ; 80 columns
	jsr vdc_save_more_cell
	jsr vdc_show_more
	jmp .alternate_colours
    ; 40 columns
+
}
.more_access1
	lda SCREEN_ADDRESS + (SCREEN_WIDTH*SCREEN_HEIGHT-1)
	sta .more_text_char
!ifdef Z6_FCM_MODE {
	; A cell is two bytes here, and over a picture the high byte points into
	; the tile store: writing the '*' screen code into the low byte alone left
	; the cell pointing at some OTHER tile, which is the static white box the
	; prompt showed on Shogun's ship - and why the colour blink below could not
	; make it flash, a full colour tile taking its pixels from the store rather
	; than from colour RAM. Save both bytes and the colour, and flash the whole
	; cell between the prompt and whatever was behind it. Over text this is the
	; same blink as before: the cell alternates with a space rather than with
	; the background colour.
.more_access1b
	lda SCREEN_ADDRESS + (SCREEN_WIDTH*SCREEN_HEIGHT-1)
	sta .more_text_high
	ldz #0
	lda [zp_more_colour],z
	sta .more_text_colour
}
!ifdef Z6_ECM_MODE {
	; bit 7 selects a background register in ECM, so no reverse video
	lda #$2a ; screen code for "*"
	ora ecm_bits
} else {
	lda #128 + $2a ; screen code for reversed "*"
}
.more_access2
!ifndef TARGET_X16 {
	sta SCREEN_ADDRESS + (SCREEN_WIDTH*SCREEN_HEIGHT-1)
} else {
	jsr vera_save_more_cell	; the X16 keeps its cell's character AND colour
}
!ifdef Z6_FCM_MODE {
	jsr .more_fcm_show		; ...and the high byte with it, so the store above
							; cannot leave a stale tile code on screen
}

	; wait for ENTER
.alternate_colours
!ifndef BENCHMARK {
--	ldx s_colour
!ifdef TARGET_PLUS4 {
	lda plus4_vic_colours,x
	tax
}
	; The blink phase must live in memory, not in y. The
	; call to mouse update routines kills it
	inc .more_blink_phase
	lda .more_blink_phase
	and #1
	beq +
!ifdef TARGET_C128 {
	bit COLS_40_80
	bpl +++
	; 80 columns
	jsr vdc_hide_more
	jmp ++
	; 40 columns
+++	ldx reg_backgroundcolour
} else ifdef TARGET_X16 {
	jsr vera_hide_more
	jmp ++
} else ifdef Z6_FCM_MODE {
	jsr .more_fcm_hide
	jmp ++
} else {
	ldx reg_backgroundcolour
}
+
!ifdef TARGET_C128 {
	bit COLS_40_80
	bpl ++
	; 80 columns
	jsr vdc_show_more
} else ifdef TARGET_X16 {
	jsr vera_show_more
} else ifdef Z6_FCM_MODE {
	jsr .more_fcm_show
}
++
!ifndef Z6_FCM_MODE {
!ifdef TARGET_MEGA65 {
	jsr colour2k
}
.more_access3
!ifndef TARGET_X16 {
	stx COLOUR_ADDRESS + (SCREEN_WIDTH*SCREEN_HEIGHT-1)
} else {
	ldx $8000
}
!ifdef TARGET_MEGA65 {
	jsr colour1k
}
}
.check_for_keypress
	ldx #40
---
	jsr wait_a_jiffy
	jsr getchar_and_maybe_toggle_darkmode
	cmp #0
	bne +
	dex
	bne ---
	beq -- ; Always branch
+
}
!ifdef TARGET_C128 {
    bit COLS_40_80
    bpl +
    ; 80 columns
	jsr vdc_hide_more
	jmp .increase_num_rows_done
    ; 40 columns
+
}
	lda .more_text_char
.more_access4
!ifndef TARGET_X16 {
	sta SCREEN_ADDRESS + (SCREEN_WIDTH*SCREEN_HEIGHT -1)
} else {
	jsr vera_hide_more		; ...which puts the saved cell back
}
!ifdef Z6_FCM_MODE {
	lda .more_text_high
.more_access4b
	sta SCREEN_ADDRESS + (SCREEN_WIDTH*SCREEN_HEIGHT -1)
	lda .more_text_colour
	ldz #0
	sta [zp_more_colour],z
}
.increase_num_rows_done
	rts

.more_text_char !byte 0
.more_blink_phase !byte 0

!ifdef Z6_FCM_MODE {
.more_text_high   !byte 0	; the cell's high byte: nonzero means a picture tile
.more_text_colour !byte 0
.more_fcm_show
	; the prompt: the '*' as an ordinary glyph, so the high byte must go to
	; zero, in the text colour rather than whatever a tile left in colour RAM
	lda #128 + $2a
.more_access5
	sta SCREEN_ADDRESS + (SCREEN_WIDTH*SCREEN_HEIGHT-1)
	lda #0
.more_access6
	sta SCREEN_ADDRESS + (SCREEN_WIDTH*SCREEN_HEIGHT-1)
	lda s_colour
	ldz #0
	sta [zp_more_colour],z
	rts
.more_fcm_hide
	; ...and the other half of the blink is the cell exactly as it was
	lda .more_text_char
.more_access7
	sta SCREEN_ADDRESS + (SCREEN_WIDTH*SCREEN_HEIGHT-1)
	lda .more_text_high
.more_access8
	sta SCREEN_ADDRESS + (SCREEN_WIDTH*SCREEN_HEIGHT-1)
	lda .more_text_colour
	ldz #0
	sta [zp_more_colour],z
	rts
}

.set_more_prompt_pos
	; Point the [More] prompt at the bottom right cell of the current
	; window. In z6 every window has its own rectangle, so this can't be a
	; fixed address: the VIC/VDC targets rewrite the addresses in
	; .more_access1-4, and the X16 remembers the cell for VERAPrintChar.
!ifdef TARGET_X16 {
	ldx current_window
	; last column of the window, clamped to the screen
	lda window_x,x
	clc
	adc window_x_size,x
	cmp s_screen_width
	bcc +
	lda s_screen_width
+	sec
	sbc #1
	sta .vera_more_col
	; last row of the window, clamped to the screen
	lda window_y,x
	clc
	adc window_y_size,x
	cmp s_screen_height
	bcc +
	lda s_screen_height
+	sec
	sbc #1
	sta .vera_more_row
	rts
} else {
	jsr get_cursor ; x=row, y=column
	stx .more_saved_row
	sty .more_saved_column
	ldx current_window
	; last column of the window, clamped to the screen
	lda window_x,x
	clc
	adc window_x_size,x
	cmp s_screen_width
	bcc +
	lda s_screen_width
+	sec
	sbc #1
	pha
	; last row of the window, clamped to the screen
	lda window_y,x
	clc
	adc window_y_size,x
	cmp s_screen_height
	bcc +
	lda s_screen_height
+	sec
	sbc #1
	tax
	pla
	tay
	clc
	jsr s_plot ; sets zp_screenline/zp_colourline for that row
	; the cell's address is the start of the line plus the column
!ifdef Z6_FCM_MODE {
	lda zp_screencolumn ; a cell is two bytes wide
	asl
	sta .more_cell_offset
} else {
	lda zp_screencolumn
	sta .more_cell_offset
}
	lda zp_screenline
	clc
	adc .more_cell_offset
	sta .more_access1 + 1
	sta .more_access2 + 1
	sta .more_access4 + 1
!ifdef Z6_FCM_MODE {
	sta .more_access5 + 1
	sta .more_access7 + 1
	ora #1					; the cell's high byte. A row's start is a multiple
	sta .more_access1b + 1	; of the row width and the cell offset is a column
	sta .more_access4b + 1	; doubled, so this is an even address and the +1
	sta .more_access6 + 1	; cannot carry into the page
	sta .more_access8 + 1
}
	lda zp_screenline + 1
	adc #0
	sta .more_access1 + 2
	sta .more_access2 + 2
	sta .more_access4 + 2
!ifdef Z6_FCM_MODE {
	sta .more_access1b + 2
	sta .more_access4b + 2
	sta .more_access5 + 2
	sta .more_access6 + 2
	sta .more_access7 + 2
	sta .more_access8 + 2
}
!ifndef BENCHMARK {
!ifdef Z6_FCM_MODE {
	; zp_colourline holds the row's colour RAM offset, already biased to the
	; colour byte, so adding the cell offset lands on the prompt's colour
	lda zp_colourline
	clc
	adc .more_cell_offset
	sta zp_more_colour
	lda zp_colourline + 1
	adc #0
	sta zp_more_colour + 1
} else {
	lda zp_colourline
	clc
	adc .more_cell_offset
	sta .more_access3 + 1
	lda zp_colourline + 1
	adc #0
	sta .more_access3 + 2
}
}
!ifdef TARGET_C128 {
	; ...and the same cell in the VDC's own memory, which none of the writes
	; above can reach: the VDC keeps characters at $0000 and attributes at
	; $0800, while zp_screenline and zp_colourline are the VIC-II ones, so only
	; the base differs. Without this the 80 column prompt was nailed to the
	; bottom right of the screen rather than of the current window.
	lda zp_screenline
	clc
	adc .more_cell_offset
	sta .vdc_more_char_addr
	lda zp_screenline + 1
	adc #0
	sec
	sbc #>$0400
	sta .vdc_more_char_addr + 1
	lda zp_colourline
	clc
	adc .more_cell_offset
	sta .vdc_more_colour_addr
	lda zp_colourline + 1
	adc #0
	sec
	sbc #>($d800 - $0800)
	sta .vdc_more_colour_addr + 1
}
	; put the cursor back where the text is being printed
	ldx .more_saved_row
	ldy .more_saved_column
	clc
	jmp s_plot

.more_saved_row    !byte 0
.more_saved_column !byte 0
.more_cell_offset  !byte 0
}

printchar_flush
	; flush the printchar buffer into the current window
	lda s_reverse
	pha

	ldx first_buffered_column
	cpx buffer_index
	bcs +

	ldx buffer_index
	dex
	stx last_break_char_buffer_pos
	jsr print_line_from_buffer
	
	bcs + ; The line couldn't be printed
	ldx buffer_index
	dex
	lda print_buffer2,x
	sta s_reverse
	lda print_buffer,x
	jsr s_printchar
+

	; ldx first_buffered_column
; -   cpx buffer_index
	; bcs +
	; lda print_buffer2,x
	; sta s_reverse
	; lda print_buffer,x
	; jsr s_printchar
	; inx
	; bne -

+	pla
	sta s_reverse
	jmp start_buffering

print_line_from_buffer
	; Prints the text from first_buffered_column to last_break_char_buffer_pos
	; "Is there a line to print on?" is a question about the window being
	; printed into, not about window 0. Inherited from the non-z6 screen model,
	; where window 0 is the only place buffered text ever goes, this read
	; window_y - i.e. window 0's top row - whatever window was current, so a
	; window 1 that filled the screen (the spec notes Journey makes one) silently
	; swallowed everything printed into it. Window 0 is index 0, so its own
	; behaviour is unchanged.
	ldx current_window
	lda window_y,x
	cmp s_screen_height
	bcc +
	; There is no free line to print on, return with carry set
	rts
+
!ifdef TARGET_C128 {
	bit COLS_40_80
	bmi +
	jmp .printline40

+	lda zp_screenline + 1
	sec
	sbc #$04 ; adjust from $0400 (VIC-II) to $0000 (VDC)
	tay
	lda zp_screenline
	clc
	adc zp_screencolumn
	bcc +
	iny
+	jsr VDCSetAddress
	ldy #VDC_DATA
	sty VDC_ADDR_REG

	ldx first_buffered_column
-   cpx last_break_char_buffer_pos
	bcs .done_print_80
	lda print_buffer,x
	jsr convert_petscii_to_screencode
	ora print_buffer2,x
--	bit     VDC_ADDR_REG
	bpl --
	sta VDC_DATA_REG
	inx
	bne - ; Always branch

.done_print_80	

	lda last_break_char_buffer_pos
	sec
	sbc first_buffered_column

!ifdef COLOURFUL_LOWER_WIN {

	pha ; Char count

	; ; Fill relevant portion of colour RAM (start at offset $1800) with the game's foreground colour
	lda zp_colourline + 1
	sec
	sbc #$d0 ; adjust from $d800 (VIC-II) to $0800 (VDC)
	tay
	lda zp_colourline
	clc
	adc zp_screencolumn
	bcc +
	iny
+	jsr VDCSetAddress

	ldx s_colour
	lda vdc_vic_colours,x
	ora #$80 ; Bit 7 = charset, bit 0-4 = fg colour
	ldx #VDC_DATA
	jsr VDCWriteReg
	; We have written default fg colour to the first position in colour RAM. Now fill the rest positions.
	lda #0 ; Set to Fill mode ; Not needed, we have 0 in A
	ldx #VDC_VSCROLL
	jsr VDCWriteReg
	ldx #VDC_COUNT
	pla
	sec
	sbc #1
	jsr VDCWriteReg
	
.dont_colour_80	
}
	jmp .done_print_line_from_buffer
	
.printline40
}

!ifdef TARGET_X16 {
	; Address every cell, as the other targets do. This used to print the first
	; character through s_printchar and let the rest ride on the VERA address
	; pointer that call left behind (and undo its cursor step with a "no idea
	; why we need to do this" dec). Now that a window can scroll, s_printchar
	; can end up in .s_scroll_vera, whose copy loop leaves the pointer wherever
	; it finished, so the rest of the line would be written into the blue.
	ldy first_buffered_column
-	cpy last_break_char_buffer_pos
	bcs ++
	lda print_buffer,y
	jsr convert_petscii_to_screencode
	ora print_buffer2,y
	jsr VERAPrintChar ; a = screen code, y = column; preserves y
	iny
	bne - ; Always branch
++

} else ifdef Z6_FCM_MODE {
		; y indexes the print buffer by column, but a screen cell is two
		; bytes, so double it for the store and halve it again afterwards.
		ldy first_buffered_column
-		cpy last_break_char_buffer_pos
		bcs ++
		lda print_buffer,y
		jsr convert_petscii_to_screencode
		ora print_buffer2,y
		pha
		tya
		asl
		tay
		pla
!ifdef Z6_FCM_TEXT_BAKE {
		; transparent window over a picture? bake the glyph into the tile
		pha
		ldx current_window
		lda window_bake,x
		beq .plb_no_bake
		iny						; the cell's tile-select (high) byte
		lda (zp_screenline),y
		dey
		beq .plb_no_bake		; no picture here: ordinary text
		pla						; a = screen code, y = 2 * column
		jsr s_bake_char
		jmp .plb_baked
.plb_no_bake
		pla
}
		sta (zp_screenline),y
		+clear_cell_high_byte
		lda s_colour
		+sta_colour_ram ; the colour pointer is biased by one
!ifdef Z6_FCM_TEXT_BAKE {
.plb_baked
}
		tya
		lsr
		tay
		iny
		bne - ; Always branch
++
} else {
	!ifdef TARGET_MEGA65 {
		jsr colour2k	
	}
		ldy first_buffered_column
-		cpy last_break_char_buffer_pos
		bcs ++
		lda print_buffer,y
		jsr convert_petscii_to_screencode
	!ifdef Z6_ECM_MODE {
		and #$3f ; only 64 characters, and the top bits select the background
		ora ecm_bits
	} else {
		ora print_buffer2,y
	}
		sta (zp_screenline),y
		+clear_cell_high_byte
	!ifdef COLOURFUL_LOWER_WIN {
	!ifdef TARGET_PLUS4 {
		ldx s_colour
		lda plus4_vic_colours,x
	} else {
		lda s_colour
	}
		sta (zp_colourline),y
	}
		iny
		bne - ; Always branch

++	
	!ifdef TARGET_MEGA65 {
		jsr colour1k
	}
}

.done_print_line_from_buffer
	lda last_break_char_buffer_pos
	sec
	sbc first_buffered_column
	clc
	adc zp_screencolumn
	sta zp_screencolumn

	clc
	rts

printchar_buffered
	; a is PETSCII character to print
	sta .buffer_char
	cmp #13
	beq +
	sta anything_printed
+	
	; need to save x,y
	txa
	pha
	tya
	pha
	; is this a buffered window?
	ldx current_window
	lda window_attributes,x
	and #WIN_BUFFERED
	beq .is_not_buffered
	lda is_buffered_window ; global flag, set by the buffer_mode opcode
	bne .buffered_window
.is_not_buffered
	lda .buffer_char
	jsr s_printchar
	jmp .printchar_done
	; update the buffer
.buffered_window
	; calculate the left edge and right edge (exclusive) of the current
	; window's text area; buffer positions are absolute screen columns
	ldx current_window
	jsr s_window_left_edge
	sta .buffer_left
	jsr s_window_right_edge
	sta .buffer_edge
	; Does this window wrap? Without the attribute (windows 1-7 start without
	; it, z-spec 8.8.3.3) a line that fills the window is not carried onto the
	; next one: the text that does not fit is dropped, exactly as it is in an
	; unbuffered window, since buffering only decides *where* a wrapped line
	; breaks (8.8.3.1.2.2).
	lda window_attributes,x
	and #WIN_WRAPPING
	sta .buffer_wrap
	lda .buffer_char
	; add this char to the buffer
	cmp #$0d
	bne .check_break_char
	jsr printchar_flush
	; more on the same line
	jsr increase_num_rows
	lda #$0d
	jsr s_printchar
	jsr start_buffering
!ifdef ZORK0_MSDOS_QUIRK {
	jsr nl_fire_pending ; the deferred firing point: the new line has begun
}
	jmp .printchar_done
.check_break_char
	ldy buffer_index
	cpy .buffer_edge
	bcs .buffer_is_full ; Don't register break chars on last position of buffer.
	cmp #$20 ; Space
	beq .break_char
	cmp #$2d ; -
	bne .add_char
.break_char
	; update index to last break character
	sty last_break_char_buffer_pos
	jmp .add_char
.buffer_is_full
	; the line reaches the window's right margin: a wrapping window carries
	; the overflow onto the next line (below), a non-wrapping one ignores it
	ldx .buffer_wrap
	bne .add_char
	jmp .printchar_done
.add_char
	ldx .buffer_edge
	sta print_buffer,y
	lda s_reverse
	ora s_colour_swap ; swapped colours render as reverse video
	sta print_buffer2,y
	iny
	sty buffer_index
	lda .buffer_wrap ; x still holds .buffer_edge for max_chars_on_line below
	bne .may_break_line
	jmp .printchar_done ; no wrapping: the line is never broken, only filled
.may_break_line
	cpy .buffer_edge ; right edge of the current window
	beq ++
	bcs + ; Clear case - always print a line

-	jmp .printchar_done

++	; Print a line *if* we're on last line of a windowful of text
	jsr .window_rows_minus_one ; x is preserved
	cmp window_linecount,y
	bne - ; Not on last line
	dex
+
	; print the line until last space
	; First calculate max# of characters on line
	; ldx s_screen_width
	; lda s_screen_height
	; sec
	; sbc window_y
	; sbc #1
	; cmp num_rows
	; bne +
	; dex ; Max 39 chars on last line on screen.
; +	
	stx max_chars_on_line
	; Check if we have a "perfect space" - a space after 40 characters
	lda print_buffer,x
	cmp #$20
	beq .print_40_2 ; Print all in buffer, regardless of which column buffering started in
	; Now find the character to break on
	ldy last_break_char_buffer_pos
	beq .print_40 ; If there are no break characters on the line, print all 40 characters
	; Check if the break character is a space
	lda print_buffer,y
	cmp #$20
	beq .print_buffer
	iny
	bne .store_break_pos ; Always branch
.print_40
	; If we can't find a place to break, and buffered output started after the window's left edge, print a line break and move the text in the buffer to the next line.
	ldx first_buffered_column
	cpx .buffer_left
	beq .print_40_2
	jmp .line_completed
.print_40_2	
	ldy max_chars_on_line
.store_break_pos
	sty last_break_char_buffer_pos
.print_buffer
	lda s_reverse
	pha

	dec last_break_char_buffer_pos ; Print last character using normal print routine, to avoid trouble

	jsr print_line_from_buffer

	ldx last_break_char_buffer_pos
	inc last_break_char_buffer_pos ; Restore old value, since we decreased it by one before

	bcs + ; The line couldn't be printed
	; Print last character
	lda print_buffer2,x
	sta s_reverse
	lda print_buffer,x
	jsr s_printchar
+
	inx

	pla
	sta s_reverse

.line_completed
	; the line is done: count it, and fire any newline interrupt before the
	; carried-over text is placed - the interrupt routine may move the
	; margins (Shogun, Zork Zero), and the carried text belongs inside the
	; new ones. x holds the carry's source position in the buffer.
	txa
	pha
	jsr increase_num_rows
	ldx current_window ; the margins may have moved: recompute the edges
	jsr s_window_left_edge
	sta .buffer_left
	jsr s_window_right_edge
	sta .buffer_edge
	pla
	tax

.move_remaining_chars_to_buffer_start
	; Skip initial spaces, move the rest of the line back to the window's left edge and update indices
	ldy .buffer_left
	cpx buffer_index
	beq .after_copy_loop
	lda print_buffer,x
	cmp #$20
	bne .copy_loop
	inx
.copy_loop
	cpx buffer_index
	beq .after_copy_loop
	lda print_buffer,x
	sta print_buffer,y
	lda print_buffer2,x
	sta print_buffer2,y
	iny
	inx
	bne .copy_loop ; Always branch
.after_copy_loop
	sty buffer_index
	lda .buffer_left
	sta first_buffered_column
	; more on the same line (the line count moved up to .line_completed,
	; where the newline interrupt can still shape the carried text)
	lda last_break_char_buffer_pos
	cmp .buffer_edge
	bcs +
	lda #$0d
	jsr s_printchar
+   ldy #0
	sty last_break_char_buffer_pos
!ifdef ZORK0_MSDOS_QUIRK {
	jsr nl_fire_pending ; the deferred firing point: the new line has begun
}
.printchar_done
	pla
	tay
	pla
	tax
	rts
anything_printed       !byte 0
.buffer_char       !byte 0
.buffer_left       !byte 0
.buffer_edge       !byte 0
.buffer_wrap       !byte 0 ; WIN_WRAPPING for the window being buffered
; print_buffer            !fill 41, 0
.save_x			   !byte 0
.save_y			   !byte 0
first_buffered_column !byte 0

clear_screen_raw
	lda #147
	jsr s_printchar
	rts

printstring_raw
; Parameters: Address in a,x to 0-terminated string
	stx .read_byte + 1
	sta .read_byte + 2
	ldx #0
.read_byte
	lda $8000,x
	beq +
	jsr s_printchar
	inx
	bne .read_byte
+	rts
	

save_cursor
	; remember the live cursor position in the current window's
	; cursor properties (absolute screen coordinates)
	jsr get_cursor
	tya
	ldy current_window
	sta window_x_cursor,y
	txa
	sta window_y_cursor,y
	rts

restore_cursor
	; move the live cursor to the current window's stored position
	ldy current_window
	ldx window_y_cursor,y
	lda window_x_cursor,y
	tay
;	jmp set_cursor

set_cursor
	; input: y=column (0-39)
	;        x=row (0-24)
	clc
	jmp s_plot

get_cursor
	; output: y=column (0-39)
	;         x=row (0-24)
	sec
	jmp s_plot

!ifndef Z4PLUS {

.statusline_temp = z_operand_value_low_arr + 4
.num_width_temp = z_operand_value_high_arr + 4;

number_print_width
; a,x = signed number (a is HB)
; Returns: y = number of characters
	ldy #1 ; Base length
;	sty .num_width_temp
	cmp #$80
	bcc + ; Positive number
	iny ; Add 1 for minus
	eor #$ff
	pha
	txa
	eor #$ff
	adc #0 ; Carry is set, so this adds 1
	tax
	pla
	adc #0
+	sta .num_width_temp + 1
	cpx #10
	sbc #0
	bcc ++ ; Done
	iny
	lda .num_width_temp + 1
	cpx #100
	sbc #0
	bcc ++
	iny
	lda .num_width_temp + 1
	cpx #<1000
	sbc #>1000
	bcc ++
	iny
	lda .num_width_temp + 1
	cpx #<10000
	sbc #>10000
	bcc ++
	iny
++	rts

statusline_print_room
	; Input:
	; y = columns to the right that don't need emptying

	sty .statusline_temp + 1
	;
	; Room name
	; 
	; name of the object whose number is in the first global variable
	lda #16
	jsr z_get_low_global_variable_value
	jsr print_obj

	; Make sure cursor is on top row
	sec
	jsr s_plot
	cpx #0
	beq +
	; Cursor was moved down (object name probably contains a newline character). Put cursor on top row again.
	ldx #0
	clc
	jsr s_plot
+
	;
	; fill the rest of the line with spaces
	;
	lda s_screen_width
	sec
	sbc .statusline_temp + 1
	sta .statusline_temp + 1
-   lda zp_screencolumn
	cmp .statusline_temp + 1
	bcs +
	lda #$20
	jsr s_printchar
	jmp -
+   rts
	
z_ins_show_status
	; show_status (hardcoded size)

draw_status_line
	lda current_window
	pha
	jsr save_cursor
	lda #2
	sta current_window
	ldx #0
	ldy #0
	jsr set_cursor
	lda #18 ; reverse on
	jsr s_printchar
	ldx darkmode
	ldy statuslinecol,x 
	lda zcolours,y
	jsr s_set_text_colour

!ifdef TARGET_X16 {
	lda s_screen_width
	cmp #30
	bcs +
	ldy #0
	jsr statusline_print_room
	jmp .statusline_done
+
}

	;
	; score or time game?
	;

!ifdef Z3 {
	ldy #header_flags_1
	jsr read_header_word
	and #$02
	beq +
	jmp .timegame
+
}
	; score game
	lda z_operand_value_low_arr
	pha
	lda z_operand_value_high_arr
	pha
	lda z_operand_value_low_arr + 1
	pha
	lda z_operand_value_high_arr + 1
	pha

	; If we get here, the screen is 32, 40, 64 or 80 columns
!ifdef SUPPORT_80COL {
	lda s_screen_width
	cmp #60
	bcc + 
	jmp .print_score_64 ; 64+ wide statusline 
+
}
	lda #17
	jsr z_get_low_global_variable_value
	jsr number_print_width
	sty .statusline_temp
	lda #18
	jsr z_get_low_global_variable_value
	jsr number_print_width
;	sty .statusline_temp + 1
	tya
	clc
	adc .statusline_temp
	sta .statusline_temp

	ldx #0

!ifdef TARGET_X16 {
	lda s_screen_width
	cmp #35
	bcs +++
; .print_score_32
; 12345678901234567890123456789012
; A Cave                  123:1234
	ldy .statusline_temp
	iny
	iny
	jsr statusline_print_room

	lda s_screen_width
	sec
	sbc .statusline_temp
	sbc #2
	tay
	jsr set_cursor
	lda #32
	jsr s_printchar
	lda #17
	jsr print_low_global_variable_value
	lda #58
	jsr s_printchar
	jmp .print_moves
+++
}
	; If we get here, the screen is 40 columns

; 1234567890123456789012345678901234567890
; A Cave                    Sc:123 Mv:1234

!ifndef TARGET_MEGA65 {
; .print_score_40
	lda .statusline_temp
	clc
	adc #8
	tay	
	jsr statusline_print_room

	lda s_screen_width
	sec
	sbc .statusline_temp
	sbc #8
	tay
	jsr set_cursor
	; Print " Sc:"
	lda #>.score_short_str
	ldx #<.score_short_str
	jsr printstring_raw
	lda #17
	jsr print_low_global_variable_value
	; Print " Mv:"
	lda #>.turns_short_str
	ldx #<.turns_short_str
	jsr printstring_raw
	jmp .print_moves
}

!ifdef SUPPORT_80COL {
.print_score_64
; 1234567890123456789012345678901234567890123456789012345678901234
; A Cave                                 Score: 123  Moves: 1234

	ldy #26
	jsr statusline_print_room

	; Print " Score: "
	lda s_screen_width
	sec
	sbc #26
	tay
	jsr set_cursor
	lda #>.score_str
	ldx #<.score_str
	jsr printstring_raw
	lda #17
	jsr print_low_global_variable_value
	jsr get_cursor
	sty .statusline_temp
	; Print " Moves: "
	lda s_screen_width
	sec
	sbc #14
	sbc .statusline_temp
	tay
-	lda #32
	jsr s_printchar
	dey
	bne -
	; ldx #0
	; jsr set_cursor
	lda #>.turns_str
	ldx #<.turns_str
	jsr printstring_raw
}
	
.print_moves
	lda #18
	jsr print_low_global_variable_value
!ifdef SUPPORT_80COL {
	lda s_screen_width
	cmp #60
	bcc +
	jsr get_cursor
	sty .statusline_temp
	sec
	sbc .statusline_temp
	tay
-	lda #32
	jsr s_printchar
	dey
	bne -
+
}	
.all_done_score_sl
	pla
	sta z_operand_value_high_arr + 1
	pla
	sta z_operand_value_low_arr + 1
	pla
	sta z_operand_value_high_arr
	pla
	sta z_operand_value_low_arr
	jmp .statusline_done

!ifdef Z3 {
.time_str !pet " Time: ",0
.ampm_str !pet " AM ",0

.print_clock_number
	sty z_temp + 11
	txa
	ldy #0
-	cmp #10
	bcc .print_tens
	sbc #10 ; C is already set
	iny
	bne - ; Always branch
.print_tens
	tax
	tya
	bne +
	lda z_temp + 11
	bne ++
+	ora #$30
++	jsr s_printchar
	txa
	ora #$30
	jmp s_printchar

.timegame
	; time game
	ldx #0
	lda s_screen_width
!ifdef TARGET_X16 {
	cmp #37
	bcs .normal_time

	; This is a 32 column screen (< 32 don't get to this point)
	ldy #9
	jsr statusline_print_room
	
	; Don't print " Time: " string
	ldx #0
	ldy #23
	jsr set_cursor
	jmp .print_time_data
.normal_time
}
	ldy #16
	jsr statusline_print_room

	lda s_screen_width
	sec
	sbc #16
	tay
	jsr set_cursor
	lda #>.time_str
	ldx #<.time_str
	jsr printstring_raw
.print_time_data
; Print hours
	lda #65 + 32
	sta .ampm_str + 1
	lda #17 ; hour
	jsr z_get_low_global_variable_value
; Change AM to PM if hour >= 12
	cpx #12
	bcc +
	lda #80 + 32
	sta .ampm_str + 1
+	cpx #0
	bne +
	ldx #12
; Subtract 12 from hours if hours >= 13, so 15 becomes 3 etc
+	cpx #13
	bcc +
	txa
	sbc #12
	tax
+	ldy #$20 ; " " before if < 10
	jsr .print_clock_number
	lda #58 ; :
	jsr s_printchar
; Print minutes
	lda #18 ; minute
	jsr z_get_low_global_variable_value
	ldy #$30 ; "0" before if < 10
	jsr .print_clock_number
; Print AM/PM
	lda #>.ampm_str
	ldx #<.ampm_str
	jsr printstring_raw
}
.statusline_done
	ldx darkmode
	ldy fgcol,x 
	lda zcolours,y
	jsr s_set_text_colour
	lda #146 ; reverse off
	jsr s_printchar
	pla
	sta current_window
	jmp restore_cursor

!ifndef TARGET_MEGA65 {
.score_short_str !pet " Sc:",0
.turns_short_str !pet " Mv:",0
}
!ifdef SUPPORT_80COL {
.score_str !pet " Score: ",0
.turns_str !pet " Moves: ",0
}
}

