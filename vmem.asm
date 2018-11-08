!ifdef USEVM {
; virtual memory

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

!ifdef SMALLBLOCK {
	vmem_blocksize = 512
} else {
	vmem_blocksize = 1024
}

vmem_blockmask = 255 - (>(vmem_blocksize - 1))
vmem_block_pagecount = vmem_blocksize / 256
vmap_max_length  = (vmem_end-vmem_start) / vmem_blocksize
vmap_z_h = datasette_buffer_start
vmap_z_l = vmap_z_h + vmap_max_length

!ifndef VMEM_CLOCK {
!ifdef SMALLBLOCK {
vmap_c64 !fill 100 ; Arrghh... This hardcoded value is not nice.
} else {
vmap_c64 = vmap_z_l + vmap_max_length
}
} else {
vmap_clock_index !byte 0        ; index where we will attempt to load a block next time
}

vmap_c64_offset !byte 0
vmap_index !byte 0              ; current vmap index matching the z pointer
vmap_first_swappable_index !byte 0 ; first vmap index which can be used for swapping in static/high memory
vmem_1kb_offset !byte 0         ; 256 byte offset in 1kb block (0-3)
vmem_cache_cnt !byte 0         ; current execution cache
vmem_cache_index !byte 0,0,0,0,0,0,0
;	!fill vmem_cache_count ; cache currently contains this vmap index
vmem_all_blocks_occupied !byte 0
; vmem_temp !byte 0

!ifdef DEBUG {
!ifdef PREOPT {
print_optimized_vm_map
	; x = 0 : Algorithm = queue
	; x = 1 : Algorithm = clock
	txa
	pha
	jsr printchar_flush
	pla
	tax
	lda #0
	sta streams_output_selected + 2
	sta is_buffered_window
	jsr newline
	jsr dollar
	jsr dollar
	jsr dollar
	cpx #0
	bne +
	jsr print_following_string
	!pet "queue",13,0
	jmp ++
+	jsr print_following_string
	!pet "clock",13,0
++	ldx #0
-	lda vmap_z_h,x
	beq +++
	jsr print_byte_as_hex
	lda vmap_z_l,x
	jsr print_byte_as_hex
	jsr colon
	inx
	cpx #vmap_max_length
	bcc -

	; Print block that was just to be read
-	lda zp_pc_h
	ora #$80 ; Mark as used
	jsr print_byte_as_hex
	lda zp_pc_l
	and #vmem_blockmask
	jsr print_byte_as_hex
	jsr colon
	
+++	jsr newline
	jsr dollar
	jsr dollar
	jsr dollar
	jsr newline
    jsr kernel_readchar   ; read keyboard
    jmp kernel_reset      ; reset
}

!ifdef TRACE_VM {
print_vm_map
!zone {
    ; print caches
    jsr space
    lda #66
    jsr streams_print_output
    jsr space
    lda vmem_cache_cnt
    jsr printa
    jsr space
    jsr dollar
    lda vmem_cache_index
    jsr print_byte_as_hex
    jsr space
    jsr dollar
    lda vmem_cache_index + 1
    jsr print_byte_as_hex
    jsr space
    jsr dollar
    lda vmem_cache_index + 2
    jsr print_byte_as_hex
    jsr space
    jsr dollar
    lda vmem_cache_index + 3
    jsr print_byte_as_hex
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
    and #%11100000
    jsr print_byte_as_hex
    jsr space
    jsr dollar
    lda vmap_z_h,y ; zmachine mem offset ($0 - 
    and #%00011111
    jsr printa
    lda vmap_z_l,y ; zmachine mem offset ($0 - 
    jsr print_byte_as_hex
    lda #0 ; add 00
    jsr print_byte_as_hex
    jsr space
!ifdef VMEM_CLOCK {
	tya
	asl
!ifndef SMALLBLOCK {
	asl
}
	adc #>story_start
} else {
    lda vmap_c64,y ; c64 mem offset ($20 -, for $2000-)
}
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
    ; vmap_index = index to load
    ; side effects: a,y,x,status destroyed
!ifdef TRACE_FLOPPY {
	jsr dollar
	jsr dollar
	lda vmap_index
	jsr print_byte_as_hex
	jsr comma
	tax
	lda vmap_z_h,x
	jsr print_byte_as_hex
	lda vmap_z_l,x
	jsr print_byte_as_hex
}

	
!ifdef VMEM_CLOCK {
	lda vmap_index
	asl
!ifndef SMALLBLOCK {
	asl
}
	; Carry is already clear
	adc #>story_start
} else {
    ldx vmap_index
    lda vmap_c64,x ; c64 mem offset ($20 -, for $2000-)
}
!ifdef TRACE_FLOPPY {
	jsr comma
	jsr print_byte_as_hex
}
	tay ; Store in y so we can use it later.
;	cmp #$e0
;	bcs +
    cmp #first_banked_memory_page
    bcs load_blocks_from_index_using_cache
+	lda #vmem_block_pagecount ; number of blocks
	sta readblocks_numblocks
	sty readblocks_mempos + 1
	lda vmap_z_l,x ; start block
	sta readblocks_currentblock
	lda vmap_z_h,x ; start block
	and #$07
	sta readblocks_currentblock + 1
	jsr readblocks
!ifdef TRACE_VM {
    jsr print_following_string
    !pet "load_blocks (normal) ",0
    jsr print_vm_map
}
    rts

load_blocks_from_index_using_cache
    ; vmap_index = index to load
    ; vmem_cache_cnt = which 256 byte cache use as transfer buffer
	; y = first c64 memory page where it should be loaded
    ; side effects: a,y,x,status destroyed
    ; initialise block copy function (see below)

	; Protect buffer which z_pc points to
	lda vmem_cache_cnt
	tax
	clc
	adc #>vmem_cache_start
	cmp z_pc_mempointer + 1
	bne +
	inx
	cpx #vmem_cache_count
	bcc ++
	ldx #0
++	stx vmem_cache_cnt
+
    ldx vmap_index
    lda #>vmem_cache_start ; start of cache
    clc
    adc vmem_cache_cnt
    sta .copy_to_vmem + 2
    sty .copy_to_vmem + 5
    ldx #0 ; Start with page 0 in this 1KB-block
    ; read next into vmem_cache
-   lda #>vmem_cache_start ; start of cache
    clc
    adc vmem_cache_cnt
    sta readblocks_mempos + 1
    txa
    pha
    ldx vmap_index
    ora vmap_z_l,x ; start block
    sta readblocks_currentblock
    lda vmap_z_h,x ; start block
    and #$07
    sta readblocks_currentblock + 1
    jsr readblock
    ; copy vmem_cache to block (banking as needed)
    sei
    +set_memory_all_ram
    ldy #0
.copy_to_vmem
    lda $8000,y
    sta $8000,y
    iny
    bne .copy_to_vmem
;    inc .copy_to_vmem + 2
    inc .copy_to_vmem + 5
    +set_memory_no_basic
    cli
    pla
    tax
    inx
	cpx #vmem_block_pagecount ; read 4 blocks (1 kb) in total
    bcc -

	ldx .copy_to_vmem + 5
	dex
	txa
	ldx vmem_cache_cnt
    sta vmem_cache_index,x
    rts

prepare_static_high_memory
    lda #$ff
    sta zp_pc_h
    sta zp_pc_l

; ############################################################### New section Start
	
; Clear vmap_z_h
	ldy #vmap_max_length - 1
	lda #0
-	sta vmap_z_h,y
	dey
	bpl -

	lda #5
	clc
	adc config_load_address + 4
	sta zp_temp
	lda #>config_load_address
;	adc #0 ; Not needed if disk info is always <= 249 bytes
	sta zp_temp + 1
	ldy #1
	lda (zp_temp),y
	sta zp_temp + 3 ; # of blocks already loaded
	dey
	lda (zp_temp),y ; # of blocks in the list
	tax
	cpx #vmap_max_length + 1
	bcc +
	ldx #vmap_max_length
+	stx zp_temp + 2  ; Number of bytes to copy
; Copy to vmap_z_h
	iny
-	iny
	lda (zp_temp),y
	sta vmap_z_h - 2,y

!ifdef VMEM_CLOCK {
	and #%01000000 ; Check if non-swappable memory
	bne .dont_set_vmap_swappable
	lda vmap_first_swappable_index
	bne .dont_set_vmap_swappable
	dey
	dey
	sty vmap_first_swappable_index
;	sty vmap_clock_index
	iny
	iny
.dont_set_vmap_swappable
}	

	dex
	bne -
; Point to lowbyte array	
	ldy #0
	lda (zp_temp),y
	clc
	adc zp_temp
	adc #2
	sta zp_temp
	ldy #vmap_max_length - 1
-	lda #0
	cpy zp_temp + 2
	bcs +
	lda (zp_temp),y
+	sta vmap_z_l,y
	dey
	bpl -
	
!ifndef VMEM_CLOCK {
	iny
	lda #story_start
-	sta vmap_c64_offset,y
	clc
	adc #vmem_block_pagecount
	iny
	cpy zp_temp + 2
	bcc -
}

; Load all suggested pages which have not been pre-loaded
-	lda zp_temp + 3 ; First index which has not been loaded
	beq ++ ; First block was loaded with header
	cmp zp_temp + 2 ; Total # of indexes in the list
	bcs +
	; jsr dollar
	sta vmap_index
	tax
	jsr load_blocks_from_index
++	inc zp_temp + 3
	bne - ; Always branch
+
!ifdef VMEM_CLOCK {
	ldx zp_temp + 2
	cpx #vmap_max_length
	bcc +
	dex
+	stx vmap_clock_index
}

; ################################################################# New Section End	
	
!ifdef TRACE_VM {
    jsr print_vm_map
}
    rts
.zp_maxmem !byte 0

read_byte_at_z_address
    ; Subroutine: Read the contents of a byte address in the Z-machine
    ; a,x,y (high, mid, low) contains address.
    ; Returns: value in a
    sty mempointer ; low byte unchanged
    ; same page as before?
    cmp zp_pc_h
    bne .read_new_byte
    cpx zp_pc_l
    bne .read_new_byte
    ; same 256 byte segment, just return
    ldy #0
    lda (mempointer),y
    rts
.read_new_byte
    sta zp_pc_h
	ora #$80
	sta vmem_temp + 1
    txa
    sta zp_pc_l
    and #255 - vmem_blockmask ; keep index into kB chunk
    sta vmem_1kb_offset
	txa
	and #vmem_blockmask
	sta vmem_temp
!ifdef TRACE_VM_PC {
	pha
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
	pla
}
    ; is there a block with this address in map?
    ldx #vmap_max_length - 1
-   ; compare with low byte
    cmp vmap_z_l,x ; zmachine mem offset ($0 - 
    beq +
.check_next_block
	dex
    bpl -
	bmi .no_such_block
	; is the block active and the highbyte correct?
+   lda vmap_z_h,x
    and #$87
	cmp vmem_temp + 1
	beq +
    lda vmem_temp
    jmp .check_next_block ; next entry if used bit not set
+
    ; vm index for this block found
    stx vmap_index
!ifdef VMEM_CLOCK {
	lda vmap_z_h,x
	ora #%00100000 		; Set referenced flag
    sta vmap_z_h,x
;	txa
;	ldx next_quick_index
}
    jmp .index_found

; no index found, add last
.no_such_block

	; Load 1 KB block into RAM
!ifdef VMEM_CLOCK {
	ldx vmap_clock_index
-	lda vmap_z_h,x
	bpl .block_chosen
!ifdef DEBUG {
!ifdef PREOPT {
	ldx #1
	jmp print_optimized_vm_map
}	
}
	tay
	and #$20
	beq .block_maybe_chosen
	tya
	and #%11011111 ; Turn off referenced flag
	sta vmap_z_h,x
--	inx
	cpx #vmap_max_length
	bcc -
	ldx vmap_first_swappable_index
	bne - ; Always branch
.block_maybe_chosen
	; Protect block where z_pc currently points
	tya
	and #%111
	cmp z_pc
	bne .block_chosen
	lda z_pc + 1
	and #vmem_blockmask
	cmp vmap_z_l,x
	beq -- ; This block is protected, keep looking
.block_chosen
	txa
	tay
	asl
!ifndef SMALLBLOCK {
	asl
}
	; Carry is already clear
	adc #>story_start
	sta vmap_c64_offset
	; Pick next index to use
	iny
	cpy #vmap_max_length
	bcc .not_max_index
	ldy vmap_first_swappable_index
.not_max_index
	sty vmap_clock_index
} else {
	lda vmem_all_blocks_occupied
	bne .replace_block
    ldx #vmap_max_length - 1
-	lda vmap_z_h,x
	bpl .block_chosen
	and #$40
	bne .last_block_used ; We have scanned down to dynmem. Give up.
	dex 
	bne - ; Always branch
.last_block_used
!ifdef DEBUG {
!ifdef PREOPT {
	ldx #0
	jmp print_optimized_vm_map
}	
}
	inc vmem_all_blocks_occupied
.replace_block
    ldx #vmap_max_length - 1
	; Protect block where z_pc currently points
	lda vmap_z_h + vmap_max_length - 1
	and #%111
	cmp z_pc
	bne .block_chosen
	lda z_pc + 1
	and #vmem_blockmask
	cmp vmap_z_l,x
	bne .block_chosen
	dex
.block_chosen
	lda vmap_c64,x
	sta vmap_c64_offset
}

	; We have now decided on a map position where we will store the requested block. Position is held in x.
!ifdef DEBUG {
!ifdef PRINT_SWAPS {
	lda streams_output_selected + 2
	beq +
	lda #20
	jsr $ffd2
	lda #64
	jsr $ffd2
	lda #20
	jsr $ffd2
	jmp ++
+	jsr space
	jsr dollar
	txa
	jsr print_byte_as_hex
	jsr colon
	lda vmap_c64_offset
	jsr dollar
	jsr print_byte_as_hex
	jsr colon
    lda vmap_z_h,x
	bpl .printswaps_part_2
	and #$7
	jsr dollar
	jsr print_byte_as_hex
    lda vmap_z_l,x
	jsr print_byte_as_hex
.printswaps_part_2
	jsr arrow
	jsr dollar
	lda zp_pc_h
	jsr print_byte_as_hex
    lda zp_pc_l
	and #vmem_blockmask
	jsr print_byte_as_hex
	jsr space
++	
}
}
	
	; Forget any cache pages belonging to the old block at this position. 
	ldy #vmem_cache_count - 1
-	lda vmem_cache_index,y
	and #vmem_blockmask
	cmp vmap_c64_offset
	bne +
	lda #0
	sta vmem_cache_index,y
+	dey
	bpl -

	; Store address of 1 KB block to load, then load it
	lda zp_pc_h
    ora #%10000000 ; mark as used
    sta vmap_z_h,x
    lda zp_pc_l
    and #vmem_blockmask ; skip bit 0,1 since kB blocks
    sta vmap_z_l,x
    stx vmap_index
    jsr load_blocks_from_index
.index_found
    ; index x found
!ifdef VMEM_CLOCK {
    lda vmap_index
	tax
	asl
!ifndef SMALLBLOCK {
	asl
}
	; Carry is already clear
	adc #>story_start
} else {
    ldx vmap_index
    ; check if swappable memory
    lda vmap_c64,x
}
	sta vmap_c64_offset
	cmp #first_banked_memory_page
    bcc .unswappable
    ; this is swappable memory
    ; update vmem_cache if needed
    clc
    adc vmem_1kb_offset
	; Check if this page is in cache
    ldx #vmem_cache_count - 1
-   cmp vmem_cache_index,x
    beq .cache_updated
    dex
    bpl -
	; The requested page was not found in the cache
    ; copy vmem to vmem_cache (banking as needed)
    sta .copy_from_vmem_to_cache + 2
	ldx vmem_cache_cnt
	; Protect page held in z_pc_mempointer + 1
	pha
	txa
	clc
	adc #>vmem_cache_start
	cmp z_pc_mempointer + 1
	bne +
	inx
	cpx #vmem_cache_count
	bcc ++
	ldx #0
++	stx vmem_cache_cnt

+	pla
	sta vmem_cache_index,x
    lda #>vmem_cache_start ; start of cache
    clc
    adc vmem_cache_cnt
    sta .copy_from_vmem_to_cache + 5
    sei
    +set_memory_all_ram
-   ldy #0
.copy_from_vmem_to_cache
    lda $8000,y
    sta $8000,y
    iny
    bne .copy_from_vmem_to_cache
    +set_memory_no_basic
    cli
    ; set next cache to use when needed
	inx
	txa
	dex
	cmp #vmem_cache_count
	bcc ++
	lda #0
++	sta vmem_cache_cnt
.cache_updated
    ; x is now vmem_cache (0-3) where current z_pc is
    txa
    clc
    adc #>vmem_cache_start
    sta mempointer + 1
    ldx vmap_index
    bne .update_page_rank ; always true
.unswappable
    ; update memory pointer
    lda vmem_1kb_offset
    clc
    adc vmap_c64_offset
    sta mempointer + 1
.update_page_rank
    ; update page rank
!ifndef VMEM_CLOCK { 
	cpx #$00  ; x is index of accesses Z_PC
    beq .return_result
    txa
    tay
    dey ; y = index before x
    ; check if map[y] is dynamic
    lda vmap_z_h,y
    and #$40
    bne .return_result
    ; not dynamic, let's bubble this index up (swap x and y)
    ; swap vmap entries at <x> and <y>
.swap_x_and_y
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
}
    ; return result
    ldy #0
    lda (mempointer),y
    rts
}
