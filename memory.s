mempos
    .word $0000
sector
    .byt 0

+readsectors
    .(
    ; read <n> sectors (each 256 bytes) from disc to memory
    ; x=start sector [in]
    ; y=number of sectors to read [in]
    ; a=start memory position ($<y>00) [in]
    ; $err = error code [out]
    sty cnt
    stx sector
    sta mempos + 1 ; memory position to store data in

loop
    ;ldx cnt
    ;LDA #$00
    ;JSR $BDCD      ; write counter
    jsr readsector ; read sector
    inc mempos+1   ; update mempos,sector for next iteration
    inc sector
    dec cnt        ; loop
    bne loop
    rts

cnt .byt 0
    .)

+readsector
    .(
    ; read 1 sector
    ; $mempos (contains address to store in) [in]
    ; $err = error code [out]

    ; convert sector to track/sector
    ; (assuming 16 tracks, each with 16 sectors)
    LDA sector
    AND #$0f
    STA floppy_sector
    LDA sector
    LSR
    LSR
    LSR
    LSR
    STA floppy_track
    INC floppy_track ; tracks are 1..
    
    ; convert track/sector to ascii and update drive command
    LDA #$30
    STA uname_track
    STA uname_track + 1
    STA uname_sector
    STA uname_sector + 1

    LDA floppy_track
    CMP #10
    BCC small_track
    LDA #$31
    STA uname_track
small_track 
    CLC
    ADC #$30
    STA uname_track+1

    LDA floppy_sector
    CMP #10
    BCC small_sector
    LDA #$31
    STA uname_sector
small_sector 
    CLC
    ADC #$30
    STA uname_sector+1

    ; open the channel file
    LDA #cname_len
    LDX #<cname
    LDY #>cname
    JSR $FFBD     ; call SETNAM

    LDA #$02      ; file number 2
    LDX $BA       ; last used device number
    BNE skip
    LDX #$08      ; default to device 8
skip    
    LDY #$02      ; secondary address 2
    JSR $FFBA     ; call SETLFS

    JSR $FFC0     ; call OPEN
    BCS error    ; if carry set, the file could not be opened

    ; open the command channel

    LDA #uname_len
    LDX #<uname
    LDY #>uname
    JSR $FFBD     ; call SETNAM
    LDA #$0F      ; file number 15
    LDX $BA       ; last used device number
    LDY #$0F      ; secondary address 15
    JSR $FFBA     ; call SETLFS

    JSR $FFC0     ; call OPEN (open command channel and send U1 command)
    BCS error    ; if carry set, the file could not be opened

    ; check drive error channel here to test for
    ; FILE NOT FOUND error etc.

    LDX #$02      ; filenumber 2
    JSR $FFC6     ; call CHKIN (file 2 now used as input)

    LDA mempos
    STA $AE
    LDA mempos+1
    STA $AF

    LDY #$00
loop   
    JSR $FFCF     ; call CHRIN (get a byte from file)
    STA ($AE),Y   ; write byte to memory
    INY
    BNE loop     ; next byte, end when 256 bytes are read
close
    LDA #$0F      ; filenumber 15
    JSR $FFC3     ; call CLOSE

    LDA #$02      ; filenumber 2
    JSR $FFC3     ; call CLOSE

    JSR $FFCC     ; call CLRCHN
    inc $d020
    RTS
error
    ; ackumulator contains BASIC error code
    ; most likely errors:
    ; A = $05 (DEVICE NOT PRESENT)
    sta err
    JMP close    ; even if OPEN failed, the file has to be closed

cname
    .asc "#"
cname_len = * - cname

uname
    .asc "U1 2 0 "
uname_track
    .asc "18 "
uname_sector
    .asc "00"
uname_len = * - uname
floppy_track .byt 0
floppy_sector .byt 0
    .)

