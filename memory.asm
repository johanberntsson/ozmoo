readblocks
    ; read <n> blocks (each 256 bytes) from disc to memory
    ; x=start block [in]
    ; y=number of blocks to read [in]
    ; a=start memory position ($<y>00) [in]
    ; $err = error code [out]
    sty .cnt
    stx .block
    sta .mempos + 1 ; memory position to store data in
-   jsr .readblock ; read block
    inc .mempos+1   ; update mempos,block for next iteration
    inc .block
    dec .cnt        ; loop
    bne -
    rts

.cnt !byte 0

.readblock
    ; read 1 block from floppy
    ; $mempos (contains address to store in) [in]
    ; $err = error code [out]

    ; convert block to track/sector
    ; (assuming 16 tracks, each with 16 sectors)
    LDA .block
    AND #$0f
    STA .sector
    LDA .block
    LSR
    LSR
    LSR
    LSR
    STA .track
    INC .track ; tracks are 1..
    
    ; convert track/sector to ascii and update drive command
    LDA #$30
    STA .uname_track
    STA .uname_track + 1
    STA .uname_sector
    STA .uname_sector + 1

    LDA .track
    CMP #10
    BCC +
    LDA #$31
    STA .uname_track
+   CLC
    ADC #$30
    STA .uname_track+1

    LDA .sector
    CMP #10
    BCC +
    LDA #$31
    STA .uname_sector
+   CLC
    ADC #$30
    STA .uname_sector+1

    ; open the channel file
    LDA #cname_len
    LDX #<.cname
    LDY #>.cname
    JSR kernel_setnam ; call SETNAM

    LDA #$02      ; file number 2
    LDX $BA       ; last used device number
    BNE +
    LDX #$08      ; default to device 8
+   LDY #$02      ; secondary address 2
    JSR kernel_setlfs ; call SETLFS

    JSR kernel_open     ; call OPEN
    BCS .error    ; if carry set, the file could not be opened

    ; open the command channel

    LDA #uname_len
    LDX #<.uname
    LDY #>.uname
    JSR kernel_setnam ; call SETNAM
    LDA #$0F      ; file number 15
    LDX $BA       ; last used device number
    LDY #$0F      ; secondary address 15
    JSR kernel_setlfs ; call SETLFS

    JSR kernel_open ; call OPEN (open command channel and send U1 command)
    BCS .error    ; if carry set, the file could not be opened

    ; check drive error channel here to test for
    ; FILE NOT FOUND error etc.

    LDX #$02      ; filenumber 2
    JSR kernel_chkin ; call CHKIN (file 2 now used as input)

    LDA .mempos
    STA $AE
    LDA .mempos+1
    STA $AF

    LDY #$00
-   JSR kernel_readchar ; call CHRIN (get a byte from file)
    STA ($AE),Y   ; write byte to memory
    INY
    BNE -         ; next byte, end when 256 bytes are read
.close
    LDA #$0F      ; filenumber 15
    JSR kernel_close ; call CLOSE

    LDA #$02      ; filenumber 2
    JSR kernel_close ; call CLOSE

    JSR kernel_clrchn ; call CLRCHN
!ifdef DEBUG {
    inc $d020 
}
    RTS
.error
    ; ackumulator contains BASIC error code
    ; most likely errors:
    ; A = $05 (DEVICE NOT PRESENT)
    sta err
    JMP .close    ; even if OPEN failed, the file has to be closed

.cname !text "#"
cname_len = * - .cname

.uname !text "U1 2 0 "
.uname_track !text "18 "
.uname_sector !text "00"
uname_len = * - .uname

.track !byte 0
.sector !byte 0
.mempos !word $0000
.block !byte 0
