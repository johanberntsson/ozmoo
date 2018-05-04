; Which Z-machine to generate binary for
; (usually defined on the acme command line instead)
;Z3 = 1
;Z5 = 1

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
stack_start = $1c00
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
!source "disk.asm"
!source "screen.asm"
!source "memory.asm"
!source "stack.asm"
!source "utilities.asm"
!source "zmachine.asm"
!ifdef USEVM {
!source "vmem.asm"
}

.initialize
	; Default banks during execution: Like standard except Basic ROM is replaced by RAM.
	ldx #%00110110
	stx zero_processorports

	jsr load_dynamic_memory
	jsr prepare_static_high_memory

	jsr stack_init
	jsr z_init
	jsr z_execute

	; Back to normal memory banks
	ldx #%00110111
	stx zero_processorports

    rts

load_header
    ; read the header
    lda #>story_start ; first free memory block
    ldx #$00    ; first block to read from floppy
    ldy #$01    ; read 1 block
    jsr readblocks

    ; check z machine version
    lda story_start + header_version
!ifdef Z3 {
    cmp #3
    beq +
}
!ifdef Z5 {
    cmp #5
    beq +
}
    jsr fatalerror
    !pet "unsupported story version", 0

+   ; check file length
!ifdef Z3 {
    ; file length should be multiplied by 2 (for Z3)
	lda #0
	sta filelength
    lda story_start + header_filelength
	sta filelength + 1
    lda story_start + header_filelength + 1
	asl
	sta filelength + 2
	rol filelength + 1
	rol filelength
}
!ifdef Z5 {
    ; file length should be multiplied by 4 (for Z5)
	lda #0
	sta filelength
    lda story_start + header_filelength
	sta filelength + 1
    lda story_start + header_filelength + 1
	asl
	sta filelength + 2
	rol filelength + 1
	rol filelength
	asl filelength + 2
	rol filelength + 1
	rol filelength
}
	ldy filelength
	ldx filelength + 1
	lda filelength + 2
	beq +
	inx
	bne +
	iny
+	sty fileblocks
	stx fileblocks + 1

!ifdef DEBUG {
    ; show how many blocks to read (exluding header)
    ;jsr print_following_string
    ;!pet "total blocks: ",0
    ;ldx fileblocks + 1
    ;jsr printx
    ;lda #$0d
    ;jsr kernel_printchar
}
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
+   jsr fatalerror
    !pet "Out of memory", 0

    ; read the rest
++  ldx #>story_start ; first free memory block
    inx        ; skip header
    txa
    ldx #$01           ; first block to read from floppy
    ldy fileblocks + 1 ; read the rest of the blocks
    dey ; skip the header
    jmp readblocks

prepare_static_high_memory
    ; the default case is to simply treat all as dynamic (r/w)
    rts
}
