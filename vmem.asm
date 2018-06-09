; virtual memory
TRACE_VM = 1
;TRACE_VM_PC = 1
PRELOAD_UNTIL = header_static_mem ; dynmem only
;PRELOAD_UNTIL = header_dictionary ; dynmen + grammar tables
;PRELOAD_UNTIL = header_high_mem   ; dynmem + statmem

; virtual memory address space
; Z1-Z3: 128 kB (0 - $1ffff)
; Z4-Z5: 256 kB (0 - $3ffff)
; Z6-Z8: 512 kB (0 - $7ffff)
;
; map structure: one entry for each kB of available virtual memory
; each map entry is:
; 1 byte: ZMachine offset high byte (bitmask: $F0=used, $80=dynamic (rw))
; 1 byte: ZMachine offset low byte
; 1 byte: C64 offset ($30 - $cf for $3000-$D000)
;
; need 44*3=132 bytes for $3000-$D000
; will store in datasette_buffer
;
; Example: dejavu.z3
; abbrevations: $0042
; object_table: $0102
; globals: $0636
; static memory: $0a4a
; dictionary: $1071
; high memory: $1764
; initial PC: $1765
; filelength: $57e4 
;
; Using story_start
; dictionary.asm: ok
; objecttable.asm: ok, since object table in dynmem
; ozmoo.asm: ok
; screen.asm: ok, only z_ins_get_cursor to story in array/dynmem
; streams.asm: probably ok, stores in table/array in dynmem
; text.asm: probably ok, string_array, parse_array in dynmem
;           - should make read_next_byte more efficient
; vmem.asm: ok
; zmachine.asm: seems ok, only direct access for header + dynmem 
;
;  vmap_max_length = 5
;  initial vmap_length = 3
;  final   vmap_length = 5
;  entry   zoffset   c64offset
;    0     $00 $00     $30
;    1     $00 $04     $34
;    2     $00 $08     $38 <- static_mem_start = $0a4a, index 2
;    3     $00 $0b     $3b
;    4     $00 $10     $40
;          $00 $14     $44 <- pc $1765, index 5
;          $00 $18     $48
;          $00 $1b     $4b
;          $00 $20     $50
; ...
;          $00 $57         <- filelength $57e4
; 
; swapping: bubble up latest used frame, remove from end of mapping array
;           (do not swap or move dynamic frames)

vmap_max_length  = 27 ; $3000-$cc00
;vmap_max_length  = 5 ; tests
;vmap_max_length  = 44 ; $3000-$d000
vmap_z_h = datasette_buffer_start
vmap_z_l = vmap_z_h + vmap_max_length
vmap_c64 = vmap_z_l + vmap_max_length

!ifdef USEVM {

!ifdef DEBUG {
!ifdef TRACE_VM {
print_vm_map
    ldy #0
-   cpy #10
    bcs +
    jsr space ; alignment when <10
+   jsr printy
    jsr space
    lda vmap_z_h,y ; zmachine mem offset ($0 - 
    and #%11000000
    jsr print_byte_as_hex
    jsr space
    jsr dollar
    lda vmap_z_h,y ; zmachine mem offset ($0 - 
    and #%00111111
    jsr printa
    lda vmap_z_l,y ; zmachine mem offset ($0 - 
    jsr print_byte_as_hex
    lda #0 ; add 00
    jsr print_byte_as_hex
    jsr space
    lda vmap_c64,y ; c64 mem offset ($20 -, for $2000-)
    jsr print_byte_as_hex
    lda #$30
    jsr streams_print_output
    jsr streams_print_output
    jsr newline
    iny 
    cpy #vmap_max_length
    bne -
    rts
}
}

load_blocks_from_index
    ; x = index to load
    ; side effects: a,y,status destroyed
    txa
    pha
    ldy #4 ; number of blocks
    lda vmap_c64,x ; c64 mem offset ($20 -, for $2000-)
    pha
    lda vmap_z_l,x ; start block
    tax
    pla
    stx readblocks_currentblock
    sty readblocks_numblocks
    sta readblocks_mempos + 1
    jsr readblocks
!ifdef TRACE_VM {
    ;jsr print_vm_map
}
    pla
    tax
    rts

load_dynamic_memory
    ; load header
    jsr load_header
    ; load dynamic memory
    ; read in chunks of 4 blocks (1 kB)
    lda story_start + PRELOAD_UNTIL
    lsr    ; x/4
    lsr
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
    stx readblocks_currentblock
    sty readblocks_numblocks
    sta readblocks_mempos + 1
    jmp readblocks

prepare_static_high_memory
    ; prepare initial map structure with already loaded
    ; dynamic memory marked as rw (not swappable)
    ; missing blocks will later be loaded as needed
    ; by read_byte_at_z_address
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
    ; check if rw or ro (swappable)
    cmp story_start + PRELOAD_UNTIL
    bcs + ; a >= static_mem
    ; allocated 1kB entry
    sta vmap_z_l,y ; z offset ($00 -)
    lda #$c0 ; used, dynamic
    sta vmap_z_h,y 
    jmp ++
+   ; non-allocated 1kB entry
    lda #0
    sta vmap_z_h,y
    sta vmap_z_l,y
++  iny
    cpy #vmap_max_length
    bne -
!ifdef TRACE_VM {
    ;jsr print_vm_map
}
    rts

read_byte_at_z_address
    ; Subroutine: Read the contents of a byte address in the Z-machine
    ; a,x,y (high, mid, low) contains address.
    ; Returns: value in a
    sta zp_pc_h
    stx zp_pc_l
    sty mempointer ; low byte unchanged
!ifdef TRACE_VM_PC {
    lda zp_pc_l
    cmp #$10
    bcs +
    cmp #$08
    bcc +
    jsr print_following_string
    !pet "pc: ", 0
    lda zp_pc_h
    jsr print_byte_as_hex
    lda zp_pc_l
    jsr print_byte_as_hex
    lda mempointer
    jsr print_byte_as_hex
    jsr newline
+
}
    ; is there a block with this address in map?
    ldx #$ff ; this is the active block, if found
    ldy #0
-   ; is the block active?
    lda vmap_z_h,y
    and #$80
    beq +     ; next entry if used bit not set
    ; compare with low byte
    lda zp_pc_l
    and #$fc ; skip bit 0,1 since kB blocks
    cmp vmap_z_l,y ; zmachine mem offset ($0 - 
    bne + 
    ; is the high byte correct?
    lda vmap_z_h,y
    and #$7
    cmp zp_pc_h
    bne +
    ; vm index for this block found
    tya
    tax ; store block index in x
    jmp .index_found
+   iny
    cpy #vmap_max_length
    bne -
    ; no index found, add last
!ifdef TRACE_VM {
    ;jsr print_following_string
    ;!pet "notfound", 13, 0
}
    ldx #vmap_max_length
    dex
    lda zp_pc_h
    ora #$80 ; mark as used
    sta vmap_z_h,x
    lda zp_pc_l
    and #$fc ; skip bit 0,1 since kB blocks
    sta vmap_z_l,x
    jsr load_blocks_from_index
.index_found
    ; index x found. get return value
    lda zp_pc_l
    and #$03 ; keep index into kB chunk
    clc
    adc vmap_c64,x
    sta mempointer + 1
    ; update page rank
    cpx #$00  ; x is index of accesses Z_PC
    beq .return_result
!ifdef TRACE_VM {
    ;jsr printx
    ;jsr newline
}
    txa
    tay
    dey ; y = index before x
    ; check if map[y] is dynamic
    lda vmap_z_h,y
    and #$40
    bne .return_result
    ; not dynamic, let's bubble this index up (swap x and y)
    ; swap vmap entries at <x> and <y>
    lda vmap_z_h,y
    pha
    lda vmap_z_l,y
    pha
    lda vmap_c64,y
    pha
    lda vmap_z_h,x
    sta vmap_z_h,y
    lda vmap_z_l,x
    sta vmap_z_l,y
    lda vmap_c64,x
    sta vmap_c64,y
    pla
    sta vmap_c64,x
    pla
    sta vmap_z_l,x
    pla
    sta vmap_z_h,x
.return_result
!ifdef TRACE_VM {
    ;pha
    ;jsr print_vm_map
    ;pla
}
    ; return result
    ldy #0
    lda (mempointer),y
    rts
}

read_word_at_z_address
    ; Subroutine: Read the contents of a two consequtive byte addresses in the Z-machine
    ; a,x,y (high, mid, low) contains first address.
    ; Returns: values in a,x  (first byte, second byte)
    ;
    ; WARNING: only call this is you are sure that the bytes are
    ; in consequtive memory. This is not always true when using 
    ; virtual memory
    ; 
    jsr read_byte_at_z_address
    pha
    ldy #1
    lda (mempointer),y
    tax
    pla
    rts

