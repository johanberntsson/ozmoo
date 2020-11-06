
dynmem_size !byte 0, 0

vmem_cache_cnt !byte 0         ; current execution cache
vmem_cache_page_index !fill cache_pages + 1, 0
!ifdef TARGET_C128 {
vmem_cache_bank_index !fill cache_pages + 1, 0
}

!ifndef VMEM {
; Non-virtual memory

read_byte_at_z_address
	; Subroutine: Read the contents of a byte address in the Z-machine
	; a,x,y (high, mid, low) contains address.
	; Returns: value in a

	sty mempointer ; low byte unchanged
	; same page as before?
	cpx zp_pc_l
	bne .read_new_byte
	; same 256 byte segment, just return
.return_result
	ldy #0
!ifdef TARGET_PLUS4 {
	sei
	sta plus4_enable_ram
	lda (mempointer),y
	sta plus4_enable_rom
	cli
} else {
	lda (mempointer),y
}
	rts
.read_new_byte
	txa
	sta zp_pc_l
	clc
	adc #>story_start
	sta mempointer + 1
!ifdef TARGET_PLUS4 {
	bne .return_result ; Always branch
} else {	
	cmp #first_banked_memory_page
	bcc .return_result
; swapped memory
	; ; Carry is already clear
	; adc #>story_start
	; sta vmap_c64_offset
	; cmp #first_banked_memory_page
	; bcc .unswappable
	; this is swappable memory
	; update vmem_cache if needed
	; Check if this page is in cache
	ldx #vmem_cache_count - 1
-   cmp vmem_cache_page_index,x
	beq .cache_updated
	dex
	bpl -
	; The requested page was not found in the cache
	; copy vmem to vmem_cache (banking as needed)
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
	sta vmem_cache_page_index,x
	pha
	lda #>vmem_cache_start ; start of cache
	clc
	adc vmem_cache_cnt
	tay
	pla
!ifdef TARGET_C128 {
	stx vmem_temp
	ldx #0
	jsr copy_page_c128
	ldx vmem_temp
} else {
	jsr copy_page
}
	; set next cache to use when needed
	inx
	txa
	dex
	cmp #vmem_cache_count
	bcc ++
	lda #0
++	sta vmem_cache_cnt
.cache_updated
	; x is now vmem_cache (0-4) where we want to read
	txa
	clc
	adc #>vmem_cache_start
	sta mempointer + 1
	jmp .return_result 
} ; Not TARGET_PLUS4
	
} else {
; virtual memory

; virtual memory address space
; Z1-Z3: 128 kB (0 - $1ffff)
; Z4-Z5: 256 kB (0 - $3ffff)
; Z6-Z8: 512 kB (0 - $7ffff)
;
; map structure: one entry for each block (512 bytes) of available virtual memory
; each map entry is:
; 1 byte: ZMachine offset high byte (1-3 lowest bits used for ZMachine offset, the rest used to store ticks since block was last used)
; 1 byte: ZMachine offset low byte
;
; needs 102*2=204 bytes for $3400-$FFFF
; will store in datasette_buffer
;

vmem_blocksize = 512
vmem_indiv_block_mask = >(vmem_blocksize - 1)
vmem_block_pagecount = vmem_blocksize / 256
vmap_max_size = (vmap_buffer_end - vmap_buffer_start) / 2
; If we go past this limit we get in trouble, since we overflow the memory area we can use. 
; vmap_max_entries	!byte 0 ; Moved to ZP
; vmap_used_entries	!byte 0 ; Moved to ZP
vmap_blocks_preloaded !byte 0
vmap_z_h = vmap_buffer_start
vmap_z_l = vmap_z_h + vmap_max_size

vmap_first_ram_page		!byte 0
vmap_c64_offset !byte 0
vmap_index !byte 0              ; current vmap index matching the z pointer
vmem_offset_in_block !byte 0         ; 256 byte offset in 512 byte block (0-1)
; vmem_temp !byte 0

vmem_tick 			!byte $e0
vmem_oldest_age		!byte 0
vmem_oldest_index	!byte 0

vmap_temp			!byte 0,0,0

!ifdef Z8 {
	vmem_tick_increment = 4
	vmem_highbyte_mask = $03
} else {
!ifdef Z3 {
	vmem_tick_increment = 1
	vmem_highbyte_mask = $00
} else {
	vmem_tick_increment = 2
	vmem_highbyte_mask = $01
}
}

!ifdef COUNT_SWAPS {
vmem_swap_count !byte 0,0
}

!ifdef DEBUG {
!ifdef PREOPT {
print_optimized_vm_map
	stx zp_temp ; Nonzero means premature exit
	jsr printchar_flush
	lda #0
	sta streams_output_selected + 2
	sta is_buffered_window
	jsr newline
	jsr dollar
	jsr dollar
	jsr dollar
	jsr print_following_string
	!pet "clock",13,0
	ldx #0
-	lda vmap_z_h,x
	jsr print_byte_as_hex
	lda vmap_z_l,x
	jsr print_byte_as_hex
	jsr colon
	inx
	cpx vmap_used_entries
	bcc -

	lda zp_temp
	bne +++
	; Print block that was just to be read
	lda zp_pc_h
	jsr print_byte_as_hex
	lda zp_pc_l
	jsr print_byte_as_hex
	jsr colon
	
+++	jsr newline
	jsr dollar
	jsr dollar
	jsr dollar
	jsr newline
	jsr kernal_readchar   ; read keyboard
	jmp kernal_reset      ; reset
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
	lda vmem_cache_page_index
	jsr print_byte_as_hex
	jsr space
	jsr dollar
	lda vmem_cache_page_index + 1
	jsr print_byte_as_hex
	jsr space
	jsr dollar
	lda vmem_cache_page_index + 2
	jsr print_byte_as_hex
	jsr space
	jsr dollar
	lda vmem_cache_page_index + 3
	jsr print_byte_as_hex
	jsr newline
	ldy #0
-	; print
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
	tya
	asl
	adc vmap_first_ram_page
	jsr print_byte_as_hex
	lda #$30
	jsr streams_print_output
	lda #$30
	jsr streams_print_output
	jsr newline
.next_entry
	iny 
	cpy vmap_used_entries
	bcc -
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

	lda vmap_index
	tax
	asl
	; Carry is already clear
	adc vmap_first_ram_page

!ifdef TRACE_FLOPPY {
	jsr comma
	jsr print_byte_as_hex
}
	sta readblocks_mempos + 1
!ifndef TARGET_PLUS4 {
	tay ; This value need to be in y if we jump to load_blocks_from_index_using_cache
	cmp #first_banked_memory_page
	bcs load_blocks_from_index_using_cache
}
	lda #vmem_block_pagecount ; number of blocks
	sta readblocks_numblocks
	lda vmap_z_l,x ; start block
	asl
	sta readblocks_currentblock
!if vmem_highbyte_mask > 0 {
	lda vmap_z_h,x ; start block
	and #vmem_highbyte_mask
} else {
	lda #0
}
	rol
	sta readblocks_currentblock + 1
	jsr readblocks
!ifdef TRACE_VM {
	jsr print_following_string
	!pet "load_blocks (normal) ",0
	jsr print_vm_map
}
	rts

!ifndef TARGET_PLUS4 {
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
	lda #>vmem_cache_start ; start of cache
	clc
	adc vmem_cache_cnt
	sta vmem_temp
	sty vmem_temp + 1
	ldx #0 ; Start with page 0 in this 512-byte block
	; read next into vmem_cache
-   lda #>vmem_cache_start ; start of cache
	clc
	adc vmem_cache_cnt
	sta readblocks_mempos + 1
	txa
	pha
	sta vmap_temp
	ldx vmap_index
	lda vmap_z_l,x ; start block
	asl
	ora vmap_temp
	sta readblocks_currentblock
!if vmem_highbyte_mask > 0 {
	lda vmap_z_h,x ; start block
	and #vmem_highbyte_mask
} else {
	lda #0
}
	rol
	sta readblocks_currentblock + 1
	jsr readblock
	; copy vmem_cache to block (banking as needed)
	lda vmem_temp
	ldy vmem_temp + 1
!ifdef TARGET_C128 {
	ldx #0
	jsr copy_page_c128
} else {
	jsr copy_page
}
	inc vmem_temp + 1
	pla
	tax
	inx
	cpx #vmem_block_pagecount ; read 2 blocks (512 bytes) in total
	bcc -

	ldx vmem_temp + 1
	dex
	txa
	ldx vmem_cache_cnt
	sta vmem_cache_page_index,x
!ifdef TARGET_C128 {
	lda #0 ; TODO: This will depend on where in vmap the block is.
	sta vmem_cache_bank_index,x
}
	rts
}

read_byte_at_z_address
	; Subroutine: Read the contents of a byte address in the Z-machine
	; a,x,y (high, mid, low) contains address.
	; Returns: value in a

!ifdef TARGET_C128 {
	; TODO: For C128, we do the dynmem check both here and 40 lines down. Make it better!
	cmp #0
	bne .not_dynmem
	cpx nonstored_blocks
	bcs .not_dynmem

	; This is in dynmem, so we always read from bank 1
	txa
	clc
	adc #>story_start_bank_1
	sta vmem_temp + 1
	lda #0
	sta vmem_temp
	lda #vmem_temp
	sta $02aa
	ldx #$7f
	jmp $02a2
	
.not_dynmem	
}


	sty mempointer ; low byte unchanged
	; same page as before?
	cpx zp_pc_l
	bne .read_new_byte
	cmp zp_pc_h
	bne .read_new_byte
	; same 256 byte segment, just return
.read_and_return_value
	ldy #0
!ifdef TARGET_PLUS4 {
	sei
	sta plus4_enable_ram
	lda (mempointer),y
	sta plus4_enable_rom
	cli
} else {
	lda (mempointer),y
}
	rts
.read_new_byte
	cmp #0
	bne .non_dynmem
	cpx nonstored_blocks
	bcs .non_dynmem
	; Dynmem access
	sta zp_pc_h
	txa
	sta zp_pc_l
	adc #>story_start
	sta mempointer + 1
	bne .read_and_return_value ; Always branch
.non_dynmem
	sta zp_pc_h
	stx zp_pc_l
	lsr
	sta vmem_temp + 1
	lda #0
	sta vmap_quick_index_match
	txa
	and #vmem_indiv_block_mask ; keep index into kB chunk
	sta vmem_offset_in_block
	txa
	ror
	sta vmem_temp
	; Check quick index first
	ldx #vmap_quick_index_length - 1
-	ldy vmap_quick_index,x
	cmp vmap_z_l,y ; zmachine mem offset ($0 -
	beq .quick_index_candidate
--	dex
	bpl -
	bmi .no_quick_index_match ; Always branch
.quick_index_candidate
!if vmem_highbyte_mask > 0 {
	lda vmap_z_h,y
	and #vmem_highbyte_mask
	cmp vmem_temp + 1
	beq .quick_index_match
	lda vmem_temp
	jmp --
}
.quick_index_match
	inc vmap_quick_index_match
	sty vmap_index
	jmp .index_found
;	tya
;	tax
;	jmp .correct_vmap_index_found ; Always branch
	
.no_quick_index_match
	lda vmem_temp

	; is there a block with this address in map?
	ldx vmap_used_entries
	dex
-   ; compare with low byte
	cmp vmap_z_l,x ; zmachine mem offset ($0 - 
	beq +
.check_next_block
	dex
	bpl -
	bmi .no_such_block ; Always branch
	; is the highbyte correct?
+
!if vmem_highbyte_mask > 0 {
	lda vmap_z_h,x
	and #vmem_highbyte_mask
	cmp vmem_temp + 1
	beq .correct_vmap_index_found
	lda vmem_temp
	jmp .check_next_block
}
.correct_vmap_index_found
	; vm index for this block found
	stx vmap_index

	ldy vmap_quick_index_match
	bne ++ ; This is already in the quick index, don't store it again
	txa
	ldx vmap_next_quick_index
	sta vmap_quick_index,x
	inx
	cpx #vmap_quick_index_length
	bcc +
	ldx #0
+	stx vmap_next_quick_index
++	jmp .index_found

; no index found, add last
.no_such_block

	; Load 512 byte block into RAM
!if SUPPORT_REU = 1 {
	; First, check if this is initial REU loading
	ldx use_reu
	cpx #$80
	bne .not_initial_reu_loading
	ldx #0
	lda vmap_z_l ; ,x is not needed here, since x is always 0
	asl
	cmp z_pc + 1
	bne .block_chosen
	inx ; Set x to 1
	bne .block_chosen ; Always branch
}

.not_initial_reu_loading
	ldx vmap_used_entries
	cpx vmap_max_entries
	bcc .block_chosen

!ifdef DEBUG {
!ifdef PREOPT {
	ldx #0
	jmp print_optimized_vm_map
}	
}	
	; Find the best block to replace

	; Create a copy of the block z_pc points to, shifted one step to the right, 
	; to be comparable to vmap entries
	lda z_pc
	lsr
	sta vmap_temp + 1
	lda z_pc + 1
	ror
	sta vmap_temp + 2

	; Store very recent oldest_age so the first valid index in the following
	; loop will be picked as the first candidate.
	lda #$ff
!ifdef DEBUG {
	sta vmem_oldest_index
}
	sta vmem_oldest_age
	
	; Check all indexes to find something older
	ldx vmap_used_entries
	dex
-	lda vmap_z_h,x
	cmp vmem_oldest_age
	bcs +
	; Found older
	; Skip if z_pc points here; it could be in either page of the block.
	ldy vmap_z_l,x
	cpy vmap_temp + 2
!if vmem_highbyte_mask > 0 {
	bne ++
	tay
	and #vmem_highbyte_mask
	cmp vmap_temp + 1
	beq +
	tya
} else {
	beq +
}
++	sta vmem_oldest_age
	stx vmem_oldest_index
+	dex
	cpx #$ff
	bne -

	; Load chosen index
	ldx vmem_oldest_index
	
.block_chosen
!ifdef COUNT_SWAPS {
	inc vmem_swap_count + 1
	bne ++
	inc vmem_swap_count
++
}
	
	cpx vmap_used_entries
	bcc +
	; This block was unoccupied
	inc vmap_used_entries
+	txa
	asl
	; Carry is already clear
	adc vmap_first_ram_page
	sta vmap_c64_offset

!ifdef DEBUG {
	lda vmem_oldest_index
	cmp #$ff
	bne +
	lda #ERROR_NO_VMEM_INDEX
	jsr fatalerror
+
}

	; We have now decided on a map position where we will store the requested block. Position is held in x.
!ifdef DEBUG {
!ifdef PRINT_SWAPS {
	lda streams_output_selected + 2
	beq +
	lda #20
	jsr s_printchar
	lda #64
	jsr s_printchar
	lda #20
	jsr s_printchar
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
	cpx vmap_used_entries
	bcs .printswaps_part_2
	lda vmap_z_h,x
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
	jsr print_byte_as_hex
	jsr space
++	
}
}

!ifndef TARGET_PLUS4 {
	; Forget any cache pages belonging to the old block at this position.
	lda vmap_c64_offset
	cmp #first_banked_memory_page
	bcc .cant_be_in_cache
	ldy #vmem_cache_count - 1
-	lda vmem_cache_page_index,y
	and #(255 - vmem_indiv_block_mask)
	cmp vmap_c64_offset
	bne +
; TODO: For C128, check if it's the right bank too, to make this more efficient	
	lda #0
	sta vmem_cache_page_index,y
+	dey
	bpl -
.cant_be_in_cache	
} ; not TARGET_PLUS4

	; Update tick
	lda vmem_tick
	clc
	adc #vmem_tick_increment
	bcc +

	; Tick counter has passed max value. Decrease tick value for all pages. Set tick counter back.
	txa
	pha
	
	ldx vmap_used_entries
	dex
-	lda vmap_z_h,x
	sec
	sbc #$80
	bpl ++
	and #vmem_highbyte_mask
++	sta vmap_z_h,x
	dex
	bpl -
	
	pla
	tax
	lda #$80
+	sta vmem_tick

	; Store address of 512 byte block to load, then load it
	lda zp_pc_h
	lsr
	sta vmap_z_h,x
	lda zp_pc_l
;	and #(255 - vmem_indiv_block_mask) ; skip bit 0 since 512 byte blocks
	ror
	sta vmap_z_l,x
	stx vmap_index
	jsr load_blocks_from_index
.index_found
	; index found
	; Update tick for last access 
	ldx vmap_index
!if vmem_highbyte_mask > 0 {
	lda vmap_z_h,x
	and #vmem_highbyte_mask
	ora vmem_tick
} else {
	lda vmem_tick
}
	sta vmap_z_h,x
	txa
	
	asl
	; Carry is already clear
	adc vmap_first_ram_page
	sta vmap_c64_offset

!ifndef TARGET_PLUS4 {
	cmp #first_banked_memory_page
	bcc .unswappable
	; this is swappable memory
	; update vmem_cache if needed
	clc
	adc vmem_offset_in_block
	; Check if this page is in cache
	ldx #vmem_cache_count - 1
	tay
-	tya
	cmp vmem_cache_page_index,x
!ifdef TARGET_C128 {
	bne .not_a_match
	lda #0 ; TODO: This should depend on the vmap index.
	cmp vmem_cache_bank_index,x
	bne .not_a_match
	jmp .cache_updated
.not_a_match
} else {
	beq .cache_updated
}
	dex
	bpl -
	; The requested page was not found in the cache
	; copy vmem to vmem_cache (banking as needed)
	sty vmem_temp
	ldx vmem_cache_cnt
	; Protect page held in z_pc_mempointer + 1
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

+	tya
	sta vmem_cache_page_index,x
!ifdef TARGET_C128 {
	lda #0 ; TODO: Should depend on the vmap cache index
	sta vmem_cache_bank_index,x
}	
	lda #>vmem_cache_start ; start of cache
	clc
	adc vmem_cache_cnt
	tay
	lda vmem_temp
!ifdef TARGET_C128 {
	stx vmem_temp + 1
	ldx #0
	jsr copy_page_c128
	ldx vmem_temp + 1
} else {
	jsr copy_page
}
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
	bne .return_result ; always true
.unswappable
} ; not TARGET_PLUS4

	; update memory pointer
	lda vmem_offset_in_block
	clc
	adc vmap_c64_offset
	sta mempointer + 1
.return_result
	ldy #0
!ifdef TARGET_PLUS4 {
	sei
	sta plus4_enable_ram
	lda (mempointer),y
	sta plus4_enable_rom
	cli
} else {
	lda (mempointer),y
}
	rts
}
