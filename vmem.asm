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
; Example: DragonTroll.z5 (assuming $2000 - $2a00 used for vm to force swap)
;          vmap_max_length = 6
;  entry   zoffset   c64offset
;    0       $00        $20
;    1       $02        $22
;    2       $04        $24  <- static_mem_start = $05f1 
;    3       $06        $26  <- vmap_length = 3 (loaded dynamic mem only)
;    4       $08        $28
;    5       $0a        $2a
;            $0c             <- vmap_length = 6 (loaded all, max value)
;            $0e             <- end of zmachine memory $0e8c
; 
; first zbyte read: $63 ($2063)
; 
; swapping: bubble up latest used frame, remove from end of mapping array
;           (do not swap or move dynamic frames)

static_mem_start = datasette_buffer_start      ; $033c = 828
vmap_length  = datasette_buffer_start  + 1     ; $033d = 829
vmap_max_length  = datasette_buffer_start  + 2 ; $033e = 830
vmap_start = datasette_buffer_start  + 3       ; $033f = 831

!ifdef USEVM {
!ifdef DEBUG {
print_vm_map
    jsr print_following_string
    !pet "vmap static,length: ", 0
    ldx static_mem_start
    jsr printx
    lda #$20
    jsr kernel_printchar
    ldx vmap_length
    jsr printx
    lda #$0d
    jsr kernel_printchar

    lda #0
    sta zx1
    ldy #0
-   ldx zx1
    jsr printx
    lda #$20
    jsr kernel_printchar
    ldx vmap_start,y ; zmachine mem offset ($0 - 
    jsr printx
    lda #$20
    jsr kernel_printchar
    iny 
    ldx vmap_start,y ; c64 mem offset ($20 -, for $2000-)
    jsr printx
    lda #$0d
    jsr kernel_printchar
    iny 
    inc zx1
    lda zx1
    cmp vmap_max_length
    bne -
    rts
}

load_dynamic_memory
    ; load header
    jsr load_header

    ; load dynamic memory
    lda #>story_start;
    clc
    adc #1 ; skip header
    ldx #$01
    ldy story_start + header_static_mem
    sty static_mem_start
    jsr readblocks

    ; prepare initial map structure
    lda static_mem_start ; convert static start from block to index
    clc
    ror ; convert to compact 512 byte offset
    sta static_mem_start ; store index
    sta vmap_length      ; initially only dynamics are saved
    inc vmap_length      ; length is last_index + 1
    lda #0
    sta vmap_max_length
    tay
-   ; calculate c64 offset
    asl ; 512 bytes each
    sta vmap_start,y ; zmachine mem offset ($0 - 
    clc 
    adc #>story_start
    iny
    sta vmap_start,y ; c64 mem offset ($20 -, for $2000-)
    iny
    inc vmap_max_length
    lda vmap_max_length
    cmp #6 ; stop at $2c00, 6 entries
    bne -
!ifdef DEBUG {
    jsr print_vm_map
}
    rts

prepare_static_high_memory
    ; vmap is already set up
    ; blocks will be loaded as needed by read_byte_at_z_address
    rts

read_byte_at_z_address
    ; Subroutine: Read the contents of a byte address in the Z-machine
    ; a,x,y (high, mid, low) contains address.
    ; Returns: value in a
!ifdef DEBUG {
    pha
    txa
    pha
    tya
    pha
    jsr print_following_string
    !pet "zpc: ", 0
    ldx z_pc
    jsr printx
    lda #$20
    jsr kernel_printchar
    ldx z_pc + 1
    jsr printx
    lda #$20
    jsr kernel_printchar
    ldx z_pc + 2
    jsr printx
    lda #$0d
    jsr kernel_printchar
    pla
    tay
    pla
    tax
    pla
}

    ; is there a block with this address in map
    sty mempointer + 1
    ; convert to compact 512 byte address
    ror
    txa
    ror
    sta zx1
    ; check if such a block already exists
    ldy #0
    ldx #0
-   iny
    lda vmap_start,y ; zmachine mem offset ($0 - 
    cmp zx1
    beq +
    iny
    inx
    cpx vmap_length
    bne -

    ; this block is not loaded 
    ; add it last
    lda vmap_length
    clc 
    adc #>story_start
    sta vmap_start,y ; c64 mem offset ($20 -, for $2000-)
    iny
    lda vmap_length
    clc
    ror ; convert to compact 512 byte offset
    sta vmap_start,y ; zmachine mem offset ($0 - 
    inc vmap_length

+   ; loaded, get the value
    dey
    sta vmap_start,y ; c64 mem offset ($20 -, for $2000-)
    sta mempointer
    ldy #0
    lda (mempointer),y
    rts
    
read_word_at_z_address
    jmp read_byte_at_z_address
}
