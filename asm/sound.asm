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
; Future improvements:
; - perhaps change preload of all sounds to load on demand for faster init?

!ifdef SOUND {
!zone sound_support {

!ifdef Z5PLUS {
LOOPING_SUPPORTED = 1
}

!ifdef LURKING_HORROR {
; Lurking horror isn't following the standard, and we add hardcoded
; looping support instead
LOOPING_SUPPORTED=1
.lh_repeats
!byte $00, $00, $00, $01, $ff, $00, $01, $01, $01, $01
!byte $ff, $01, $01, $ff, $00, $ff, $ff, $ff, $ff, $ff
}

!ifdef TARGET_MEGA65 {

;TRACE_SOUND = 1
;SOUND_AIFF_ENABLED = 1
;SOUND_WAV_ENABLED = 1

sound_load_msg !pet "Loading sound: ",13,0
;sound_load_msg_2 !pet 13,"Done.",0
.sound_file_extension
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

sound_table_size = 253
sound_table
sound_start_page_low !fill sound_table_size,0
sound_start_page_high !fill sound_table_size,0
sound_length_pages !fill sound_table_size,0

sound_base_value = 1024*1024/256 ; 1 MB into Attic RAM
sound_next_page !byte <sound_base_value, >sound_base_value

sound_file_target = z_temp + 3 ; 4 bytes
.sound_temp = z_temp + 6 ; 2 bytes
.fx_number = z_temp + 8
sound_mempointer_32 = z_operand_value_low_arr
sound_dir_ptr = z_operand_value_high_arr
sound_files_read !byte 0

.read_filename_char
	jsr read_sound_dir_char
	sta sound_file_name,x
	inx
	rts

reset_sound_dir_ptr
; Read directory into Attic RAM at $08080400 (513 KB in)
	lda #$00
	sta sound_dir_ptr
	lda #$04
	sta sound_dir_ptr + 1
	lda #$08
	sta sound_dir_ptr + 2
	sta sound_dir_ptr + 3
	rts

read_sound_dir_char
	lda [sound_dir_ptr],z
	inq sound_dir_ptr
	rts

setup_sound_mempointer_32
	; Sets sound_mempointer to $08080000
	lda #0
	sta sound_mempointer_32
	sta sound_mempointer_32 + 1
	lda #8
	sta sound_mempointer_32 + 2
	sta sound_mempointer_32 + 3
	rts

.copy_sound_table_and_return
	; Copy sound table from Attic RAM, address $08080100
	jsr setup_sound_mempointer_32
	lda #1
	sta sound_mempointer_32 + 1
	lda #<sound_table_size * 3
	sta .sound_temp
	lda #>sound_table_size * 3
	sta .sound_temp + 1
	ldz #0
	ldy #0
.load_from_attic
	lda [sound_mempointer_32],z
.store_in_sound_table
	sta sound_table,y
	iny
	inz
	bne +
	inc sound_mempointer_32 + 1
	inc .store_in_sound_table + 2
+	dec .sound_temp + 10
	bne .load_from_attic
	dec .sound_temp + 1
	bne .load_from_attic
	jmp .loaded_sounds_success

read_sound_files
	bit m65_x16_statmem_already_loaded
	bpl +

	jsr setup_sound_mempointer_32
	ldz #0
	lda [sound_mempointer_32],z
	cmp #83 ; 's'
	beq .copy_sound_table_and_return

+	lda #>sound_load_msg
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

	ldx #0 ; Status for sound counter
-	jsr kernal_readchar
	sta [sound_dir_ptr],z
	inq sound_dir_ptr

	cpx #0
	bne +
	cmp #$22 ; "
	bne ++
	inx
	bne ++ ; Always branch
+	cmp #$29
	bne +
	lda #$24
	jsr s_printchar
+	ldx #0
++	jsr kernal_readst
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

; ; Read loop/music markers (Music marker NOT CURRENTLY IMPLEMENTED)
	; lda #0
	; sta .sound_repeating
	; jsr .read_filename_char
	ldy #0
	; cmp #$52 ; 'r' for Repeating
	; bne +
	; dec .sound_repeating

; Read file extension
; .filename_end_of_markers
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

!ifdef DEBUG {
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
}
	

; Load file to Attic RAM
	lda zp_temp
	ldx #<sound_file_name
	ldy #>sound_file_name
	jsr kernal_setnam ; call SETNAM

	; Signal that REU copy routine should not update progress bar
	lda #0
	sta reu_progress_bar_updates

; Load to address 1024K and onward in Attic RAM
	ldx sound_next_page
	lda sound_next_page + 1
	ldy .fx_number
	stx sound_start_page_low - 3,y
	sta sound_start_page_high - 3,y
	
	jsr m65_load_file_to_reu ; in reu.asm
	inc sound_files_read

!ifdef DEBUG {
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
} else {
	pha
	lda #20 ; delete
	jsr s_printchar
	pla
}

	
	ldy .fx_number
	sta sound_length_pages - 3,y
	clc
	adc sound_next_page
	sta sound_next_page
	bcc +
	inc sound_next_page + 1
+ 
	jmp .skip_to_end_of_line

.end_of_dir
	jsr close_io

	jsr wait_a_sec
	jsr wait_a_sec

	ldx #$ff
	jsr erase_window
	
	; Set carry if no files could be read
	lda sound_files_read
	bne +
	sec
	rts
	
+	; Copy sound table to Attic RAM, address $08080100
	jsr setup_sound_mempointer_32
	lda #1
	sta sound_mempointer_32 + 1
	lda #<sound_table_size * 3
	sta .sound_temp
	lda #>sound_table_size * 3
	sta .sound_temp + 1
	ldz #0
	ldy #0
.load_from_sound_table
	lda sound_table,y
	sta [sound_mempointer_32],z
	iny
	inz
	bne +
	inc sound_mempointer_32 + 1
	inc .load_from_sound_table + 2
+	dec .sound_temp + 10
	bne .load_from_sound_table
	dec .sound_temp + 1
	bne .load_from_sound_table

	; Set a flag in Attic RAM to say "Sound effects have been loaded"
	lda #0
	sta sound_mempointer_32 + 1
	lda #83 ; 's'
	ldz #0
	sta [sound_mempointer_32],z
;	lda sound_files_read	
.loaded_sounds_success
	clc
	rts

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

sound_is_playing !byte 0

.sound_callback
    lda sound_is_playing
    beq .sound_callback_done
    ; We issued a sound request. Is it still running?
    lda $d720
    and #$08
	bne +
	; The sound is playing, but maybe we should stop it to process
	; the next command in queue?
	lda curr_sound_done_repeats
	beq .sound_callback_done
	lda sound_command_queue_pointer
    beq .sound_callback_done
	; There is an command in queue, and we've played this 1+ times
	jsr stop_sound_effect_sub
	
+   ; the sound has stopped
    lda #0
    sta sound_is_playing
	inc curr_sound_done_repeats
	; If there is something in queue, we process the next command
	lda sound_command_queue_pointer
	beq +
	jsr sound_effect
	jmp .sound_callback_done
+
!ifdef LOOPING_SUPPORTED {
    ; are we looping?
    lda curr_sound_arg_repeats
	
    cmp #$ff
    beq .sound_callback_restart_sample
    dec curr_sound_arg_repeats
    beq .sound_finished
.sound_callback_restart_sample
    ; loop!
    jsr .play_sample
    jmp .sound_callback_done
}
.sound_finished
!ifdef Z5PLUS {
    ; trigger the routine callback, if any
	ldx sound_routine_queue_count
	cpx #SOUND_ROUTINE_QUEUE_SIZE
	bcs ++ ; No room in queue
    lda curr_sound_arg_routine
    ora curr_sound_arg_routine + 1
    beq ++  ; routine = 0
    ; routine isn't 0, trigger the callback
    lda curr_sound_arg_routine
	sta sound_routine_queue_low,x
    lda curr_sound_arg_routine + 1
	sta sound_routine_queue_high,x
	inc sound_routine_queue_count
++
}
	jsr .play_next_sound
.sound_callback_done
    ; finish interrupt handling
    asl $d019 ; acknowledge irq
    jmp $ea31  ; finish irq

sound_start_input_counter !byte 0

; This is set by z_ins_sound_effect
sound_arg_number !byte 0
sound_arg_effect !byte 0
sound_arg_volume !byte 0
sound_arg_repeats !byte 0
sound_arg_routine !byte 0, 0

; This is for sound currently playing
curr_sound_done_repeats !byte 0
curr_sound_arg_repeats  !byte 0
curr_sound_arg_routine  !byte 0, 0

sound_tmp !byte 0,0

; Sound command queue
SOUND_COMMAND_QUEUE_SIZE =  8
sound_command_queue         !fill SOUND_COMMAND_QUEUE_SIZE*8,0
sound_command_queue_pointer !byte 0

; signal for the z-machine to run the routine argument
sound_routine_queue_low !byte 0,0,0,0,0,0,0,0
sound_routine_queue_high !byte 0,0,0,0,0,0,0,0
sound_routine_queue_count !byte 0
SOUND_ROUTINE_QUEUE_SIZE = 8

; This is set by sound-aiff or sound-wav
sample_rate_hz !byte 0,0 
sample_is_signed !byte 0 ; 0 if sample data is unsigned, $ff if signed
sample_start_address !byte 0,0,0,0 ; 32 bit pointer
sample_stop_address !byte 0,0,0,0 ; 32 bit pointer

.current_effect !byte $ff
.bad_audio_format_msg !pet "[unsupported audio format]", 13, 0
.sample_clock_dummy !byte 0 ; A dummy byte just before sample_clock, needed for the calculations for conversion from sample rate
.sample_clock !byte 0,0,0

pop_sound_command_queue
	lda sound_command_queue_pointer
	cmp #9
	bcc + ; Queue has 0 or 8 bytes => Set to 0
	ldy #8
-	lda sound_command_queue,y
	sta sound_command_queue - 8,y
	iny
	cpy sound_command_queue_pointer
	bcc -
	tya
	sbc #8 ; Carry already set
	sta sound_command_queue_pointer
	rts
+	lda #0
	sta sound_command_queue_pointer
	rts

sound_effect
    ; input: sound_command_queue holds next command

	; sound_command_queue + ...
	; 0: number LB
	; 1: number HB
	; 2: effect LB
	; 3: effect HB
	; 4: volume
	; 5: repeats    (v5 only)
	; 6: routine LB (v5 only)
	; 7: routine HB (v5 only)

	lda sound_command_queue ; number
	sta sound_arg_number
	lda sound_command_queue + 2 ; effect
	sta sound_arg_effect

	lda sound_command_queue + 4
	bne ++
	; No volume given, set to max...
	lda #255
	sta sound_command_queue + 4
++
!ifdef Z5PLUS {
	; ... and set repeats to 1 for z5
	lda sound_command_queue + 5
	bne +
	lda #1
	sta sound_command_queue + 5
+
}

	lda sound_command_queue + 4 ; volume
	cmp #$ff
	beq +
	cmp #9 ; Values 9-254 are rounded down to 8
	bcc ++
	lda #8
	sta sound_command_queue + 4 
++	asl
	asl
	asl
	asl
	asl
	sec
	sbc sound_command_queue + 4
+	; MEGA65's volume is [0,64]. Convert from z-machine [0,255]
	clc
	ror
	clc
	ror
	sta sound_arg_volume
!ifdef Z5PLUS {
	lda sound_command_queue + 5 ; repeats
	sta sound_arg_repeats
	lda sound_command_queue + 6 ; routine LB
	sta sound_arg_routine
	lda sound_command_queue + 7 ; routine HB
	sta sound_arg_routine + 1
}
	jsr pop_sound_command_queue

!ifdef LURKING_HORROR {
	ldx sound_arg_number
	lda .lh_repeats,x
	sta sound_arg_repeats
}

    ; currently we ignore 1 prepare
    lda sound_arg_effect
    cmp #2 ; start
	beq .play_sound_effect
	cmp #3 ; stop
    beq .stop_sound_effect
	cmp #4 ; finish with
    beq .stop_sound_effect
.return
    rts

stop_sound_effect_sub
    lda #$00
    sta $d720
    sta $d740
    sta sound_is_playing
	rts

.play_sound_effect
    ; input: x = sound effect (3, 4 ...)
	lda input_counter
	sta sound_start_input_counter
    ; convert to zero indexed
	ldx sound_arg_number ; Sound number ( 3 .. 255)
    dex
    dex
    dex
	lda sound_start_page_high,x
	beq .return
!ifdef TRACE_SOUND {
    jsr print_following_string
    !text "play_sound_effect ",0
    lda .current_effect
    jsr printa
    jsr space
    jsr printx
    jsr newline
}
	lda sound_arg_repeats
	sta curr_sound_arg_repeats
	lda #0
	sta curr_sound_done_repeats
	lda sound_arg_routine
	sta curr_sound_arg_routine
	lda sound_arg_routine + 1
	sta curr_sound_arg_routine + 1
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
	bit sound_is_playing
	bpl .play_next_sound
	ldx sound_arg_number
	beq .do_stop
	dex
	dex
	dex
	cpx .current_effect
	bne .play_next_sound
.do_stop
	jsr stop_sound_effect_sub

.play_next_sound
	lda sound_command_queue_pointer
	beq +
	jmp sound_effect
+   rts

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
    ; NOTE: it should be possible to use channel 0 only and mirror it
    ; using $d71c, but this only work on real HW, not in the emulator
    ; stop playback while loading new sample data
    lda #$00
    sta $d720
    ; store sample start address in base and current address
    lda sample_start_address
    sta $d721 ; base 
    sta $d72a ; current
    lda sample_start_address + 1
    sta $d722
    sta $d72b
    lda sample_start_address + 2
    sta $d723
    sta $d72c
    ; store sample stop address
    lda sample_stop_address
    sta $d727
    lda sample_stop_address + 1
    sta $d728
    ; volume
    lda sound_arg_volume
    sta $d729
    sta $d71c ; mirror the sound for stereo
    ; sample clock/rate
    jsr .calculate_sample_clock
    lda .sample_clock
    sta $d724
    lda .sample_clock + 1
    sta $d725
    lda .sample_clock + 2
    sta $d726
    ; Enable playback of channel 0
    lda #$82 ; CH0EN + CH0SBITS (10 = 8 bits sample)
    ldx sample_is_signed
    beq +
    ora #$20 ; CH0SGN
+   sta $d720
    ; enable audio dma
    lda #$80 ; AUDEN
    sta $d711
    sta sound_is_playing ; tell the interrupt that we are running
    rts

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
} ; ifdef TARGET_MEGA65
} ; zone sound_support
} ; ifdef SOUND
.immediate !byte 0

.ignore_effect
	rts
z_ins_sound_effect
	ldy z_operand_count
	beq play_beep ; beep if no args (Z-machine standards, p101)
	ldx z_operand_value_low_arr
!ifdef SOUND {
	cpy #2
	bcc play_beep ; Only one arg => play beep!
	cpx #0
	beq ++
+   cpx #$03
    bcc play_beep
++	ldy #0
	sty .immediate
	lda z_operand_value_low_arr + 1 ; effect
	cmp #2
	bcc .ignore_effect
	cmp #5
	bcs .ignore_effect
	
	; This is 2:play, 3:stop, or 4:finish with
	bit sound_is_playing
	bpl .play_immediate
	ldy sound_start_input_counter
	cpy input_counter
	bne .play_immediate ; Not same text input cycle => play now!

	; Enqueue sound, if there is room in queue
	ldy sound_command_queue_pointer
	cpy #8*SOUND_COMMAND_QUEUE_SIZE
	bcc .enqueue ; There is room in queue => enqueue! 
	; No room in queue => play now!

.play_immediate
	ldy #0
	sty sound_command_queue_pointer
	dec .immediate ; Set to 255

.enqueue
	ldy sound_command_queue_pointer
	ldx #0
-	lda z_operand_value_low_arr,x
	sta sound_command_queue,y
	iny
	lda z_operand_value_high_arr,x
	sta sound_command_queue,y
	iny
	inx
	cpx z_operand_count
	bcc -
	lda #0
-	cpx #4
	bcs .done_copying_to_queue
	sta sound_command_queue,y
	iny
	sta sound_command_queue,y
	iny
	inx
	bne - ; Always branch
.done_copying_to_queue
	sty sound_command_queue_pointer
	
	bit .immediate
	bpl +
	jmp sound_effect
+	rts

} ; ifdef SOUND

play_beep
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
	jsr wait_an_interval
	jsr wait_an_interval
	lda #$20
	sta $d404
	rts
} else {
	!ifdef TARGET_X16 {
.sound_low_pitched_beep
	lda #$02
.sound_high_pitched_beep
	stz VERA_ctrl
	pha
	lda #$11
	sta VERA_addr_bank
	lda #$f9
	sta VERA_addr_high
	lda #$c0
	sta VERA_addr_low
	lda #0
	sta VERA_data0
	pla
	sta VERA_data0
	lda #$c0 + 63
	sta VERA_data0
	lda #$80
	sta VERA_data0
	ldy #1
	ldx #60
	jsr wait_yx_ms
	lda #$f9
	sta VERA_addr_high
	lda #$c2
	sta VERA_addr_low
	lda #$c0 + 0
	sta VERA_data0
	rts
	} else ifdef TARGET_PLUS4 {
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


