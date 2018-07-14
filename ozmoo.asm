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

; Define DEBUG for additional runtime printouts
; (usually defined on the acme command line instead)
;DEBUG = 1

!source "constants.asm"

; Trace information
z_trace_page 		  = 256 * ((>program_end) + 1)
!ifdef TRACE {
	z_trace_size = 256
} else {
	z_trace_size = 0
}

; where to store vmem_caches
vmem_cache_start = z_trace_page + z_trace_size ; stack_start + stack_size
vmem_cache_base_count = 4 ; Should be a multiple of 4. Higher values than 4 are not working properly (HH game breaks). Should probably be set to 4 later, when the interpreter is so big that vmem never needs to handle more than 102 blocks.
!ifdef USEVM {
!ifdef vmem_cache_start {
!ifndef vmem_cache_count {
!if (>vmem_cache_start) & (255 - vmem_blockmask) = 0 {
    vmem_cache_count = vmem_cache_base_count ; 4 caches
} else {
    vmem_cache_count = (vmem_cache_base_count + vmem_block_pagecount - ((>vmem_cache_start) & (255 - vmem_blockmask))) ; 5-7 caches
}
} else {
    vmem_cache_count = 0
}
vmem_cache_size = vmem_cache_count * 256 ; 4 caches, 256 bytes each

stack_start = vmem_cache_start + vmem_cache_size
stack_size = $0400;
story_start = stack_start + stack_size

vmem_start = story_start
!ifdef ALLRAM {
	vmem_end = $10000
} else {
	vmem_end = $d000
}
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

	jsr init_screen_colours

	; start text output from bottom of the screen
	ldy #0
	ldx #24
	jsr set_cursor
	
	; Default banks during execution: Like standard except Basic ROM is replaced by RAM.
	+set_memory_no_basic

!ifdef DYNMEM_ALREADY_LOADED {
	jsr parse_header
} else {
	jsr load_dynamic_memory
}
	jsr prepare_static_high_memory
    jsr parse_dictionary
    jsr parse_object_table

	jsr streams_init
	jsr stack_init
	jsr z_init
	jsr z_execute

	; Back to normal memory banks
	+set_memory_normal

    rts

load_header
    ; read the header
    lda #>story_start ; first free memory block
    ldx #$00    ; first block to read from floppy
    stx readblocks_currentblock
    stx readblocks_currentblock + 1
    sta readblocks_mempos + 1
    jsr readblock
    ;jmp parse_header

parse_header ; must follow load_header
    ; check z machine version
    lda story_start + header_version
!ifdef Z3 {
    cmp #3
    beq +
}
!ifdef Z4 {
    cmp #4
    beq +
}
!ifdef Z5 {
    cmp #5
    beq +
}
!ifdef Z8 {
    cmp #8
    beq +
}
    lda #ERROR_UNSUPPORTED_STORY_VERSION
    jsr fatalerror

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

!ifndef USEVM {
load_dynamic_memory
    ; the default case is to simply treat all as dynamic (r/w)
    jsr load_header
	; check that the file is not too big
	ldx fileblocks
	bne +
    ldx fileblocks + 1
    cpx #>($D000 - story_start) ; don't overwrite $d000
    bcc ++
+   lda #ERROR_OUT_OF_MEMORY
    jsr fatalerror

    ; read the rest
++  ldx #>story_start ; first free memory block
    inx        ; skip header
    txa
    ldx #$01           ; first block to read from floppy
    ldy fileblocks + 1 ; read the rest of the blocks
    dey ; skip the header
    stx readblocks_currentblock ; currentblock + 1 already 0 in load_header
    sty readblocks_numblocks
    sta readblocks_mempos + 1
    jmp readblocks

prepare_static_high_memory
    ; the default case is to simply treat all as dynamic (r/w)
    rts
}

program_end

