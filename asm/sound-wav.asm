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
;
; Note on syntax: the 32-bit indirect quad load is written "ldq [zp],z" here.
; Acme 0.97 as released (1 May 2026) insists on the ",z" for ldq, while the
; 2021/2022 development snapshots insisted on its absence ("ldq [zp]", which is
; also what docs/cputypes/cpu m65.txt still says). Both spellings assemble to
; the same 42 42 ea b2 <zp>, and the hardware does use z as the index, which is
; why the loads below set it first. "stq [zp]" is unchanged - acme wants no ,z
; on that one either way.

!ifdef SOUND_WAV_ENABLED {

;VERIFY_WAV_CHUNK_ID = 1

.sample_rate !byte 0,0
.chunk_size        !byte 0,0,0,0 ; 32 bit address
.chunk_header_size !byte 8,0,0,0 ; the ID and size are 4 bytes each

.parse_wav
    ; parses the WAV where .copy_effect_to_fastram put it: SOUND_FASTRAM_OFFSET
    ; into SOUND_FASTRAM_BANK
    lda #<SOUND_FASTRAM_OFFSET
    ldx #>SOUND_FASTRAM_OFFSET
    ldy #SOUND_FASTRAM_BANK
    ldz #0
    stq sound_file_target
!ifdef VERIFY_WAV_CHUNK_ID {
    ldq [sound_file_target],z
    ; is this a WAV file (should start with RIFF)
    cmp #82 ; 'R'?
    bne .bad_parse_wav
}
    ; skip the RIFF header. Both bytes, so this does not depend on the base
    ; offset's low byte being zero.
    lda #<(SOUND_FASTRAM_OFFSET + $0c)
    sta sound_file_target
    lda #>(SOUND_FASTRAM_OFFSET + $0c)
    sta sound_file_target + 1
    ; iterate over chunks
.parse_chunk
    ldz #4
    ldq [sound_file_target],z
    stq .chunk_size
    ldz #0
    ldq [sound_file_target],z
    cpz #$20
    bne +
    ; fmt chunk
    ; channels
    ldz #$08 
    ldq [sound_file_target],z
    cpy #1 ; 1 channel?
    bne .bad_parse_wav
    ; sample rate
    ldz #$0c
    ldq [sound_file_target],z
    stx .sample_rate + 1
    sta .sample_rate + 0
    ; bits/sample
    ldz #$14
    ldq [sound_file_target],z
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
    ; will trigger an error message
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
