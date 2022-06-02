; Sound support (currently only for MEGA65)
;
; Ozmoo can read and play sound effects (samples) from
; wav or aiff files. Aiff files can be extracted from
; blorb files using the rezrov utility:
; http://www.ifarchive.org/if-archive/programming/blorb/rezrov.c
; or converted from other sample formats using a tool like
; sndfile-convert
;
; Blorb files are the standard asset format for Inform games,
; and Infocom assets from Sherlock, The Luring Horror and Shogun
; have been converted to blorb.
; Specification: https://www.eblong.com/zarf/blorb/
;
; Currently we only support sample files with 8 bits, one channel.
;
; TODO:
; - perhaps change preload of all sounds to load on demand for faster init

!ifdef SOUND {
!zone sound_support {
!ifdef TARGET_MEGA65 {

;TRACE_SOUND = 1
;SOUND_AIFF_ENABLED = 1
SOUND_WAV_ENABLED = 1

sound_load_msg !pet "Loading sound: ",13,0
sound_load_msg_2 !pet 13,"Done.",0
.sound_file_extension
;	!pet ".wav",34,32
!ifdef SOUND_AIFF_ENABLED {
	!pet ".aiff"
	.filename_extension_len = 5
}
!ifdef SOUND_WAV_ENABLED {
	!pet ".wav"
	.filename_extension_len = 4
}
sound_file_name 
	!pet "#000xx.aiff........." ; Must have room for a full name + ",s"
; !ifdef SOUND_AIFF_ENABLED {
	; !pet "aiff"
; }
; !ifdef SOUND_WAV_ENABLED {
	; !pet "wav"
; }
	; !byte $a0,$a0,$a0,$a0,$a0,$a0,$a0,$a0
sound_start_page_low !fill 253,0
sound_start_page_high !fill 253,0
sound_length_pages !fill 253,0
sound_base_value = 1024*1024/256 ; 1 MB into Attic RAM
sound_next_page !byte <sound_base_value, >sound_base_value

sound_nums !byte 100,10,1
sound_data_base = z_temp + 3
sound_file_target = sound_data_base ; 4 bytes
dir_entry_start = sound_data_base +  4 ; 1 byte
;sound_file_track = sound_data_base + 5 ; 1 byte
;sound_file_sector = sound_data_base + 6 ; 1 byte
;.sound_file_device = sound_data_base + 5
;.dir_pointer = sound_data_base + 7 ; 2 bytes
.fx_number = sound_data_base + 5
.sound_temp = sound_data_base + 6
sound_index_ptr = z_operand_value_low_arr ; 4 bytes
sound_index_base_ptr = z_operand_value_low_arr + 4; 4 bytes
sound_dir_ptr = z_operand_value_high_arr
;.data_pointer = object_temp ; 2 bytes
; sound_index = z_operand_value_low_arr + 4 ; 1 byte
.sound_repeating !byte 0
; top_soundfx_plus_1 !byte 0
sound_files_read !byte 0

; read_sound_file
	; ; a: Sound file number (3-255)
	
	; ; Set filename
	; ldx #0
; -	ldy #48 ; "0"
; --	cmp sound_nums,x
	; bcc +
	; sbc sound_nums,x
	; iny
	; bne -- ; Always branch
; +	sty sound_file_name,x
	; inx
	; cpx #3
	; bcc -

	; jsr get_free_vmem_buffer

	; ; Set pointers
	; sta readblocks_mempos + 1 ; Low byte is always 0
	; sta .dir_pointer + 1
	; ldy #0
	; sty .dir_pointer
	
; ; Read a directory sector
	; lda #40
	; ldx #3
; .read_next_dir_sector

	; jsr read_track_sector
	; lda #2
	; sta dir_entry_start
; .compare_next_dir_entry
	; ldy dir_entry_start
	; lda (.dir_pointer),y
	; cmp #$82
	; bne .dir_not_match
	; iny
	; lda (.dir_pointer),y
	; sta sound_file_track
	; iny
	; lda (.dir_pointer),y
	; sta sound_file_sector
	; iny
	; ldx #0
; --	lda sound_file_name,x
	; cmp (.dir_pointer),y
	; bne .dir_not_match
	; inx
	; iny
	; cpx #7 ; Should be 16, but during testing it's easier if the stop after 7 characters, so 003.aif is recognized (final f is missing) 
	; bcc --

; ; We have a match - Read the file!
	; jmp .read_file
	
; .dir_not_match
	; lda dir_entry_start
	; clc
	; adc #$20
	; sta dir_entry_start
	; bcc .compare_next_dir_entry
	
; ; Check next directory block here
	; ldy #0
	; lda (.dir_pointer),y
	; beq .fail
	; pha
	; iny
	; lda (.dir_pointer),y
	; tax
	; pla
	; bne .read_next_dir_sector ; Always branch
; .fail
	; sec
	; rts

.read_filename_char
	jsr read_sound_dir_char
	sta sound_file_name,x
	inx
	rts

reset_sound_dir_ptr
; Read directory into Attic RAM at $08080000
	lda #$00
	sta sound_dir_ptr
	sta sound_dir_ptr + 1
	lda #$08
	sta sound_dir_ptr + 2
	sta sound_dir_ptr + 3
	rts

read_sound_dir_char
	lda [sound_dir_ptr],z
	inq sound_dir_ptr
	rts

read_sound_files

;	jsr get_free_vmem_buffer

	; Set pointers
;	sta readblocks_mempos + 1 ; Low byte is always 0
;	sta .dir_pointer + 1
;	ldy #0
;	sty .dir_pointer
;	sty .data_pointer

;	jsr get_free_vmem_buffer
;	sta .data_pointer + 1


	lda #>sound_load_msg
	ldx #<sound_load_msg
	jsr printstring_raw

; ==================== NEW CODE TO READ DIR

	ldz #0
	jsr reset_sound_dir_ptr

	lda #directory_name_len
	ldx #<directory_name
	ldy #>directory_name
	jsr kernal_setnam ; call SETNAM

	lda #3      ; file number
	ldx boot_device
	ldy #0      ; secondary address
	jsr kernal_setlfs ; call SETLFS
	jsr kernal_open     ; call OPEN
;	bcs disk_error    ; if carry set, the file could not be opened

	ldx #3      ; filenumber
	jsr kernal_chkin ; call CHKIN (file# in x now used as input)

-	jsr kernal_readchar
	sta [sound_dir_ptr],z
	inq sound_dir_ptr

	jsr kernal_readst
	bne .dir_copying_done

	jmp -

.dir_copying_done
	lda #$03      ; filenumber 2
	jsr kernal_close ; call CLOSE

	jsr reset_sound_dir_ptr
	
	; Skip load address and disk title
	ldy #31
-	jsr read_sound_dir_char
	dey
	bne -

.skip_to_end_of_line
-	jsr read_sound_dir_char
	cmp #0
	bne -

;	ldy .fx_number
;	sty SCREEN_ADDRESS

.read_next_line	
	lda #0
	sta zp_temp + 1
	; Read row pointer
	jsr read_sound_dir_char
	sta zp_temp
	jsr read_sound_dir_char
	ora zp_temp
	bne +
	jmp .end_of_dir
+

; Skip line number
	jsr read_sound_dir_char
	jsr read_sound_dir_char

; Find first "
-	jsr read_sound_dir_char
	cmp #0
	beq .read_next_line
	cmp #$22 ; Charcode for "
	bne -

; Reset number
	ldx #0 ; Counter for filename characters read
	stx .fx_number ; The number of the sound (3-255)

; Check that first char is )
	jsr .read_filename_char
	cmp #$29 ; ')'
	bne .skip_to_end_of_line

; Read digits
.read_next_digit
	jsr .read_filename_char
	and #$0f
	sta .sound_temp
	lda .fx_number
	asl
	asl
	adc .fx_number
	asl
	adc .sound_temp
	sta .fx_number
	cpx #4
	bcc .read_next_digit

; Read loop/music markers (Music marker NOT CURRENTLY IMPLEMENTED)
	lda #0
	sta .sound_repeating
	jsr .read_filename_char
	ldy #0
	cmp #$52 ; 'r' for Repeating
	bne +
	dec .sound_repeating

; Read file extension
.filename_end_of_markers
;	ldy #0
-	jsr .read_filename_char
+	cmp .sound_file_extension,y
	bne .skip_to_end_of_line
	iny
	cpy #.filename_extension_len ; Length; should be 4 for ".wav" or 5 for ".aiff" 
	bcc -

	stx zp_temp

; Add ,s to filename (to read it as a SEQ file)
	ldx zp_temp
	lda #$2c ; ','
	sta sound_file_name,x
	inx
	lda #$53 ; 's'
	sta sound_file_name,x
	inx
	lda #$2c ; ','
	sta sound_file_name,x
	inx
	lda #$52 ; 'r'
	sta sound_file_name,x
	inx
	stx zp_temp

; Print filename for debug purposes
	lda #34
	jsr s_printchar
	ldx #0
-	lda sound_file_name,x
	jsr s_printchar
	inx
	cpx zp_temp
	bcc -
	lda #34
	jsr s_printchar

; Load file to Attic RAM
	lda zp_temp
	ldx #<sound_file_name
	ldy #>sound_file_name
	jsr kernal_setnam ; call SETNAM

	; Signal that REU copy routine should not update progress bar
	lda #0
	sta reu_progress_bar_updates

; Load to adress 1024K and onward in Attic RAM
	ldx sound_next_page
	lda sound_next_page + 1
	ldy .fx_number
	stx sound_start_page_low - 3,y
	sta sound_start_page_high - 3,y
	
	jsr m65_load_file_to_reu ; in reu.asm
	inc sound_files_read

; Print pages loaded for debug purposes (a = 1, b=2, ...)
	pha
	lsr
	lsr
	clc
	adc #$40
	jsr s_printchar
	lda #13
	jsr s_printchar
	pla
	
	ldy .fx_number
	sta sound_length_pages - 3,y
	clc
	adc sound_next_page
	sta sound_next_page
	bcc +
	inc sound_next_page + 1
+ 
	; stx sound_next_page
	; sta sound_next_page + 1
	; txa
	; sec
	; sbc sound_start_page_low - 3,y
	; sta sound_length_pages - 3,y
	; jsr wait_a_sec
	
; Start reading from dir again
;	ldx #3      ; filenumber 3
;	jsr kernal_chkin ; call CHKIN (file 3 now used as input)

	jmp .skip_to_end_of_line

.end_of_dir
;	lda #$03      ; filenumber 2
;	jsr kernal_close ; call CLOSE
	jsr close_io

	jsr wait_a_sec
	jsr wait_a_sec

	ldx #$ff
	jsr erase_window
	
	; Set carry if no files could be read
	clc
	lda sound_files_read
	bne +
	sec
+
	rts
; -	
	; inc $d020
	; jmp -


;	cmp #$52 ; 'r'
;	bne .filename_after_digits
;	dec .sound_repeats ; Set it to $ff

; We have a match - Read the file!
;	jsr .read_file
;	inc sound_files_read
	


; .read_file

	; lda sound_file_track
	; ldx sound_file_sector
; .read_next_file_sector
	; jsr read_track_sector

	; ; Copy to target address
	; lda .dir_pointer + 1
	; sta dma_source_address + 1
	; lda sound_file_target
	; sta dma_dest_address
	; lda sound_file_target + 1
	; sta dma_dest_address + 1
	; lda sound_file_target + 2
	; and #$0f
	; sta dma_dest_bank_and_flags
	
	; lda sound_file_target + 2
	; sta vmem_temp
	; lda sound_file_target + 3
	
	; ldy #4
; -	asl vmem_temp
	; rol
	; dey
	; bne -
	; sta dma_dest_address_top

	; ldy #2
	; sty dma_source_address
	; ldy #0
	; sty dma_count + 1 ; Transfer 254 bytes
	; sty dma_source_bank_and_flags
	; sty dma_source_address_top
	; ldx #254
	; lda (.dir_pointer),y
	; bne +
	; iny
	; lda (.dir_pointer),y
	; tax
	; dex
; +	stx dma_count

	; jsr m65_run_dma

; ; Increase the address
	; lda #0
	; tax
	; tay
	; taz
	; lda dma_count
	; clc
	; adcq sound_file_target
	; stq sound_file_target

	; ldy #1
	; lda (.dir_pointer),y
	; tax
	; dey
	; lda (.dir_pointer),y
	; bne .read_next_file_sector	

	; lda .fx_number
	; adc #64
	; jsr s_printchar
	; clc
	; rts

; store_sound_effect_start
	; ; Insert code here to copy the 4-byte value in sound_file_target to the table for sound effect
	; ; start addresses. The index to use is in top_soundfx_plus_1
	; ldq sound_file_target
	; stq [sound_index_ptr]
	; lda #0
	; tax
	; tay
	; taz
	; lda #4
	; clc
	; adcq sound_index_ptr
	; stq sound_index_ptr
	; rts

; read_all_sound_files
	; lda #>sound_load_msg
	; ldx #<sound_load_msg
	; jsr printstring_raw

; ; Init target address ($08100000) and index address ($0807F800)
	; ldz #$08
	; ldy #$10
	; lda #$00
	; tax
	; stq sound_file_target
	; ldy #$07
	; ldx #$f8
	; stq sound_index_base_ptr

	; ; lda #3
	; ; sta top_soundfx_plus_1
	
	; jsr read_sound_files
	
; ; -	jsr store_sound_effect_start
	; ; lda top_soundfx_plus_1
	; ; jsr read_sound_file
	; ; bcs +
	; ; inc top_soundfx_plus_1
	; ; bne -
; ; +
	; ; ; A file couldn't be read. We're done.
	
	; lda #>sound_load_msg_2
	; ldx #<sound_load_msg_2
	; jsr printstring_raw
	; jsr wait_a_sec
	; ldx #$ff
	; jsr erase_window
	; clc
	; lda sound_files_read
	; bne +
	; sec
; ;	lda #3
; ;	cmp top_soundfx_plus_1 ; Set carry if no sound files could be loaded
; +	rts

init_sound
    ; set up an interrupt to monitor playback
    sei
    lda #<.sound_callback
    ldx #>.sound_callback
    sta $0314
    stx $0315
    lda $d011
    and #$7f ; high raster bit = 0
    sta $d011
    lda #251 ; low raster bit (1 raster beyond visible screen)
    sta $d012
    cli
    jmp read_sound_files

.sound_is_playing !byte 0

.sound_callback
    lda .sound_is_playing
    beq .sound_callback_done
    ; We issued a sound request. Is it still running?
    lda $d720
    and #$08
    beq .sound_callback_done
    ; the sound has stopped
    lda #0
    sta .sound_is_playing
!ifdef Z5PLUS {
    ; are we looping?
    lda sound_arg_repeats
	
    cmp #$ff
    beq .sound_callback_restart_sample
    dec sound_arg_repeats
    beq .sound_finished
.sound_callback_restart_sample
    ; loop!
    jsr .play_sample
    jmp .sound_callback_done
}
.sound_finished
!ifdef Z5PLUS {
    ; trigger the routine callback, if any
    lda sound_arg_routine
    bne +
    lda sound_arg_routine + 1
    beq ++  ; routine = 0
+   ; routine isn't 0, trigger the callback
    lda #1
    sta trigger_sound_routine
++
}
.sound_callback_done
    ; finish interrupt handling
    asl $d019 ; acknowlege irq
    jmp $ea31  ; finish irq


; This is set by z_ins_sound_effect
sound_arg_effect !byte 0
sound_arg_volume !byte 0
sound_arg_repeats !byte 0
sound_arg_routine !byte 0, 0

sound_tmp !byte 0,0

; signal for the z-machine to run the routine argument
trigger_sound_routine !byte 0

; This is set by sound-aiff or sound-wav
sample_rate_hz !byte 0,0 
sample_is_signed !byte 0 ; 0 if sample data is unsigned, $ff if signed
sample_start_address !byte 0,0,0,0 ; 32 bit pointer
sample_stop_address !byte 0,0,0,0 ; 32 bit pointer

.current_effect !byte $ff
.bad_audio_format_msg !pet "[unsupported audio format]", 13, 0
.sample_clock_dummy !byte 0 ; A dummy byte just before sample_clock, needed for the calculations for conversion from sample rate
.sample_clock !byte 0,0,0

sound_effect
    ; currently we ignore 1 prepare and 4 finish with
    lda sound_arg_effect
    cmp #2 ; start
    beq .play_sound_effect
    cmp #3 ; stop
    beq .stop_sound_effect
.return
    rts
    
.play_sound_effect
    ; input: x = sound effect (3, 4 ...)
    ; convert to zero indexed
 ;   cpx top_soundfx_plus_1
 ;   bcs .return
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
+   ; parse sound effect data
    lda #$00
    sta sample_start_address + 2;
!ifdef SOUND_WAV_ENABLED {
    jsr .parse_wav
}
!ifdef SOUND_AIFF_ENABLED {
    jsr .parse_aiff
}
    ; error if sample_start_address not set
    lda sample_start_address + 2;
    bne +
    lda #>.bad_audio_format_msg
    ldx #<.bad_audio_format_msg
    jmp printstring_raw
+   ; play the sample
    jmp .play_sample;

.stop_sound_effect
    lda #$00
    sta $d720
    sta $d740
    sta .sound_is_playing
    rts

.calculate_sample_clock
   ; frequency (assuming CPU running at 40.5 MHz)
    ;
    ; max sample clock $ffffff is about 40 MHz sample rate
    ; (stored in $d724-$d726)
    ;
    ; $ffffff / sample_clock = CPU / f  => sample_clock = ($ffffff * f)/ CPU
    ; but $ffffff/CPU is constant about 1/2.414
    ; sample_clock =  f / 2.414
    ;
    ; to avoid floating point, multiply by 1000
    ; x = (f * 2414)/1000 
    ;
    ; this is still hard to do with integers, so simplify by
    ; using 106/256 (~= 1/2.415) instead. This will be 1% faster.
    ; x = f * (106/256) = (f * 106) >> 8
	stx sound_tmp
	sty sound_tmp + 1
    jsr mega65io
    lda #0
    tax
    tay
    taz
    lda #106
    stq $d770
    ldx sample_rate_hz + 1
    lda sample_rate_hz
    stq $d774
    ldq $d778
    stq .sample_clock_dummy ; Skip the lowbyte at $d778, to perform >> 8
	ldx sound_tmp
	ldy sound_tmp + 1
    rts

.play_sample
    ; TODO: it should be possible to use channel 0 only and mirror
    ; it using $d71c, but I can't get it to work
    ; .play_sample_ch3 can be removed if this is solved
	ldx #$0
	ldy #$20
    jsr .play_sample_ch_xy ; left
    ; enable audio dma
    lda #$80 ; AUDEN
    sta $d711
    sta .sound_is_playing ; tell the interrupt that we are running
    rts

.play_sample_ch_xy
	; stop playback while loading new sample data
	lda #$00
	sta $d720,x
	sta $d720,y
	; store sample start address in base and current address
	lda sample_start_address
	sta $d721,x ; base 
	sta $d721,y ; base 
	sta $d72a,x ; current
	sta $d72a,y ; current
	lda sample_start_address + 1
	sta $d722,x
	sta $d722,y
	sta $d72b,x
	sta $d72b,y
	lda sample_start_address + 2
	sta $d723,x
	sta $d723,y
	sta $d72c,x
	sta $d72c,y
	; store sample stop address
	lda sample_stop_address
	sta $d727,x
	sta $d727,y
	lda sample_stop_address + 1
	sta $d728,x
	sta $d728,y
	; volume
	lda sound_arg_volume
	sta $d729,x
	sta $d729,y
;    sta $d71c ; mirror the sound for stereo (TODO: doesn't work!)
;    sta $d71e ; mirror the sound for stereo (TODO: doesn't work!)
	; sample clock/rate
	jsr .calculate_sample_clock
	lda .sample_clock
	sta $d724,x
	sta $d724,y
	lda .sample_clock + 1
	sta $d725,x
	sta $d725,y
	lda .sample_clock + 2
	sta $d726,x
	sta $d726,y
	; Enable playback of channel 0
	lda #$82 ; CH0EN + CH0SBITS (10 = 8 bits sample)
	bit sample_is_signed
	bpl +
	ora #$20 ; CH0SGN
+   sta $d720,x
	sta $d720,y
	rts

;.play_sample_ch0
;    ; stop playback while loading new sample data
;    lda #$00
;    sta $d720
;    ; store sample start address in base and current address
;    lda sample_start_address
;    sta $d721 ; base 
;    sta $d72a ; current
;    lda sample_start_address + 1
;    sta $d722
;    sta $d72b
;    lda sample_start_address + 2
;    sta $d723
;    sta $d72c
;    ; store sample stop address
;    lda sample_stop_address
;    sta $d727
;    lda sample_stop_address + 1
;    sta $d728
;    ; volume
;    lda sound_arg_volume
;    sta $d729
;    sta $d71c ; mirror the sound for stereo (TODO: doesn't work!)
;    ; sample clock/rate
;    jsr .calculate_sample_clock
;    lda .sample_clock
;    sta $d724
;    lda .sample_clock + 1
;    sta $d725
;    lda .sample_clock + 2
;    sta $d726
;    ; Enable playback of channel 0
;    lda #$82 ; CH0EN + CH0SBITS (10 = 8 bits sample)
;    ldx sample_is_signed
;    beq +
;    ora #$20 ; CH0SGN
;+   sta $d720
;    rts

!ifdef SOUND_WAV_ENABLED {
!source "sound-wav.asm"
}
!ifdef SOUND_AIFF_ENABLED {
!source "sound-aiff.asm"
}

.copy_effect_to_fastram
    ; copy effect .current_effect to fastRAM so it can be played
	; index = effect * 4
    ldx .current_effect
	lda #0
	sta dma_source_address
	lda sound_start_page_low,x
	sta dma_source_address + 1
	lda sound_start_page_high,x
	and #$0f
	sta dma_source_bank_and_flags
	lda sound_start_page_high,x
	lsr
	lsr
	lsr
	lsr
	ora #$80 ; Base of Attic RAM
	sta dma_source_address_top

    ; Set the size of the sound data
    lda #$00
    sta dma_count
	lda sound_length_pages,x
	sta dma_count + 1
    ; copy to $40000
    lda #$00
    sta dma_dest_address
    sta dma_dest_address + 1
    sta dma_dest_address_top
    lda #$04
    sta dma_dest_bank_and_flags
    ; copy
    jmp m65_run_dma
	
	
	
	; ; index = effect * 4
    ; lda #0
    ; tax
    ; tay
    ; taz
    ; lda .current_effect
	; stq sound_index_ptr
	; clc
	; rolq sound_index_ptr
	; rolq sound_index_ptr
    ; ; add index (base = $0807FC00)
    ; clc
    ; ldz #8
    ; ldy #7
    ; ldx #$fc
    ; lda #0
    ; adcq sound_index_ptr
	; stq sound_index_ptr
	; ; read index
	; ldz #0 ; note that ldq uses z
	; ldq [sound_index_ptr]
    ; ; store source address
    ; sta dma_source_address
    ; stx dma_source_address + 1
    ; sty dma_source_bank_and_flags
    ; lda #$80 ; base of attic ram (HyperRAM)
    ; sta dma_source_address_top
    ; ; copy the whole bank
    ; lda #$ff
    ; sta dma_count
    ; sta dma_count + 1
    ; ; copy to $4000
    ; lda #$00
    ; sta dma_dest_address
    ; sta dma_dest_address + 1
    ; sta dma_dest_address_top
    ; lda #$04
    ; sta dma_dest_bank_and_flags
    ; ; copy
    ; jmp m65_run_dma


} ; ifdef TARGET_MEGA65
} ; zone sound_support
} ; ifdef SOUND

z_ins_sound_effect
	ldy z_operand_count
	beq .play_beep ; beep if no args (Z-machine standards, p101)
	ldx z_operand_value_low_arr
!ifdef SOUND {
    cpx #$03
    bcc .play_beep
    ; parse rest of the args
	lda z_operand_value_low_arr + 1 ; effect
	sta sound_arg_effect

;	ldy z_operand_count
	cpy #3
	bcs +
	; No volume given, set to max...
	lda #255
	sta z_operand_value_low_arr + 2
!ifdef Z5PLUS {
	; ... and set repeats to 1 for z5
	lda #1
	sta z_operand_value_high_arr + 2
}
+		
!ifdef Z5PLUS {
	cpy #4
	bcs +
	; No routine given, set to 0
	lda #0
	sta z_operand_value_low_arr + 3
	sta z_operand_value_high_arr + 3
+
}

	lda z_operand_value_low_arr + 2 ; volume
	cmp #$ff
	beq +
	cmp #9 ; Values 9-254 are rounded down to 8
	bcc ++
	lda #8
	sta z_operand_value_low_arr + 2 
++	asl
	asl
	asl
	asl
	asl
	sec
	sbc z_operand_value_low_arr + 2
+	sta sound_arg_volume
!ifdef Z5PLUS {
	lda z_operand_value_high_arr + 2 ; repeats
	bne +
	lda #1
+	sta sound_arg_repeats
	lda z_operand_value_low_arr + 3 ; routine
	sta sound_arg_routine
	lda z_operand_value_high_arr + 3 ; routine
	sta sound_arg_routine + 1
}
    jmp sound_effect
} ; ifdef SOUND
.play_beep
	lda #$08 ; Frequency for low-pitched beep
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
!ifdef TARGET_MEGA65 {
	ldz #40
.outer_loop
}
	ldy #40
--	ldx #0
-	dex
	bne -
	dey
	bne --
!ifdef TARGET_MEGA65 {
	dez
	bne .outer_loop
}
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


