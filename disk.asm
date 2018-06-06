;TRACE_FLOPPY = 1
;TRACE_FLOPPY_VERBOSE = 1

readblocks_numblocks     !byte 0 
readblocks_currentblock  !byte 0,0 ; 257 = ff 1
readblocks_mempos        !byte 0,0 ; $2000 = 00 20
    
readblocks
    ; read <n> blocks (each 256 bytes) from disc to memory
    ; set values in readblocks_* before calling this function
!ifdef TRACE_FLOPPY {
    jsr newline
    jsr print_following_string
    !pet "readblocks (n,curr,pos) ",0
    lda readblocks_numblocks
    jsr printa
    jsr comma
    lda readblocks_currentblock
    jsr print_byte_as_hex
    lda readblocks_currentblock + 1
    jsr print_byte_as_hex
    jsr comma
    lda readblocks_mempos + 1
    jsr print_byte_as_hex
    lda readblocks_mempos 
    jsr print_byte_as_hex
    jsr newline
}
-   jsr .readblock ; read block
    inc readblocks_mempos + 1   ; update mempos,block for next iteration
    inc readblocks_currentblock
    bne +
    inc readblocks_currentblock + 1
+   dec readblocks_numblocks        ; loop
    bne -
    ; clear arguments for next call
    lda #0
    sta readblocks_currentblock + 1
    rts

.readblock
    ; read 1 block from floppy
    ; $mempos (contains address to store in) [in]

    ; convert block to track/sector
    ; (assuming each tracks has 16 sectors, skipping track18)
    lda readblocks_currentblock
    and #$0f
    sta .sector
    lda readblocks_currentblock
    sta .track
    lda readblocks_currentblock + 1
    ldx #4
-   lsr
    ror .track
    dex
    bne -
    inc .track ; tracks are 1..
    lda .track
    cmp #18
    bcc +
    inc .track ; skip track 18

    ; convert track/sector to ascii and update drive command
+   lda .track
    jsr conv2dec
    stx .uname_track
    sta .uname_track + 1
    lda .sector
    jsr conv2dec
    stx .uname_sector
    sta .uname_sector + 1

!ifdef TRACE_FLOPPY_VERBOSE {
    jsr space
    jsr dollar
    lda readblocks_mempos + 1
    jsr print_byte_as_hex
    lda readblocks_mempos 
    jsr print_byte_as_hex
    jsr comma
    ldx readblocks_currentblock
    jsr printx
    ;jsr comma
    ;lda #<.uname
    ;ldy #>.uname
    ;jsr printstring
    jsr newline
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

    lda readblocks_mempos
    sta zp_mempos
    lda readblocks_mempos+1
    sta zp_mempos + 1

    ldy #$00
-   jsr kernel_readchar ; call CHRIN (get a byte from file)
    sta (zp_mempos),Y   ; write byte to memory
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
    lda #ERROR_FLOPPY_READ_ERROR
    jsr fatalerror
.cname !text "#"
cname_len = * - .cname

.uname !text "U1 2 0 "
.uname_track !text "18 "
.uname_sector !text "00"
;!ifdef DEBUG {
    !byte 0 ; end of string, so we can print debug messages
;}
uname_len = * - .uname
.track  !byte 0
.sector !byte 0
