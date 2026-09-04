; Constants for the Apple II / II+ target (-t:apple2)
;
; The machine-specific half; everything shared with the other Apple targets is
; in constants-apple2-common.asm, sourced at the end.
;
; --- screen -----------------------------------------------------------------
; 24 rows, not 25: the reference for text comparisons is `dfrotz -h 24 -w 40`.
; The rows of the text page are interleaved - row base = $400 + (row & 7) * $80
; + (row >> 3) * $28 - so SCREEN_ADDRESS is only the base of the table, never
; a row stride; screenkernal.asm's Apple II branch reaches a row through a
; lookup table.
SCREEN_HEIGHT         = 24
SCREEN_WIDTH          = 40
SCREEN_ADDRESS        = $0400

COLOUR_ADDRESS        = $d000
COLOUR_ADDRESS_DIFF   = COLOUR_ADDRESS - SCREEN_ADDRESS

; A screen byte's top two bits are its video mode: 
; - $00-$3f inverse, 
; - $40-$7f flashing
; - $80-$ff normal. So a blank cell is $a0, not $20, and the cursor is
SPACE_SCREENCODE      = $a0

!source "constants-apple2-common.asm"
