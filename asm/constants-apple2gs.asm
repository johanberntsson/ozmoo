; Constants for the Apple IIgs target (-t:apple2gs)
;
; The machine-specific half; everything shared with the other Apple targets is
; in constants-apple2-common.asm, sourced at the end.
;
; The screen half of this file is the IIe's, byte for byte: a IIgs running in
; its Apple II personality has exactly the IIe's 80 column main/aux text page
; and its alternate character set, which is why the screen branches in the
; shared code are on A2_80COL rather than on TARGET_APPLE2E. What this machine
; adds is below that: colour for the text it draws, a readable vertical blank,
; and a speed register.
;
; --- screen -----------------------------------------------------------------
SCREEN_HEIGHT         = 24
SCREEN_WIDTH          = 80
SCREEN_ADDRESS        = $0400
A2_ROW_BYTES          = SCREEN_WIDTH / 2

A2_CLR80STORE         = $C000
A2_SET80STORE         = $C001
A2_CLR80VID           = $C00C
A2_SET80VID           = $C00D
A2_CLRALTCHAR         = $C00E
A2_SETALTCHAR         = $C00F
A2_MAIN_HALF          = $C054
A2_AUX_HALF           = $C055
A2_RDPAGE2            = $C01C

; --- the auxiliary bank ------------------------------------------------------
A2_CLRRAMRD           = $C002
A2_SETRAMRD           = $C003
A2_CLRRAMWRT          = $C004
A2_SETRAMWRT          = $C005

A2_AUX_FIRST_PAGE     = $08
A2_AUX_PAGES          = $c0 - A2_AUX_FIRST_PAGE

COLOUR_ADDRESS        = $d000
COLOUR_ADDRESS_DIFF   = COLOUR_ADDRESS - SCREEN_ADDRESS

SPACE_SCREENCODE      = $a0

; --- colour, which is what this target has and its siblings do not ----------
; TBCOLOR: the high nybble is the character colour and the low nybble the
; background, both from the same sixteen, and both apply to the WHOLE screen.
; An Apple text screen is one byte per cell on every machine including this
; one, so there is nowhere a per-cell colour could live - which costs nothing,
; because one pair at a time is Ozmoo's model everywhere outside z6 anyway, and
; the one thing that does vary per cell is the exact swap of the pair (a status
; line, Arthur's boxed parser messages), which comes free from bit 7: an
; inverse character is drawn with the two colours exchanged.
A2_TBCOLOR            = $C022

; The border is the low nybble of CLOCKCTL, whose top nybble belongs to the
; battery clock - so this one is read, masked and written back, never stored.
A2_BORDER             = $C034

; Bit 7 forces monochrome text whatever TBCOLOR says, and the machine comes up
; with whatever the control panel last chose. So it is cleared at boot rather
; than assumed: the phase rule is to set what we depend on.
A2_MONOCHROME         = $C021

; Bit 7 reads 1 during vertical blanking on a IIgs (a IIe reads the same bit
; inverted). Ozmoo only counts its edges, so the polarity does not matter - see
; kernal_getchar in apple2-kernal.asm.
A2_VBL                = $C019

; CYAREG: bit 7 is the 2.8 MHz speed and bits 0-3 are the "slow this machine
; down while a disk motor is on in slots 4-7" bits, which is what lets a
; cycle-timed 5.25" driver work on a fast machine. Bits 4-6 are not ours.
A2_SPEED              = $C036
A2_SPEED_FAST         = $80
A2_SPEED_SLOT_MOTOR   = $0f

; --- machine identification -------------------------------------------------
; A IIgs answers the IIe's $FBB3/$FBC0 identification like an enhanced IIe, so
; those cannot refuse a IIe on a IIgs-only disk. The documented test is the
; identification routine at $FE1F: it returns with the carry CLEAR on a IIgs
; and the ROM version in Y, and on every earlier machine that address holds an
; RTS, which leaves the carry as the caller set it.
A2_ID_GS              = $fe1f

!source "constants-apple2-common.asm"
