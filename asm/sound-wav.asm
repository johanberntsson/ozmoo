; WAV is a standard format for sample data:
; http://www.lightlink.com/tjweber/StripWav/Canon.html
; http://www.ringthis.com/dev/wave_format.htm
;
; The samples need to be 8 bit, mono. Audacity can be used
; to export wav files in the correct format:
; - Select "File/Export/Export as WAV" from the main menu
; - Select "Other compressed files" as the file type
; - Select "Unsigned 8-bit PCM" as the encoding
; - Save the file
;
; use mediainfo or exiftool to check the WAV metadata

!ifdef SOUND_WAV_ENABLED {

;VERIFY_WAV_CHUNK_ID = 1

.sample_rate !byte 0,0
.chunk_size        !byte 0,0,0,0 ; 32 bit address
.chunk_header_size !byte 8,0,0,0 ; the ID and size are 4 bytes each

.parse_wav
    ; parses WAV at $4000
    lda #0
    tax
    ldy #4
    taz
    stq sound_file_target
!ifdef VERIFY_WAV_CHUNK_ID {
    ldq [sound_file_target]
    ; is this a WAV file (should start with RIFF)
    cmp #82 ; 'R'?
    bne .bad_parse_wav
}
    ; skip the RIFF header
    lda #$0c
    sta sound_file_target
    ; iterate over chunks
.parse_chunk
    ldz #4
    ldq [sound_file_target]
    stq .chunk_size
    ldz #0
    ldq [sound_file_target]
    cpz #$20
    bne +
    ; fmt chunk
    ; channels
    ldz #$08 
    ldq [sound_file_target]
    cpy #1 ; 1 channel?
    bne .bad_parse_wav
    ; sample rate
    ldz #$0c
    ldq [sound_file_target]
    stx .sample_rate + 1
    sta .sample_rate + 0
    ; bits/sample
    ldz #$14
    ldq [sound_file_target]
    cpy #8 ; 8 bits?
    bne .bad_parse_wav
    jmp .next_chunk
+   cpz #$74
    bne +
    ; info chunk, just skip
    jmp .next_chunk
+   cpz #$61
    beq .data_chunk
    ; unknown chunk
.bad_parse_wav
    ; just returning without setting sample_address_start
    ; will trigger an error messsage
    rts
.next_chunk
    ldq sound_file_target
    clc
    adcq .chunk_size
    adcq .chunk_header_size
    stq sound_file_target
    jmp .parse_chunk
.data_chunk
    ; data chunk
    ldq sound_file_target
    clc
    adcq .chunk_header_size
    stq sample_start_address
    adcq .chunk_size
    stq sample_stop_address
    lda .sample_rate
    sta sample_rate_hz
    lda .sample_rate + 1
    sta sample_rate_hz + 1
    ; TODO: how to see if the sample data is signed or not?
    lda #$ff
    sta sample_is_signed
    rts
}
