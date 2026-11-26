; Neo6502-native SAVE/RESTORE helpers.
; This file is sourced inside disk.asm's save_restore zone.

; Storage bytes for neo header and filename operations
neo_save_header !fill 26, 0
neo_save_payload_size !byte 0, 0

; The payload spans the saved ZP bytes, the stack and dynamic memory.  dynmem_size
; is a runtime header-derived variable, not an assemble-time constant, so it must
; be read from memory here; using the label address would make the save overrun
; into resident VMEM (and truncate at restore time).
neo_calc_save_payload_size
	lda dynmem_size
	clc
	adc #<(stack_size + zp_bytes_to_save)
	sta neo_save_payload_size
	lda dynmem_size + 1
	adc #>(stack_size + zp_bytes_to_save)
	sta neo_save_payload_size + 1
	rts

; neo_build_save_filename builds a length-prefixed save filename in neo_kernal_lpref_name.
; Input: A = slot digit as ASCII (e.g., $30 for slot 0)
; Output: neo_kernal_lpref_name contains the length-prefixed save filename
;         Length byte at neo_kernal_lpref_name, filename bytes at neo_kernal_lpref_name + 1 onwards
;         Last character replaced with slot digit from input A
; Registers: C is cleared on return. Y is used as copy index.
neo_build_save_filename
	pha				; save slot digit
	lda #neo_save_filename_len	; length is an ACME constant
	sta neo_kernal_lpref_name
	ldy #0
-	lda neo_save_filename,y
	sta neo_kernal_lpref_name + 1,y
	iny
	cpy #neo_save_filename_len
	bne -
	pla				; restore slot digit
	sta neo_kernal_lpref_name + neo_save_filename_len
	clc
	rts

neo_write_save_header
	pha
	lda #'O'
	sta neo_save_header + 0
	lda #'Z'
	sta neo_save_header + 1
	lda #'M'
	sta neo_save_header + 2
	lda #'S'
	sta neo_save_header + 3
	lda #'A'
	sta neo_save_header + 4
	lda #'V'
	sta neo_save_header + 5
	lda #1
	sta neo_save_header + 6
	pla
	sta neo_save_header + 7

	ldy #0
.wsh_copy
	cpy #14
	bcs .wsh_copy_done
	lda .inputstring,y
	beq .wsh_zero
	sta neo_save_header + 8,y
	iny
	bne .wsh_copy
.wsh_zero
	lda #0
	sta neo_save_header + 8,y
	iny
	cpy #14
	bcc .wsh_zero
.wsh_copy_done

	lda #<(stack_start - zp_bytes_to_save)
	sta neo_save_header + 22
	lda #>(stack_start - zp_bytes_to_save)
	sta neo_save_header + 23
	jsr neo_calc_save_payload_size
	lda neo_save_payload_size
	sta neo_save_header + 24
	lda neo_save_payload_size + 1
	sta neo_save_header + 25

	clc
	rts

neo_read_save_header
	lda #26
	sta neo_kernal_size
	lda #0
	sta neo_kernal_size + 1

	lda #3
	ldx #<neo_save_header
	ldy #>neo_save_header
	jsr neo_kernal_read_file
	bcs .nrsh_fail

	lda neo_save_header + 0
	cmp #'O'
	bne .nrsh_fail
	lda neo_save_header + 1
	cmp #'Z'
	bne .nrsh_fail
	lda neo_save_header + 2
	cmp #'M'
	bne .nrsh_fail
	lda neo_save_header + 3
	cmp #'S'
	bne .nrsh_fail
	lda neo_save_header + 4
	cmp #'A'
	bne .nrsh_fail
	lda neo_save_header + 5
	cmp #'V'
	bne .nrsh_fail
	lda neo_save_header + 6
	cmp #1
	bne .nrsh_fail

	clc
	rts

.nrsh_fail
	sec
	rts

neo_print_save_comment
	ldx #8
.print_save_char_loop
	cpx #22
	bcs .print_save_done
	lda neo_save_header,x
	beq .print_save_done
	jsr s_printchar
	inx
	jmp .print_save_char_loop
.print_save_done
	clc
	rts

neo_save_game

	lda #>.saveslot_msg_save
	ldx #<.saveslot_msg_save
	jsr printstring_raw

	lda #>.saveslot_msg
	ldx #<.saveslot_msg
	jsr printstring_raw

	jsr .input_alphanum

	cpx #1
	bne .nsg_fail_jump

	lda .inputstring
	cmp first_unavailable_save_slot_charcode
	bpl .nsg_fail_jump

	sta .saveslot

	jmp .nsg_continue
.nsg_fail_jump
	jmp .nsg_fail
.nsg_continue

	lda #>.savename_msg
	ldx #<.savename_msg
	jsr printstring_raw

	jsr .input_alphanum

	cpx #0
	beq .nsg_fail_jump

	lda #>.save_msg
	ldx #<.save_msg
	jsr printstring_raw

	lda .saveslot
	jsr neo_write_save_header

	lda .saveslot
	jsr neo_build_save_filename

	lda #neo_save_filename_len
	ldx #<(neo_kernal_lpref_name + 1)
	ldy #>(neo_kernal_lpref_name + 1)
	jsr kernal_setnam

	lda #4
	ldx #8
	ldy #3
	jsr kernal_setlfs
	jsr kernal_open
	bcs .nsg_fail_jump

	ldx #4
	jsr kernal_chkout

	lda #26
	sta neo_kernal_size
	lda #0
	sta neo_kernal_size + 1

	lda #4
	ldx #<neo_save_header
	ldy #>neo_save_header
	jsr neo_kernal_write_file
	bcs .nsg_fail_jump

	jsr .swap_pointers_for_save

	jsr neo_calc_save_payload_size
	lda neo_save_payload_size
	sta neo_kernal_size
	lda neo_save_payload_size + 1
	sta neo_kernal_size + 1

	lda #4
	ldx #<(stack_start - zp_bytes_to_save)
	ldy #>(stack_start - zp_bytes_to_save)
	jsr neo_kernal_write_file
	bcs .nsg_payload_fail

	lda #4
	jsr kernal_close

	jsr .swap_pointers_for_save

	ldx #0
	jsr erase_window

	lda #0
	ldx #1
	clc
	rts

.nsg_payload_fail
	jsr .swap_pointers_for_save

.nsg_fail
	lda #4
	jsr kernal_close
	ldx #0
	jsr erase_window
	lda #0
	tax
	clc
	rts

neo_restore_game
	; Show which slots hold saves, with their comments, before asking which
	; slot to restore. This mirrors the non-Neo restore path in disk.asm.
	; Empty and invalid slots are labelled too, so only occupied digits need
	; to be considered at the prompt.
	jsr neo_list_save_files

	lda #>.saveslot_msg_restore
	ldx #<.saveslot_msg_restore
	jsr printstring_raw

	lda #>.saveslot_msg
	ldx #<.saveslot_msg
	jsr printstring_raw

	jsr .input_alphanum
	cpx #1
	bne .nrg_fail_jump

	lda .inputstring
	cmp first_unavailable_save_slot_charcode
	bpl .nrg_fail_jump

	sta .saveslot

	jmp .nrg_continue
.nrg_fail_jump
	jmp .nrg_fail
.nrg_continue

	lda .saveslot
	jsr neo_build_save_filename

	lda #neo_save_filename_len
	ldx #<(neo_kernal_lpref_name + 1)
	ldy #>(neo_kernal_lpref_name + 1)
	jsr kernal_setnam

	lda #3
	ldx #8
	ldy #0
	jsr kernal_setlfs
	jsr kernal_open
	bcs .nrg_fail_jump

	ldx #3
	jsr kernal_chkin

	jsr neo_read_save_header
	bcs .nrg_fail_jump2

	jmp .nrg_header_checks
.nrg_fail_jump2
	jmp .nrg_fail
.nrg_header_checks

	lda neo_save_header + 7
	cmp .saveslot
	bne .nrg_fail_jump2

	lda neo_save_header + 22
	cmp #<(stack_start - zp_bytes_to_save)
	bne .nrg_fail_jump2

	lda neo_save_header + 23
	cmp #>(stack_start - zp_bytes_to_save)
	bne .nrg_fail_jump2

	jsr neo_calc_save_payload_size
	lda neo_save_header + 24
	cmp neo_save_payload_size
	bne .nrg_fail_jump2

	lda neo_save_header + 25
	cmp neo_save_payload_size + 1
	bne .nrg_fail_jump2

	lda #>.restore_msg
	ldx #<.restore_msg
	jsr printstring_raw

	jsr .swap_pointers_for_save

	lda neo_save_header + 24
	sta neo_kernal_size
	lda neo_save_header + 25
	sta neo_kernal_size + 1

	lda #3
	ldx #<(stack_start - zp_bytes_to_save)
	ldy #>(stack_start - zp_bytes_to_save)
	jsr neo_kernal_read_file
	bcs .nrg_payload_fail

	lda #3
	jsr kernal_close

	jsr .swap_pointers_for_save

	ldx #0
	jsr erase_window
	jsr get_page_at_z_pc

	lda #0
	ldx #1
	clc
	rts

.nrg_payload_fail
	jsr .swap_pointers_for_save

.nrg_fail
	lda #3
	jsr kernal_close
	ldx #0
	jsr erase_window
	lda #0
	tax
	clc
	rts

neo_list_save_files
	lda #13
	jsr s_printchar

	lda #0
	sta neo_list_save_index

.nls_loop
	lda neo_list_save_index
	cmp disk_info + 1
	bcc .nls_have_slot
	jmp .nls_done

.nls_have_slot
	clc
	adc #$30
	jsr s_printchar

	lda #>.nls_colon
	ldx #<.nls_colon
	jsr printstring_raw

	lda neo_list_save_index
	clc
	adc #$30
	jsr neo_build_save_filename

	lda #neo_save_filename_len
	ldx #<(neo_kernal_lpref_name + 1)
	ldy #>(neo_kernal_lpref_name + 1)
	jsr kernal_setnam

	lda #<neo_kernal_lpref_name
	ldx #>neo_kernal_lpref_name
	ldy #0
	jsr neo_kernal_file_stat
	bcs .nls_empty

	lda #3
	ldx #8
	ldy #0
	jsr kernal_setlfs
	jsr kernal_open
	bcs .nls_invalid

	ldx #3
	jsr kernal_chkin

	jsr neo_read_save_header
	bcs .nls_invalid_close

	lda #3
	jsr kernal_close

	jsr neo_print_save_comment
	jmp .nls_next

.nls_invalid_close
	lda #3
	jsr kernal_close

.nls_invalid
	lda #>.nls_invalid_str
	ldx #<.nls_invalid_str
	jsr printstring_raw
	jmp .nls_next

.nls_empty
	lda #>.nls_empty_str
	ldx #<.nls_empty_str
	jsr printstring_raw

.nls_next
	lda #13
	jsr s_printchar
	inc neo_list_save_index
	jmp .nls_loop

.nls_done
	lda #1
	clc
	rts

neo_list_save_index	!byte 0
.nls_colon		!pet ": ", 0
.nls_empty_str		!pet "(empty)", 0
.nls_invalid_str	!pet "(invalid)", 0
