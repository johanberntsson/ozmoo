.mempos
    !word $0000
.block
    !byte 0

readblocks
    ; read <n> blocks (each 256 bytes) from disc to memory
    ; x=start block [in]
    ; y=number of blocks to read [in]
    ; a=start memory position ($<y>00) [in]
    ; $err = error code [out]
    sty .cnt
    stx .block
    sta .mempos + 1 ; memory position to store data in
.loop
    ;ldx cnt
    ;LDA #$00
    ;JSR $BDCD      ; write counter
    jsr .readblock ; read block
    inc .mempos+1   ; update mempos,block for next iteration
    inc .block
    dec .cnt        ; loop
    bne .loop
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
    BCC .small_track
    LDA #$31
    STA .uname_track
.small_track 
    CLC
    ADC #$30
    STA .uname_track+1

    LDA .sector
    CMP #10
    BCC .small_sector
    LDA #$31
    STA .uname_sector
.small_sector 
    CLC
    ADC #$30
    STA .uname_sector+1

    ; open the channel file
    LDA #cname_len
    LDX #<.cname
    LDY #>.cname
    JSR $FFBD     ; call SETNAM

    LDA #$02      ; file number 2
    LDX $BA       ; last used device number
    BNE .skip
    LDX #$08      ; default to device 8
.skip    
    LDY #$02      ; secondary address 2
    JSR $FFBA     ; call SETLFS

    JSR $FFC0     ; call OPEN
    BCS .error    ; if carry set, the file could not be opened

    ; open the command channel

    LDA #uname_len
    LDX #<.uname
    LDY #>.uname
    JSR $FFBD     ; call SETNAM
    LDA #$0F      ; file number 15
    LDX $BA       ; last used device number
    LDY #$0F      ; secondary address 15
    JSR $FFBA     ; call SETLFS

    JSR $FFC0     ; call OPEN (open command channel and send U1 command)
    BCS .error    ; if carry set, the file could not be opened

    ; check drive error channel here to test for
    ; FILE NOT FOUND error etc.

    LDX #$02      ; filenumber 2
    JSR $FFC6     ; call CHKIN (file 2 now used as input)

    LDA .mempos
    STA $AE
    LDA .mempos+1
    STA $AF

    LDY #$00
.loop2   
    JSR $FFCF     ; call CHRIN (get a byte from file)
    STA ($AE),Y   ; write byte to memory
    INY
    BNE .loop2    ; next byte, end when 256 bytes are read
.close
    LDA #$0F      ; filenumber 15
    JSR $FFC3     ; call CLOSE

    LDA #$02      ; filenumber 2
    JSR $FFC3     ; call CLOSE

    JSR $FFCC     ; call CLRCHN
    inc $d020
    RTS
.error
    ; ackumulator contains BASIC error code
    ; most likely errors:
    ; A = $05 (DEVICE NOT PRESENT)
    sta err
    JMP .close    ; even if OPEN failed, the file has to be closed

.cname
    !pet "#"
cname_len = * - .cname

.uname
    !pet "U1 2 0 "
.uname_track
    !pet "18 "
.uname_sector
    !pet "00"
uname_len = * - .uname
.track !byte 0
.sector !byte 0

