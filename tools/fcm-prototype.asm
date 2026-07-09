; Throwaway MEGA65 FCM prototype for Ozmoo z6, step 2 of the todo.txt plan.
;
; Sets up a 320x200 full colour screen with 16-bit character codes, DMAs a
; picture's deduplicated tiles into bank 1 ($10000), and points screen RAM at
; them. Answers: is bank 1 free and visible to the VIC-IV, does DMA reach it,
; and does a real Arthur picture render.
;
; Build: acme -f cbm -o fcmtest.prg fcmtest.asm

!source "pic.inc"

SCREEN      = $e000                 ; 40x25 cells, 2 bytes each = 2000 bytes
COLS        = 40
ROWS        = 25
LINESTEP    = COLS * 2

BLANK_TILE  = $10000                ; 64 zero bytes: transparent filler cell
TILE_STORE  = $10040                ; the picture's unique tiles
BLANK_CODE  = BLANK_TILE / 64       ; 1024
TILE_CODE   = TILE_STORE / 64       ; 1025

zp_screen   = $40                   ; 2 bytes
zp_map      = $42                   ; 2 bytes

CHARSET     = $1800                 ; copy of the C64 charset, for codes < 256

* = $0801
    !byte $0b,$08,$0a,$00,$9e,$32,$30,$36,$31,$00,$00,$00   ; 10 SYS 2061

start
    sei
    lda #65
    sta $00                         ; 40 MHz
    jsr mega65io

    lda $d05d                       ; hot registers would overwrite what follows
    and #$7f
    sta $d05d

    lda #0
    sta $d020
    sta $d021
    sta $d070                       ; palette bank 0 for both editing and display

    lda $d031
    and #%01010111                  ; H640 off, ATTR off (8-bit colour), V400 off
    sta $d031

    lda $d054
    and #%11111010                  ; FCLRLO off: codes < 256 stay text chars
    ora #%00000101                  ; CHR16 on, FCLRHI on: codes >= 256 are FCM
    sta $d054

    lda #COLS
    sta $d05e                       ; chars per row
    lda #<LINESTEP
    sta $d058
    lda #>LINESTEP
    sta $d059

    lda #<SCREEN                    ; SCNPTR
    sta $d060
    lda #>SCREEN
    sta $d061
    lda #0
    sta $d062
    sta $d063
    sta $d064                       ; COLPTR: colour RAM base
    sta $d065

    lda $d030                       ; 2 KB colour RAM window at $d800
    ora #$01
    sta $d030

    jsr copy_charset
    lda #<CHARSET                   ; CHARPTR: glyphs for codes < 256
    sta $d068
    lda #>CHARSET
    sta $d069
    lda #0
    sta $d06a

    jsr set_palette
    jsr clear_colour_ram
    jsr blank_tile
    jsr copy_tiles
    jsr fill_screen
    jsr write_text

-   jmp -

; The C64 character ROM appears at $d000 while CHAREN (bit 2 of $01) is clear.
copy_charset
    lda #$33
    sta $01
    ldx #0
-   lda $d000,x
    sta CHARSET,x
    lda $d100,x
    sta CHARSET + $100,x
    lda $d200,x
    sta CHARSET + $200,x
    lda $d300,x
    sta CHARSET + $300,x
    inx
    bne -
    lda #$37
    sta $01
    rts

; "fcm ok" in screen codes on the last row, in white, using codes < 256.
; FCLRLO is off, so these render as ordinary 8-byte glyphs from CHARPTR while
; the picture above them renders as full colour tiles.
TEXT_ROW    = 24
TEXT_SCREEN = SCREEN + TEXT_ROW * LINESTEP
TEXT_COLOUR = $d800 + TEXT_ROW * LINESTEP     ; 2 KB window, byte 1 of each cell

write_text
    ldx #0                          ; character index
    ldy #0                          ; byte offset: two bytes per cell
-   lda text_data,x
    sta TEXT_SCREEN,y               ; low byte of the screen code
    lda #0
    sta TEXT_SCREEN + 1,y           ; high byte: 0, so the code is < 256
    sta TEXT_COLOUR,y               ; colour byte 0: no flags
    lda #1                          ; colour byte 1: white
    sta TEXT_COLOUR + 1,y
    iny
    iny
    inx
    cpx #6
    bne -
    rts
text_data
    !byte 6, 3, 13, 32, 15, 11      ; f c m _ o k

; ---------------------------------------------------------------------------
mega65io
    lda #$47
    sta $d02f
    lda #$53
    sta $d02f
    rts

; Palette entries 16..31 hold the picture's colours. 0..15 stay as the C64's,
; for text. Entry 0 is never used by a picture pixel: 0 is transparent in FCM.
set_palette
    ldx #0
-   lda pal_data,x
    sta $d100 + PIC_PAL_BASE,x
    lda pal_data + 16,x
    sta $d200 + PIC_PAL_BASE,x
    lda pal_data + 32,x
    sta $d300 + PIC_PAL_BASE,x
    inx
    cpx #16
    bne -
    rts

; ---------------------------------------------------------------------------
; Colour RAM is 2 bytes per cell in CHR16. Byte 0 holds flags (all off) and
; byte 1 the colour used for pixel value 255, which no picture pixel is.
clear_colour_ram
    lda #$03                        ; FILL
    sta dma_command_lsb
    lda #0
    sta dma_source_address          ; fill with 0
    sta dma_source_address + 1
    sta dma_source_bank_and_flags
    sta dma_source_address_top
    sta dma_dest_address
    sta dma_dest_address + 1
    lda #$08                        ; $ff80000: colour RAM
    sta dma_dest_bank_and_flags
    lda #$ff
    sta dma_dest_address_top
    lda #<(COLS * ROWS * 2)
    sta dma_count
    lda #>(COLS * ROWS * 2)
    sta dma_count + 1
    jsr run_dma
    lda #0
    sta dma_command_lsb             ; back to COPY
    rts

blank_tile
    lda #$03                        ; FILL
    sta dma_command_lsb
    lda #0
    sta dma_source_address
    sta dma_source_address + 1
    sta dma_source_bank_and_flags
    sta dma_source_address_top
    sta dma_dest_address
    sta dma_dest_address + 1
    sta dma_dest_address_top
    lda #$01                        ; bank 1: $10000
    sta dma_dest_bank_and_flags
    lda #64
    sta dma_count
    lda #0
    sta dma_count + 1
    jsr run_dma
    lda #0
    sta dma_command_lsb
    rts

; Copy the tiles from the program's own RAM up into bank 1.
copy_tiles
    lda #<tile_data
    sta dma_source_address
    lda #>tile_data
    sta dma_source_address + 1
    lda #0
    sta dma_source_bank_and_flags
    sta dma_source_address_top
    sta dma_dest_address_top
    lda #<(TILE_STORE & $ffff)
    sta dma_dest_address
    lda #>(TILE_STORE & $ffff)
    sta dma_dest_address + 1
    lda #$01                        ; bank 1
    sta dma_dest_bank_and_flags
    lda #<(PIC_TILES * 64)
    sta dma_count
    lda #>(PIC_TILES * 64)
    sta dma_count + 1
    jsr run_dma
    rts

run_dma
    jsr mega65io
    lda #0
    sta $d702
    lda #>dma_list
    sta $d701
    lda #<dma_list
    sta $d705
    rts

dma_list
    !byte $0b                       ; 12-byte F011B list
    !byte $80
dma_source_address_top      !byte 0
    !byte $81
dma_dest_address_top        !byte 0
    !byte $00
dma_command_lsb             !byte 0
dma_count                   !word 0
dma_source_address          !word 0
dma_source_bank_and_flags   !byte 0
dma_dest_address            !word 0
dma_dest_bank_and_flags     !byte 0
dma_command_msb             !byte 0
dma_modulo                  !word 0

; ---------------------------------------------------------------------------
; Screen RAM: the picture's cell map, offset by the tile store's screen code.
; Cells to the right of the picture get the blank tile.
fill_screen
    lda #<SCREEN
    sta zp_screen
    lda #>SCREEN
    sta zp_screen + 1
    lda #<map_data
    sta zp_map
    lda #>map_data
    sta zp_map + 1

    ldx #0                          ; row
.row
    ldy #0                          ; byte offset within the row
.col
    cpx #PIC_CELLS_H                ; below the picture: blank the whole row
    bcs .blank
    cpy #(PIC_CELLS_W * 2)
    bcs .blank
    lda (zp_map),y
    clc
    adc #<TILE_CODE
    sta (zp_screen),y
    iny
    lda (zp_map),y
    adc #>TILE_CODE
    sta (zp_screen),y
    iny
    bne .next
.blank
    lda #<BLANK_CODE
    sta (zp_screen),y
    iny
    lda #>BLANK_CODE
    sta (zp_screen),y
    iny
.next
    cpy #LINESTEP
    bcc .col

    lda zp_screen                   ; next screen row
    clc
    adc #LINESTEP
    sta zp_screen
    bcc +
    inc zp_screen + 1
+
    lda zp_map                      ; next map row
    clc
    adc #(PIC_CELLS_W * 2)
    sta zp_map
    bcc +
    inc zp_map + 1
+
    inx
    cpx #ROWS
    bcc .row
    rts

; ---------------------------------------------------------------------------
* = $0c00
pal_data
    !binary "pic-pal.bin"

* = $0c40
map_data
    !binary "pic-map.bin"

* = $2000
tile_data
    !binary "pic-tiles.bin"
