+readsector
    ; Input
    ; Output

    ; open the channel file
    .(
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

    LDA #<sector_address
    STA $AE
    LDA #>sector_address
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
    ; Akkumulator contains BASIC error code

    ; most likely errors:
    ; A = $05 (DEVICE NOT PRESENT)

    ; ... error handling for open errors ...
    inc $d021
    JMP close    ; even if OPEN failed, the file has to be closed

cname
    .asc "#"
cname_len = * - cname

uname
    .asc "U1 2 0 18 0"
uname_len = * - uname
    .)

