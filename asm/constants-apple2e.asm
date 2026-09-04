; Constants for the Apple IIe target (-t:apple2e)
;
; The machine-specific half; everything shared with the other Apple targets is
; in constants-apple2-common.asm, sourced at the end. This build also runs on a
; IIc and, until phase 3 gives it a target of its own, on a IIgs.
;
; --- screen -----------------------------------------------------------------
; Still the phase-1 40-column screen: the 80-column bank-split text page is
; step 6 of the phase 2 plan, and until then a IIe build renders exactly as the
; II+ one does. The row interleave is the same on both machines.
SCREEN_HEIGHT         = 24
SCREEN_WIDTH          = 40
SCREEN_ADDRESS        = $0400

COLOUR_ADDRESS        = $d000
COLOUR_ADDRESS_DIFF   = COLOUR_ADDRESS - SCREEN_ADDRESS

; A screen byte's top two bits are its video mode - $00-$3f inverse, $40-$7f
; flashing (inverse lower case once ALTCHARSET is on), $80-$ff normal - so a
; blank cell is $a0, not $20.
SPACE_SCREENCODE      = $a0

; --- machine identification -------------------------------------------------
; Apple's own ROM identification bytes. $FBB3 is $06 on every machine with a
; IIe-style ROM and something else on a II or II+; $FBC0 then separates the
; family. Read once at boot by a2e_identify (ozmoo.asm), which refuses a II+
; and leaves the answer in a2_machine for the font 3 decision later on.
A2_ID_MACHINE         = $fbb3
A2_ID_SUBMODEL        = $fbc0

!source "constants-apple2-common.asm"
