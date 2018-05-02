; virtual memory
;
; virtual memory address space
; Z1-Z3: 128 kB
; Z4-Z5: 256 kB
; Z6-Z8: 512 kB

; map structure: one entry for each 512B of available virtual memory
; ZMachine PC: ???????a bcdefghi jklmnopq, but since 512 bytes each
; can skip LSB, and pack like abcdefgh (jklmnopq)
; 
; each map entry is:
; 1 byte: C64 offset ($20 - $cf for $2000-$D000)
; 1 byte: ZMachine offset (abcdefgh, see above)
;
; need 44*2=88 bytes for $2000-$D000, or 56*2 = 112 bytes for $2000-$FFFF
; will store in datasette_buffer
;
; swapping: bubble up latest used frame, remove from end of mapping array

!ifdef USEVM {
.dynamic_memory_size !byte 0
load_dynamic_memory
    ; load header
    jsr load_header

!ifdef DEBUG {
    ldx story_start + header_static_mem
    jsr print_following_string
    !pet "dynamic ", 0
    jsr printx
    lda #$20
    jsr kernel_printchar
    ldx story_start + header_static_mem + 1
    jsr printx
    lda #13
    jsr kernel_printchar
}

    ; load dynamic memory
    lda #>story_start;
    clc
    adc #1 ; skip header
    ldx #$01
    ldy story_start + header_static_mem
    sty .dynamic_memory_size
    jsr readblocks

    ; mark header + dynamic memory as rw (not ok to swap)
    rts

prepare_static_high_memory
    ; initalize mapping entries for the remaining address space
!ifdef DEBUG {
    jsr print_following_string
    !pet "static+high start", 13, 0
}

    ; number of blocks to read
    lda fileblocks + 1 ; total number of blocks
    sec 
    sbc .dynamic_memory_size ; blocks already read
    tay
    dey ; skip last block in dynamic_memory


    lda #>story_start
    clc
    adc .dynamic_memory_size; blocks already read
    tax

    ldx .dynamic_memory_size; first block to read
    inx

    jsr readblocks

    ; mark static + high memory as ro (ok to swap)
    rts

read_word_at_z_address
    ; Subroutine: Read the contents of a byte address in the Z-machine
    ; a,x,y (high, mid, low) contains address.
    ; Returns: value in a
    cmp #0
    bne .too_high
    sty mempointer
    txa
    clc
    adc #>story_start
    sta mempointer + 1
    ldy #0
    lda (mempointer),y
    rts
.too_high
    jsr fatalerror
    !pet "tried to access z-machine memory over 64kb", 0

read_byte_at_z_address
    ; Subroutine: Read the contents of a two consequtive byte addresses in the Z-machine
    ; a,x,y (high, mid, low) contains first address.
    ; Returns: values in a,x  (first byte, second byte)
    cmp #0
    bne .too_high
    sty mempointer
    txa
    clc
    adc #>story_start
    sta mempointer + 1
    ldy #1
    lda (mempointer),y
    tax
    dey
    lda (mempointer),y
    rts
}
