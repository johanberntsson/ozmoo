; Sound effects on the Commander X16: @sound_effect played through VERA's PCM
; FIFO. Sourced from sound.asm under !ifdef TARGET_X16, inside its zone, so the
; shared opcode layer there (the command queue, the argument defaults, the
; routine-callback queue) is used unchanged and only the hardware differs. This
; is the same arrangement as pictures-mega65.asm / pictures-x16.asm.
;
; How it differs from the MEGA65 engine, which is where the shape of the code
; above comes from:
;
;  - No preload. The MEGA65 reads every wav into attic RAM at boot; the X16 has
;    nowhere to put a megabyte, so a sound is LOADed from SD the first time it is
;    played, into banked RAM, exactly as pictures-x16.asm stages a picture. One
;    effect is resident at a time (.current_effect), so replaying or looping one
;    does not touch the disk.
;  - No parser. make.rb has already read the wav header and written the samples
;    as a bare stream of SIGNED bytes plus a rate register byte (see
;    prepare_x16_sounds, and ../temp/sounds.asm at the end of this file), because
;    VERA's 8-bit PCM is signed where a wav's is not, and because working out the
;    rate register needs a divide the X16 has no hardware multiplier to shortcut.
;  - No fire-and-forget. The MEGA65's audio DMA plays a sample with no CPU
;    involvement at all; VERA has a 4 KB FIFO that has to be kept fed, so this
;    engine hangs a handler on $0314 in front of the kernal's and pushes bytes
;    from an interrupt. Two consequences worth knowing: a sound costs a few
;    percent of the CPU while it plays, and "the sample has all been pushed" is
;    not "the sound has finished" - the FIFO still holds up to half a second of
;    it, which is why the drain check below waits for the FIFO-empty flag before
;    firing the game's callback routine.
;
; Note the order of the file: .play_sound_effect must come first, because the
; effect dispatch in sound.asm reaches it with a branch, and the tables are at
; the end for the same reason. SND_COUNT and SND_HIGHEST_NUMBER come from make.rb
; as -D defines rather than from the generated table file, so the !if tests below
; can be resolved before that file is read.

.play_sound_effect
	; Start sound_arg_number (3..255). Reached from sound_effect's dispatch.
	lda input_counter
	sta sound_start_input_counter
	ldx sound_arg_number
	cpx #3
	bcc .snd_return			; 0 is "stop everything", 1 and 2 are the beeps
!if SND_HIGHEST_NUMBER < 255 {
	cpx #SND_HIGHEST_NUMBER + 1
	bcs .snd_return			; past what this build has
}
	dex
	dex
	dex						; zero indexed, as .current_effect is
	lda snd_rate,x
	beq .snd_return			; a rate of 0 means "not in this build" - ignore it
	sta .snd_play_rate
	lda snd_len_lo,x
	sta .snd_len
	lda snd_len_mid,x
	sta .snd_len + 1
	lda snd_len_hi,x
	sta .snd_len + 2
	lda sound_arg_repeats
	sta curr_sound_arg_repeats
	lda #0
	sta curr_sound_done_repeats
	lda sound_arg_routine
	sta curr_sound_arg_routine
	lda sound_arg_routine + 1
	sta curr_sound_arg_routine + 1
	cpx .current_effect
	beq .play_sample		; already resident, so the disk is not touched
	stx .current_effect
	jsr .snd_stage
	bcc .play_sample
.snd_return
	rts

.play_sample
	; Fill the FIFO and let it run. The order matters twice over. The prefill
	; shares the cursor with .snd_irq, so sound_is_playing stays 0 until it is
	; done - that is what stops an interrupt arriving mid-prefill from pushing
	; the same bytes twice. And AUDIO_RATE is written last, because a rate of 0
	; means the FIFO is not consumed at all, so nothing is heard until it is set.
	jsr .snd_silence
	jsr .snd_seed
	lda sound_arg_volume	; the shared scale hands us VERA's [0,15] nybble
	and #$0f
	sta VERA_audio_ctrl		; bits 5 and 4 clear: 8-bit mono
	ldx #0					; no cap: push until the FIFO is full
	jsr .snd_feed
	jsr .snd_check_pass_end	; a sound smaller than the FIFO is already all in
	lda #$80
	sta sound_is_playing
	lda .snd_play_rate
	sta VERA_audio_rate
	lda .snd_rem
	ora .snd_rem + 1
	ora .snd_rem + 2
	beq +					; nothing left to push: no wake-ups wanted, or
	lda VERA_ien			; AFLOW would fire for every byte the FIFO drains
	ora #$08
	sta VERA_ien
+	rts

stop_sound_effect_sub
	jmp .snd_silence

.snd_silence
	lda #0
	sta sound_is_playing
	sta VERA_audio_rate		; stop consuming the FIFO
	sta .snd_rem
	sta .snd_rem + 1
	sta .snd_rem + 2
	lda VERA_ien
	and #$f7				; no more AFLOW wake-ups
	sta VERA_ien
	lda #$80
	sta VERA_audio_ctrl		; reset the FIFO: what was queued is dropped
	rts

.snd_seed
	; Point the feed cursor at the start of the resident sample. It always
	; begins at the foot of SOUND_BANK, because that is where .snd_stage loads.
	lda #SOUND_BANK
	sta .snd_bank
	lda #0
	sta .snd_get + 1
	lda #$a0
	sta .snd_get + 2
	lda .snd_len
	sta .snd_rem
	lda .snd_len + 1
	sta .snd_rem + 1
	lda .snd_len + 2
	sta .snd_rem + 2
	rts

; ---------------------------------------------------------------------------
init_sound
	; Install the FIFO-feeding handler in front of the kernal's own, which must
	; still run: on this target it is what scans the keyboard and moves the
	; mouse pointer (Ozmoo installs nothing else here, which is why the mouse
	; works by itself - see the mouse section of CLAUDE.md).
	lda #$ff
	sta .current_effect
	lda #0
	sta sound_is_playing
	sei
	lda $0314
	sta .old_irq
	lda $0315
	sta .old_irq + 1
	lda #<.snd_irq
	sta $0314
	lda #>.snd_irq
	sta $0315
	cli
!if SND_COUNT = 0 {
	sec						; no sounds: tell z_init to clear the header bit
} else {
	clc
}
	rts

snd_shutdown
	; Called on the way out to BASIC, beside the rest of the VERA teardown: put
	; the FIFO and the interrupt vector back the way the kernal left them.
	jsr .snd_silence
	sei
	lda .old_irq
	ora .old_irq + 1
	beq +					; init_sound never ran, so there is nothing to undo
	lda .old_irq
	sta $0314
	lda .old_irq + 1
	sta $0315
+	cli
	rts

; ---------------------------------------------------------------------------
sound_poll
	; Start the next queued sound. The interrupt cannot do this itself the way
	; the MEGA65's callback does: on this target the next sound has to be LOADed
	; from SD, and the kernal must not be called from an interrupt. So the queue
	; is advanced from here, which text.asm calls on every input wait. The cost
	; is that a sound queued behind another starts at the next input wait rather
	; than the instant the first one ends.
	lda sound_command_queue_pointer
	beq .sp_out
	bit sound_is_playing
	bpl .sp_next
	; Something is playing and something is waiting. The MEGA65's callback cuts
	; the current sound short once it has played through at least once, which is
	; what stops a looping effect blocking the queue for ever; but there,
	; "played through" means the DMA has finished reading the sample, and here it
	; would mean only that the last byte has been pushed - the FIFO still holds
	; up to half a second of audio nobody has heard yet. So the cut also requires
	; the sound to have a pass still to come (curr_sound_arg_repeats, which
	; .snd_check_pass_end leaves at 0 on the last one): a looping sound is cut,
	; a one-shot is left to drain and the queue moves on when it has.
	; Without this test a queued command truncated the sound in front of it by a
	; FIFO's worth - measured: Sherlock's 2.20 s effect 3 came out 1.96 s.
	lda curr_sound_done_repeats
	beq .sp_out
	lda curr_sound_arg_repeats
	beq .sp_out
	jsr stop_sound_effect_sub
.sp_next
	jmp sound_effect
.sp_out
	rts

; ---------------------------------------------------------------------------
.snd_irq
	; In front of the kernal's handler. Entered from the kernal's interrupt
	; stub, so a, x and y are already saved on the stack; we must leave the
	; stack as we found it and chain unconditionally, or the keyboard and the
	; mouse pointer stop working.
	;
	; This does not look at VERA_ISR at all. AFLOW (ISR bit 3) is the prompt
	; wake-up, but the kernal's own 60 Hz vsync interrupt comes through here
	; too, and topping the FIFO up on those as well costs ~130 bytes a frame at
	; 8 kHz and means a sound survives anything that clears our IEN bit behind
	; our back.
	lda sound_is_playing
	bpl .snd_irq_chain
	lda 0					; the bank register belongs to the interrupted code
	pha
	jsr .snd_service
	pla
	sta 0
.snd_irq_chain
	jmp (.old_irq)

.snd_service
	lda .snd_rem
	ora .snd_rem + 1
	ora .snd_rem + 2
	beq .ss_draining
	ldx #4					; at most 1 KB per interrupt, so a refill cannot
	jsr .snd_feed			; hold up the kernal's own interrupt work for long
	; fall through to see whether that was the end of the sample

.snd_check_pass_end
	; Called wherever the cursor can reach the end of the sample: after a feed
	; in the interrupt, and after .play_sample's prefill for a sound that fits
	; in the FIFO whole.
	lda .snd_rem
	ora .snd_rem + 1
	ora .snd_rem + 2
	beq +
	rts
+	inc curr_sound_done_repeats
!ifdef LOOPING_SUPPORTED {
	lda curr_sound_arg_repeats
	cmp #$ff
	beq .cp_again			; $ff: play for ever
	dec curr_sound_arg_repeats
	beq .cp_last
.cp_again
	; Seed the next pass now rather than waiting for the FIFO to run dry, so a
	; loop has no gap in it: the FIFO still holds the tail of this pass.
	jmp .snd_seed
}
.cp_last
	; Nothing left to push. Stop asking to be woken by the FIFO - it is below
	; the AFLOW threshold and would wake us for every byte it drains - and let
	; the 60 Hz interrupt notice when the tail has been heard.
	lda VERA_ien
	and #$f7
	sta VERA_ien
	rts

.ss_draining
	lda VERA_audio_ctrl
	and #$40				; FIFO empty: the tail has played out, so the sound
	beq .ss_out				; really is over now
	lda #0
	sta sound_is_playing
	sta VERA_audio_rate
!ifdef Z5PLUS {
	; Hand the game's routine argument to the main loop, which runs it between
	; instructions (text.asm). It must never be called from here.
	ldx sound_routine_queue_count
	cpx #SOUND_ROUTINE_QUEUE_SIZE
	bcs .ss_out
	lda curr_sound_arg_routine
	ora curr_sound_arg_routine + 1
	beq .ss_out				; no routine argument
	lda curr_sound_arg_routine
	sta sound_routine_queue_low,x
	lda curr_sound_arg_routine + 1
	sta sound_routine_queue_high,x
	inc sound_routine_queue_count
}
.ss_out
	rts

.snd_feed
	; Push samples into the FIFO until it is full or the sample runs out.
	; In: x = how many 256-byte chunks at most (0 = as many as it takes).
	; The bank register is ours for the duration: the caller saved it.
	lda .snd_bank
	sta 0
.sf_chunk
	ldy #0
.sf_byte
	lda .snd_rem
	ora .snd_rem + 1
	ora .snd_rem + 2
	beq .sf_done
	lda VERA_audio_ctrl
	and #$80				; FIFO full? A write then would drop the sample.
	bne .sf_done
.snd_get
	lda $a000				; the cursor: this operand is the address
	sta VERA_audio_data
	inc .snd_get + 1
	bne .sf_count
	inc .snd_get + 2
	lda .snd_get + 2
	cmp #$c0				; off the top of the window: on to the next bank
	bne .sf_count
	lda #$a0
	sta .snd_get + 2
	inc .snd_bank
	lda .snd_bank
	sta 0
.sf_count
	lda .snd_rem			; rem -= 1, 24 bit
	bne +
	lda .snd_rem + 1
	bne ++
	dec .snd_rem + 2
++	dec .snd_rem + 1
+	dec .snd_rem
	dey
	bne .sf_byte
	dex						; x = 0 on entry wraps to 255 chunks, i.e. no cap
	bne .sf_chunk
.sf_done
	rts

; ---------------------------------------------------------------------------
.snd_stage
	; Load sound .current_effect + 3 into the sound banks, SOUND_BANK upward
	; through the $a000 window. Carry set if it could not be read. Modelled on
	; pictures-x16.asm's .pic_stage, with two differences: it stops at the end
	; of the banks make.rb reserved rather than walking into whatever is above
	; them, and it uses no zero page at all (the store below is its own cursor),
	; because it can be reached from the [More] prompt in the middle of a print.
	jsr .snd_silence		; the banks are about to be overwritten
	lda .current_effect
	clc
	adc #3
	sta .snd_num
	jsr .snd_set_filename
	lda #SND_FILE_NAME_LEN
	ldx #<snd_file_name
	ldy #>snd_file_name
	jsr kernal_setnam
	lda #3					; logical file 3: 2 is the story and picture loader's
	tay						; secondary 3: read
	ldx boot_device
	jsr kernal_setlfs
	jsr kernal_open
	bcc +
	jmp .st_fail
+	ldx #3
	jsr kernal_chkin
	lda #SOUND_BANK
	sta 0
	lda #0
	sta .st_put + 1
	lda #$a0
	sta .st_put + 2
	lda #SOUND_BANKS
	sta .st_banks
	; Read exactly as many bytes as the table promises, and insist on getting
	; them. The table and the file come from the same build, so any other length
	; means the game folder does not match the interpreter - a file deleted,
	; replaced, or (on this kernal) not there at all, since OPEN reports success
	; for a name that does not exist and the read then yields whatever the DOS
	; left in its buffer. Playing that is worse than playing nothing: it is a
	; bank of arbitrary bytes at whatever rate the table says.
	lda .snd_len
	sta .st_left
	lda .snd_len + 1
	sta .st_left + 1
	lda .snd_len + 2
	sta .st_left + 2
-	lda .st_left
	ora .st_left + 1
	ora .st_left + 2
	bne +
	jmp .st_done			; got the lot; anything past it is not ours
+	jsr kernal_readst
	bne .st_short			; end of file first: not the file we were promised
	jsr kernal_readchar
.st_put
	sta $a000
	lda .st_left			; one fewer to go, 24 bit
	bne +
	lda .st_left + 1
	bne ++
	dec .st_left + 2
++	dec .st_left + 1
+	dec .st_left
	inc .st_put + 1
	bne -
	inc .st_put + 2
	lda .st_put + 2
	cmp #$c0
	bne -
	lda #$a0
	sta .st_put + 2
	inc 0
	dec .st_banks
	bne -
	; Past the banks make.rb reserved. It sizes them from the files themselves,
	; so the length check above should have caught this first; stop rather than
	; scribble on the staging or undo banks over our heads.
.st_short
	jsr kernal_clrchn
	lda #3
	jsr kernal_close
	jmp .st_bad

.st_done
	jsr kernal_clrchn
	lda #3
	jsr kernal_close
	clc
	rts

.st_fail
	jsr kernal_clrchn
	lda #3
	jsr kernal_close
.st_bad
	lda #$ff
	sta .current_effect		; nothing usable is resident now
	sec
	rts

.snd_set_filename
	; .snd_num (3..255) into snd_file_name as three digits
	lda .snd_num
	ldx #$2f				; '0' - 1
-	inx
	sec
	sbc #100
	bcs -
	adc #100				; carry is clear here, so this adds exactly 100
	stx snd_file_name + 2
	ldx #$2f
-	inx
	sec
	sbc #10
	bcs -
	adc #10
	stx snd_file_name + 3
	ora #$30
	sta snd_file_name + 4
	rts

; ---------------------------------------------------------------------------
SND_FILE_NAME_LEN = 10
; make.rb writes the sample files into the game directory as [S003] etc, next to
; [ZCODE] and the [P###] pictures. !pet lowercase becomes the host's uppercase.
snd_file_name !pet "[s000],s,r"

.snd_num	!byte 0			; the number .snd_set_filename is formatting
.old_irq	!byte 0,0		; the kernal's interrupt handler, which we chain to
.snd_play_rate !byte 0		; AUDIO_RATE for the sound being played
.snd_len	!byte 0,0,0		; its length, for a repeat to re-seed from
.snd_bank	!byte 0			; where the feed cursor is now...
.snd_rem	!byte 0,0,0		; ...and how much of the sample is still to push
.st_banks	!byte 0			; banks the loader may still write to...
.st_left	!byte 0,0,0		; ...and bytes it still expects to read

; snd_len_lo/mid/hi and snd_rate, indexed by (sound number - 3). A rate of 0
; means the build does not have that sound.
!source "../temp/sounds.asm"
