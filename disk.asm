readblocks
    ; read <n> blocks (each 256 bytes) from disc to memory
    ; x=start block [in]
    ; y=number of blocks to read [in]
    ; a=start memory position ($<y>00) [in]
    sty .cnt
    stx .block
    sta .mempos + 1 ; memory position to store data in
-   jsr .readblock ; read block
    inc .mempos+1   ; update mempos,block for next iteration
    inc .block
    dec .cnt        ; loop
    bne -
    rts

.readblock
    ; read 1 block from floppy
    ; $mempos (contains address to store in) [in]

    ; convert block to track/sector
    ; (assuming 16 tracks, each with 16 sectors)
    lda .block
    and #$0f
    sta .sector
    lda .block
    lsr
    lsr
    lsr
    lsr
    sta .track
    inc .track ; tracks are 1..

    ; convert track/sector to ascii and update drive command
    lda .track
    jsr conv2dec
    stx .uname_track
    sta .uname_track + 1
    lda .sector
    jsr conv2dec
    stx .uname_sector
    sta .uname_sector + 1

!ifdef DEBUG {
    ldx .block
    jsr printx
    lda #$20
    jsr kernel_printchar
    lda #<.uname
    ldy #>.uname
    jsr printstring
}
    ; open the channel file
    lda #cname_len
    ldx #<.cname
    ldy #>.cname
    jsr kernel_setnam ; call SETNAM

    lda #$02      ; file number 2
    ldx $BA       ; last used device number
    bne +
    ldx #$08      ; default to device 8
+   ldy #$02      ; secondary address 2
    jsr kernel_setlfs ; call SETLFS

    jsr kernel_open     ; call OPEN
    bcs .error    ; if carry set, the file could not be opened

    ; open the command channel

    lda #uname_len
    ldx #<.uname
    ldy #>.uname
    jsr kernel_setnam ; call SETNAM
    lda #$0F      ; file number 15
    ldx $BA       ; last used device number
    ldy #$0F      ; secondary address 15
    jsr kernel_setlfs ; call SETLFS

    jsr kernel_open ; call OPEN (open command channel and send U1 command)
    bcs .error    ; if carry set, the file could not be opened

    ; check drive error channel here to test for
    ; FILE NOT FOUND error etc.

    ldx #$02      ; filenumber 2
    jsr kernel_chkin ; call CHKIN (file 2 now used as input)

    lda .mempos
    sta zx1
    lda .mempos+1
    sta zx2

    ldy #$00
-   jsr kernel_readchar ; call CHRIN (get a byte from file)
    sta (zx1),Y   ; write byte to memory
    iny
    bne -         ; next byte, end when 256 bytes are read
.close
    lda #$0F      ; filenumber 15
    jsr kernel_close ; call CLOSE

    lda #$02      ; filenumber 2
    jsr kernel_close ; call CLOSE

    jsr kernel_clrchn ; call CLRCHN
    rts
.error
    ; accumulator contains BASIC error code
    ; most likely errors:
    ; A = $05 (DEVICE NOT PRESENT)
    jsr .close    ; even if OPEN failed, the file has to be closed
    jsr fatalerror
    !pet "floppy read error", 0

.cname !text "#"
cname_len = * - .cname

.uname !text "U1 2 0 "
.uname_track !text "18 "
.uname_sector !text "00"
!ifdef DEBUG {
    !byte 13, 0 ; end of string, so we can print debug messages
}
uname_len = * - .uname

.cnt    !byte 0
.track  !byte 0
.sector !byte 0
.block  !byte 0
.mempos !word $0000
