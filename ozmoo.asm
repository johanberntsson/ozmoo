; Which Z-machine to generate binary for
; (usually defined on the acme command line instead)
; Z1, Z2, Z6 and Z7 will (probably) never be supported
;Z3 = 1
;Z4 = 1
;Z5 = 1
;Z8 = 1

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

stack_size = $0400;

!ifdef USEVM {
!ifdef ALLRAM {
	vmem_end = $10000
} else {
	vmem_end = $d000
}	
}


; basic program (10 SYS2061)
!source "basic-boot.asm"
    +start_at $080d
    jmp .initialize

; global variables
filelength !byte 0, 0, 0
fileblocks !byte 0, 0
c64_model !byte 0 ; 1=NTSC/6567R56A, 2=NTSC/6567R8, 3=PAL/6569
game_id		!byte 0,0,0,0

; include other assembly files
!source "utilities.asm"
!source "streams.asm"
!source "disk.asm"
!source "screen.asm"
!source "memory.asm"
!source "stack.asm"
!source "zmachine.asm"
!ifdef USEVM {
!source "vmem.asm"
}
!source "zaddress.asm"
!source "text.asm"
!source "dictionary.asm"
!source "objecttable.asm"

.initialize
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

    rts

!ifndef USEVM {
prepare_static_high_memory
    ; the default case is to simply treat all as dynamic (r/w)
    rts
}

program_end

	!align 255, 0, 0
z_trace_page
	!fill z_trace_size, 0

vmem_cache_start
!zone deletable_init {
deletable_init
	cld
    ; check if PAL or NTSC (needed for read_line timer)
w0  lda $d012
w1  cmp $d012
    beq w1
    bmi w0
    and #$03
    sta c64_model
    ; enable lower case mode
    lda #23
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
;    jsr kernel_readchar   ; read keyboard
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

	; Check how many vmem_blocks are not stored in raw disk sectors
!ifdef USEVM {
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
	bne .maybe_inc_nonstored_blocks ; Carry should always be clear
}
.store_nonstored_blocks
	sty nonstored_blocks
}
	
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

!zone disk_config {
auto_disk_config
; Figure out best device# for all disks set to auto device# (value = 0)
	lda #0
	tay ; Disk#
.next_disk
	tax ; Memory index
	lda disk_info + 3,x
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
	sta disk_info + 3,x
.device_selected
	sta zp_temp + 1 ; Store currently selected device#
	lda disk_info + 6,x
	beq +
	; This is a story disk
	txa ; Save value of x
	ldx zp_temp + 1 ; Load currently selected device#
	inc device_map - 8,x ; Mark device as in use by a story disk
	tax
+	iny
	cpy disk_info + 1 ; # of disks
	bcs .done
	txa
	adc disk_info + 2,x
	bne .next_disk ; Always branch
.done
	rts
}
!zone insert_disks_at_boot {
insert_disks_at_boot
;	jsr kernel_readchar
	jsr prepare_for_disk_msgs
	lda #0
	tay ; Disk#
.next_disk
	tax ; Memory index
	cpy #1
	bcc .dont_need_to_insert_this
	; Store in current_disks
	lda disk_info + 3,x
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
	cpy disk_info + 1 ; # of disks
	bcs .done
	txa
	adc disk_info + 2,x
	bne .next_disk ; Always branch
.done
	rts
}

!ifdef USEVM {
;	!align 255, 0, 0 ; 1 page (assuming code above is <= 256 bytes)
	!fill 1024 - (* - vmem_cache_start),0 ; 4 pages
	!align 256 * (255 - vmem_blockmask) + 255, 0, 0 ; 0-1 pages with SMALLBLOCK, 0-3 pages without
vmem_cache_size = * - vmem_cache_start
vmem_cache_count = vmem_cache_size / 256
}
!align 255, 0, 0 ; To make sure stack is page-aligned even if not using vmem.

stack_start
	!fill stack_size, 0

story_start
!ifdef USEVM {
vmem_start
}

config_load_address = stack_start + 512
