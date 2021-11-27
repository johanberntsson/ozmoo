
dynmem_size !byte 0, 0

vmem_cache_cnt !byte 0         ; current execution cache
vmem_cache_page_index !fill cache_pages + 1, 0
!ifdef TARGET_C128 {
vmem_cache_bank_index !fill cache_pages + 1, 0
}

!ifdef TARGET_PLUS4 {
	SKIP_VMEM_BUFFERS = 1
} else {
!ifdef SKIP_BUFFER {
	SKIP_VMEM_BUFFERS = 1
}
}

!ifndef SKIP_VMEM_BUFFERS {
get_free_vmem_buffer
	; Protect buffer which z_pc points to
	lda vmem_cache_cnt
	tax
	clc
	adc #>vmem_cache_start
	cmp z_pc_mempointer + 1
	bne +
	jsr inc_vmem_cache_cnt
	txa
	clc
	adc #>vmem_cache_start ; start of cache
+	cmp mempointer + 1
	bne +
	; mempointer points to this page. Store $ff in zp_pc_h so mempointer won't be used
	pha
	lda #$ff
	sta zp_pc_h
	pla
+	stx vmem_cache_cnt
	rts

inc_vmem_cache_cnt
	ldx vmem_cache_cnt
	inx
	cpx #vmem_cache_count
	bcc +
	ldx #0
+	stx vmem_cache_cnt
	rts


}

!ifndef VMEM {
; Non-virtual memory

read_byte_at_z_address
	; Subroutine: Read the contents of a byte address in the Z-machine
	; a,x,y (high, mid, low) contains address.
	; Returns: value in a

	; same page as before?
	cpx zp_pc_l
	bne .read_new_byte
	; same 256 byte segment, just return
!ifdef SKIP_BUFFER {
	txa
	clc
	adc #>story_start
	cmp #first_banked_memory_page
	bcs .read_under_rom
}
.return_result
	+before_dynmem_read
	lda (mempointer),y
	+after_dynmem_read
	rts
.read_new_byte
!ifndef TARGET_PLUS4 {
	sty mempointer_y
}
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
; Memory under IO / ROM
!ifdef SKIP_BUFFER {
.read_under_rom
	+disable_interrupts
	+set_memory_all_ram_unsafe
	lda (mempointer),y
	+set_memory_no_basic
	+enable_interrupts
	rts
} else { 	
	; Check if this page is in cache
	ldx #vmem_cache_count - 1
-   cmp vmem_cache_page_index,x
	bne +
	txa
	clc
	adc #>vmem_cache_start
	sta mempointer + 1
	bne .return_result ; Always branch
+	dex
	bpl -
	; The requested page was not found in the cache
	; copy vmem to vmem_cache (banking as needed)
	pha
	
	jsr get_free_vmem_buffer
	sta mempointer + 1
	sta vmem_temp
	ldx vmem_cache_cnt
	pla
	sta vmem_cache_page_index,x
	pha
	ldy vmem_temp
	pla
	jsr copy_page

	; set next cache to use when needed
	jsr inc_vmem_cache_cnt
	ldy mempointer_y
	jmp .return_result 
} ; Not SKIP_VMEM_BUFFERS
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
vmap_z_l = vmap_buffer_start
vmap_z_h = vmap_z_l + vmap_max_size

vmap_first_ram_page		!byte 0
vmap_index !byte 0              ; current vmap index matching the z pointer
vmem_offset_in_block !byte 0         ; 256 byte offset in 512 byte block (0-1)
; vmem_temp !byte 0

vmap_temp			!byte 0,0,0

vmap_c64_offset !byte 0

!ifdef TARGET_C128 {
vmap_c64_offset_bank !byte 0
first_vmap_entry_in_bank_1 !byte 0
vmap_first_ram_page_in_bank_1 !byte 0
vmem_bank_temp !byte 0
}

vmem_tick 			!byte $e0
vmem_oldest_age		!byte 0
vmem_oldest_index	!byte 0

!ifdef Z8 {
	vmem_tick_increment = 4
	vmem_highbyte_mask = $03
} else {
!ifndef Z4PLUS {
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
	ldx #$ff
	jsr erase_window
	lda #0
	sta streams_output_selected + 2
	sta is_buffered_window
	jsr print_following_string
	!pet 13,"$po$:",0

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
	
+++	
	jsr print_following_string
	!pet "$$$$",0
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
	and #$ff xor vmem_highbyte_mask
	jsr print_byte_as_hex
	jsr space
	jsr dollar
	lda vmap_z_h,y ; zmachine mem offset ($0 - 
	and #vmem_highbyte_mask
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
!ifdef TARGET_C128 {
	ldy #0
	sty vmem_bank_temp
	cmp first_vmap_entry_in_bank_1
	bcc .in_bank_0
	sbc first_vmap_entry_in_bank_1 ; Carry is already set
	asl
	adc vmap_first_ram_page_in_bank_1 ; Carry is already clear
	tay ; This value need to be in y when we jump to load_blocks_from_index_using_cache 
	inc vmem_bank_temp
	bne load_blocks_from_index_using_cache ; Always branch
.in_bank_0
}	
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
	; For C128: vmem_bank_temp = RAM bank in which page y resides
	; side effects: a,y,x,status destroyed
	; initialise block copy function (see below)

	jsr get_free_vmem_buffer
	sta vmem_temp
	
	sty vmem_temp + 1
	ldx #0 ; Start with page 0 in this 512-byte block
	; read next into vmem_cache
-   lda vmem_temp ; start of cache
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
	ldx vmem_bank_temp
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
	lda vmem_bank_temp
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
	cpx nonstored_pages
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


	; same page as before?
	cpx zp_pc_l
	bne .read_new_byte
	cmp zp_pc_h
	bne .read_new_byte
	; same 256 byte segment, just return
.read_and_return_value
	+before_dynmem_read
	lda (mempointer),y
	+after_dynmem_read

	rts
.read_new_byte
	sta zp_pc_h
	stx zp_pc_l
!ifndef TARGET_C128 {
	cmp #0
	bne .non_dynmem
	cpx nonstored_pages
	bcs .non_dynmem
	; Dynmem access
	txa
	adc #>story_start
	sta mempointer + 1
	bne .read_and_return_value ; Always branch
}	
.non_dynmem
	sty mempointer_y
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
	
.no_quick_index_match
	lda vmem_temp

	; is there a block with this address in map?
	ldx vmap_used_entries
-   ; compare with low byte
	; TODO: It would be helpful to ensure vmap_z_l - 1 is near the start of
	; a page, so the following frequently executed instruction doesn't
	; incur too many extra page-crossing cycles.
	cmp vmap_z_l - 1,x ; zmachine mem offset ($0 - 
	beq +
.check_next_block
	dex
	bne -
	beq .no_such_block ; Always branch
	; is the highbyte correct?
+
!if vmem_highbyte_mask > 0 {
	lda vmap_z_h - 1,x
	and #vmem_highbyte_mask
	cmp vmem_temp + 1
	beq .correct_vmap_index_found
	lda vmem_temp
	jmp .check_next_block
}
.correct_vmap_index_found
	; vm index for this block found
        dex
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
+	
	txa
	
!ifdef TARGET_C128 {
	; TODO: C128: Check if x is >= vmap_first_ram_page_in_bank_1
	cmp first_vmap_entry_in_bank_1
	bcc + ; Not in bank 1
	ldy #1
	sty vmap_c64_offset_bank
	sbc first_vmap_entry_in_bank_1 ; Carry already set
	clc
	asl ; Multiply by 2 to count in 256-byte pages rather than 512-byte vmem blocks
	adc vmap_first_ram_page_in_bank_1
	bne ++ ; Always branch
+
	ldy #0
	sty vmap_c64_offset_bank
}	
	asl
	
	; Carry is already clear
	adc vmap_first_ram_page
++	sta vmap_c64_offset



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
!ifdef TARGET_C128 {
	lda vmem_cache_bank_index,y
	cmp vmap_c64_offset_bank
	bne +
}
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

!ifdef TARGET_C128 {
	cmp first_vmap_entry_in_bank_1
	bcc .not_in_bank_1
	ldy #1
	sty vmap_c64_offset_bank
	sbc first_vmap_entry_in_bank_1 ; Carry already set
	asl ; Multiply by 2 to count in 256-byte pages rather than 512-byte vmem blocks
	adc vmap_first_ram_page_in_bank_1 ; Carry already clear
	bne .store_offset ; Always branch
.not_in_bank_1	
	ldy #0
	sty vmap_c64_offset_bank
}	

	asl
	; Carry is already clear
	adc vmap_first_ram_page
.store_offset	
	sta vmap_c64_offset

!ifndef TARGET_PLUS4 {
!ifdef TARGET_C128 {
	; Bank is in y at this point
	cpy #0
	bne .swappable_memory
}
	cmp #first_banked_memory_page
	bcc .unswappable
.swappable_memory
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
	lda vmap_c64_offset_bank
	cmp vmem_cache_bank_index,x
	bne .not_a_match
	beq.cache_updated
.not_a_match
} else {
	beq .cache_updated
}
	dex
	bpl -
	; The requested page was not found in the cache
	; copy vmem to vmem_cache (banking as needed)
	sty vmem_temp
	jsr get_free_vmem_buffer
	tay
!ifdef TARGET_C128 {
	lda vmap_c64_offset_bank
	sta vmem_cache_bank_index,x
}
	lda vmem_temp
	sta vmem_cache_page_index,x
!ifdef TARGET_C128 {
	stx vmem_temp + 1
	ldx vmap_c64_offset_bank
	jsr copy_page_c128
	ldx vmem_temp + 1
} else {
	jsr copy_page
}
	lda vmem_cache_cnt
	jsr inc_vmem_cache_cnt
	tax
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
	ldy mempointer_y
	+before_dynmem_read
	lda (mempointer),y
	+after_dynmem_read
	rts
}
