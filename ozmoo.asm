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

; where to store stack
stack_start = $2c00
stack_size = $0400;

; where to store story data
story_start = stack_start + stack_size

; basic program (10 SYS2061)
!source "basic-boot.asm"
    +start_at $080d
    jmp .initialize

; global variables
filelength !byte 0, 0, 0
fileblocks !byte 0, 0

; include other assembly files
!source "streams.asm"
!source "disk.asm"
!source "screen.asm"
!source "memory.asm"
!source "stack.asm"
!source "utilities.asm"
!source "zmachine.asm"
!ifdef USEVM {
!source "vmem.asm"
}
!source "text.asm"
!source "dictionary.asm"
!source "objecttable.asm"

.initialize
    ; enable lower case mode
    lda #23
    sta reg_screen_char_mode

	; Default banks during execution: Like standard except Basic ROM is replaced by RAM.
	ldx #%00110110
	stx zero_processorports


	jsr load_dynamic_memory
	jsr prepare_static_high_memory
    jsr parse_dictionary
    jsr parse_object_table

	jsr streams_init
	jsr stack_init
	jsr z_init
	jsr z_execute

!ifdef DEBUG {
    ;jsr test_object_table
	;jsr testtext
}


	; Back to normal memory banks
	ldx #%00110111
	stx zero_processorports

    rts

load_header
    ; read the header
    lda #>story_start ; first free memory block
    ldx #$00    ; first block to read from floppy
    ldy #$01    ; read 1 block
    stx readblocks_currentblock
    sty readblocks_numblocks
    sta readblocks_mempos + 1
    jsr readblocks

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
    stx readblocks_currentblock
    sty readblocks_numblocks
    sta readblocks_mempos + 1
    jmp readblocks

prepare_static_high_memory
    ; the default case is to simply treat all as dynamic (r/w)
    rts
}
