!ifdef USEVM {
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

vmap_max_length  = (vmem_end-vmem_start)/1024
vmap_z_h = datasette_buffer_start
vmap_z_l = vmap_z_h + vmap_max_length
vmap_c64 = vmap_z_l + vmap_max_length

vmap_index !byte 0        ; current vmap index matching the z pointer
vmem_buffer_index !byte 0 ; buffer currently contains this vmap index


!ifdef DEBUG {
!ifdef TRACE_VM {
print_vm_map
!zone {
    ; print buffer
    jsr space
    lda #66
    jsr streams_print_output
    jsr space
    jsr dollar
    lda vmem_buffer_index
    jsr print_byte_as_hex
    lda #$30
    jsr streams_print_output
    lda #$30
    jsr streams_print_output
    jsr newline
    ldy #0
-   ; don't print empty entries
    lda vmap_z_h,y ; zmachine mem offset ($0 - 
    and #$f0
    beq .next_entry
    ; not empty, print
    cpy #10
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
    lda #$30
    jsr streams_print_output
    jsr newline
.next_entry
    iny 
    cpy #vmap_max_length
    bne -
    rts
}
}
}

load_blocks_from_index
    ; x = index to load
    ; side effects: a,y,status destroyed
    ldx vmap_index
    ; initialise block copy function (see below)
    lda #>vmem_buffer_start ; start of buffer
    sta .copy_to_vmem + 2
    lda vmap_c64,x ; start block
    sta .copy_to_vmem + 5
    sta vmem_buffer_index
    ; read 4 blocks into vmem_buffer
    lda #4
    sta readblocks_numblocks
    lda #>vmem_buffer_start ; start of buffer
    sta readblocks_mempos + 1
    lda vmap_z_l,x ; start block
    sta readblocks_currentblock
    jsr readblocks
    ; copy vmem_buffer to block (banking as needed)
    sei
    +set_memory_all_ram
    ldx #4
-   ldy #0
.copy_to_vmem
    lda $8000,y
    sta $8000,y
    iny
    bne .copy_to_vmem
    inc .copy_to_vmem + 2
    inc .copy_to_vmem + 5
    dex
    bne -
    +set_memory_no_basic
    cli
!ifdef TRACE_VM {
    ;jsr print_following_string
    ;!pet "load_blocks_from_index: ",0
    ;jsr print_vm_map
}
    ldx vmap_index
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
    lda #$00
    sta vmem_buffer_index
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
    sty vmap_index
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
    stx vmap_index
    jsr load_blocks_from_index
.index_found
    ; index x found
    ldx vmap_index
    ; check if swappable memory
    lda vmap_z_h,x
    and #$40
    bne .unswappable
    ; this is swappable memory
    ; update vmem_buffer if needed
    lda vmap_c64,x
    cmp vmem_buffer_index
    beq .buffer_updated
    ; copy vmem to vmem_buffer (banking as needed)
    lda vmap_c64,x ; start block
    sta .copy_to_vmem_to_buffer + 2
    sta vmem_buffer_index
    lda #>vmem_buffer_start ; start of buffer
    sta .copy_to_vmem_to_buffer + 5
    sei
    +set_memory_all_ram
    ldx #4
-   ldy #0
.copy_to_vmem_to_buffer
    lda $8000,y
    sta $8000,y
    iny
    bne .copy_to_vmem_to_buffer
    inc .copy_to_vmem_to_buffer + 2
    inc .copy_to_vmem_to_buffer + 5
    dex
    bne -
    +set_memory_no_basic
    cli
.buffer_updated
    lda zp_pc_l
    and #$03 ; keep index into kB chunk
    clc
    adc #>vmem_buffer_start
    sta mempointer + 1
    ldx vmap_index
    bne .update_page_rank ; always true
.unswappable
    ; update memory pointer
    lda zp_pc_l
    and #$03 ; keep index into kB chunk
    clc
    adc vmap_c64,x
    sta mempointer + 1
.update_page_rank
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

