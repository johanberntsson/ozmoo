; Which Z-machine to generate binary for
; (usually defined on the acme command line instead)
; Z1, Z2, Z6 and Z7 will (probably) never be supported
;Z3 = 1
;Z4 = 1
;Z5 = 1
;Z8 = 1

!ifdef VMEM {
!ifndef ALLRAM {
	ALLRAM = 1
}
}

!ifdef ALLRAM {
!ifdef CACHE_PAGES {
	cache_pages = CACHE_PAGES ; Note, this is not final. One page may be added. vmem_cache_count will hold final # of pages.
} else {
	cache_pages = 4 ; Note, this is not final. One page may be added. vmem_cache_count will hold final # of pages.
}
}

!ifdef Z4 {
	Z4PLUS = 1
}
!ifdef Z5 {
	Z4PLUS = 1
	Z5PLUS = 1
}
!ifdef Z8 {
	Z4PLUS = 1
	Z5PLUS = 1
}

!source "constants.asm"

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
	BGCOL = 2
}
!ifndef FGCOL {
	FGCOL = 9
}

; Border color: 0 = as background, 1 = as foreground, 2-9: specified Z-code colour. Default: as background
!ifndef BORDERCOL {
	BORDERCOL = 0
}
!if BORDERCOL = 0 {
	BORDER_LIKE_BG = 1
}
!if BORDERCOL = 1 {
	BORDER_LIKE_FG = 1
}

!ifndef STATCOL {
	STATCOL = FGCOL
}



;  * = $0801 ; This must now be set on command line: --setpc $0801

program_start

    jmp .initialize

; global variables
filelength !byte 0, 0, 0
fileblocks !byte 0, 0
; c64_model !byte 0 ; 1=NTSC/6567R56A, 2=NTSC/6567R8, 3=PAL/6569
game_id		!byte 0,0,0,0

; include other assembly files
!source "utilities.asm"
!source "screenkernal.asm"
!source "streams.asm"
!source "disk.asm"
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

.initialize
!ifdef TESTSCREEN {
    jmp testscreen
}
	jsr deletable_init
	jsr prepare_static_high_memory
    jsr parse_object_table
!ifndef Z5PLUS {
    ; Setup default dictionary
    lda story_start + header_dictionary     ; 05
    ldx story_start + header_dictionary + 1 ; f3
	jsr parse_dictionary
}
	
	
	jsr streams_init
	jsr stack_init

	jsr init_screen_colours
	
	; start text output from bottom of the screen
	ldy #0
	ldx #24
	jsr set_cursor
	
	jsr z_init
	jsr z_execute

	; Back to normal memory banks
	+set_memory_normal

	jsr $fda3 ; init I/O
	;jsr $fd50 ; init memory
	jsr $fd15 ; set I/O vectors
	jsr $ff5b ; more init
    jmp ($a000)

; The following code, down to program_end, can be placed in the stack area instead, but is put here to make sure stack can be decreased to two pages.	
	
!ifdef VMEM {
prepare_static_high_memory
    lda #$ff
    sta zp_pc_h
    sta zp_pc_l

; Clear vmap_z_h
	ldy vmap_max_entries
	lda #0
-	sta vmap_z_h - 1,y
	dey
	bne -

; Clear quick index
	ldx #vmap_quick_index_length
-	sta vmap_next_quick_index,x ; Sets next quick index AND all entries in quick index to 0
	dex
	bpl -
	
	
	lda #5
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
	bcc +
	beq +
	ldx vmap_max_entries
+	stx zp_temp + 2  ; Number of bytes to copy
	iny
	lda (zp_temp),y
	sta zp_temp + 3 ; # of blocks already loaded

; Copy to vmap_z_h
-	iny
	lda (zp_temp),y
	sta vmap_z_h - 2,y
	dex
	bne -
	
	; ldy #vmap_max_length - 1
; -	lda vmap_z_h,y
	; and #%01000000 ; Check if non-swappable memory
	; bne .dont_set
	; sty vmap_first_swappable_index
	; dey
	; bpl -
; .dont_set
	
; Point to lowbyte array	
	ldy #0
	lda (zp_temp),y
	clc
	adc zp_temp
	adc #2
	sta zp_temp
	ldy vmap_max_entries
	dey
-	lda #0
	cpy zp_temp + 2
	bcs +
	lda (zp_temp),y
+	sta vmap_z_l,y
	dey
	bpl -
	
; Load all suggested pages which have not been pre-loaded
-	lda zp_temp + 3 ; First index which has not been loaded
	beq ++ ; First block was loaded with header
	cmp zp_temp + 2 ; Total # of indexes in the list
	bcs +
	; jsr dollar
	sta vmap_index
	tax
	jsr load_blocks_from_index
++	inc zp_temp + 3
	bne - ; Always branch
+
	ldx zp_temp + 2
	cpx vmap_max_entries
	bcc +
	dex
+	stx vmap_clock_index

!ifdef TRACE_VM {
    jsr print_vm_map
}
    rts
} else {
prepare_static_high_memory
    ; the default case is to simply treat all as dynamic (r/w)
    rts
}


	
program_end

	!align 255, 0, 0
z_trace_page
	!fill z_trace_size, 0

vmem_cache_start

!ifdef ALLRAM {

;	!align 255, 0, 0 ; 1 page (assuming code above is <= 256 bytes)
	!fill cache_pages * 256,0 ; typically 4 pages
!ifdef VMEM {
!if (stack_size + *) & 256 {
	!fill 256,0 ; Add one page to avoid vmem alignment issues
}
} 

vmem_cache_size = * - vmem_cache_start
vmem_cache_count = vmem_cache_size / 256
}
!align 255, 0, 0 ; To make sure stack is page-aligned even if not using vmem.

stack_start

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
	lda story_start + 1
	and #(255 - 16 - 32 - 64) ; Screen-splitting not available, variable-pitch font is not default
	sta story_start + 1
} else {
!ifdef Z4 {
	lda story_start + header_flags_1
	and #(255 - 4 - 8) ; bold font, italic font not available
	ora #(16 + 128) ; Fixed-space style, timed input available
	sta story_start + header_flags_1
} else { ; Z5PLUS
	lda story_start + header_flags_1
	and #(255 - 4 - 8) ; bold font, italic font not available
	ora #(1 + 16 + 128) ; Colours, Fixed-space style, timed input available
	sta story_start + header_flags_1
	lda story_start + $11
	and #(255 - 8 - 16 - 32 - 128) ; pictures, undo, mouse, sound effect not available
	sta story_start + $11
}
}
!ifdef Z4PLUS {
	lda #8
	sta story_start + $1e ; Interpreter number (8 = C64)
	lda #65
	sta story_start + $1f ; Interpreter number. Usually ASCII code for a capital letter (We use @ until the terp is ready for release)
	lda #25
	sta story_start + $20 ; Screen lines
	lda #40
	sta story_start + $21 ; Screen columns
}
!ifdef Z5PLUS {
	lda #>320
	sta story_start + $22 ; Screen width in units
	lda #<320
	sta story_start + $23 ; Screen width in units
	lda #>200
	sta story_start + $24 ; Screen height in units
	lda #<200
	sta story_start + $25 ; Screen height in units
	lda #8
	sta story_start + $26 ; Font width in units
	sta story_start + $27 ; Font height in units
	; TODO: Store default background and foreground colour in 2c, 2d (or comply to game's wish?)
}
	lda #0
	sta story_start + $32 ; major standard revision number which this terp complies to
	sta story_start + $33 ; minor standard revision number which this terp complies to
	
	; Copy alphabet pointer from header, or default
	ldx #<default_alphabet
	ldy #>default_alphabet
!ifdef Z5PLUS {
	lda story_start + header_alphabet_table
	ora story_start + header_alphabet_table + 1
	beq .no_custom_alphabet
	ldx story_start + header_alphabet_table + 1
	lda story_start + header_alphabet_table
	clc
	adc #>story_start
	tay
.no_custom_alphabet
}
	stx alphabet_table
	sty alphabet_table + 1
	
	; Copy z_pc from header
	lda #0
	ldx story_start + header_initial_pc
	ldy story_start + header_initial_pc + 1
!ifndef VMEM {
	sta z_pc
}
	jsr set_z_pc
	jsr get_page_at_z_pc

	; Setup globals pointer
	lda story_start + header_globals + 1
	clc
	adc #<(story_start - 32)
	sta z_low_global_vars_ptr
	sta z_high_global_vars_ptr
	lda story_start + header_globals
	adc #>(story_start - 32)
	sta z_low_global_vars_ptr + 1
	adc #1
	sta z_high_global_vars_ptr + 1 

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
!ifdef BENCHMARK {
	ldy #1
	jmp z_rnd_init
} else {
	jmp z_rnd_init_random
}
}

!zone deletable_init {
deletable_init
	cld
    ; ; check if PAL or NTSC (needed for read_line timer)
; w0  lda $d012
; w1  cmp $d012
    ; beq w1
    ; bmi w0
    ; and #$03
    ; sta c64_model
    ; enable lower case mode
!ifdef CUSTOM_FONT {
    lda #18
} else {
	lda #23
}
    sta reg_screen_char_mode
	lda #$80
	sta charset_switchable

	jsr init_screen_colours ; _invisible

; Read and parse config from boot disk
	; $BA holds last used device#
	ldy $ba
	cpy #8
	bcc .pick_default_boot_device
	cpy #12
	bcc .store_boot_device
.pick_default_boot_device
	ldy #8
.store_boot_device
	sty boot_device ; Boot device# stored
!ifdef VMEM {
	lda #<config_load_address
	sta readblocks_mempos
	lda #>config_load_address
	sta readblocks_mempos + 1
	lda #19
	ldx #0
; No need to load y with boot device#, already in place
	jsr read_track_sector
	inc readblocks_mempos + 1
	lda #19
	ldx #1
	ldy boot_device
	jsr read_track_sector
;    jsr kernal_readchar   ; read keyboard
; Copy game id
	ldx #0
-	lda config_load_address,x
	sta game_id,x
	inx
	cpx #4
	bcc -
; Copy disk info
	ldx config_load_address + 4
	dex
-	lda config_load_address + 4,x
	sta disk_info - 1,x
	dex
	bne -
	
	jsr auto_disk_config
;	jsr init_screen_colours
	jsr insert_disks_at_boot
} else { ; End of !ifdef VMEM
	sty disk_info + 4
	ldx #$30 ; First unavailable slot
	lda story_start + header_static_mem
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
    ; check z machine version
    lda story_start + header_version
!ifdef Z3 {
    cmp #3
}
!ifdef Z4 {
    cmp #4
}
!ifdef Z5 {
    cmp #5
}
!ifdef Z8 {
    cmp #8
}
	beq .supported_version
    lda #ERROR_UNSUPPORTED_STORY_VERSION
    jsr fatalerror
.supported_version

	; Check how many z-machine memory blocks (256 bytes each) are not stored in raw disk sectors
!ifdef VMEM {
	ldy story_start + header_static_mem
	lda story_start + header_static_mem + 1
	beq .maybe_inc_nonstored_blocks
	iny ; Add one page if statmem doesn't start on a new page ($xx00)
.maybe_inc_nonstored_blocks
	tya
    and #255 - vmem_blockmask ; keep index into kB chunk
	beq .store_nonstored_blocks
	iny
!ifndef SMALLBLOCK {
	bne .maybe_inc_nonstored_blocks ; Always branch
}
.store_nonstored_blocks
	sty nonstored_blocks
	tya
	clc
	adc #>story_start
	sta vmap_first_ram_page
	lda #0
	sec
	sbc vmap_first_ram_page
	lsr
!ifndef SMALLBLOCK {
	lsr
} else {
	; This space constraint can not be a problem with big (1KB) vmem blocks.
	cmp #vmap_max_size ; Maximum space available
	bcc ++
	lda #vmap_max_size
++	
}
	sta vmap_max_entries

} ; End of !ifdef VMEM

+   ; check file length
    ; Start by multiplying file length by 2
	lda #0
	sta filelength
    lda story_start + header_filelength
	sta filelength + 1
    lda story_start + header_filelength + 1
	asl
	rol filelength + 1
	rol filelength
!ifdef Z4PLUS {
    ; Multiply file length by 2 again (for Z4, Z5 and Z8)
	asl
	rol filelength + 1
	rol filelength
!ifdef Z8 {
    ; Multiply file length by 2 again (for Z8)
	asl
	rol filelength + 1
	rol filelength
}
}
	sta filelength + 2
	ldy filelength
	ldx filelength + 1
	beq +
	inx
	bne +
	iny
+	sty fileblocks
	stx fileblocks + 1
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
	bcc .dont_need_to_insert_this
	stx zp_temp
	sty zp_temp + 1
	ldy zp_temp
	jsr print_insert_disk_msg
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
	rts
}
} ; End if !ifdef VMEM

	!fill stack_size - (* - stack_start),0 ; 4 pages

story_start
!ifdef VMEM {
vmem_start

!ifdef ALLRAM {

!if $10000 - vmem_start > $cc00 {
	vmem_end = vmem_start + $cc00
} else {
	vmem_end = $10000
}

} else {
	vmem_end = $d000
}	

}

!ifdef vmem_cache_size {
!if vmem_cache_size >= $200 {
	config_load_address = vmem_cache_start
}
}
!ifndef config_load_address {
	config_load_address = $0400
}
