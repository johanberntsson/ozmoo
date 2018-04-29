; Define DEBUG for additional runtime printouts
DEBUG = 1

; where to store story data
mem_start = $2000

; story file header constants
header_version = $0
header_flags_1 = $1
header_high_mem = $4
header_initial_pc = $6
header_dictionary = $8
header_object_table = $a
header_globals = $c
header_static_mem = $e
header_flags_2 = $10
header_abbreviations = $18
header_filelength = $1a
header_checksum = $1c
header_interpreter_number = $1e
header_interpreter_version = $1f
header_screen_height_lines = $20
header_screen_width_chars = $21
header_screen_width_units = $22
header_screen_height_units = $24
header_font_width_units = $26
header_font_height_units = $27
header_default_bg_color = $2c
header_default_fg_color = $2d
header_terminating_chars_table = $2e
header_standard_revision_number = $32
header_alphabet_table = $34
header_header_extension_table = $36

; basic program (10 SYS2061)
!source "basic-boot.asm"
    +start_at $080d
    jmp .initialize

; global variables
err !byte 0
temp !byte 0, 0, 0, 0
; include other assembly files
!source "disk.asm"
!source "screen.asm"
!source "memory.asm"

.initialize
    ; read the header
    lda #>mem_start ; first free memory block
    ldx #$00    ; first block to read from floppy
    ldy #$01    ; read 1 block
    jsr readblocks

    ; check file length (need to be multiplied by constant (4 for v5))
	lda #0
	sta temp
    lda mem_start + header_filelength
	sta temp + 1
    lda mem_start + header_filelength + 2
	asl
	sta temp + 2
	rol temp + 1
	rol temp
	asl temp + 2
	rol temp + 1
	rol temp
	lda temp + 1
	sta err

!ifdef DEBUG {
    ; show how many blocks to read (exluding header)
    jsr printstring
    !pet "total blocks: ",0
    ldx err
    jsr printx
}
    ; read the rest
    ldx #>mem_start ; first free memory block
    inx        ; skip header
    txa
    ldx #$01    ; first block to read from floppy
    ldy err    ; read <header_filelength> blocks
    jsr readblocks
    rts
