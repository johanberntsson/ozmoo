; Sound support (currently only for MEGA65)
;
; Ozmoo can read and play sound effects (samples) from
; aiff files. The aiff files can be extracted from
; blorb files using the rezrov utility:
; http://www.ifarchive.org/if-archive/programming/blorb/rezrov.c
; or converted from other sample formats using a tool like
; sndfile-convert
;
; Currently we only support AIFF with 8 bits, one channel.
;
; Blorp files are the standard asset format for Inform games,
; and Infocom assets from Sherlock, The Luring Horror and Shogun
; have been converted to blorp.
; Specification: https://www.eblong.com/zarf/blorb/
;
; AIFF is a standard format for various media, including samples:
; https://www.instructables.com/How-to-Read-aiff-Files-using-C/
; use mediainfo or exiftool to check the AIFF metadata
;
; TODO:
; - add second channel for stereo
; - support all options for @sound_effect
; - sample rate correct, but conversion to d724-726 a bit off (see 007.aiff)
; - perhaps change preload of all sounds to load on demand

!ifdef SOUND {
!zone sound_support {
!ifdef TARGET_MEGA65 {

;TRACE_SOUND = 1

sound_load_msg !pet "Loading sound: ",0
sound_load_msg_2 !pet 13,"Done.",0
sound_file_name 
	!pet "000.aiff"
	!byte $a0,$a0,$a0,$a0,$a0,$a0,$a0,$a0
sound_nums !byte 100,10,1
sound_data_base = z_temp + 3
sound_file_target = sound_data_base ; 4 bytes
dir_entry_start = sound_data_base +  4 ; 1 byte
sound_file_track = sound_data_base + 5 ; 1 byte
sound_file_sector = sound_data_base + 6 ; 1 byte
.dir_pointer = sound_data_base + 7 ; 2 bytes

sound_index_ptr = z_operand_value_low_arr ; 4 bytes
; sound_index = z_operand_value_low_arr + 4 ; 1 byte

top_soundfx_plus_1 !byte 0


read_sound_file
	; a: Sound file number (3-255)
	
	; Set filename
	ldx #0
-	ldy #48 ; "0"
--	cmp sound_nums,x
	bcc +
	sbc sound_nums,x
	iny
	bne -- ; Always branch
+	sty sound_file_name,x
	inx
	cpx #3
	bcc -

	jsr get_free_vmem_buffer

	; Set pointers
	sta readblocks_mempos + 1 ; Low byte is always 0
	sta .dir_pointer + 1
	ldy #0
	sty .dir_pointer
	
; Read a directory sector
	lda #40
	ldx #3
.read_next_dir_sector

	jsr read_track_sector
	lda #2
	sta dir_entry_start
.compare_next_dir_entry
	ldy dir_entry_start
	lda (.dir_pointer),y
	cmp #$82
	bne .dir_not_match
	iny
	lda (.dir_pointer),y
	sta sound_file_track
	iny
	lda (.dir_pointer),y
	sta sound_file_sector
	iny
	ldx #0
--	lda sound_file_name,x
	cmp (.dir_pointer),y
	bne .dir_not_match
	inx
	iny
	cpx #7 ; Should be 16, but during testing it's easier if the stop after 7 characters, so 003.aif is recognized (final f is missing) 
	bcc --

; We have a match - Read the file!
	jmp .read_file
	
.dir_not_match
	lda dir_entry_start
	clc
	adc #$20
	sta dir_entry_start
	bcc .compare_next_dir_entry
	
; Check next directory block here
	ldy #0
	lda (.dir_pointer),y
	beq .fail
	pha
	iny
	lda (.dir_pointer),y
	tax
	pla
	bne .read_next_dir_sector ; Always branch
.fail
	sec
	rts

.read_file

	lda sound_file_track
	ldx sound_file_sector
.read_next_file_sector
	jsr read_track_sector

	; Copy to target address
	lda .dir_pointer + 1
	sta dma_source_address + 1
	lda sound_file_target
	sta dma_dest_address
	lda sound_file_target + 1
	sta dma_dest_address + 1
	lda sound_file_target + 2
	and #$0f
	sta dma_dest_bank_and_flags
	
	lda sound_file_target + 2
	sta vmem_temp
	lda sound_file_target + 3
	
	ldy #4
-	asl vmem_temp
	rol
	dey
	bne -
	sta dma_dest_address_top

	ldy #2
	sty dma_source_address
	ldy #0
	sty dma_count + 1 ; Transfer 254 bytes
	sty dma_source_bank_and_flags
	sty dma_source_address_top
	ldx #254
	lda (.dir_pointer),y
	bne +
	iny
	lda (.dir_pointer),y
	tax
	dex
+	stx dma_count

	jsr m65_run_dma

; Increase the address
	lda #0
	tax
	tay
	taz
	lda dma_count
	clc
	adcq sound_file_target
	stq sound_file_target

	ldy #1
	lda (.dir_pointer),y
	tax
	dey
	lda (.dir_pointer),y
	bne .read_next_file_sector	

	lda top_soundfx_plus_1
	adc #62
	jsr s_printchar
	clc
	rts

store_sound_effect_start
	; Insert code here to copy the 4-byte value in sound_file_target to the table for sound effect
	; start addresses. The index to use is in top_soundfx_plus_1
	ldq sound_file_target
	stq [sound_index_ptr]
	lda #0
	tax
	tay
	taz
	lda #4
	clc
	adcq sound_index_ptr
	stq sound_index_ptr
	rts

read_all_sound_files
	lda #>sound_load_msg
	ldx #<sound_load_msg
	jsr printstring_raw

; Init target address ($08080000) and index address ($0807FC00)
	lda #8
	tay
	taz
	lda #0
	tax
	stq sound_file_target
	dey
	ldx #$fc
	stq sound_index_ptr

	lda #3
	sta top_soundfx_plus_1
-	jsr store_sound_effect_start
	lda top_soundfx_plus_1
	jsr read_sound_file
	bcs +
	inc top_soundfx_plus_1
	bne -
+
	; A file couldn't be read. We're done.
	
	lda #>sound_load_msg_2
	ldx #<sound_load_msg_2
	jsr printstring_raw
	jsr wait_a_sec
	ldx #$ff
	jsr erase_window
	lda #3
	cmp top_soundfx_plus_1 ; Set carry if no sound files could be loaded
.return
	rts

init_sound = read_all_sound_files

sound_arg_effect !byte 0
sound_arg_volume !byte 0
sound_arg_repeats !byte 0
sound_arg_routine !byte 0, 0

sound_effect
    ; currently we ignore 1 prepare and 4 finish with
    lda sound_arg_effect
    cmp #2 ; start
    beq .play_sound_effect
    cmp #3 ; stop
    beq .stop_sound_effect
    rts
    
.stop_sound_effect
    ; TODO
    rts

.play_sound_effect
    ; input: x = sound effect (3, 4 ...)
    ; convert to zero indexed
    cpx top_soundfx_plus_1
    bcs .return
    dex
    dex
    dex
!ifdef TRACE_SOUND {
    jsr print_following_string
    !pet "play_sound_effect ",0
    lda .current_effect
    jsr printa
    jsr space
    jsr printx
    jsr newline
}
    cpx .current_effect
    beq +
    ; load sound effect into fastRAM at $40000
    stx .current_effect ; store as zero indexed index instead
    jsr .copy_effect_to_fastram
+   ; play sound effect
    jmp .play_aiff

.exponent !byte 0,0
.sample_rate_big_endian !byte 0, 0, 0 ; two first bytes are value in Hz
.bad_audio_format_msg !pet "[bad audio format]", 13, 0
.current_effect !byte $ff

.play_aiff
    ; plays AIFF at $4000
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
	lda #>.bad_audio_format_msg
	ldx #<.bad_audio_format_msg
	jmp printstring_raw

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
    sta $d721 ; base 
    sta $d72a ; current
    lda sound_file_target + 1
    sta $d722
    sta $d72b
    lda sound_file_target + 2
    sta $d723
    sta $d72c
    ; calculate end point by adding saved chunk size to sample start
    clc
    pla
    adc $d721
    sta $d727
    pla
    adc $d722
    sta $d728

    ; volume
	lda sound_arg_volume
    sta $d729
    sta $d71c ; mirror channel for stereo

    ; frequency (assuming CPU running at 40 MHz)
    ; x = (f * 40)/100 = (f/10) << 2
    lda .sample_rate_big_endian + 1 ; note big endian
    sta dividend
    lda .sample_rate_big_endian
    sta dividend + 1
    lda #10
    sta divisor
    lda #$00
    sta divisor + 1
    jsr divide16
    clc
    rol dividend
    rol dividend + 1
    rol dividend
    rol dividend + 1
    lda dividend
    sta $d724
    lda dividend + 1
    sta $d725
    lda #$00
    sta $d726

    ; Enable playback of channel 0
    lda #$82
    sta $d720

    ; enable audio dma
    lda #$80
    sta $d711

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

.copy_effect_to_fastram
    ; copy effect .current_effect to fastRAM so it can be played
	; index = effect * 4
    lda #0
    tax
    tay
    taz
    lda .current_effect
	stq sound_index_ptr
	clc
	rolq sound_index_ptr
	rolq sound_index_ptr
    ; add index (base = $0807FC00)
    clc
    ldz #8
    ldy #7
    ldx #$fc
    lda #0
    adcq sound_index_ptr
	stq sound_index_ptr
	; read index
	ldz #0 ; note that ldq uses z
	ldq [sound_index_ptr]
    ; store source address
    sta dma_source_address
    stx dma_source_address + 1
    sty dma_source_bank_and_flags
    lda #$80 ; base of attic ram (HyperRAM)
    sta dma_source_address_top
    ; copy the whole bank
    lda #$ff
    sta dma_count
    sta dma_count + 1
    ; copy to $4000
    lda #$00
    sta dma_dest_address
    sta dma_dest_address + 1
    sta dma_dest_address_top
    lda #$04
    sta dma_dest_bank_and_flags
    ; copy
    jmp m65_run_dma


} ; ifdef TARGET_MEGA65
} ; zone sound_support
} ; ifdef SOUND

z_ins_sound_effect
	lda #$08
	ldy z_operand_count
	beq .play_beep ; beep if no args (Z-machine standards, p101)
	ldx z_operand_value_low_arr
!ifdef SOUND {
    cpx #$03
    bcc .play_beep
    ; parse rest of the args
	lda z_operand_value_low_arr + 1 ; effect
	sta sound_arg_effect
	lda z_operand_value_low_arr + 2 ; volume
	sta sound_arg_volume
	lda z_operand_value_high_arr + 2 ; repeats
	sta sound_arg_repeats
	lda z_operand_value_low_arr + 3 ; routine
	sta sound_arg_routine
	lda z_operand_value_high_arr + 3 ; routine
	sta sound_arg_routine + 1
    jmp sound_effect
}
.play_beep
    dex
	beq .sound_high_pitched_beep
	dex
	beq .sound_low_pitched_beep
	rts
!ifdef HAS_SID {	
.sound_high_pitched_beep
	lda #$40
.sound_low_pitched_beep
	sta $d401
	lda #$21
	sta $d404
	ldy #40
--	ldx #0
-	dex
	bne -
	dey
	bne --
	lda #$20
	sta $d404
	rts
} else {
	!ifdef TARGET_PLUS4 {
.sound_high_pitched_beep
	lda #$f2
.sound_low_pitched_beep
	sta ted_voice_2_low
	sta ted_voice_2_high
	lda #32 + 15
	sta ted_volume
	ldy #40
--	ldx #0
-	dex
	bne -
	dey
	bne --
	lda #0 + 15
	sta ted_volume
	rts
	} else {
.sound_high_pitched_beep
.sound_low_pitched_beep
	rts
	}
}


