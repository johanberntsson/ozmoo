; Constants for the Apple IIe target (-t:apple2e)
;
; The machine-specific half; everything shared with the other Apple targets is
; in constants-apple2-common.asm, sourced at the end. This build also runs on a
; IIc and, until phase 3 gives it a target of its own, on a IIgs.
;
; --- screen -----------------------------------------------------------------
; The 80 column text page is the II+'s interleaved rows plus a bank split: cell
; (row, column) is the byte at row_base(row) + column / 2, in AUX RAM for an
; even column and in MAIN for an odd one. So a row is 40 bytes in each of two
; banks, the row table is the same one the II+ uses, and only the store itself
; is different - see a2_put_char in screenkernal.asm.
SCREEN_HEIGHT         = 24
SCREEN_WIDTH          = 80
SCREEN_ADDRESS        = $0400

; How many bytes of screen memory one row occupies in one bank: half the width
; here, the whole width on a II+. The scroll and the [More] prompt's cell are
; measured in these, not in columns.
A2_ROW_BYTES          = SCREEN_WIDTH / 2

; --- the 80 column soft switches --------------------------------------------
; $C000-$C00F is the keyboard when READ and the mode switches when WRITTEN, so
; every one of these is reached with sta and never with lda. 80STORE is turned
; on once at boot and stays on; it makes PAGE2 stop selecting the displayed
; page and start selecting which bank $0400-$07FF is read from and written to,
; and it affects that range alone - instruction fetch, the zero page, the stack
; and the vmem cache stay in main RAM whatever it says.
A2_CLR80STORE         = $C000
A2_SET80STORE         = $C001
A2_CLR80VID           = $C00C   ; 40 column video
A2_SET80VID           = $C00D   ; 80 column video
A2_CLRALTCHAR         = $C00E   ; the primary character set (flashing, no lower case)
A2_SETALTCHAR         = $C00F   ; the alternate one (inverse lower case instead)
A2_MAIN_HALF          = $C054   ; PAGE2 off: the odd columns. The resting state
A2_AUX_HALF           = $C055   ; PAGE2 on:  the even columns
A2_RDPAGE2            = $C01C   ; bit 7 says which half is selected (read only)

; --- the auxiliary bank ------------------------------------------------------
; A 128K IIe is two 64K banks, and these two switches say which one $0200-$BFFF
; answers with - RAMRD for reads (instruction fetch included, which is why the
; code that uses it lives in the language card; see apple2-aux.asm) and RAMWRT
; for writes. Neither touches the zero page, the stack or $D000-$FFFF, which
; follow ALTZP and which Ozmoo never switches at all. Written, never read, like
; every other switch in this range.
A2_CLRRAMRD           = $C002   ; read $0200-$BFFF from main. The resting state
A2_SETRAMRD           = $C003   ; ...and from aux
A2_CLRRAMWRT          = $C004   ; write $0200-$BFFF to main. The resting state
A2_SETRAMWRT          = $C005   ; ...and to aux

; What of the auxiliary bank is ours: $0800-$BFFF, since $0400-$07FF is the
; even half of the 80 column screen and the pages below it are small enough not
; to be worth the arithmetic. 184 pages, 46K - bigger than the whole main-RAM
; cache and smaller than any story, so it is a cache rather than a copy.
A2_AUX_FIRST_PAGE     = $08
A2_AUX_PAGES          = $c0 - A2_AUX_FIRST_PAGE

COLOUR_ADDRESS        = $d000
COLOUR_ADDRESS_DIFF   = COLOUR_ADDRESS - SCREEN_ADDRESS

; With ALTCHARSET on, a screen byte is the character's ASCII with bit 7 set for
; normal video and clear for inverse, over the whole of ASCII $20-$7f - which is
; what gives this screen its lower case. The one hole is $40-$5f: those codes
; are MouseText on an enhanced IIe, so inverse upper case has to be written as
; $00-$1f instead. convert_petscii_to_screencode produces exactly that form.
; A blank cell is still $a0, and the cursor is still an inverse space, $20.
SPACE_SCREENCODE      = $a0

!source "constants-apple2-common.asm"
