; To compile and run using acme and x16emu
;
; acme --cpu 65c02 -o testx16.bin --format cbm testx16.asm
; x16-emulator/x16emu -prg testx16.bin -run

COL2 = 0
COL3 = 2
COL4 = 5
COL5 = 7
COL6 = 6
COL7 = 4
COL8 = 3
COL9 = 1
BGCOL = 9
FGCOL = 2
INPUTCOL = FGCOL
BGCOLDM = 2
FGCOLDM = 4
BORDERCOL = 0
BORDERCOLDM = 0
BORDERCOL_FINAL = BGCOL
BORDERCOLDM_FINAL = BORDERCOLDM
CURSORCOL = 1 ; Follow FGCOL
CURSORCOLDM = 1 ; Follow FGCOL
CURSORCHAR = 224
STATCOL = FGCOL
STATCOLDM = FGCOLDM
TARGET_X16 = 1

*=$0801
    !byte $0b,$08,$01,$00,$9e,$32,$30,$36,$31,$00,$00,$00
    jmp .testx16

scroll_delay !byte 0
streams_print_output
printchar_flush
kernal_reset
print_num_signed
print_num_unsigned
write_header_byte
    rts

!source "asm/constants.asm"
!source "asm/vera.asm"
!source "asm/constants-header.asm"
!source "asm/utilities.asm"
!source "asm/screenkernal.asm"

.testx16
    lda #14 
    jsr $ffd2
    jsr s_init
    lda #65 ; 'a'
    jsr s_printchar
    rts

.testvera
lda #14
jsr $ffd2
lda #65
jmp $ffd2
;jsr .testx16
lda #$1c 
jsr $ffd2
lda #'a'
jsr $ffd2
lda #$0d
jsr $ffd2
LDA #0
STA VERA_ctrl	; Select primary VRAM address
LDA #$01	; VPOKE 1st argument (The 0x00 in this is the 0 bank)
STA VERA_addr_high	; Set primary address bank to 0, stride to 2

; VPOKE 1,$b000,2
; VPOKE 1,$b001,1
; The following is the same as the 2 above VPOKE statements

LDA #0		; VPOKE 2nd argument
STA VERA_addr_low	; Set Primary address low byte to 0
LDA #$b0	; Not using the high byte, just want to stay on <0,0>
STA VERA_addr_high	; Set primary address high byte to 0
LDA #2		; VPOKE 3rd argument (set the character to "B")
STA VERA_data0	; Writing $73 to primary address ($01:$b000)

; Set the color to white
LDA #1		; VPOKE 2nd argument (next byte over)
STA VERA_addr_low	; Next byte over
LDA #1		; VPOKE 3rd argument (white color code)
STA VERA_data0	; Write the color
rts

