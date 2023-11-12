; Which Z-machine to generate binary for
; (usually defined on the acme command line instead)
; Z6 will never be supported
;Z1 = 1
;Z2 = 1
;Z3 = 1
;Z4 = 1
;Z5 = 1
;Z7 = 1
;Z8 = 1

; Which machine to generate code for
; C64 is default target
!ifndef VMEM {
!ifndef SLOW {
	SLOW = 1
}
}

!ifdef TARGET_MEGA65 {
	TARGET_ASSIGNED = 1
	FAR_DYNMEM = 1
	COMPLEX_MEMORY = 1
	HAS_SID = 1
	SUPPORT_REU = 1
	SUPPORT_80COL = 1;
	!ifndef SLOW {
		SLOW = 1
	}
	!ifdef SLOW {
		!ifndef VMEM {
			SKIP_BUFFER = 1
		}
	}
	!ifndef NOSCROLLBACK {
		SCROLLBACK = 1
	}
}
!ifdef TARGET_PLUS4 {
	TARGET_PLUS4_OR_C128 = 1
	TARGET_ASSIGNED = 1
	COMPLEX_MEMORY = 1
	VMEM_END_PAGE = $fc
	SUPPORT_REU = 0
	!ifndef SLOW {
		SLOW = 1
	}
	!ifndef NOSCROLLBACK {
		SCROLLBACK = 1
		; SCROLLBACK_RAM_PAGES may be set by make.rb;
		; Must be an even number, where 6 * 4 <= SCROLLBACK_RAM_PAGES <= 11 * 4
		!ifndef SCROLLBACK_RAM_PAGES {
			SCROLLBACK_RAM_PAGES = 6 * 4
		}
	}
}
!ifdef TARGET_C64 {
	TARGET_ASSIGNED = 1
}
!ifdef TARGET_C128 {
	TARGET_PLUS4_OR_C128 = 1
	TARGET_ASSIGNED = 1
	FAR_DYNMEM = 1
	COMPLEX_MEMORY = 1
	VMEM_END_PAGE = $fc
	HAS_SID = 1
	SUPPORT_80COL = 1;
	SUPPORT_REU = 1
;	REUBOOST = 1
	!ifndef SLOW {
		SLOW = 1
	}
	!ifndef NOSCROLLBACK {
		SCROLLBACK = 1
		; SCROLLBACK_RAM_PAGES may be set by make.rb;
		; Must be an even number, where 6 * 4 <= SCROLLBACK_RAM_PAGES <= 11 * 4
	}
}

!ifndef TARGET_ASSIGNED {
	; No target given. C64 is the default target
	TARGET_C64 = 1
}

!ifdef TARGET_C64 {
	HAS_SID = 1
	!ifdef SLOW {
		!ifndef VMEM {
			SKIP_BUFFER = 1
		}
	}
	!ifndef NOSCROLLBACK {
		SCROLLBACK = 1
	}
}

!ifdef VMEM {
	!ifndef SUPPORT_REU {
		SUPPORT_REU = 1
	}
} else {
	!ifndef SUPPORT_REU {
		SUPPORT_REU = 0
	}
}


!ifndef VMEM_END_PAGE {
	VMEM_END_PAGE = $00 ; Last page of accessible RAM for VMEM, plus 1.
}

!ifdef TARGET_PLUS4 {
	cache_pages = 0
} else {
	!ifdef CACHE_PAGES {
		cache_pages = CACHE_PAGES ; Note, this is not final. One page may be added. vmem_cache_count will hold final # of pages.
	} else {
		cache_pages = 4 ; Note, this is not final. One page may be added. vmem_cache_count will hold final # of pages.
	}
}

!ifdef SCROLLBACK_RAM_PAGES {
	SCROLLBACK_RAM_START_PAGE = (VMEM_END_PAGE - SCROLLBACK_RAM_PAGES) & $ff ; VMEM_END_PAGE is 0 for C64, hence & $ff
}

!ifndef TERPNO {
	TERPNO = 8
}

!ifdef Z1 {
	ZMACHINEVERSION = 1
}
!ifdef Z2 {
	ZMACHINEVERSION = 2
}
!ifdef Z3 {
	ZMACHINEVERSION = 3
	Z3PLUS = 1
}
!ifdef Z4 {
	ZMACHINEVERSION = 4
	Z3PLUS = 1
	Z4PLUS = 1
}
!ifdef Z5 {
	ZMACHINEVERSION = 5
	Z3PLUS = 1
	Z4PLUS = 1
	Z5PLUS = 1
}
!ifdef Z7 {
	ZMACHINEVERSION = 7
	Z3PLUS = 1
	Z4PLUS = 1
	Z5PLUS = 1
	Z7PLUS = 1
}
!ifdef Z8 {
	ZMACHINEVERSION = 8
	Z3PLUS = 1
	Z4PLUS = 1
	Z5PLUS = 1
	Z7PLUS = 1
}

!ifdef TRACE {
	z_trace_size = 256
} else {
	z_trace_size = 0
}

!ifdef STACK_PAGES {
	stack_size = STACK_PAGES * $100;
} else {
	stack_size = $0400;
}


!ifndef COL2 {
	COL2 = 0
}
!ifndef COL3 {
	COL3 = 2
}
!ifndef COL4 {
	COL4 = 5
}
!ifndef COL5 {
	COL5 = 7
}
!ifndef COL6 {
	COL6 = 6
}
!ifndef COL7 {
	COL7 = 4
}
!ifndef COL8 {
	COL8 = 3
}
!ifndef COL9 {
	COL9 = 1
}

!ifndef BGCOL {
	BGCOL = 9
}
!ifndef FGCOL {
	FGCOL = 2
}
!ifndef INPUTCOL {
	INPUTCOL = FGCOL
}

!ifndef BGCOLDM {
	BGCOLDM = 2
}
!ifndef FGCOLDM {
	FGCOLDM = 4
}
!ifndef INPUTCOLDM {
	INPUTCOLDM = FGCOLDM
}

!ifndef Z5PLUS {
	!if (INPUTCOL != FGCOL) OR (INPUTCOLDM != FGCOLDM) {
		USE_INPUTCOL = 1
	}
}


; Border color: 0 = as background, 1 = as foreground, 2-9: specified Z-code colour. Default: as background

!ifndef BORDERCOL {
	!ifdef Z5PLUS {
		BORDERCOL = 0
	} else {
		BORDERCOL = BGCOL
	}
}
!ifndef BORDERCOLDM {
	!ifdef Z5PLUS {
		BORDERCOLDM = 0
	} else {
		BORDERCOLDM = BGCOLDM
	}
}
; For z3 and z4, change border colour magic values 0 and 1 to actual bgcol or fgcol, for shorter code
!ifndef Z5PLUS {
	!if BORDERCOL = 0 {
		BORDERCOL_FINAL = BGCOL
	}
	!if BORDERCOL = 1 {
		BORDERCOL_FINAL = FGCOL
	}
	!if BORDERCOLDM = 0 {
		BORDERCOLDM_FINAL = BGCOLDM
	}
	!if BORDERCOLDM = 1 {
		BORDERCOLDM_FINAL = FGCOLDM
	}
}
!ifndef BORDERCOL_FINAL {
	BORDERCOL_FINAL = BORDERCOL
}
!ifndef BORDERCOLDM_FINAL {
	BORDERCOLDM_FINAL = BORDERCOLDM
}
!if BORDERCOL_FINAL = 0 {
	BORDER_MAY_FOLLOW_BG = 1
} else {
	!if BORDERCOLDM_FINAL = 0 {
		BORDER_MAY_FOLLOW_BG = 1
	}
}
!if BORDERCOL_FINAL = 1 {
	BORDER_MAY_FOLLOW_FG = 1
} else {
!if BORDERCOLDM_FINAL = 1 {
	BORDER_MAY_FOLLOW_FG = 1
}
}

!ifndef STATCOL {
	STATCOL = FGCOL
}
!ifndef STATCOLDM {
	STATCOLDM = FGCOLDM
}

!ifndef CURSORCOL {
	CURSORCOL = 1 ; Follow FGCOL
}
!ifndef CURSORCOLDM {
	CURSORCOLDM = 1 ; Follow FGCOL
}

!ifndef CURSORCHAR {
	CURSORCHAR = 224
}

!ifndef SPLASHWAIT {
	SPLASHWAIT = 15
}

!ifdef Z5PLUS {
	COLOURFUL_LOWER_WIN = 1
}
!ifdef USE_INPUTCOL {
	!ifndef COLOURFUL_LOWER_WIN {
		COLOURFUL_LOWER_WIN = 1
	}
}
;!if CURSORCOL > 1 {
;	!ifndef COLOURFUL_LOWER_WIN {
;		COLOURFUL_LOWER_WIN = 1
;	}
;}
;!if CURSORCOLDM > 1 {
;	!ifndef COLOURFUL_LOWER_WIN {
;		COLOURFUL_LOWER_WIN = 1
;	}
;}


;  * = $0801 ; This must now be set on command line: --setpc $0801

program_start

		!ifdef TARGET_C128 {
			lda #%00001110 ; 48K RAM0 (0-$c000)
			sta $ff00
		}
	jmp .initialize

!ifdef VMEM {
	RESTART_SUPPORTED = 1
} else {
	!ifdef TARGET_MEGA65 {
		RESTART_SUPPORTED = 1
	} 
}

; =========================================== Highbytes of jump table

z_jump_high_arr

; 0OP

z_opcount_0op_jump_high_arr
	!byte >z_ins_rtrue - 1
	!byte >(z_ins_rfalse - 1)
	!byte >(z_ins_print - 1)
	!byte >(z_ins_print_ret - 1)
	!byte >(z_ins_nop - 1)
!ifndef Z5PLUS {
	!byte >(z_ins_save - 1)
	!byte >(z_ins_restore - 1)
} else {
	!byte >(z_not_implemented - 1)
	!byte >(z_not_implemented - 1)
}
!ifdef RESTART_SUPPORTED {
	!byte >(z_ins_restart - 1)
} else {
	!byte >(z_ins_not_supported - 1)
}
	!byte >(z_ins_ret_popped - 1)
!ifndef Z5PLUS {
	!byte >(stack_pull - 1) ; z_ins_pop
} else {
	!byte >(z_ins_catch - 1)
}
	!byte >(z_ins_quit - 1)
	!byte >(z_ins_new_line - 1)
!ifndef Z4PLUS {
	!byte >(z_ins_show_status - 1)
} else {
	!byte >(z_ins_nop - 1) ; should be nop according to show_status/spec 1.0
}
	!byte >(make_branch_true - 1) ; z_ins_verify
!ifdef Z5PLUS {
	!byte >(z_not_implemented - 1)
	!byte >(make_branch_true - 1) ; z_ins_piracy
} else {
	!byte >(z_not_implemented - 1)
	!byte >(z_not_implemented - 1)
}

; 1OP

z_opcount_1op_jump_high_arr
	!byte >(z_ins_jz - 1)
	!byte >(z_ins_get_sibling - 1)
	!byte >(z_ins_get_child - 1)
	!byte >(z_ins_get_parent - 1)
	!byte >(z_ins_get_prop_len - 1)
	!byte >(z_ins_inc - 1)
	!byte >(z_ins_dec - 1)
	!byte >(z_ins_print_addr - 1)
	!byte >(z_ins_call_xs - 1)
	!byte >(z_ins_remove_obj - 1)
	!byte >(z_ins_print_obj - 1)
	!byte >(z_ins_ret - 1)
	!byte >(z_ins_jump - 1)
	!byte >(z_ins_print_paddr - 1)
	!byte >(z_ins_load - 1)
!ifndef Z5PLUS {
	!byte >(z_ins_not - 1)
} else {
	!byte >(z_ins_call_xn - 1)
}

; 2OP

z_opcount_2op_jump_high_arr
	!byte >(z_not_implemented - 1)
	!byte >(z_ins_je - 1)
	!byte >(z_ins_jl - 1)
	!byte >(z_ins_jg - 1)
	!byte >(z_ins_dec_chk - 1)
	!byte >(z_ins_inc_chk - 1)
	!byte >(z_ins_jin - 1)
	!byte >(z_ins_test - 1)
	!byte >(z_ins_or - 1)
	!byte >(z_ins_and - 1)
	!byte >(z_ins_test_attr - 1)
	!byte >(z_ins_set_attr - 1)
	!byte >(z_ins_clear_attr - 1)
	!byte >(z_ins_store - 1)
	!byte >(z_ins_insert_obj - 1)
	!byte >(z_ins_loadw_and_storew - 1)
	!byte >(z_ins_loadb - 1)
	!byte >(z_ins_get_prop - 1)
	!byte >(z_ins_get_prop_addr - 1)
	!byte >(z_ins_get_next_prop - 1)
	!byte >(z_ins_add - 1)
	!byte >(z_ins_sub - 1)
	!byte >(z_ins_mul - 1)
	!byte >(z_ins_div - 1)
	!byte >(z_ins_mod - 1)
!ifndef Z4PLUS {
	!byte >(z_not_implemented - 1)
} else {
	!byte >(z_ins_call_xs - 1)
}
!ifndef Z5PLUS {
	!byte >(z_not_implemented - 1)
	!byte >(z_not_implemented - 1)
	!byte >(z_not_implemented - 1)
} else {
	!byte >(z_ins_call_xn - 1)
	!byte >(z_ins_set_colour - 1)
	!byte >(z_ins_throw - 1)
}
	!byte >(z_not_implemented - 1)
	!byte >(z_not_implemented - 1)
	!byte >(z_not_implemented - 1)

; VAR	

z_opcount_var_jump_high_arr
	!byte >(z_ins_call_xs - 1)
	!byte >(z_ins_loadw_and_storew - 1)
	!byte >(z_ins_storeb - 1)
	!byte >(z_ins_put_prop - 1)
	!byte >(z_ins_read - 1)
	!byte >(z_ins_print_char - 1)
	!byte >(z_ins_print_num - 1)
	!byte >(z_ins_random - 1)
	!byte >(z_ins_push - 1)
	!byte >(z_ins_pull - 1)
	!byte >(z_ins_split_window - 1)
	!byte >(z_ins_set_window - 1)
!ifdef Z4PLUS {
	!byte >(z_ins_call_xs - 1)
	!byte >(z_ins_erase_window - 1)
	!byte >(z_ins_erase_line - 1)
	!byte >(z_ins_set_cursor - 1)
	!byte >(z_ins_get_cursor - 1)
	!byte >(z_ins_set_text_style - 1)
	!byte >(z_ins_buffer_mode - 1)
} else {
	!byte >(z_not_implemented - 1)
	!byte >(z_not_implemented - 1)
	!byte >(z_not_implemented - 1)
	!byte >(z_not_implemented - 1)
	!byte >(z_not_implemented - 1)
	!byte >(z_not_implemented - 1)
	!byte >(z_not_implemented - 1)
}
	!byte >(z_ins_output_stream - 1)
	!byte >(z_ins_not_supported - 1)
	!byte >(z_ins_sound_effect - 1)
!ifdef Z4PLUS {
	!byte >(z_ins_read_char - 1)
	!byte >(z_ins_scan_table - 1)
} else {
	!byte >(z_not_implemented - 1)
	!byte >(z_not_implemented - 1)
}
!ifdef Z5PLUS {
	!byte >(z_ins_not - 1)
	!byte >(z_ins_call_xn - 1)
	!byte >(z_ins_call_xn - 1)
	!byte >(z_ins_tokenise_text - 1)
	!byte >(z_ins_encode_text - 1)
	!byte >(z_ins_copy_table - 1)
	!byte >(z_ins_print_table - 1)
	!byte >(z_ins_check_arg_count - 1)
} else {
	!byte >(z_not_implemented - 1)
	!byte >(z_not_implemented - 1)
	!byte >(z_not_implemented - 1)
	!byte >(z_not_implemented - 1)
	!byte >(z_not_implemented - 1)
	!byte >(z_not_implemented - 1)
	!byte >(z_not_implemented - 1)
	!byte >(z_not_implemented - 1)
}

; EXT

z_opcount_ext_jump_high_arr
!ifdef Z5PLUS {
	!byte >(z_ins_save - 1)
	!byte >(z_ins_restore - 1)
	!byte >(z_ins_log_shift - 1)
	!byte >(z_ins_art_shift - 1)
	!byte >(z_ins_set_font - 1)
	!byte >(z_not_implemented - 1)
	!byte >(z_not_implemented - 1)
	!byte >(z_not_implemented - 1)
	!byte >(z_not_implemented - 1)
	!byte >(z_ins_save_undo - 1)
	!byte >(z_ins_restore_undo - 1)
	!byte >(z_ins_print_unicode - 1)
	!byte >(z_ins_check_unicode - 1)
	!byte >(z_ins_set_true_colour - 1)
}


; =========================================== Lowbytes of jump table
	
z_jump_low_arr

; 0OP

z_opcount_0op_jump_low_arr
	!byte <(z_ins_rtrue - 1)
	!byte <(z_ins_rfalse - 1)
	!byte <(z_ins_print - 1)
	!byte <(z_ins_print_ret - 1)
	!byte <(z_ins_nop - 1)
!ifndef Z5PLUS {
	!byte <(z_ins_save - 1)
	!byte <(z_ins_restore - 1)
} else {
	!byte <(z_not_implemented - 1)
	!byte <(z_not_implemented - 1)
}
!ifdef RESTART_SUPPORTED {
	!byte <(z_ins_restart - 1)
} else {
	!byte <(z_ins_not_supported - 1)
}
	!byte <(z_ins_ret_popped - 1)
!ifndef Z5PLUS {
	!byte <(stack_pull - 1) ; z_ins_pop
} else {
	!byte <(z_ins_catch - 1)
}
	!byte <(z_ins_quit - 1)
	!byte <(z_ins_new_line - 1)
!ifndef Z4PLUS {
	!byte <(z_ins_show_status - 1)
} else {
	!byte <(z_ins_nop - 1) ; should be nop according to show_status/spec 1.0
}
	!byte <(make_branch_true - 1) ; z_ins_verify
!ifdef Z5PLUS {
	!byte <(z_not_implemented - 1)
	!byte <(make_branch_true - 1) ; z_ins_piracy
} else {
	!byte <(z_not_implemented - 1)
	!byte <(z_not_implemented - 1)
}

; 1OP

z_opcount_1op_jump_low_arr
	!byte <(z_ins_jz - 1)
	!byte <(z_ins_get_sibling - 1)
	!byte <(z_ins_get_child - 1)
	!byte <(z_ins_get_parent - 1)
	!byte <(z_ins_get_prop_len - 1)
	!byte <(z_ins_inc - 1)
	!byte <(z_ins_dec - 1)
	!byte <(z_ins_print_addr - 1)
	!byte <(z_ins_call_xs - 1)
	!byte <(z_ins_remove_obj - 1)
	!byte <(z_ins_print_obj - 1)
	!byte <(z_ins_ret - 1)
	!byte <(z_ins_jump - 1)
	!byte <(z_ins_print_paddr - 1)
	!byte <(z_ins_load - 1)
!ifndef Z5PLUS {
	!byte <(z_ins_not - 1)
} else {
	!byte <(z_ins_call_xn - 1)
}
	
; 2OP

z_opcount_2op_jump_low_arr
	!byte <(z_not_implemented - 1)
	!byte <(z_ins_je - 1)
	!byte <(z_ins_jl - 1)
	!byte <(z_ins_jg - 1)
	!byte <(z_ins_dec_chk - 1)
	!byte <(z_ins_inc_chk - 1)
	!byte <(z_ins_jin - 1)
	!byte <(z_ins_test - 1)
	!byte <(z_ins_or - 1)
	!byte <(z_ins_and - 1)
	!byte <(z_ins_test_attr - 1)
	!byte <(z_ins_set_attr - 1)
	!byte <(z_ins_clear_attr - 1)
	!byte <(z_ins_store - 1)
	!byte <(z_ins_insert_obj - 1)
	!byte <(z_ins_loadw_and_storew - 1)
	!byte <(z_ins_loadb - 1)
	!byte <(z_ins_get_prop - 1)
	!byte <(z_ins_get_prop_addr - 1)
	!byte <(z_ins_get_next_prop - 1)
	!byte <(z_ins_add - 1)
	!byte <(z_ins_sub - 1)
	!byte <(z_ins_mul - 1)
	!byte <(z_ins_div - 1)
	!byte <(z_ins_mod - 1)
!ifndef Z4PLUS {
	!byte <(z_not_implemented - 1)
} else {
	!byte <(z_ins_call_xs - 1)
}
!ifndef Z5PLUS {
	!byte <(z_not_implemented - 1)
	!byte <(z_not_implemented - 1)
	!byte <(z_not_implemented - 1)
} else {
	!byte <(z_ins_call_xn - 1)
	!byte <(z_ins_set_colour - 1)
	!byte <(z_ins_throw - 1)
}
	!byte <(z_not_implemented - 1)
	!byte <(z_not_implemented - 1)
	!byte <(z_not_implemented - 1)

; VAR	

z_opcount_var_jump_low_arr
	!byte <(z_ins_call_xs - 1)
	!byte <(z_ins_loadw_and_storew - 1)
	!byte <(z_ins_storeb - 1)
	!byte <(z_ins_put_prop - 1)
	!byte <(z_ins_read - 1)
	!byte <(z_ins_print_char - 1)
	!byte <(z_ins_print_num - 1)
	!byte <(z_ins_random - 1)
	!byte <(z_ins_push - 1)
	!byte <(z_ins_pull - 1)
	!byte <(z_ins_split_window - 1)
	!byte <(z_ins_set_window - 1)
!ifdef Z4PLUS {
	!byte <(z_ins_call_xs - 1)
	!byte <(z_ins_erase_window - 1)
	!byte <(z_ins_erase_line - 1)
	!byte <(z_ins_set_cursor - 1)
	!byte <(z_ins_get_cursor - 1)
	!byte <(z_ins_set_text_style - 1)
	!byte <(z_ins_buffer_mode - 1)
} else {
	!byte <(z_not_implemented - 1)
	!byte <(z_not_implemented - 1)
	!byte <(z_not_implemented - 1)
	!byte <(z_not_implemented - 1)
	!byte <(z_not_implemented - 1)
	!byte <(z_not_implemented - 1)
	!byte <(z_not_implemented - 1)
}
	!byte <(z_ins_output_stream - 1)
	!byte <(z_ins_not_supported - 1)
	!byte <(z_ins_sound_effect - 1)
!ifdef Z4PLUS {
	!byte <(z_ins_read_char - 1)
	!byte <(z_ins_scan_table - 1)
} else {
	!byte <(z_not_implemented - 1)
	!byte <(z_not_implemented - 1)
}
!ifdef Z5PLUS {
	!byte <(z_ins_not - 1)
	!byte <(z_ins_call_xn - 1)
	!byte <(z_ins_call_xn - 1)
	!byte <(z_ins_tokenise_text - 1)
	!byte <(z_ins_encode_text - 1)
	!byte <(z_ins_copy_table - 1)
	!byte <(z_ins_print_table - 1)
	!byte <(z_ins_check_arg_count - 1)
} else {
	!byte <(z_not_implemented - 1)
	!byte <(z_not_implemented - 1)
	!byte <(z_not_implemented - 1)
	!byte <(z_not_implemented - 1)
	!byte <(z_not_implemented - 1)
	!byte <(z_not_implemented - 1)
	!byte <(z_not_implemented - 1)
	!byte <(z_not_implemented - 1)
}

; EXT

z_opcount_ext_jump_low_arr
!ifdef Z5PLUS {
	!byte <(z_ins_save - 1)
	!byte <(z_ins_restore - 1)
	!byte <(z_ins_log_shift - 1)
	!byte <(z_ins_art_shift - 1)
	!byte <(z_ins_set_font - 1)
	!byte <(z_not_implemented - 1)
	!byte <(z_not_implemented - 1)
	!byte <(z_not_implemented - 1)
	!byte <(z_not_implemented - 1)
	!byte <(z_ins_save_undo - 1)
	!byte <(z_ins_restore_undo - 1)
	!byte <(z_ins_print_unicode - 1)
	!byte <(z_ins_check_unicode - 1)
	!byte <(z_ins_set_true_colour - 1)
}

z_number_of_ext_opcodes_implemented = * - z_opcount_ext_jump_low_arr

z_number_of_opcodes_implemented = * - z_jump_low_arr

!ifdef TARGET_C128 {
!source "constants-c128.asm"

!ifdef CUSTOM_FONT {
!ifdef UNDO {
.setup_copy_font
	ldy #>$1800
	lda reu_bank_for_undo
	ldx #$fc
	clc
	jsr store_reu_transfer_params
	lda #8
    sta reu_translen + 1
	rts

; Font is actually at $1800, where it can't be copied to bank 1, since dynmem starts at $1600
; so we copy it to $0800 instead
c128_copy_font_to_bank_1
	jsr .setup_copy_font
	lda #%10110000;  C64 -> REU with immediate execution
	sta reu_command
	; Wait until raster is in border
-	bit $d011
	bpl -
	; Make REU see RAM bank 1
	lda $d506
	ora #%01000000 ; Bit 6: 0 means bank 0, bit 7 is unused
	sta $d506
	jsr .setup_copy_font
	ldy #>$0800
	sty reu_c64base + 1
	lda #%10110001;  REU -> c64 with immediate execution
	sta reu_command
	; Restore REU to see RAM bank 0
	lda $d506
	and #%00111111 ; Bit 6: 0 means bank 0, bit 7 is unused
	sta $d506
	rts	
}
}

c128_reset_to_basic
	; this needs to be at the start of the program since
	; I need to bank back the normal memory and the latter
	; part of Ozmoo will be under the BASIC ROM.
	lda #0
	sta $ff00
	lda #$01
	sta $2b
	lda #$10
	sta $2c
	jmp basic_reset

; Adding support for 2MHz in the border
; https://sites.google.com/site/h2obsession/CBM/C128/2mhz-border

allow_2mhz_in_40_col !byte 1
use_2mhz_in_80_col !byte 0 ; Initial value should always be 0

use_2mhz_in_80_col_in_game_value = 1 ; This value is used after setup

!ifndef SMOOTHSCROLL {
;phase 2 of 2MHz speed-up = change CPU to 2MHz
;and set raster IRQ for top-of-screen less 1 raster
;and do normal KERNAL routines of IRQ
c128_border_phase2
	lda #1
	ldx allow_2mhz_in_40_col
	stx reg_2mhz	;CPU = 2MHz
	sta $d019	;clear VIC raster IRQ
	lda #<c128_border_phase1    ;set top-of-screen (phase 1)
	ldx #>c128_border_phase1
	sta $0314        ;as new IRQ vector
	stx $0315
	lda $d011
	and #$7f	;high raster bit = 0
	sta $d011
	lda #48+3-1	;low raster bits (default + Y_Scroll - 1 early raster = 50)
	sta $d012
	cli		;allow sprite/pen IRQs
	jsr $c22c	;flash VIC cursor, etc.
	jmp $fa6b	;update Jiffy Clock, control Cassette, handle SOUND/PLAY/MOVSPR
				;and return from IRQ

;phase 1 of 2MHz speed-up = change CPU back to 1MHz
;and set raster IRQ for bottom-of-screen
;NOTE the CPU is in BANK 15 (the VIC will soon start top of visible screen)
c128_border_phase1
	lda #<c128_border_phase2    ;set bottom-of-screen (phase 2)
	ldx #>c128_border_phase2
	sta $0314        ;as new IRQ vector
	stx $0315
	lda $d011
	and #$7f	;high raster bit = 0
	sta $d011
	lda #251	;low raster bits (1 raster beyond visible screen)
	sta $d012
	lda #1
	sta $d019	;clear VIC raster IRQ
	lsr		; A = 0
	sta reg_2mhz	;CPU = 1MHz
	jmp $ff33	;return from IRQ
}

} else {
!source "constants.asm"
}
!source "constants-header.asm"

!if SUPPORT_REU = 1 {
progress_reu = parse_array
reu_progress_ticks = parse_array + 1
reu_last_disk_end_block = string_array ; 2 bytes
!ifdef REUBOOST {
!ifdef Z4PLUS {
	!ifdef Z7PLUS {
		reu_boost_hash_pages = 8
	} else {
		reu_boost_hash_pages = 4
	}
} else {
	reu_boost_hash_pages = 2
}

reu_boost_mode !byte 0 ; Set to $ff to activate
reu_boost_hash_table = (first_banked_memory_page - reu_boost_hash_pages) * 256

; The values calculated here for reu_boost_area_start_page and reu_boost_area_pagecount
; are correct for C128. For C64, they are changed at runtime, as they can't be calculated
; until dynmem size is known. 

reu_boost_area_start_page !byte >story_start
reu_boost_area_pagecount !byte (>reu_boost_hash_table) - (>story_start)
} ; ifdef REUBOOST
} ; if SUPPORT_REU = 1

; global variables
; filelength !byte 0, 0, 0
!ifdef TARGET_MEGA65 {
fileblocks !byte 0, 0, 0
}
; c64_model !byte 0 ; 1=NTSC/6567R56A, 2=NTSC/6567R8, 3=PAL/6569
!ifdef VMEM {
game_id		!byte 0,0,0,0
}

.initialize
	cld
	cli
!ifdef TARGET_C128 {
	lda #$f0 ; Background colour
	jsr VDCInit
	; initialize is in Basic LO ROM in C128 mode, so we need
	; to turn off BASIC already here. Since the set_memory_no_basic
	; macro isn't defined yet we'll have to do it manually
	lda #%00001110
	sta $ff00
!if SPLASHWAIT > 0 {
!ifdef SMOOTHSCROLL {
	bit COLS_40_80
	bpl +
	lda #<splashline7alt
	sta splash_index_lb + 7
	lda #>splashline7alt
	sta splash_index_hb + 7
	lda scroll_delay_values + 1
	sta scroll_delay
+
}
}
}


!ifdef TESTSCREEN {
	jmp testscreen
}
	jsr deletable_init_start
;	jsr init_screen_colours
	jsr deletable_screen_init_1
!if SPLASHWAIT > 0 {
	jsr splash_screen
}

!ifdef VMEM {
!ifdef TARGET_C64 {
	; set up C64 SuperCPU if any
	; see: http://www.elysium.filety.pl/tools/supercpu/superprog.html
	lda $d0bc ; SuperCPU control register (read only)
	and #$80  ; DOS extension mode? 0 if SuperCPU, 1 if standard C64
	beq .supercpu
	;bne .nosupercpu 
	; it doesn't matter what you store in the SuperCPU control registers
	; it is just the access itself that counts
	;sta $d07e ; enable hardware registers
	;sta $d076 ; basic optimization
	;sta $d077 ; no memory optimization
	;sta $d07f ; disable hardware registers
	;sta $d07a ; normal speed (1 MHz)
}
	; SuperCPU and REU doesn't work well together
	; https://www.lemon64.com/forum/viewtopic.php?t=68824&sid=330a8c62e22ebd2cf654c14ae8073fb9
	;
!if SUPPORT_REU = 1 {
	lda #0
	sta z_temp + 1
	!ifdef Z3PLUS {
		lda story_start + header_filelength
	} else {
		lda #$ff ; For z1 and z2 we don't know, so we assume the biggest size
	}
	!ifndef Z4PLUS {
		asl
		rol z_temp + 1
	} else {
		!ifdef Z7PLUS {
			ldx #3
-			asl
			rol z_temp + 1
			dex
			bne -
		} else {
			asl
			rol z_temp + 1
			asl
			rol z_temp + 1
		}
	}
	sec
	sbc story_start + header_static_mem
	tay
	lda z_temp + 1
	sbc #0
	tax
	tya
	clc
	adc #4 ; Add 1 KB for rounding errors + empty block in REU
	txa
	adc #1
	; A now holds an upper limit on statmem size in 64 KB blocks
	sta statmem_reu_banks

!ifdef TARGET_C128 {
	; Make sure REU uses RAM bank 0
	lda $d506
	and #%00111111 ; Bit 6: 0 means bank 0, bit 7 is unused
	sta $d506
}
	jsr reu_start

!ifdef TARGET_C128 {
!ifdef CUSTOM_FONT {
!ifdef UNDO {
	bit COLS_40_80
	bmi +
	lda reu_bank_for_undo
	cmp #$7f ; $7f = undo in RAM, $80+ = no undo
	bcs +
	jsr c128_copy_font_to_bank_1
+
}
}
}
	!ifdef SCROLLBACK {
		ldx use_reu
		beq .store_bank_number
		ldx statmem_reu_banks
;		cpx scrollback_bank
;		bcs +
.store_bank_number
		!ifdef UNDO {
			lda reu_bank_for_undo
			cmp #$7f ; $7f = undo in RAM, $80+ = no undo
			bcs .no_undo_reu_bank
			inx
.no_undo_reu_bank
		}
		stx scrollback_bank
		; inx
		; stx scrollback_bank + 1
+		jsr init_reu_scrollback
	}
	lda #147
	jsr s_printchar
} else {
	; This case is used by Plus/4 only
	!ifdef SCROLLBACK_RAM_PAGES {
		jsr init_reu_scrollback
	}
}

.supercpu
}
	jsr deletable_init
	jsr parse_object_table
!ifndef Z5PLUS {
	; Setup default dictionary
	jsr parse_default_dictionary
}

!ifdef Z5PLUS {
	; set up terminating characters
	jsr parse_terminating_characters
}
	
	jsr streams_init
	jsr stack_init

	jsr deletable_screen_init_2

	lda #0
	sta keyboard_buff_len

	jsr z_init

!ifdef TARGET_C128 {
	; Let's speed things up.
	; this needs to be after the z_init call since 
	; z_init uses SID to initialize the random number generator
	; and SID doesn't work in fast mode.
	bit COLS_40_80
	bpl +
	; 80 columns mode
	; switch to 2MHz
	lda #use_2mhz_in_80_col_in_game_value
	sta use_2mhz_in_80_col
	sta reg_2mhz	;CPU = 2MHz
	lda $d011
	; Clear top bit (to not break normal interrupt) and bit 4 to blank screen 
	and #%01101111
	sta $d011
	jmp ++
+	; 40 columns mode
!ifndef SMOOTHSCROLL {
	; use 2MHz only when rasterline is in the border for VIC-II
	sei 
	lda #<c128_border_phase2
	ldx #>c128_border_phase2
	sta $0314
	stx $0315
	lda $d011
	and #$7f ; high raster bit = 0
	sta $d011
	lda #251 ; low raster bit (1 raster beyond visible screen)
	sta $d012
	cli
}
++
}

!ifdef SCROLLBACK {
	lda scrollback_supported
	sta scrollback_enabled
}

	jsr z_execute

!ifdef TARGET_PLUS4_OR_C128 {
!ifdef TARGET_C128 {
	jmp c128_reset_to_basic
} else {
	lda #$01
	sta $2b
	lda #$10
	sta $2c
	jmp basic_reset
}
} else {
	; Back to normal memory banks
	lda #%00110111
	sta 1
;	+set_memory_normal
	jmp (basic_reset)
}

!if SUPPORT_REU = 1 {
statmem_reu_banks !byte 0
}


; include other assembly files
!ifdef SMOOTHSCROLL {
!source "smoothscroll.asm"
}
!source "utilities.asm"
!ifdef SCROLLBACK {
!source "scrollback.asm"
}
!source "screenkernal.asm"
!source "screen.asm"
!source "streams.asm" ; Must come before "text.asm"
!source "disk.asm"
;!ifdef SOUND {
!source "sound.asm"
;}
;!ifdef VMEM {
	!if SUPPORT_REU = 1 {
	!source "reu.asm"
	}
;}
!source "memory.asm"
!source "stack.asm"
;##!ifdef VMEM {
!source "vmem.asm"
;##}
!source "zmachine.asm"
!source "zaddress.asm"
!source "text.asm"
!source "dictionary.asm"
!source "objecttable.asm"


!ifdef TARGET_PLUS4_OR_C128 {
	!if SPLASHWAIT > 0 {
		!source "splashscreen.asm"
	}
}

!ifdef Z7 {
calc_z7_offsets
	ldy #header_string_offset
	jsr read_header_word
	sta string_offset + 1
	stx string_offset + 2
	ldy #header_routine_offset
	jsr read_header_word
	stx routine_offset + 2

	ldx #3
-	asl string_offset + 2
	rol string_offset + 1
	rol string_offset
	asl routine_offset + 2
	rol
	rol routine_offset
	dex
	bne -
	sta routine_offset + 1
	rts
}


!ifdef TARGET_C128 {

!ifdef Z4PLUS {
update_screen_width_in_header
	lda s_screen_width
	ldy #header_screen_width_chars
!ifdef Z5PLUS {
	jsr write_header_byte
	ldy #header_screen_width_units
	tax
	lda #0
	jmp write_header_word
} else {
	jmp write_header_byte
}
}

c128_setup_mmu
	lda #5 ; 4 KB common RAM at bottom only
	sta c128_mmu_ram_cfg
	ldx #2
-	lda c128_mmu_values,x
	sta c128_mmu_pcra,x
	dex
	bpl -

	ldx #copy_page_c128_src_end - copy_page_c128_src
-	lda copy_page_c128_src - 1,x
	sta copy_page_c128 - 1,x
	dex
	bne -
	rts

!ifdef UNDO_RAM {
; Setup a RAM buffer for Undo
undo_ram_setup
	bit reu_bank_for_undo
	bpl + ; An REU bank has already been assigned
	; Check if undo fits in bank 1
	jsr calc_dynmem_size
	clc
	lda #(>stack_size) + 1
	adc nonstored_pages
	bcs + ; Dynmem + stack + ZP > 64 KB, so no way to fit in RAM buffer
	sta object_temp
	adc nonstored_pages
	; adc story_start + header_static_mem
	; bcs +
	; ldy story_start + header_static_mem + 1
	; beq +++
	; clc
	; adc #1
	bcs +
+++	adc #>story_start_far_ram
	bcs +
	cmp #VMEM_END_PAGE
	bcs +
	lda #VMEM_END_PAGE
	sec
	sbc object_temp
	sta ram_undo_page
	; Decrease vmem size
	lda object_temp
	lsr ; Divide by 2 to get # of VMEM blocks
	bcc ++
	adc #0 ; Adds one since C=1 (for when undo size is e.g. 20.5 VMEM blocks)
++	sta vmap_entries_reserved
	; lda vmap_max_entries
	; sec
	; sbc object_temp + 1
	; sta vmap_max_entries
	ldy #$7f
	sty reu_bank_for_undo ; Special value $7f means undo uses RAM buffer
+
	rts
}

c128_move_dynmem_and_calc_vmem
	; Copy dynmem to bank 1
	lda #>story_start
	sta zp_temp
	lda #>story_start_far_ram
	sta zp_temp + 1
	lda nonstored_pages
	sta zp_temp + 2
-	lda zp_temp
	ldy #>(vmem_cache_start + $200)
	ldx #0
	jsr copy_page_c128
	lda #>(vmem_cache_start + $200)
	ldy zp_temp + 1
	ldx #1
	jsr copy_page_c128
	inc zp_temp
	inc zp_temp + 1
	dec zp_temp + 2
	bne -

	; Copy any preloaded statmem pages down in memory, now that dynmem has moved
	lda #>story_start
	sta zp_temp + 1 ; First destination page
	clc
	adc nonstored_pages
	sta zp_temp ; First source page

-	lda zp_temp
	cmp #VMEM_END_PAGE
	bcs .done_vmem_move
	ldy zp_temp + 1
	ldx #0
	jsr copy_page_c128
	inc zp_temp
	inc zp_temp + 1
	bne - ; Always branch

.done_vmem_move
	; Add free RAM in bank 1 as vmem memory

	lda #>story_start
	sta vmap_first_ram_page

	; Remember above which index in vmem the blocks are in bank 1
!ifdef SCROLLBACK_RAM_PAGES {
	lda #SCROLLBACK_RAM_START_PAGE
} else {
	lda #VMEM_END_PAGE
}
	sec
	sbc #>story_start
	lsr ; Convert from 256-byte pages to 512-byte vmem blocks
	sta first_vmap_entry_in_bank_1

	; Remember the first page used for vmem in bank 1
	lda #>story_start_far_ram
	adc nonstored_pages ; Carry is already clear
	sta vmap_first_ram_page_in_bank_1

	; Calculate how many vmem pages we can fit in bank 1
	lda #VMEM_END_PAGE
	sec
	sbc vmap_first_ram_page_in_bank_1
	lsr ; Convert from 256-byte pages to 512-byte vmem blocks
!ifdef UNDO_RAM {
	sec
	sbc vmap_entries_reserved
	clc
}
	; Now A holds the # of vmem blocks we can fit in bank 1

	adc first_vmap_entry_in_bank_1 ; Add the # of vmem blocks in bank 0
	cmp #vmap_max_size
	bcc +
	lda #vmap_max_size
+	sta vmap_max_entries
	rts
}

!ifdef VMEM {
!ifndef NOSECTORPRELOAD {
.progress_suggested !byte 6

load_suggested_pages
; Load all suggested pages which have not been pre-loaded

; Print progress bar
	lda #13
	jsr s_printchar
	lda vmap_used_entries
	sec
	sbc vmap_blocks_preloaded
	tax
-	cpx #6
	bcc .start_loading
	lda #47
	jsr s_printchar
	txa
	sec
	sbc #6
	tax
	bne -
.start_loading
	lda vmap_blocks_preloaded ; First index which has not been loaded
	cmp vmap_used_entries ; Total # of indexes in the list
	bcs +
	sta vmap_index
	tax
	jsr load_blocks_from_index
	dec .progress_suggested
	bne ++
	lda #20
	jsr s_printchar
	lda #6
	sta .progress_suggested
++	inc vmap_blocks_preloaded
	bne .start_loading ; Always branch
+
	ldx vmap_used_entries
	cpx vmap_max_entries
	bcc +
	dex
+	

!ifdef TRACE_VM {
	jsr print_vm_map
}
	rts
} ; ifndef NOSECTORPRELOAD
} ; ifdef VMEM

!ifdef UNDO {
print_no_undo
	; ldy #header_flags_2 + 1
	; jsr read_header_word
	; and #(255 - 16) ; no undo
	; ldy #header_flags_2 + 1
	; jsr write_header_byte
	lda #>.no_undo_msg
	ldx #<.no_undo_msg
	jsr printstring_raw
	jmp wait_a_sec
.no_undo_msg
	!pet "Undo not available",13,13,0
}

!ifdef TARGET_MEGA65 {
NEED_CALC_DYNMEM = 1
}
!ifdef VMEM {
NEED_CALC_DYNMEM = 1
}

!ifdef NEED_CALC_DYNMEM {
calc_dynmem_size
	; Store the size of dynmem AND (if VMEM is enabled)
	; check how many z-machine memory blocks (256 bytes each) are not stored in raw disk sectors
!ifdef TARGET_C128 {
	; Special case because we need to read a header word from dynmem before dynmem
	; has been moved to its final location.
	lda story_start + header_static_mem
	ldx story_start + header_static_mem + 1
} else {
	; Target is not C128
	ldy #header_static_mem
	jsr read_header_word
}
	stx dynmem_size
	sta dynmem_size + 1
	
;!ifdef TARGET_MEGA65 {
	tay
	cpx #0
	beq .maybe_inc_nonstored_pages
	iny ; Add one page if statmem doesn't start on a new page ($xx00)
.maybe_inc_nonstored_pages
	tya
!ifdef TARGET_MEGA65 {
	and #%00000001 ; keep index into kB chunk
} else {
	and #vmem_indiv_block_mask ; keep index into kB chunk
}
	beq .store_nonstored_pages
	iny
.store_nonstored_pages
	sty nonstored_pages
;}
	rts
}

	
program_end

!ifdef USE_HISTORY {
history_start
	!fill USE_HISTORY, $00 ; make sure that there is some history available
}

!ifndef TARGET_C128 {
	!align 255, 0, 0
}

!ifdef USE_HISTORY {
history_end
!if history_end - history_start < 255 {
  history_size = history_end - history_start
} else {
  history_size = 255  ; max size of history buffer
}
history_lastpos = history_size -1 ; last pos (size of history buffer - 1)
}

z_trace_page
	!fill z_trace_size, 0

!ifndef TARGET_C128 {
vmem_cache_start
}
vmem_cache_start_maybe

!ifndef TARGET_PLUS4_OR_C128 {
	!if SPLASHWAIT > 0 {
		!source "splashscreen.asm"
	}
}


end_of_routines_in_vmem_cache

!align 255, 0, 0 ; To make sure stack is page-aligned even if not using vmem.

!ifndef TARGET_C128 {
	!fill cache_pages * 256 - (* - vmem_cache_start_maybe),0 ; Typically 4 pages
} 

!ifdef VMEM {
	!if (stack_size + *) & 256 {
		!fill 256,0 ; Add one page to avoid vmem alignment issues
	}
}

!ifndef TARGET_C128 {
vmem_cache_size = * - vmem_cache_start
vmem_cache_count = vmem_cache_size / 256
}

!align 255, 0, 0 ; To make sure stack is page-aligned even if not using vmem.

stack_start

deletable_screen_init_1
	; start text output from bottom of the screen

!ifndef Z4PLUS {
	!ifdef TARGET_C128 {
		bit COLS_40_80
		bpl .width40
		; 80 col
		lda #54
		sta sl_score_pos
		lda #67
		sta sl_moves_pos
		lda #64
		sta sl_time_pos
.width40
		; Default values are correct, nothing to do here.
	}
}
	+init_screen_model

deletable_screen_init_2
!ifdef SMOOTHSCROLL {
	jsr toggle_smoothscroll
}
	; clear and unsplit screen, start text output from bottom of the screen (top of screen if z5)
	ldy #1
	sty is_buffered_window
	ldx #$ff
	jsr erase_window
	jmp start_buffering

z_init
!zone z_init {

!ifdef DEBUG {
!ifdef PREOPT {
	jsr print_following_string
	!pet "*** vmem optimization mode ***",13,13,0
}	
}


	lda #0
	jsr set_z_exe_mode ; 0 = Normal
	
!ifdef TRACE {
	; Setup trace
	lda #0
	sta z_trace_index
	tay
-	sta z_trace_page,y
	iny
	bne -
}

	; Calculate Z7 string offset and routine offset
!ifdef Z7 {
	jsr calc_z7_offsets
}
	
	; Modify header to tell game about terp capabilities
!ifndef Z4PLUS {
	ldy #header_flags_1
	jsr read_header_word
	and #(255 - 16 - 64) ; Statusline IS available, variable-pitch font is not default
	ora #32 ; Split screen available
	jsr write_header_byte
!ifdef SOUND {
	jsr init_sound
}
} else {
!ifdef Z4 {
	ldy #header_flags_1
	jsr read_header_word
	and #(255 - 4 - 8) ; bold font, italic font not available
	ora #(16 + 128) ; Fixed-space style, timed input available
	jsr write_header_byte
} else { ; Z5PLUS
	ldy #header_flags_1
	jsr read_header_word
	and #(255 - 4 - 8) ; bold font, italic font not available
	ora #(1 + 16 + 128) ; Colours, Fixed-space style, timed input available
	jsr write_header_byte

; check_undo
	ldy #header_flags_2 + 1
	jsr read_header_word
	and #(255 - 8 - 32) ; pictures and mouse never available
!ifdef UNDO {
	bit reu_bank_for_undo
	bpl .undo_is_available
}
	; Tell game UNDO isn't supported
	and #(255 - 16) ; no undo
.undo_is_available	
	pha
!ifdef SOUND {
	; check if the game wants to play sounds, and if we can support this
	pla
	pha
	and #$80
	beq + ; Game doesn't want to play sounds
	jsr init_sound
	bcc +
	; No sound files found, so tell game sound isn't supported
	pla
	and #(255 - 128)  ; no sound effect
	pha
+
    pla
	ldy #header_flags_2 + 1
	jsr write_header_byte
} else {
    pla
	and #(255 - 128)  ; no sound effect
	ldy #header_flags_2 + 1
	jsr write_header_byte
}
}
}
!ifdef Z4PLUS {
	lda #TERPNO ; Interpreter number (8 = C64)
	ldy #header_interpreter_number 
	jsr write_header_byte
	lda #(64 + 13) ; "M" = release 13
	ldy #header_interpreter_version  ; Interpreter version. Usually ASCII code for a capital letter
	jsr write_header_byte
	lda #25
	ldy #header_screen_height_lines
	jsr write_header_byte
!ifdef Z5PLUS {
	ldy #header_screen_height_units
	tax
	lda #0
	jsr write_header_word
}
!ifdef TARGET_C128 {
	jsr update_screen_width_in_header
} else {
	lda #SCREEN_WIDTH
	ldy #header_screen_width_chars
	jsr write_header_byte
!ifdef Z5PLUS {
	ldy #header_screen_width_units
	tax
	lda #0
	jsr write_header_word
}
} ; End not TARGET_C128
} ; End Z4PLUS
	lda #0 ; major standard revision number which this terp complies to
	tax    ; minor standard revision number which this terp complies to
	ldy #header_standard_revision_number
	jsr write_header_word

!ifdef Z5PLUS {
	lda #1
	ldy #header_font_width_units
	jsr write_header_byte
	ldy #header_font_height_units
	jsr write_header_byte
	; TODO: Store default background and foreground colour in 2c, 2d (or comply to game's wish?)
	
	; Copy alphabet pointer from header, or default
	ldy #header_alphabet_table
	jsr read_header_word
	cmp #0
	bne .custom_alphabet
	cpx #0
	beq .store_alphabet_pointer
.custom_alphabet
	jsr set_z_address
	ldy #0
-	jsr read_next_byte
	sta z_alphabet_table,y
	iny
	cpy #26*3
	bcc -
.store_alphabet_pointer
}
;	ldx #<default_alphabet
;	ldy #>default_alphabet
;.store_alphabet_pointer
;	stx alphabet_table
;	sty alphabet_table + 1
	
	; Copy z_pc from header
	ldy #header_initial_pc
	jsr read_header_word
	pha
	txa
	tay
	pla
	tax
	lda #0
!ifndef VMEM {
	sta z_pc
}
	jsr set_z_pc
	jsr get_page_at_z_pc

	; Setup globals pointer
	ldy #header_globals
	jsr read_header_word
	tay
	txa
	clc
!ifdef FAR_DYNMEM  {
	adc #<(story_start_far_ram - 32)
	sta z_low_global_vars_ptr
	sta z_high_global_vars_ptr
	tya
	adc #>(story_start_far_ram - 32)
} else {
	adc #<(story_start - 32)
	sta z_low_global_vars_ptr
	sta z_high_global_vars_ptr
	tya
	adc #>(story_start - 32)
}
	sta z_low_global_vars_ptr + 1
	adc #1
	sta z_high_global_vars_ptr + 1 

!ifdef HAS_SID {
	jsr init_sid
}
!ifdef TARGET_PLUS4 {
	lda #0
	sta ted_volume
}

	
!ifdef BENCHMARK {
	lda #$ff
	ldx #$80
	ldy #1
	jmp z_rnd_init
} else {
	jmp z_rnd_init_random
}
}

!zone deletable_init {
!ifdef TARGET_PLUS4_OR_C128 {
fkey_codes !byte $85,$89,$86,$8a,$87,$8b,$88,$8c
}

deletable_init_start

; Turn off function key strings, to let F1 work for darkmode and F keys work in BZ 
!ifdef TARGET_PLUS4_OR_C128 {
	ldx #8
-	lda #1
	sta fkey_string_lengths - 1,x
	lda fkey_codes - 1,x
	sta fkey_string_area - 1,x
	dex
	bne -
!ifdef TARGET_C128 {
	stx fkey_string_lengths + 8
	stx fkey_string_lengths + 9
}
}


!ifdef TARGET_PLUS4 {
	!ifdef CUSTOM_FONT {
		lda reg_screen_char_mode
		and #$07
		ora #$10
		sta reg_screen_char_mode
		lda reg_screen_bitmap_mode
		and #%11111011
		sta reg_screen_bitmap_mode
	} else {
		lda #$d4
		sta reg_screen_char_mode
		lda reg_screen_bitmap_mode
		ora #%00000100
		sta reg_screen_bitmap_mode
	}
}
!ifdef TARGET_C128 {
	!ifdef CUSTOM_FONT {
		; make font available to VDC as well
		jsr VDCCopyFont

		; set bit 2 in $01/$d9 to disable character ROM shadowing
		; Page 364, https://www.cubic.org/~doj/c64/mapping128.pdf
		lda #4
		sta $d9

		lda #$17 ; 0001 011X = $0400 $1800
	} else {
		lda #$16
	}
	sta reg_screen_char_mode
}
!ifdef TARGET_C64 {
	!ifdef CUSTOM_FONT {
		lda #$12
	} else {
		lda #$17
	}
	sta reg_screen_char_mode
}
!ifdef TARGET_MEGA65 {
	!ifdef CUSTOM_FONT {
		lda #$42 ; screen/font: $1000 $0800
	} else {
		lda #$26 ; screen/font: $0800 $1800 (character ROM)
	}
	sta reg_screen_char_mode
	jsr init_mega65
}

	lda #$80
	sta charset_switchable
	lda #0
	sta mempointer

	jmp init_screen_colours ; _invisible
	


!ifdef TARGET_C128 {
; Setup the memory pre-configurations we need:
; pcra: RAM in bank 0, Basic disabled, Kernal and I/O enabled
; pcrb: RAM in bank 0, RAM everywhere
; pcrc: RAM in bank 1, RAM everywhere
c128_mmu_values !byte $0e,$3f,$7f
}
!ifdef TARGET_MEGA65 {
.first_value = z_temp
.different_values !byte 0
m65_statmem_already_loaded !byte 0
m65_attic_checksum_page = ($08000000 + 512 * 1024) / 256
}

deletable_init
	cld

	; Set only space, del, cursor to repeat
	lda #0
	sta key_repeat

!ifdef TARGET_C128 {
	jsr c128_setup_mmu
}
!ifdef TARGET_MEGA65 {
	lda #$0
	sta dynmem_pointer
	sta dynmem_pointer + 1
	sta dynmem_pointer + 2
	sta mempointer
	sta mempointer + 1
;	sta mempointer + 2 ; Will be set after reading the header
	lda #$08
	sta dynmem_pointer + 3
	sta mempointer + 3
;	sta mempointer_4bytes + 3
	sta z_pc_mempointer + 3
}



; Read and parse config from boot disk
	ldy CURRENT_DEVICE
	cpy #8
	bcc .pick_default_boot_device
	cpy #16
	bcc .store_boot_device
.pick_default_boot_device
	ldy #8
.store_boot_device
	sty boot_device ; Boot device# stored

!ifdef TARGET_MEGA65 {
	jsr m65_init_reu
	jsr m65_load_header
	jsr calc_dynmem_size
	; Header of game on disk is now loaded, starting at beginning of Attic RAM

!ifdef Z3PLUS {
	lda #<m65_attic_checksum_page
	sta mempointer + 1
	lda #>m65_attic_checksum_page
	sta mempointer + 2
	ldz #header_filelength
	lda [dynmem_pointer],z
	sta .first_value

-	lda [dynmem_pointer],z
	cmp .first_value
	beq +
	inc .different_values
+	cmp [mempointer],z
	bne .must_load_statmem
	inz
	cpz #header_filelength + 4 ; Compare file length (2 bytes) + checksum (2 bytes)
	bcc -
	; Header values for file length and checksum are indentical
	lda .different_values
	beq .must_load_statmem ; All four bytes have the same value. Header can't be trusted.
	dec m65_statmem_already_loaded ; Set it to $ff

.must_load_statmem
}

!ifdef UNDO {
	clc
	lda #(>stack_size) + 1
	adc nonstored_pages
	bcc + ; Dynmem + stack + ZP fits in 64 KB
	ldy #$ff
	sty reu_bank_for_undo ; Disable undo
	jsr print_no_undo
+
}

	lda #0
	sta reu_last_disk_end_block
	sta reu_last_disk_end_block + 1
	
	lda #0
	sta z_temp + 5
	ldz #header_filelength
	lda [dynmem_pointer],z
!ifdef Z4PLUS {
	!ifdef Z7PLUS {
		ldx #3 ; File size multiplier is 2^3 = 8
	} else {
		ldx #2 ; File size multiplier is 2^2 = 4
	}
} else {
	ldx #1 ; File size multiplier is 2^1 = 2
}
-	asl
	rol z_temp + 5
	dex
	bne -
	sta z_temp + 4
	
	bit m65_statmem_already_loaded
	beq +

	; We are only to load dynmem
	ldz #header_static_mem
	lda [dynmem_pointer],z
	sta z_temp + 4
	lda #0
	sta z_temp + 5
	
+	jsr print_reu_progress_bar

	jsr m65_load_dynmem_maybe_statmem
}




!ifdef VMEM {

!ifdef TARGET_PLUS4 {
	; Make config info on screen invisible
	lda reg_backgroundcolour
	ldx #0
-	sta COLOUR_ADDRESS,x
	sta COLOUR_ADDRESS + 256,x
	inx
	bne -
}
	lda #<config_load_address
	sta readblocks_mempos
	lda #>config_load_address
	sta readblocks_mempos + 1
	lda #CONF_TRK
	ldx #0
; No need to load y with boot device#, already in place
	jsr read_track_sector
	inc readblocks_mempos + 1
	lda #CONF_TRK
	ldx #1
	ldy boot_device
	jsr read_track_sector

; Copy game id
	ldx #3
-	lda config_load_address,x
!if SUPPORT_REU = 1 {
	cmp reu_filled,x
	beq +
	dec reu_needs_loading
+
}
	sta game_id,x
	dex
	bpl -

; Copy disk info
	ldx config_load_address + 4
	dex
-	lda config_load_address + 4,x
	sta disk_info - 1,x
	dex
	bne -
	
	jsr auto_disk_config
;	jsr init_screen_colours
} else { ; End of !ifdef VMEM
!ifdef TARGET_MEGA65 {
	ldy boot_device ; Boot device# stored
	sty disk_info + 4 ; Device# for save disk
	sty disk_info + 4 + 8 ; Device# for boot/story disk
	; Store boot device in current_disks
	lda #8 ; Index of story disk in disk_info - 3
	sta current_disks - 8,y

	lda #$ff ; Use REU
	sta use_reu
}
	ldy #header_static_mem
	jsr read_header_word ; Note: This does not work on C128, but we don't support non-vmem on C128!
	ldx #$30 ; First unavailable slot
	clc
	adc #(>stack_size) + 4
	sta zp_temp
	lda #>664
	sta zp_temp + 1
	lda #<664
.one_more_slot
	sec
	sbc zp_temp
	tay
	lda zp_temp + 1
	sbc #0
	sta zp_temp + 1
	bmi .no_more_slots
	inx
	cpx #$3a
	bcs .no_more_slots
	tya
	bcc .one_more_slot ; Always branch
.no_more_slots
	stx first_unavailable_save_slot_charcode
	txa
	and #$0f
	sta disk_info + 1 ; # of save slots
}

	; Default banks during execution: Like standard except Basic ROM is replaced by RAM.
	+set_memory_no_basic

; parse_header section

!ifdef NEED_CALC_DYNMEM {
	jsr calc_dynmem_size
}

!ifdef TARGET_MEGA65 {
	bit m65_statmem_already_loaded
	bmi + 
;	jsr m65_load_statmem
	jsr init_screen_colours
!ifdef SOUND {
	; When we had to load statmem, we will also need to load sound effects, if any
	jsr setup_sound_mempointer_32
	lda #0
	taz
	sta [sound_mempointer_32],z
}	
+
}
	
!ifdef VMEM {
	; tay
	; cpx #0
	; beq .maybe_inc_nonstored_pages
	; iny ; Add one page if statmem doesn't start on a new page ($xx00)
; .maybe_inc_nonstored_pages
	; tya
	; and #vmem_indiv_block_mask ; keep index into kB chunk
	; beq .store_nonstored_pages
	; iny
; .store_nonstored_pages
	; sty nonstored_pages
	; tya
	lda nonstored_pages
	
	clc
	adc #>story_start
	sta vmap_first_ram_page
!ifdef SCROLLBACK_RAM_PAGES {
	lda #SCROLLBACK_RAM_START_PAGE
} else {
	lda #VMEM_END_PAGE
}
	sec
	sbc vmap_first_ram_page
	lsr
	cmp #vmap_max_size ; Maximum space available
	bcc ++
	lda #vmap_max_size
++

!ifdef VMEM_STRESS {
	lda #2 ; one block for PC, one block for data
}
	sta vmap_max_entries

!ifdef TARGET_C128 {
	jsr c128_move_dynmem_and_calc_vmem
}

	jsr prepare_static_high_memory

	jsr insert_disks_at_boot

!ifndef NOSECTORPRELOAD {

!if SUPPORT_REU = 1 {
	lda use_reu
	bne .dont_preload
}

	jsr load_suggested_pages
.dont_preload
} ; ifndef NOSECTORPRELOAD

} ; End of !ifdef VMEM

!ifdef CHECK_ERRORS {
	; check z machine version
	ldy #header_version
	jsr read_header_word
	cmp #ZMACHINEVERSION
	beq .supported_version
	lda #ERROR_UNSUPPORTED_STORY_VERSION
	jsr fatalerror
.supported_version
}


!ifdef TARGET_MEGA65 {

!ifdef Z3PLUS {
	; Store header values for file length and checksum in Attic RAM to say the game has been loaded

	; dynmem_pointer may have been altered by read_word_from_far_dynmem
	lda #$0
	sta dynmem_pointer
	sta dynmem_pointer + 1

	lda #<m65_attic_checksum_page
	sta mempointer + 1
	lda #>m65_attic_checksum_page
	sta mempointer + 2
	ldz #header_filelength
-	lda [dynmem_pointer],z
	sta [mempointer],z
	inz
	cpz #header_filelength + 4 ; Compare file length (2 bytes) + checksum (2 bytes)
	bcc -	
}
}

	rts

}

!ifdef VMEM {
!zone disk_config {
auto_disk_config
; Limit # of save slots to no more than 10
	lda disk_info + 1
	cmp #11
	bcc +
	lda #10
	sta disk_info + 1
	clc
+	adc #$30
	sta first_unavailable_save_slot_charcode 

; Figure out best device# for all disks set to auto device# (value = 0)
	lda #0
	tay ; Disk#
.next_disk
	tax ; Memory index
	lda disk_info + 4,x
	bne .device_selected
	cpy #2
	bcs .not_save_or_boot_disk
	; This is the save or boot disk
	lda boot_device
	bne .select_device ; Always branch
.not_save_or_boot_disk
	stx zp_temp ; Store current value of x (memory pointer)
!if SUPPORT_REU = 1 {
	ldx boot_device
	bit use_reu
	bmi .use_this_device
}
	ldx #8
-	lda device_map - 8,x
	beq .use_this_device
	inx
	bne - ; Always branch
.use_this_device
	txa
	ldx zp_temp ; Retrieve current value of x (memory pointer)
.select_device
	sta disk_info + 4,x
.device_selected
	sta zp_temp + 1 ; Store currently selected device#
	lda disk_info + 7,x
	beq +
	; This is a story disk
	txa ; Save value of x
	ldx zp_temp + 1 ; Load currently selected device#
	inc device_map - 8,x ; Mark device as in use by a story disk
	tax
+	iny
	cpy disk_info + 2 ; # of disks
	bcs .done
	txa
	adc disk_info + 3,x
	bne .next_disk ; Always branch
.done
	rts
}
!zone insert_disks_at_boot {
insert_disks_at_boot
!if SUPPORT_REU = 1 {
	lda #0
	sta reu_last_disk_end_block
	sta reu_last_disk_end_block + 1
}

	lda #0
	tay ; Disk#
.next_disk
	tax ; Memory index
	cpy #1
	bcc .dont_need_to_insert_this
	; Store in current_disks
	lda disk_info + 4,x
	stx zp_temp
	tax
	lda zp_temp
	sta current_disks - 8,x
	tax

	cpy #2
!if SUPPORT_REU = 1 {
	bcs +
	jmp .copy_data_from_disk_1_to_reu
+	lda reu_needs_loading
	beq .dont_need_to_insert_this
} else {
	bcc .dont_need_to_insert_this
}
	stx zp_temp
	sty zp_temp + 1
	ldy zp_temp
	jsr print_insert_disk_msg
!if SUPPORT_REU = 1 {
	ldx use_reu
	beq .restore_xy_disk_done
	lda #13
	jsr s_printchar
	jsr copy_data_from_disk_at_zp_temp_to_reu

}
.restore_xy_disk_done
	ldx zp_temp
	ldy zp_temp + 1

.dont_need_to_insert_this
+	iny
	cpy disk_info + 2 ; # of disks
	bcs .done
	txa
	adc disk_info + 3,x
	bne .next_disk ; Always branch
.done

!if SUPPORT_REU = 1 {
	lda use_reu
	beq .dont_use_reu
	lda #$ff ; Use REU
	sta use_reu
!ifdef REUBOOST {
	; Init and enable REU Boost Mode
	sta reu_boost_mode

!ifdef TARGET_C64 {
	lda vmap_first_ram_page
	sta reu_boost_area_start_page
	lda #>reu_boost_hash_table
	sec
	sbc reu_boost_area_start_page
	bcc .no_boost
	cmp #4
	bcc .no_boost
	sta reu_boost_area_pagecount
	bcs + ; Always branch
.no_boost
	inc reu_boost_mode
	rts
+	
}

	lda #<reu_boost_hash_table
	sta z_temp
	lda #>reu_boost_hash_table
	sta z_temp + 1
	ldx #reu_boost_hash_pages ; Need 2-8 pages depending on game size
	ldy #0
	sty reu_boost_vmap_clock
	tya
-	sta (z_temp),y
	iny
	bne -
	inc z_temp + 1
	dex
	bne -
	ldy reu_boost_area_pagecount
	cpy #vmap_max_size
	bcc +
	ldy #vmap_max_size
+	sty vmap_max_entries
	sty vmap_used_entries
-	sta vmap_z_h - 1,y
	sta vmap_z_l - 1,y
	dey
	bne -
}
}
.dont_use_reu
	rts
	
!if SUPPORT_REU = 1 {
.copy_data_from_disk_1_to_reu

	lda use_reu
	bpl .dont_need_to_insert_this
	lda reu_needs_loading
	beq .dont_need_to_insert_this

	sty zp_temp + 1

	; Prepare for copying data to REU
	lda #0
	ldx nonstored_pages
	stx z_temp ; Lowbyte of current page in Z-machine memory
	sta z_temp + 1 ; Highbyte of current page in Z-machine memory
	ldx #1 ; Start on page 1, reserve page 0 for fast copy operations
	stx z_temp + 2 ; Lowbyte of current page in REU memory
	sta z_temp + 3 ; Highbyte of current page in REU memory
	sta z_temp + 6 ; Sector# to read next, lowbyte
	sta z_temp + 7 ; Sector# to read next, highbyte
	
	jsr copy_data_from_disk_at_zp_temp_to_reu
	jmp .restore_xy_disk_done

copy_data_from_disk_at_zp_temp_to_reu
; zp_temp holds memory index into disk_info where info on this disk begins
; Perform initial copy of data to REU	
	ldx zp_temp
	lda disk_info + 6,x
	sta z_temp + 4 ; Last sector# on this disk. Store low-endian
	lda disk_info + 5,x
	sta z_temp + 5 ; Last sector# on this disk. Store low-endian
	
	jsr print_reu_progress_bar

.initial_copy_loop
	lda z_temp + 6
	cmp z_temp + 4
	lda z_temp + 7
	sbc z_temp + 5
	bcs .done_copying

	lda z_temp + 1
	ldx z_temp ; (Not) Already loaded
	ldy #0 ; Value is unimportant except for the last block, where anything > 0 may be after file end
	jsr read_byte_at_z_address
	; Current Z-machine page is now in C64 page held in mempointer + 1
	lda z_temp + 3
	ldx z_temp + 2
	ldy mempointer + 1
	jsr copy_page_to_reu
	bcs .reu_error

	; Inc Z-machine page
	inc z_temp
	bne +
	inc z_temp + 1

	; Inc REU page
+	inc z_temp + 2
	bne +
	inc z_temp + 3

	; Inc disk block#
+	inc z_temp + 6
	bne .initial_copy_loop
	inc z_temp + 7
	bne .initial_copy_loop ; Always branch

.done_copying

	lda z_temp + 4
	sta reu_last_disk_end_block
	lda z_temp + 5
	sta reu_last_disk_end_block + 1

	rts

.reu_error
	jmp reu_error

reu_start
	lda #0
	sta use_reu
	sta keyboard_buff_len
	ldx reu_c64base
	inc reu_c64base
	inx
	cpx reu_c64base
	bne .no_reu_present
; REU detected, check size
	jsr check_reu_size
;	lda #0 ; SKIP REU FOR DEBUGGING PURPOSES
	sta reu_banks
	cmp statmem_reu_banks
	bcc .no_reu_present ; REU is too small to cache this game

	lda #>.use_reu_question
	ldx #<.use_reu_question
	jsr printstring_raw
-	jsr kernal_getchar
	cmp #78
	beq .dont_cache_to_reu
	cmp #89
	bne -
	ldx #$80 ; Use REU, set vmem to reu loading mode
	stx use_reu
!ifdef UNDO {
	ldx statmem_reu_banks
	cpx reu_banks
	beq .no_reu_room_for_undo
	stx reu_bank_for_undo
.no_reu_room_for_undo
}
; !ifdef TARGET_C128 {
	; ; Make sure REU uses RAM bank 0
	; pha
	; lda $d506
	; and #%00111111 ; Bit 6: 0 means bank 0, bit 7 is unused
	; sta $d506
	; pla
; }
	ora #$80
	bne .print_reply_and_return ; Always branch

.dont_cache_to_reu
!ifdef UNDO {
	ldx #0
	stx reu_bank_for_undo
}
	lda #78 + 128
.print_reply_and_return
	jsr s_printchar
	lda #13
	jsr s_printchar
	lda #13
	jsr s_printchar
.no_reu_present
!ifdef UNDO {
!ifdef UNDO_RAM {
	jsr undo_ram_setup
}
	bit reu_bank_for_undo
	bpl +
	jmp print_no_undo
+
}
	rts

.use_reu_question
	!pet 13,"Use REU for faster play? (Y/N) ",0


} ; if SUPPORT_REU = 1

} ; zone insert_disks_at_boot

prepare_static_high_memory
	lda #$ff
	sta zp_pc_h
	sta zp_pc_l

; Clear quick index
	lda #0
	ldx #vmap_quick_index_length
-	sta vmap_next_quick_index,x ; Sets next quick index AND all entries in quick index to 0
	dex
	bpl -

; Copy vmem info from config blocks to vmap	
	lda #6
	clc
	adc config_load_address + 4
	sta zp_temp
	lda #>config_load_address
;	adc #0 ; Not needed, as disk info is always <= 249 bytes
	sta zp_temp + 1
!ifdef NOSECTORPRELOAD {
	; With no sector preload, we only fill vmem map with the blocks that are in boot file
	ldy #1
	lda (zp_temp),y
} else {
	ldy #0
	lda (zp_temp),y ; # of blocks in the list
	iny
}
	tax
	cpx vmap_max_entries
	bcc +
	ldx vmap_max_entries
+	stx vmap_used_entries  ; Number of bytes to copy
	lda (zp_temp),y
	sta vmap_blocks_preloaded ; # of blocks already loaded

!if SUPPORT_REU = 1 {
	; If using REU, suggested blocks will just be ignored
	bit use_reu
	bpl .ignore_blocks
}
	sta vmap_used_entries
	tax
.ignore_blocks

	cpx #0
	beq .no_entries
; Copy to vmap_z_h
-	iny
	lda (zp_temp),y
	sta vmap_z_h - 2,y
	dex
	bne -
	
; Point to lowbyte array	
	ldy #0
	lda (zp_temp),y
	clc
	adc #2 ; This can't set the carry
	adc zp_temp
	bcc +
	inc zp_temp + 1
+	sta zp_temp
	ldy vmap_used_entries
	dey
-	lda (zp_temp),y
	sta vmap_z_l,y
	dey
	cpy #$ff
	bne -
.no_entries
!ifdef TRACE_VM {
	jsr print_vm_map
}
	rts

} ; End of VMEM

!ifdef TARGET_MEGA65 {
m65_init_reu
	jsr check_reu_size
	sta reu_banks
	rts
}


!ifdef TARGET_MEGA65 {
m65_load_header
	ldx #$00
	stx reu_progress_bar_updates
	inx
	stx m65_reu_load_page_limit
	stx m65_reu_enable_load_page_limit
	bne ++ ; Always branch

m65_load_dynmem_maybe_statmem
	ldx m65_statmem_already_loaded
	beq ++ ; Statmem is not loaded => load entire zcode file
	ldx nonstored_pages
	stx m65_reu_load_page_limit
	ldx #$ff ; Don't store value of nonstored_pages, since it's $00 if dynmem size is >= $fe00
	stx m65_reu_enable_load_page_limit

++	lda #.zcodefilenamelen
	ldx #<.zcodefilename
	ldy #>.zcodefilename
	jsr kernal_setnam ; call SETNAM

	ldx #0 ; Start on page 0 (page 0 isn't needed for copy ops on MEGA65)
	txa
	
	jmp m65_load_file_to_reu ; in reu.asm

.zcodefilename
	!pet "zcode,s,r"
.zcodefilenamelen = * - .zcodefilename

; .dynmemfilename
	; !pet "zcode-dyn,s,r"
; .dynmemfilenamelen = * - .dynmemfilename
; +	

; m65_load_statmem
	; lda #.statmemfilenamelen
	; ldx #<.statmemfilename
	; ldy #>.statmemfilename
	; jsr kernal_setnam ; call SETNAM

	; ldx nonstored_pages
	; lda #0
	
	; jsr m65_load_file_to_reu ; in reu.asm

	; rts

; .statmemfilename
	; !pet "zcode-stat,s,r"
; .statmemfilenamelen = * - .statmemfilename
}


!ifdef HAS_SID {
init_sid
	; Init sound
	lda #0
	ldx #$18
-	sta $d400,x
	dex
	bpl -
	lda #$f
	sta $d418
	lda #$00
	sta $d405
	lda #$f2
	sta $d406

	; Init randomization
	lda #$ff
	sta $d40e
	sta $d40f
	ldx #$80
	stx $d412
	rts
}



end_of_routines_in_stack_space

	!fill stack_size - (* - stack_start),0 ; 4 pages

story_start

!ifdef vmem_cache_size {
!if vmem_cache_size >= $200 {
	config_load_address = vmem_cache_start
}
}
!ifndef config_load_address {
	config_load_address = SCREEN_ADDRESS
}
