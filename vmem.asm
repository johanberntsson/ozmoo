; virtual memory
;
; virtual memory address space
; Z1-Z3: 128 kB
; Z4-Z5: 256 kB
; Z6-Z8: 512 kB (0 - $7ffff)

; map structure: one entry for each kB of available virtual memory
; ZMachine PC: ??????ab cdefghij klmnopqr, but since 1 kB each
; can skip LSB, and pack like abcdefgh (klmnopqr)
; 
; each map entry is:
; 1 byte: C64 offset ($20 - $cf for $2000-$D000)
; 1 byte: ZMachine offset (abcdefgh, see above)
;
; need 44*2=88 bytes for $2000-$D000, or 56*2 = 112 bytes for $2000-$FFFF
; will store in datasette_buffer
;
; Example: dejavu.z3
; initial PC: $1765
; high memory base: $1764
; static memory base: $0a4a
; filelength: $57e4 -> 

;  vmap_max_length = 5
;  initial vmap_length = 3
;  final   vmap_length = 5
;  entry   zoffset   c64offset
;    0      $00 00     $20
;    1      $00 04     $24
;    2      $00 08     $28 <- static_mem_start = $0a4a, index 2
;    3      $00 0b     $2b
;    4      $00 10     $30
;           $00 14     $34 <- pc $1765, index 5
;           $00 18     $38
;           $00 1b     $3b
;           $00 20     $40
; ...
;           $00 57         <- filelength $57e4
; 
; swapping: bubble up latest used frame, remove from end of mapping array
;           (do not swap or move dynamic frames)

vmap_max_length  = 5
vmap_z_h = datasette_buffer_start        ; $033c = 828 (828-832)
vmap_z_l = vmap_z_h + vmap_max_length    ; $0341 = 833 (823-837)
vmap_c64 = vmap_z_l + vmap_max_length    ; $0346 = 838 (838-842)

!ifdef USEVM {
!ifdef DEBUG {
print_vm_map
    jsr print_following_string
    !pet "vmap", 13, 0
    ;ldx static_mem_start
    ;jsr printx
    ;lda #$20
    ;jsr kernel_printchar
    ;ldx vmap_length
    ;jsr printx
    ;lda #$0d
    ;jsr kernel_printchar

    ldy #0
-   tya
    tax
    jsr printx
    lda #$20
    jsr kernel_printchar
    ldx vmap_z_h,y ; zmachine mem offset ($0 - 
    jsr printx
    lda #$20
    jsr kernel_printchar
    ldx vmap_z_l,y ; zmachine mem offset ($0 - 
    jsr printx
    lda #$20
    jsr kernel_printchar
    ldx vmap_c64,y ; c64 mem offset ($20 -, for $2000-)
    jsr printx
    lda #$0d
    jsr kernel_printchar
    iny 
    cpy #vmap_max_length
    bne -
    rts
}

load_dynamic_memory
    ; load header
    jsr load_header

    ; load dynamic memory
    ; read in chunks of 4 blocks (1 kB)
    lda story_start + header_static_mem
    ror    ; x/4
    ror
    clc
    adc #1 ; x/4 + 1
    asl
    asl    ; (x/4 + 1) * 4
    tay
    dey    ; skip header
    ; read blocks
    lda #>story_start;
    clc
    adc #1 ; skip header
    ldx #$01
    jmp readblocks

prepare_static_high_memory
    ; vmap is already set up
    ; blocks will be loaded as needed by read_byte_at_z_address
    ; prepare initial map structure
    ldy #0
-   tya ; calculate c64 offset
    asl
    asl ; 1kB bytes each
    ; store c64 index
    pha
    clc 
    adc #>story_start
    sta vmap_c64,y ; c64 mem offset ($20 -, for $2000-)
    pla
    ; check if rw or ro (swap-able)
    cmp story_start + header_static_mem
    bcs + ; a >= static_mem
    ; allocated 1kB entry
    sta vmap_z_l,y ; z offset ($00 -)
    lda #$c0 ; used, read-only
    sta vmap_z_h,y 
    jmp ++
+   ; non-allocated 1kB entry
    lda #0
    sta vmap_z_h,y
    sta vmap_z_l,y
++  iny
    cpy #vmap_max_length
    bne -
!ifdef DEBUG {
    jsr print_vm_map
}
    rts

read_byte_at_z_address
    ; Subroutine: Read the contents of a byte address in the Z-machine
    ; a,x,y (high, mid, low) contains address.
    ; Returns: value in a
    rts
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
    sty mempointer + 1 ; low byte unchanged
    ; convert high byte to compact 512 byte address
    ror
    txa
    ror
    sta zx1

!ifdef DEBUG {
    jsr print_following_string
    !pet "compact: ", 0
    ldx zx1
    jsr printx
    lda #$0d
    jsr kernel_printchar
}

    ; check if such a block already exists
    ldy #0
    ldx #0
-   iny
    lda vmap_z_l,y ; zmachine mem offset ($0 - 
    cmp zx1
    beq +
    iny
    inx
    ;cpx vmap_length
    bne -

    ; this block is not loaded 
    ; add it last
    ;lda vmap_length
    clc 
    adc #>story_start
    sta vmap_c64,y ; c64 mem offset ($20 -, for $2000-)
    iny
    ;lda vmap_length
    clc
    ror ; convert to compact 512 byte offset
    sta vmap_z_l,y ; zmachine mem offset ($0 - 
    ;inc vmap_length

+   ; loaded, get the value
    dey
    sta vmap_c64,y ; c64 mem offset ($20 -, for $2000-)
    sta mempointer
    ldy #0
    lda (mempointer),y
    rts
    
read_word_at_z_address
    jmp read_byte_at_z_address
}
