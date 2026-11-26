; Neo6502 Morpheus adapter layer (bootstrap).
;
; This unit is the bridge between Ozmoo's historical KERNAL call surface
; (kernal_setnam/kernal_open/kernal_getchar/...) and Neo6502 Morpheus APIs.
; The initial implementation is intentionally minimal: it provides stable
; entrypoints and state capture so platform-independent code can route through
; one file while Morpheus calls are introduced incrementally.
;
; IMPORTANT:
; - Do not spread Morpheus-specific logic across shared interpreter files.
; - Keep all host API binding in this adapter, then branch from here as needed.

!zone neo6502_morpheus {


neo_kernal_status       !byte 0
neo_kernal_lfn          !byte 0
neo_kernal_device       !byte 0
neo_kernal_sa           !byte 0
neo_kernal_input_lfn    !byte 0
neo_kernal_output_lfn   !byte 0
neo_kernal_filename_len !byte 0
neo_kernal_filename_ptr !byte 0, 0
neo_kernal_jiffy        !byte 0, 0, 0
neo_kernal_command_lfn  !byte $ff
neo_kernal_io_byte      !byte 0
neo_kernal_temp_lfn     !byte 0
neo_kernal_zp_ptr       !byte 0
neo_kernal_start_addr   !byte 0, 0
neo_kernal_end_addr     !byte 0, 0
neo_kernal_size         !byte 0, 0
neo_kernal_lpref_name   !fill 257, 0
neo_kernal_cmd_response !fill 40, 0
neo_kernal_cmd_resp_len !byte 0
neo_kernal_cmd_resp_idx !byte 0

neo_kernal_status_ok_msg
	!pet "00, OK,00,00"
neo_kernal_status_ok_msg_len = * - neo_kernal_status_ok_msg

neo_kernal_status_err_msg
	!pet "30, CMD ERR,00,00"
neo_kernal_status_err_msg_len = * - neo_kernal_status_err_msg

neo_kernal_set_status_ok
	lda #0
	sta neo_kernal_status
	clc
	rts

neo_kernal_set_status_ok_preserve_a
	pha
	lda #0
	sta neo_kernal_status
	clc
	pla
	rts

neo_kernal_set_status_unimplemented
	lda #$ff
	sta neo_kernal_status
	sec
	rts

neo_kernal_api_call
	; In: A = group, X = function, params already written
	stx neo_api_function
	sta neo_api_command
	; Intentional 16-bit wraparound timeout: Y is the inner counter and X is the
	; outer counter. This gives a bounded wait without touching additional state.
	ldx #$ff
	ldy #$ff
neo_kernal_api_call_wait
	lda neo_api_command
	beq neo_kernal_api_call_done
	dey
	bne neo_kernal_api_call_wait
	dex
	bne neo_kernal_api_call_wait
	lda #$ff
	sta neo_kernal_status
	sec
	rts

neo_kernal_api_call_done
	lda neo_api_error
	sta neo_kernal_status
	beq neo_kernal_api_call_ok
	sec
	rts
neo_kernal_api_call_ok
	clc
	rts

; Console helpers used by the screen layer. ACME keeps these labels global even
; though this unit is inside a !zone; see constants-neo6502.asm for the same
; pattern used by kernal_getchar.
neo_set_cursor_pos
	; In:  X = row (Y), Y = column (X)
	; Out: A/X/Y clobbered
	pha
	txa
	pha
	tya
	sta neo_api_param0
	pla
	sta neo_api_param1
	lda #neo_api_group_console
	ldx #neo_api_fn_set_cursor_pos
	jsr neo_kernal_api_call
	pla
	rts

neo_set_console_colours
	; In:  A = foreground palette index, X = background palette index
	; Out: A/X/Y clobbered
	; CONWrite handles $80+n/$90+n as colour changes, not printable characters,
	; so this avoids depending on the optional console colour API functions.
	pha
	txa
	pha
	ora #neo_console_bg_code
	jsr neo_vector_writechar
	pla
	pla
	ora #neo_console_fg_code
	jsr neo_vector_writechar
	rts

neo_delete_line
	; In:  A = console row to delete
	; Out: A/X/Y clobbered
	pha
	sta neo_api_param0
	lda #neo_api_group_console
	ldx #neo_api_fn_delete_line
	jsr neo_kernal_api_call
	pla
	rts

neo_clear_row
	; In:  A = console row, Y = starting column
	; Out: A/X/Y clobbered
	pha
	tya
	sta neo_api_param0
	pla
	sta neo_api_param1
	sta neo_api_param3
	lda #SCREEN_WIDTH - 1
	sta neo_api_param2
	lda #neo_api_group_console
	ldx #neo_api_fn_clear_region
	jsr neo_kernal_api_call
	rts

neo_kernal_prepare_lpref_name
	; Converts SETNAM state (len + ptr to plain bytes) into a length-prefixed
	; string for Neo6502 file API calls.  Callers may be holding values in
	; zp_temp/zp_temp+1 across a file API call (VMEM paging is one example),
	; so preserve those two bytes here.
	lda zp_temp + 1
	pha
	lda zp_temp
	pha
	lda neo_kernal_filename_ptr
	sta zp_temp
	lda neo_kernal_filename_ptr + 1
	sta zp_temp + 1
	lda neo_kernal_filename_len
	sta neo_kernal_lpref_name
	tay
	beq neo_kernal_prepare_lpref_name_done
	dey
neo_kernal_prepare_lpref_name_copy
	lda (zp_temp),y
	sta neo_kernal_lpref_name + 1,y
	dey
	bpl neo_kernal_prepare_lpref_name_copy
neo_kernal_prepare_lpref_name_done
	pla
	sta zp_temp
	pla
	sta zp_temp + 1
	clc
	rts

neo_kernal_prepare_command_response
	; In: A = 0 => OK message, nonzero => error message.
	tax
	lda #0
	sta neo_kernal_cmd_resp_idx
	cpx #0
	bne neo_kernal_prepare_command_response_error
	ldx #0
neo_kernal_prepare_command_response_ok_copy
	lda neo_kernal_status_ok_msg,x
	sta neo_kernal_cmd_response,x
	inx
	cpx #neo_kernal_status_ok_msg_len
	bne neo_kernal_prepare_command_response_ok_copy
	lda #13
	sta neo_kernal_cmd_response,x
	inx
	stx neo_kernal_cmd_resp_len
	lda #0
	sta neo_kernal_status
	clc
	rts

neo_kernal_prepare_command_response_error
	ldx #0
neo_kernal_prepare_command_response_err_copy
	lda neo_kernal_status_err_msg,x
	sta neo_kernal_cmd_response,x
	inx
	cpx #neo_kernal_status_err_msg_len
	bne neo_kernal_prepare_command_response_err_copy
	lda #13
	sta neo_kernal_cmd_response,x
	inx
	stx neo_kernal_cmd_resp_len
	lda #neo_api_error_eof
	sta neo_kernal_status
	clc
	rts

neo_kernal_handle_command_channel_open
	; Handles SA=15 OPEN semantics.
	; If OPEN carries a command in the filename, execute compatible subset.
	; Regardless of command result, OPEN itself succeeds and response is read
	; through command-channel CHRIN/READST.
	lda neo_kernal_lfn
	sta neo_kernal_command_lfn
	lda neo_kernal_filename_len
	bne neo_kernal_handle_command_channel_open_has_cmd
	lda #0
	jmp neo_kernal_prepare_command_response

neo_kernal_handle_command_channel_open_has_cmd
	jsr neo_kernal_prepare_lpref_name
	lda neo_kernal_lpref_name + 1
	cmp #'s'
	beq neo_kernal_handle_command_channel_open_delete
	cmp #'S'
	bne neo_kernal_handle_command_channel_open_unknown

neo_kernal_handle_command_channel_open_delete
	ldx #1
neo_kernal_handle_command_channel_open_find_colon
	cpx neo_kernal_lpref_name
	bcs neo_kernal_handle_command_channel_open_unknown
	lda neo_kernal_lpref_name + 1,x
	cmp #':'
	beq neo_kernal_handle_command_channel_open_after_colon
	inx
	bne neo_kernal_handle_command_channel_open_find_colon

neo_kernal_handle_command_channel_open_after_colon
	inx
	stx neo_kernal_temp_lfn
	lda neo_kernal_lpref_name
	sec
	sbc neo_kernal_temp_lfn
	beq neo_kernal_handle_command_channel_open_unknown
	sta neo_kernal_lpref_name
	ldy #0
neo_kernal_handle_command_channel_open_copy_tail
	lda neo_kernal_lpref_name + 1,x
	sta neo_kernal_lpref_name + 1,y
	iny
	inx
	cpy neo_kernal_lpref_name
	bne neo_kernal_handle_command_channel_open_copy_tail

	lda #<neo_kernal_lpref_name
	sta neo_api_param0
	lda #>neo_kernal_lpref_name
	sta neo_api_param1
	lda #neo_api_group_fileio
	ldx #neo_api_fn_file_delete
	jsr neo_kernal_api_call
	bcs neo_kernal_handle_command_channel_open_unknown
	lda #0
	jmp neo_kernal_prepare_command_response

neo_kernal_handle_command_channel_open_unknown
	lda #1
	jsr neo_kernal_prepare_command_response
	clc
	rts

neo_kernal_read_file_byte
	; In: A = file channel
	sta neo_api_param0
	lda #<neo_kernal_io_byte
	sta neo_api_param1
	lda #>neo_kernal_io_byte
	sta neo_api_param2
	lda #1
	sta neo_api_param3
	lda #0
	sta neo_api_param4
	lda #neo_api_group_fileio
	ldx #neo_api_fn_file_read
	jsr neo_kernal_api_call
	bcs neo_kernal_read_file_byte_error
	lda neo_api_param3
	ora neo_api_param4
	bne neo_kernal_read_file_byte_have_data
	lda #neo_api_error_eof
	sta neo_kernal_status
	sec
	lda #0
	rts
neo_kernal_read_file_byte_have_data
	lda neo_kernal_io_byte
	clc
	rts
neo_kernal_read_file_byte_error
	lda #0
	rts

neo_kernal_write_file_byte
	; In: A = byte to write, neo_kernal_output_lfn = target file channel
	sta neo_kernal_io_byte
	lda neo_kernal_output_lfn
	sta neo_api_param0
	lda #<neo_kernal_io_byte
	sta neo_api_param1
	lda #>neo_kernal_io_byte
	sta neo_api_param2
	lda #1
	sta neo_api_param3
	lda #0
	sta neo_api_param4
	lda #neo_api_group_fileio
	ldx #neo_api_fn_file_write
	jmp neo_kernal_api_call

neo_kernal_file_stat
	; In: A/X/Y = pointer to a length-prefixed filename string
	; Out: C clear if file exists, C set on error
	; Out: neo_api_param0..param3 = 32-bit file length
	; Out: neo_api_param4 = attribute bitfield
	sta neo_api_param0
	stx neo_api_param1
	sty neo_api_param2
	lda #0
	sta neo_api_param3
	sta neo_api_param4
	sta neo_api_param5
	lda #neo_api_group_fileio
	ldx #neo_api_fn_file_stat
	jmp neo_kernal_api_call

; --- KERNAL-compatible adapter entrypoints ---

neo_kernal_setnam
	sta neo_kernal_filename_len
	stx neo_kernal_filename_ptr
	sty neo_kernal_filename_ptr + 1
	jmp neo_kernal_set_status_ok

neo_kernal_setlfs
	sta neo_kernal_lfn
	stx neo_kernal_device
	sty neo_kernal_sa
	jmp neo_kernal_set_status_ok

!source "../temp/neo-file-names.asm"

neo_kernal_open
	lda neo_kernal_sa
	cmp #15
	bne neo_kernal_open_file_open
	jmp neo_kernal_handle_command_channel_open

neo_kernal_open_file_open
	jsr neo_kernal_prepare_lpref_name
	lda neo_kernal_lpref_name
	cmp #1
	bne neo_kernal_open_have_name
	lda neo_kernal_lpref_name + 1
	cmp #'#'
	bne neo_kernal_open_have_name
	ldx #0
neo_kernal_open_map_hash_to_story
	lda neo_story_filename,x
	sta neo_kernal_lpref_name + 1,x
	inX
	cpx #neo_story_filename_len
	bne neo_kernal_open_map_hash_to_story
	lda #neo_story_filename_len
	sta neo_kernal_lpref_name
neo_kernal_open_have_name
	lda neo_kernal_lfn
	sta neo_api_param0
	lda #<neo_kernal_lpref_name
	sta neo_api_param1
	lda #>neo_kernal_lpref_name
	sta neo_api_param2

	lda #neo_api_file_mode_read
	ldx neo_kernal_sa
	cpx #1
	beq neo_kernal_open_set_mode
	cpx #3
	bne neo_kernal_open_have_mode
neo_kernal_open_set_mode
	lda #neo_api_file_mode_readwrite_create
neo_kernal_open_have_mode
	sta neo_api_param3

	lda #neo_api_group_fileio
	ldx #neo_api_fn_file_open
	jmp neo_kernal_api_call

neo_kernal_close
	sta neo_kernal_temp_lfn
	cmp neo_kernal_command_lfn
	bne neo_kernal_close_file_close
	lda #$ff
	sta neo_kernal_command_lfn
	jmp neo_kernal_set_status_ok

neo_kernal_close_file_close
	lda neo_kernal_temp_lfn
	sta neo_api_param0
	lda #neo_api_group_fileio
	ldx #neo_api_fn_file_close
	jsr neo_kernal_api_call
	bcc .close_ok
	; Ozmoo frequently issues defensive CLOSE calls (e.g. 15/2/255) even when
	; the channel may not currently be open. On Neo, that can report an API
	; error and wrongly cascade into disk error handling. Treat CLOSE errors as
	; non-fatal for compatibility with that usage pattern.
	lda #0
	sta neo_kernal_status
	clc
.close_ok
	lda neo_kernal_temp_lfn
	cmp neo_kernal_input_lfn
	bne neo_kernal_close_check_output
	lda #0
	sta neo_kernal_input_lfn

neo_kernal_close_check_output
	lda neo_kernal_temp_lfn
	cmp neo_kernal_output_lfn
	bne neo_kernal_close_done
	lda #0
	sta neo_kernal_output_lfn
neo_kernal_close_done
	clc
	rts

neo_kernal_chkin
	stx neo_kernal_input_lfn
	jmp neo_kernal_set_status_ok

neo_kernal_chkout
	stx neo_kernal_output_lfn
	jmp neo_kernal_set_status_ok

neo_kernal_clrchn
	lda #0
	sta neo_kernal_input_lfn
	sta neo_kernal_output_lfn
	jmp neo_kernal_set_status_ok

neo_kernal_readst
	lda neo_kernal_input_lfn
	cmp neo_kernal_command_lfn
	bne neo_kernal_readst_default
	lda neo_kernal_cmd_resp_idx
	cmp neo_kernal_cmd_resp_len
	bcc neo_kernal_readst_default
	lda #neo_api_error_eof
	rts

neo_kernal_readst_default
	lda neo_kernal_status
	rts

neo_kernal_readchar
	; CHRIN semantics: block until a byte is available on the current input.
	lda neo_kernal_input_lfn
	beq neo_kernal_readchar_keyboard
	cmp neo_kernal_command_lfn
	beq neo_kernal_readchar_command_channel
	jsr neo_kernal_read_file_byte
	clc
	rts

neo_kernal_readchar_command_channel
	ldx neo_kernal_cmd_resp_idx
	cpx neo_kernal_cmd_resp_len
	bcs neo_kernal_readchar_command_channel_eof
	lda neo_kernal_cmd_response,x
	sta neo_kernal_io_byte
	inx
	stx neo_kernal_cmd_resp_idx
	lda #0
	sta neo_kernal_status
	lda neo_kernal_io_byte
	clc
	rts

neo_kernal_readchar_command_channel_eof
	lda #neo_api_error_eof
	sta neo_kernal_status
	lda #0
	clc
	rts

neo_kernal_readchar_keyboard
neo_kernal_readchar_wait_key
	jsr neo_kernal_getchar
	beq neo_kernal_readchar_wait_key
	clc
	rts

neo_kernal_getchar
	; GETIN semantics: non-blocking keyboard read; A=0 when no key pending.
	jsr neo_vector_readchar
	cmp #$08 ; Neo backspace
	beq .map_delete
	cmp #$7f ; DEL
	beq .map_delete
	cmp #$1a ; Neo delete key
	bne .done
.map_delete
	lda #$14 ; CBM DELETE, which both input paths already understand
.done
	jmp neo_kernal_set_status_ok_preserve_a

neo_kernal_printchar
	; Input: A = character to write.
	pha
	lda neo_kernal_output_lfn
	beq neo_kernal_printchar_console
	cmp neo_kernal_command_lfn
	beq neo_kernal_printchar_command_channel
	pla
	jsr neo_kernal_write_file_byte
	rts

neo_kernal_printchar_command_channel
	pla
	jmp neo_kernal_set_status_ok

neo_kernal_printchar_console
	pla
	jsr neo_vector_writechar
	jmp neo_kernal_set_status_ok

neo_kernal_load
	; KERNAL LOAD compatibility:
	; - A is verify/load mode on CBM KERNAL; Neo path ignores verify for now.
	; - X/Y are treated as destination address.
	jsr neo_kernal_prepare_lpref_name
	lda #<neo_kernal_lpref_name
	sta neo_api_param0
	lda #>neo_kernal_lpref_name
	sta neo_api_param1
	stx neo_api_param2
	sty neo_api_param3
	lda #neo_api_group_fileio
	ldx #neo_api_fn_load_file
	jmp neo_kernal_api_call

neo_kernal_save
	; KERNAL SAVE compatibility:
	; - A = zero-page pointer to 16-bit start address
	; - X/Y = 16-bit end address (exclusive)
	sta neo_kernal_zp_ptr
	stx neo_kernal_end_addr
	sty neo_kernal_end_addr + 1

	ldx neo_kernal_zp_ptr
	lda $00,x
	sta neo_kernal_start_addr
	inx
	lda $00,x
	sta neo_kernal_start_addr + 1

	lda neo_kernal_end_addr
	sec
	sbc neo_kernal_start_addr
	sta neo_kernal_size
	lda neo_kernal_end_addr + 1
	sbc neo_kernal_start_addr + 1
	sta neo_kernal_size + 1
	bcs neo_kernal_save_size_ok
	lda #$ff
	sta neo_kernal_status
	sec
	rts

neo_kernal_save_size_ok
	jsr neo_kernal_prepare_lpref_name
	lda #<neo_kernal_lpref_name
	sta neo_api_param0
	lda #>neo_kernal_lpref_name
	sta neo_api_param1

	lda neo_kernal_start_addr
	sta neo_api_param2
	lda neo_kernal_start_addr + 1
	sta neo_api_param3

	lda neo_kernal_size
	sta neo_api_param4
	lda neo_kernal_size + 1
	sta neo_api_param5

	lda #neo_api_group_fileio
	ldx #neo_api_fn_store_file
	jmp neo_kernal_api_call

neo_kernal_settime
	sta neo_kernal_jiffy
	stx neo_kernal_jiffy + 1
	sty neo_kernal_jiffy + 2
	jmp neo_kernal_set_status_ok

neo_kernal_readtime
	; Temporary monotonic fallback until Morpheus clock call is wired.
	inc neo_kernal_jiffy
	bne neo_kernal_readtime_return
	inc neo_kernal_jiffy + 1
	bne neo_kernal_readtime_return
	inc neo_kernal_jiffy + 2

neo_kernal_readtime_return
	lda neo_kernal_jiffy
	ldx neo_kernal_jiffy + 1
	ldy neo_kernal_jiffy + 2
	rts

neo_kernal_delay_1ms
	; Temporary busy-wait fallback.
	ldx #8

neo_kernal_delay_1ms_outer
	ldy #$ff

neo_kernal_delay_1ms_inner
	dey
	bne neo_kernal_delay_1ms_inner
	dex
	bne neo_kernal_delay_1ms_outer
	rts

neo_kernal_reset
	; Restore the firmware's default console palette and clear the screen while
	; the interpreter's console helpers are still resident. BASIC is reloaded
	; immediately afterwards and does not reset a palette set by the game.
	lda #neo_basic_console_fg
	ldx #neo_basic_console_bg
	jsr neo_set_console_colours
	lda #12 ; CONWrite clear screen / home cursor
	jsr neo_vector_writechar
	jmp neo_reset_trampoline

; --- 16-bit Morpheus seek/read primitives for VMEM paging ---

neo_kernal_seek_file
	; Seek to 16-bit offset. Inputs: A=LFN, X=seek-low, Y=seek-high.
	; Parameter placement per neo_readblock convention:
	; param0=A (LFN), param1=X (offset low), param2=Y (offset high), param3=0, param4=0, param5=0.
	; Morpheus interprets seek offset as little-endian across param1..param4.
	sta neo_api_param0
	stx neo_api_param1
	sty neo_api_param2
	lda #0
	sta neo_api_param3
	sta neo_api_param4
	sta neo_api_param5
	lda #neo_api_group_fileio
	ldx #neo_api_fn_file_seek
	jsr neo_kernal_api_call
	rts

neo_kernal_seek_file_page
	; Seek to page*256 byte offset. Inputs: A=LFN, X=page-low, Y=page-high.
	; param0=A, param1=0, param2=page-low, param3=page-high, param4=0, param5=0.
	sta neo_api_param0
	lda #0
	sta neo_api_param1
	txa
	sta neo_api_param2
	tya
	sta neo_api_param3
	lda #0
	sta neo_api_param4
	sta neo_api_param5
	lda #neo_api_group_fileio
	ldx #neo_api_fn_file_seek
	jsr neo_kernal_api_call
	rts

neo_kernal_read_file
	; Read from file. Inputs: A=LFN, X=dest low, Y=dest high, neo_kernal_size=requested count (low/high).
	; Parameter placement per neo_readblock convention:
	; param0=A (LFN), param1=X (dest low), param2=Y (dest high),
	; param3=size_low (from neo_kernal_size), param4=size_high (from neo_kernal_size+1), param5=0.
	sta neo_api_param0
	stx neo_api_param1
	sty neo_api_param2
	lda neo_kernal_size
	sta neo_api_param3
	lda neo_kernal_size + 1
	sta neo_api_param4
	lda #0
	sta neo_api_param5
	lda #neo_api_group_fileio
	ldx #neo_api_fn_file_read
	jsr neo_kernal_api_call
	bcs neo_kernal_read_file_error

; Compare the returned 16-bit count with the requested count.
	lda neo_api_param3
	cmp neo_kernal_size
	bne neo_kernal_read_file_short
	lda neo_api_param4
	cmp neo_kernal_size + 1
	bne neo_kernal_read_file_short

neo_kernal_read_file_success
	lda #0
	sta neo_kernal_status
	clc
	rts

neo_kernal_read_file_short
	; Short read or EOF: copy the real returned count and report EOF.
	lda neo_api_param3
	sta neo_kernal_size
	lda neo_api_param4
	sta neo_kernal_size + 1

neo_kernal_read_file_eof
	lda #neo_api_error_eof
	sta neo_kernal_status
	sec
	rts

neo_kernal_read_file_error
	; API error or timeout. Preserve status from neo_kernal_api_call and return C set.
	sec
	rts

neo_kernal_write_file
	; Write to file. Inputs: A=LFN, X=src low, Y=src high, neo_kernal_size=requested count (low/high).
	; Parameter placement per neo_readblock convention:
	; param0=A (LFN), param1=X (src low), param2=Y (src high),
	; param3=size_low (from neo_kernal_size), param4=size_high (from neo_kernal_size+1), param5=0.
	sta neo_api_param0
	stx neo_api_param1
	sty neo_api_param2
	lda neo_kernal_size
	sta neo_api_param3
	lda neo_kernal_size + 1
	sta neo_api_param4
	lda #0
	sta neo_api_param5
	lda #neo_api_group_fileio
	ldx #neo_api_fn_file_write
	jsr neo_kernal_api_call
	bcs neo_kernal_write_file_error

; Compare the returned 16-bit count with the requested count.
	lda neo_api_param3
	cmp neo_kernal_size
	bne neo_kernal_write_file_short
	lda neo_api_param4
	cmp neo_kernal_size + 1
	bne neo_kernal_write_file_short

neo_kernal_write_file_success
	lda #0
	sta neo_kernal_status
	clc
	rts

neo_kernal_write_file_short
	; Short write: copy the real returned count.
	lda neo_api_param3
	sta neo_kernal_size
	lda neo_api_param4
	sta neo_kernal_size + 1

neo_kernal_write_file_eof
	lda #neo_api_error_eof
	sta neo_kernal_status
	sec
	rts

neo_kernal_write_file_error
	; API error. Preserve status from neo_kernal_api_call and return C set.
	sec
	rts

}
