; AIFF is a standard format for various media, including samples:
; https://www.instructables.com/How-to-Read-aiff-Files-using-C/
; use mediainfo or exiftool to check the AIFF metadata

!ifdef SOUND_AIFF_ENABLED {

.exponent !byte 0,0
.sample_rate_big_endian !byte 0, 0, 0 ; two first bytes are value in Hz

.parse_aiff
    ; parses AIFF at $4000
    ;
    ; simplifying assumptions:
    ; - only one SSND chunk
    ; - no comments in the SSND chunk
    ; - max size of each chunk other chunk is 256 bytes

    ; parse the AIFF header
    jsr .init_fastRAM_base
    ; skip main header
    lda #12
    jsr .add_fastRAM_base

.check_chunk
    ; check what kind of chunk this is
    ldz #2
    lda [sound_file_target],z
    pha
    lda #4
    jsr .add_fastRAM_base ; skip chunk identifier (4 bytes)
    pla
    cmp #$4e ; is it ssNd?
    bne +
    jmp .ssnd_chunk
+
    ; COMM, FORM, INST, MARK or SKIP chunk, skip this
    cmp #$4d ; is it coMm?
    bne .skip_chunk
    ; COMM chunk
    ; check channels (expect 1)
    ldz #5
    lda [sound_file_target],z
    cmp #1
    bne .bad_format
    ; check bits/sample (expect 8 bit)
    ldz #11
    lda [sound_file_target],z
    cmp #8
    bne .bad_format
    ; extract the sampling rate
    ; exponent (= (byte 12 and 13) - $3fff, only positive allowed)
    ldz #12
    lda [sound_file_target],z
    sec
    sbc #$3f
    sta .exponent + 1
    inz 
    lda [sound_file_target],z
    sbc #$ff
    sta .exponent
    ; only use one byte of fraction (enough precision as int)
    inz
    lda [sound_file_target],z
    sta .sample_rate_big_endian + 1
    inz
    lda [sound_file_target],z
    sta .sample_rate_big_endian + 2
    lda #0
    sta .sample_rate_big_endian
    ; modfiy with exponent
    lda .exponent
    sec
    sbc #7 ; we're shifting one byte
    tax
-   clc
    rol .sample_rate_big_endian + 2
    rol .sample_rate_big_endian + 1
    rol .sample_rate_big_endian
    dex
    bne -
!ifdef TRACE_SOUND {
    lda .sample_rate_big_endian
    jsr print_byte_as_hex
    jsr colon
    lda .sample_rate_big_endian + 1
    jsr print_byte_as_hex 
    jsr newline
}
    jmp .skip_chunk

.bad_format
    rts

.skip_chunk
    ldz #3
    lda [sound_file_target],z
    jsr .add_fastRAM_base ; skip chunk data (TODO check full size?)
    lda #4
    jsr .add_fastRAM_base ; skip chunk length (4 bytes)
    jmp .check_chunk

.ssnd_chunk
    ; is the sample too big?
    ldz #1
    lda [sound_file_target],z
    bne .bad_format

    ; save chunk size for later
    inz
-   lda [sound_file_target],z
    pha
    inz
    cpz #4
    bne -

    lda #12
    jsr .add_fastRAM_base ; skip until sample data (assuming no comment)
    ; stop playback while loading new sample data
    lda #$00
    sta $d720
    ; load sample address into base and current address
    lda sound_file_target 
    sta sample_start_address
    lda sound_file_target + 1
    sta sample_start_address + 1
    lda sound_file_target + 2
    sta sample_start_address + 2
    ; calculate end point by adding saved chunk size to sample start
    ; todo: adjust for comment and chunk header (-8)
    clc
    pla
    adc sample_start_address
    sta sample_stop_address
    pla
    adc sample_start_address + 1
    sta sample_stop_address + 1
	ldx .sample_rate_big_endian
	lda .sample_rate_big_endian + 1 ; Note big-endian
	stx sample_rate_hz  + 1
	sta sample_rate_hz 
	lda #0
	sta sample_is_signed
    rts

.init_fastRAM_base
    ; init sound file address pointer
	lda #0
	sta sound_file_target
	sta sound_file_target + 1
	sta sound_file_target + 3
	lda #$04
	sta sound_file_target + 2
	rts

.add_fastRAM_base
    ; add (a) to sound file address pointer
    clc
    adc sound_file_target
    sta sound_file_target
    lda sound_file_target + 1
    adc #$00
    sta sound_file_target + 1
    rts

}

