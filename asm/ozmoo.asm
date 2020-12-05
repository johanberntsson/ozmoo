; Which Z-machine to generate binary for
; (usually defined on the acme command line instead)
; Z1, Z2, Z6 and Z7 will (probably) never be supported
;Z3 = 1
;Z4 = 1
;Z5 = 1
;Z8 = 1

; Which machine to generate code for
; C64 is default and currently the only supported target, but
; future versions may include new targets such as Mega65, Plus/4 etc.
!ifdef TARGET_MEGA65 {
	TARGET_ASSIGNED = 1
	HAS_SID = 1
	SUPPORT_REU = 0
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
}
!ifdef TARGET_C64 {
	TARGET_ASSIGNED = 1
}
!ifdef TARGET_C128 {
	TARGET_PLUS4_OR_C128 = 1
	TARGET_ASSIGNED = 1
	HAS_SID = 1
	VMEM_END_PAGE = $fc
	COMPLEX_MEMORY = 1
	!ifndef SLOW {
		SLOW = 1
	}
}

!ifndef TARGET_ASSIGNED {
	; No target given. C64 is the default target
	TARGET_C64 = 1
}

!ifdef TARGET_C64 {
	HAS_SID = 1
}

!ifndef SUPPORT_REU {
	SUPPORT_REU = 1
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

!ifndef TERPNO {
	TERPNO = 8
}

!ifdef Z3 {
	ZMACHINEVERSION = 3
}
!ifdef Z4 {
	ZMACHINEVERSION = 4
	Z4PLUS = 1
}
!ifdef Z5 {
	ZMACHINEVERSION = 5
	Z4PLUS = 1
	Z5PLUS = 1
}
!ifdef Z8 {
	ZMACHINEVERSION = 8
	Z4PLUS = 1
	Z5PLUS = 1
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

!ifndef BGCOLDM {
	BGCOLDM = 2
}
!ifndef FGCOLDM {
	FGCOLDM = 4
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
	SPLASHWAIT = 3
}



;  * = $0801 ; This must now be set on command line: --setpc $0801


program_start

;	lda #4
;	sta $d020

;	lda #$41
;	jsr $ffd2
;	jsr wait_a_sec

!ifdef TARGET_C128 {
	jsr VDCInit
	; initialize is in Basic LO ROM in C128 mode, so we need
	; to turn off BASIC already here. Since the set_memory_no_basic
	; macro isn't defined yet we'll have to do it manually
	lda #%00001110
	sta $ff00
}
	jmp .initialize

!ifdef TARGET_C128 {
!source "constants-c128.asm"

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

allow_2mhz !byte $ff

;phase 2 of 2MHz speed-up = change CPU to 2MHz
;and set raster IRQ for top-of-screen less 1 raster
;and do normal KERNAL routines of IRQ
c128_border_phase2
	lda #1
	ldx allow_2mhz
	beq +
	sta $d030	;CPU = 2MHz
+	sta $d019	;clear VIC raster IRQ
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
	sta $d030	;CPU = 1MHz
	jmp $ff33	;return from IRQ

} else {
!source "constants.asm"
}
!source "constants-header.asm"



; global variables
; filelength !byte 0, 0, 0
; fileblocks !byte 0, 0
; c64_model !byte 0 ; 1=NTSC/6567R56A, 2=NTSC/6567R8, 3=PAL/6569
!ifdef VMEM {
game_id		!byte 0,0,0,0
}


.initialize
	cld
	cli
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
	jsr reu_start
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
	ldx #$ff
	jsr erase_window

	jsr z_init

!ifdef TARGET_C128 {
	; Let's speed things up.
	; this needs to be after the z_init call since 
	; z_init uses SID to initialize the random number generator
	; and SID doesn't work in fast mode.
	ldx COLS_40_80
	beq +
	; 80 columns mode
	; switch to 2MHz
	lda #1
	sta $d030	;CPU = 2MHz
	lda $d011
	; Clear top bit (to not break normal interrupt) and bit 4 to blank screen 
	and #$%01101111 
	sta $d011
	jmp ++
+	; 40 columns mode
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
++
}
	cli


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


; include other assembly files
!source "utilities.asm"
!source "screenkernal.asm"
!source "streams.asm"
!source "disk.asm"
!ifdef VMEM {
	!if SUPPORT_REU = 1 {
	!source "reu.asm"
	}
}
!source "screen.asm"
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
	
	; txa ; a = 0
	; ldx #9
; -	sta c128_function_key_string_lengths,x
	; dex
	; bpl -
	
; Just for testing
	; lda #$f0
	; ldy #$08
	; ldx #0
	; jsr copy_page_c128
	
	; lda #$08
	; ldy #$d0
	; ldx #1
	; jsr copy_page_c128


c128_move_dynmem_and_calc_vmem
	; Copy dynmem to bank 1
	lda #>story_start
	sta zp_temp
	lda #>story_start_bank_1
	sta zp_temp + 1
	lda nonstored_blocks
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

	lda #>story_start
	sta zp_temp + 1 ; First destination page
	clc
	adc nonstored_blocks
	sta zp_temp ; First source page
	; lda vmap_used_entries
	; asl
	; sta zp_temp + 2 ; How many pages to copy
	; beq .done_vmem_move

-	lda zp_temp
	cmp #VMEM_END_PAGE
	bcs .done_vmem_move
	ldy zp_temp + 1
	ldx #0
	jsr copy_page_c128
	inc zp_temp
	inc zp_temp + 1
;	dec zp_temp + 2
	bne - ; Always branch

.done_vmem_move

	; Add free RAM in bank 1 as vmem memory

	; ; First clear all vmap entries after the one which is currently the last
	; ldx vmap_used_entries
	; lda #0
; -	sta vmap_z_h,x
	; sta vmap_z_l,x
	; inx
	; cpx #vmap_max_size
	; bcc -
	
	lda #>story_start
	sta vmap_first_ram_page

	; Remember above which index in vmem the blocks are in bank 1
	lda #VMEM_END_PAGE
	sec
	sbc #>story_start
	lsr ; Convert from 256-byte pages to 512-byte vmem blocks
	; lda vmap_max_entries
	; clc
	; adc object_temp
	sta first_vmap_entry_in_bank_1

	; Remember the first page used for vmem in bank 1
	lda #>story_start_bank_1
	adc nonstored_blocks ; Carry is already clear
	sta vmap_first_ram_page_in_bank_1

	; Calculate how many vmem pages we can fit in bank 1
	lda nonstored_blocks
	lsr ; To get # of dynmem blocks, which are 512 bytes instead of 256
	sta object_temp
	lda #VMEM_END_PAGE
	sec
	sbc vmap_first_ram_page_in_bank_1
	lsr ; Convert from 256-byte pages to 512-byte vmem blocks
	; Now A holds the # of vmem blocks we can fit in bank 1
	adc vmap_max_entries ; Add the # we had room for in bank 0 from the start
	adc object_temp ; Add the # we made room for by moving dynmem to bank 1
	cmp #vmap_max_size
	bcc +
	lda #vmap_max_size
+	sta vmap_max_entries
	rts
}

	
program_end


!ifndef TARGET_C128 {
	!align 255, 0, 0
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
	
	lda #147 ; clear screen
	jsr s_printchar
	ldy #0
	sty current_window
	sty window_start_row + 3
!ifdef Z3 {
	iny
}
	sty window_start_row + 2
	sty window_start_row + 1
	ldy s_screen_heigth
	sty window_start_row
	ldy #0
	sty is_buffered_window
	ldx #$ff
	jmp erase_window

deletable_screen_init_2
	; start text output from bottom of the screen
	
	lda #147 ; clear screen
	jsr s_printchar
	ldy #1
	sty is_buffered_window
	ldx #$ff
	jsr erase_window
	ldy #0
	ldx #1
	jsr set_cursor
	jmp start_buffering

z_init
!zone z_init {

!ifdef DEBUG {
!ifdef PREOPT {
	jsr print_following_string
	!pet "*** vmem optimization mode ***",13,13,0
}	
}


	ldy #0
	sty z_exe_mode ; 0 = Normal
	
!ifdef TRACE {
	; Setup trace
	lda #0
	sta z_trace_index
	tay
-	sta z_trace_page,y
	iny
	bne -
}
	
	; Modify header to tell game about terp capabilities
!ifdef Z3 {
	ldy #header_flags_1
	jsr read_header_word
	and #(255 - 16 - 64) ; Statusline IS available, variable-pitch font is not default
	ora #32 ; Split screen available
	jsr write_header_byte
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
	ldy #header_flags_2 + 1
	jsr read_header_word
	and #(255 - 8 - 16 - 32 - 128) ; pictures, undo, mouse, sound effect not available
	jsr write_header_byte
}
}
!ifdef Z4PLUS {
	lda #TERPNO ; Interpreter number (8 = C64)
	ldy #header_interpreter_number 
	jsr write_header_byte
	lda #68 ; "D" = release 4
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
	lda s_screen_width
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
}
	
	; Copy alphabet pointer from header, or default
!ifdef Z5PLUS {
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
!ifdef TARGET_C128 {
	adc #<(story_start_bank_1 - 32)
	sta z_low_global_vars_ptr
	sta z_high_global_vars_ptr
	tya
	adc #>(story_start_bank_1 - 32)
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

deletable_init_start

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

	jmp init_screen_colours ; _invisible
	


!ifdef TARGET_C128 {
; Setup the memory pre-configurations we need:
; pcra: RAM in bank 0, Basic disabled, Kernal and I/O enabled
; pcrb: RAM in bank 0, RAM everywhere
; pcrc: RAM in bank 1, RAM everywhere
c128_mmu_values !byte $0e,$3f,$7f
}


deletable_init
	cld

	; stop key repeat (preventing problems with input in fast emulators)
!ifdef TARGET_C64 {
	lda #127
	sta $028a
}
!ifdef TARGET_C128 {
	lda #96
	sta $0a22
}
!ifdef TARGET_PLUS4 {
	lda #96
	sta $0540
}

!ifdef TARGET_C128 {
	jsr c128_setup_mmu
}



; Turn off function key strings, to let F1 work for darkmode and F keys work in BZ 
!ifdef TARGET_PLUS4_OR_C128 {
	ldx #$85
-	lda #1
	sta fkey_string_lengths - $85,x
	txa
	sta fkey_string_area - $85,x
	inx
	cpx #$85 + 8
	bcc -
!ifdef TARGET_C128 {
	lda #0
	sta fkey_string_lengths + 8
	sta fkey_string_lengths + 9
}
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
;    jsr kernal_readchar   ; read keyboard
; Copy game id
	ldx #3
-	lda config_load_address,x
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
	sty disk_info + 4
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

	; ldy #0
	; ldx #0
	; jsr set_cursor
	
	; Default banks during execution: Like standard except Basic ROM is replaced by RAM.
	+set_memory_no_basic

; parse_header section

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
!ifdef VMEM {
	tay
	cpx #0
	beq .maybe_inc_nonstored_blocks
	iny ; Add one page if statmem doesn't start on a new page ($xx00)
.maybe_inc_nonstored_blocks
	tya
	and #vmem_indiv_block_mask ; keep index into kB chunk
	beq .store_nonstored_blocks
	iny
.store_nonstored_blocks
	sty nonstored_blocks
	tya
	clc
	adc #>story_start
	sta vmap_first_ram_page
	lda #VMEM_END_PAGE
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

hello

!ifdef TARGET_C128 {
	jsr c128_move_dynmem_and_calc_vmem
}

	jsr prepare_static_high_memory

	jsr insert_disks_at_boot

!if SUPPORT_REU = 1 {
	lda use_reu
	bne .dont_preload
}
	jsr load_suggested_pages
.dont_preload

} ; End of !ifdef VMEM

!ifndef UNSAFE {
	; check z machine version
	ldy #header_version
	jsr read_header_word
	cmp #ZMACHINEVERSION
	beq .supported_version
	lda #ERROR_UNSUPPORTED_STORY_VERSION
	jsr fatalerror
.supported_version
}



   ; ; check file length
	; ; Start by multiplying file length by 2
	; lda #0
	; sta filelength
	; lda story_start + header_filelength
	; sta filelength + 1
	; lda story_start + header_filelength + 1
	; asl
	; rol filelength + 1
	; rol filelength
; !ifdef Z4PLUS {
	; ; Multiply file length by 2 again (for Z4, Z5 and Z8)
	; asl
	; rol filelength + 1
	; rol filelength
; !ifdef Z8 {
	; ; Multiply file length by 2 again (for Z8)
	; asl
	; rol filelength + 1
	; rol filelength
; }
; }
	; sta filelength + 2
	; ldy filelength
	; ldx filelength + 1
	; beq +
	; inx
	; bne +
	; iny
; +	sty fileblocks
	; stx fileblocks + 1
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
;	jsr dollar
;	jsr kernal_readchar
	jsr prepare_for_disk_msgs
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
	bcc .copy_data_from_disk_1_to_reu
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
}
.dont_use_reu
	rts
	
!if SUPPORT_REU = 1 {
.copy_data_from_disk_1_to_reu
	lda use_reu
	bpl .dont_need_to_insert_this

	sty zp_temp + 1

	; Prepare for copying data to REU
	lda #0
	ldx nonstored_blocks
	stx z_temp ; Lowbyte of current page in Z-machine memory
	sta z_temp + 1 ; Highbyte of current page in Z-machine memory
	ldx #1
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

.initial_copy_loop
	lda z_temp + 6
	cmp z_temp + 4
	lda z_temp + 7
	sbc z_temp + 5
	bcs .done_copying

	lda z_temp + 1
	ldx z_temp ; (Not) Already loaded
	sta $7fd
	stx $7fe
	ldy #0 ; Value is unimportant except for the last block, where anything > 0 may be after file end
	jsr read_byte_at_z_address
	; Current Z-machine page is now in C64 page held in mempointer + 1
	lda z_temp + 3
	ldx z_temp + 2
	ldy mempointer + 1
	jsr copy_page_to_reu
	bcs .reu_error

	ldx z_temp ; (Not) Already loaded
	stx $7ff

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
	bne +
	inc z_temp + 7
+	bne .initial_copy_loop ; Always branch

.done_copying
	rts

.reu_error
	lda #0
	sta use_reu
	lda #>.reu_error_msg
	ldx #<.reu_error_msg
	jsr printstring_raw
-	jsr kernal_getchar
	beq -
	rts

.reu_error_msg
	!pet "REU error. [SPACE]",0

copy_page_to_reu
	; a,x = REU page
	; y = C64 page
!ifdef TARGET_C128 {
	pha
	lda #0
	sta allow_2mhz
	sta $d030	;CPU = 1MHz
	pla
}

	jsr store_reu_transfer_params

	lda #%10010000;  c64 -> REU with immediate execution
	sta reu_command

!ifdef TARGET_C128 {	
	lda #1
	sta allow_2mhz
	lda COLS_40_80
	beq +
	lda #1
	sta $d030	;CPU = 2MHz
+
}

	rts

.no_reu
	lda #78 + 128
.print_reply_and_return
	jsr s_printchar
	lda #13
	jsr s_printchar
.no_reu_present	
	rts

reu_start
	lda #0
	sta use_reu
	sta keyboard_buff_len
	ldx reu_c64base
	inc reu_c64base
	inx
	cpx reu_c64base
	bne .no_reu_present
; REU detected
	lda #>.use_reu_question
	ldx #<.use_reu_question
	jsr printstring_raw
-	jsr kernal_getchar
	cmp #78
	beq .no_reu
	cmp #89
	bne -
	ldx #$80 ; Use REU, set vmem to reu loading mode
	stx use_reu
	ora #$80
	bne .print_reply_and_return ; Always branch
.use_reu_question
	!pet 13,"Use REU? (Y/N) ",0
} ; SUPPORT_REU = 1

}
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
	
	lda #6
	clc
	adc config_load_address + 4
	sta zp_temp
	lda #>config_load_address
;	adc #0 ; Not needed if disk info is always <= 249 bytes
	sta zp_temp + 1
	ldy #0
	lda (zp_temp),y ; # of blocks in the list
	tax
	cpx vmap_max_entries
;	cpx #vmap_max_size
	bcc +
	beq +
	ldx vmap_max_entries
+	stx vmap_used_entries  ; Number of bytes to copy
	iny
	lda (zp_temp),y
	sta vmap_blocks_preloaded ; # of blocks already loaded

!if SUPPORT_REU = 1 {
	; If using REU, suggested blocks will just be ignored
	bit use_reu
	bpl .ignore_blocks
}
	sta vmap_used_entries
.ignore_blocks
;	sta zp_temp + 3 ; # of blocks already loaded

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
	adc zp_temp
	adc #2
	sta zp_temp
	ldy vmap_used_entries
	beq .no_entries
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
	
.progress !byte 0	

load_suggested_pages
; Load all suggested pages which have not been pre-loaded
	lda #13
	jsr s_printchar
	lda #13
	jsr s_printchar
	lda vmap_used_entries
	sec
	sbc vmap_blocks_preloaded
	tax
-	cpx #6
	bcc +
	lda #47
	jsr s_printchar
	txa
	sec
	sbc #6
	tax
	bne -
+	lda #6
	sta .progress
-	lda vmap_blocks_preloaded ; First index which has not been loaded
	beq ++ ; First block was loaded with header
	cmp vmap_used_entries ; Total # of indexes in the list
	bcs +
	sta vmap_index
	tax
	jsr load_blocks_from_index
	dec .progress
	bne ++
	lda #20
	jsr s_printchar
	lda #6
	sta .progress
++	inc vmap_blocks_preloaded
	bne - ; Always branch
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
