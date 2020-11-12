; Routines to handle memory

; !ifndef VMEM {
; !zone {
; read_byte_at_z_address
	; ; Subroutine: Read the contents of a byte address in the Z-machine
	; ; a,x,y (high, mid, low) contains address.
	; ; Returns: value in a
	; sty mempointer
	; txa
	; clc
	; adc #>story_start
	; sta mempointer + 1
	; ldy #0
	; lda (mempointer),y
	; rts
; .too_high
	; lda #ERROR_MEMORY_OVER_64KB
	; jsr fatalerror

; }
; }

inc_z_pc_page
!zone {
	pha
	inc z_pc_mempointer + 1
	inc z_pc + 1
!ifdef VMEM {
	bne +
	inc z_pc
+	lda z_pc + 1
	and #vmem_indiv_block_mask
	beq get_page_at_z_pc_did_pha
	lda z_pc_mempointer + 1
	cmp #>story_start
	bcc get_page_at_z_pc_did_pha
} else {
; No vmem
	!ifndef TARGET_PLUS4 {
		lda z_pc + 1
		cmp #(first_banked_memory_page - (>story_start))
		bcs get_page_at_z_pc_did_pha
	}
}
; safe
	pla
	rts

}


set_z_pc
; Sets new value of z_pc, and makes sure z_pc_mempointer points to the right memory
; Parameters: New value of z_pc in a,x,y
!zone {
	sty z_pc + 2
!ifdef VMEM {
	cmp z_pc
	bne .unsafe_1
}
	cpx z_pc + 1
	beq .same_page 
	; Different page.
!ifdef VMEM {
	; Let's find out if it's the same vmem block.
	txa
	eor z_pc + 1
	and #(255 - vmem_indiv_block_mask)
	bne .unsafe_2
	; z_pc is in same vmem_block unless it's in vmem_cache
	lda z_pc_mempointer + 1
	cmp #>story_start
	bcc .unsafe_2
	; z_pc is in same vmem_block, but different page.
	stx z_pc + 1
	lda z_pc_mempointer + 1
	eor #1
	sta z_pc_mempointer + 1
} else {
; No vmem 
!ifndef TARGET_PLUS4 {
	cpx #(first_banked_memory_page - (>story_start))
	bcs .unsafe_2
}
	stx z_pc + 1
	txa
	clc
	adc #>story_start
	sta z_pc_mempointer + 1
}
.same_page
	rts
.unsafe_1
	sta z_pc
.unsafe_2
	stx z_pc + 1
	; jsr get_page_at_z_pc
	; rts
}

; Must follow set_z_pc
get_page_at_z_pc
!zone {
	pha
get_page_at_z_pc_did_pha
	stx mem_temp
!ifdef TARGET_C128 {
	; Special treatment if PC is in same block as end of dynmem
	lda z_pc
	bne .not_in_dynmem_block
	lda z_pc + 1
	cmp nonstored_blocks
	bcs .not_in_dynmem_block
	; This is in a dynmem block
	adc #>story_start_bank_1 ; Carry already clear
	sta mem_temp + 1
	ldy #0
-	cmp vmem_cache_page_index,y
	bne +
	lda vmem_cache_bank_index,y
	bne .found_it ; The page we're looking for belongs to bank 1, so this is a match!
	lda mem_temp + 1
+	iny
	cpy #vmem_cache_count
	bcc -
	; Block not found, will copy it to vmem_cache
	ldy vmem_cache_cnt
	sta vmem_cache_page_index,y
	lda #1
	sta vmem_cache_bank_index,y
	tya
	clc
	adc #>vmem_cache_start
	tay
	lda mem_temp + 1
	ldx #1
	jsr copy_page_c128
	ldy vmem_cache_cnt
	sty mem_temp + 1
	iny
	cpy #vmem_cache_count
	bcc +
	ldy #0
+	sty vmem_cache_cnt	
	ldy mem_temp + 1
.found_it
	tya
	clc
	adc #>vmem_cache_start
	sta z_pc_mempointer + 1
	ldy #0
	ldx mem_temp
	pla
	rts
.not_in_dynmem_block
}
	lda z_pc
	ldx z_pc + 1
	ldy z_pc + 2
	jsr read_byte_at_z_address
	ldy mempointer + 1
	sty z_pc_mempointer + 1
	ldy #0 ; Important: y should always be 0 when exiting this routine!
	ldx mem_temp
	pla
	rts
}

!zone {
; !ifdef VMEM {
; .reu_copy
	; ; a = source C64 page
	; ; y = destination C64 page
	; stx mem_temp
	; sty mem_temp + 1
	; ; Copy to REU
	; tay
	; lda #0
	; tax
	; jsr store_reu_transfer_params
	; lda #%10000000;  c64 -> REU with delayed execution
	; sta reu_command
	; sei
	; +set_memory_all_ram_unsafe
	; lda $ff00
	; sta $ff00
	; +set_memory_no_basic_unsafe
	; cli
	; ; Copy to C64
	; txa ; X is already 0, set a to 0 too
	; ldy mem_temp + 1
	; jsr store_reu_transfer_params
	; lda #%10000001;  REU -> c64 with delayed execution
	; sta reu_command
	; sei
	; +set_memory_all_ram_unsafe
	; lda $ff00
	; sta $ff00
	; +set_memory_no_basic_unsafe
	; cli
	; ldx mem_temp
	; ldy #0
	; rts
; }	
!ifdef TARGET_C128 {
copy_page_c128_src
; a = source
; y = destination
; x = bank (0 or 1)

!pseudopc copy_page_c128 {
	sta .copy + 2
	sty .copy + 5
	sei
	sta c128_mmu_load_pcrb,x
-   ldy #0
.copy
	lda $8000,y
	sta $8000,y
	iny
	bne .copy
	sta c128_mmu_load_pcra
	cli
	rts

read_word_from_bank_1_c128
; a = zp vector pointing to base address
; y = offset from address in zp vector
; Returns word in a,x (byte 1, byte 2)
; y retains its value
	sta .read_word + 1
	sta .read_word_2 + 1
	sei
	sta c128_mmu_load_pcrc
	iny
.read_word
	lda ($fb),y
	tax
	dey
.read_word_2
	lda ($fb),y
	sta c128_mmu_load_pcra
	cli
	rts

write_word_to_bank_1_c128
; zp vector pointing to base address must be stored in
;   write_word_c128_zp_1 and write_word_c128_zp_2 before call 
; a,x = value (byte 1, byte 2)
; y = offset from address in zp vector
; y is increased by 1
	sei
	sta c128_mmu_load_pcrc
.write_word
	sta ($fb),y
	txa
	iny
.write_word_2
	sta ($fb),y
	sta c128_mmu_load_pcra
	cli
	rts

write_word_c128_zp_1 = .write_word + 1
write_word_c128_zp_2 = .write_word_2 + 1


} ; pseudopc
copy_page_c128_src_end

} else { ; not TARGET_C128

copy_page
; a = source
; y = destination

; !ifdef VMEM {
	; bit use_reu
	; bmi .reu_copy
; }
	sta .copy + 2
	sty .copy + 5
	sei
	+set_memory_all_ram_unsafe
	+before_dynmem_read
-   ldy #0
.copy
	lda $8000,y
	sta $8000,y
	iny
	bne .copy
	+after_dynmem_read
	+set_memory_no_basic_unsafe
	cli
	rts
} ; not TARGET_C128
}



read_header_word
; y contains the address in the header
; Returns: Value in a,x
; y retains its original value
!ifdef TARGET_C128 {
	lda #<story_start_bank_1
	sta mem_temp
	lda #>story_start_bank_1
	sta mem_temp + 1
	lda #mem_temp
	jmp read_word_from_bank_1_c128
	; sta $02aa
	; ldx #$7f
	; iny
	; jsr $02a2
	; sta .tmp
	; dey
	; ldx #$7f
	; jsr $02a2
	; ldx .tmp
	; rts
} else {
	iny
	lda story_start,y
	tax
	dey
	lda story_start,y
	rts
}

write_header_word
; y contains the address in the header
; a,x contains word value
; a,x,y are destroyed
!ifdef TARGET_C128 {
	stx .tmp
	jsr setup_to_write_to_header_c128
	ldx #mem_temp
	stx write_word_c128_zp_1
	stx write_word_c128_zp_2
	ldx .tmp
	jmp write_word_to_bank_1_c128

	; ldx #$7f
	; jsr $02af
	; iny
	; lda .tmp
	; ldx #$7f
	; jmp $02af
} else {
	sta story_start,y
	iny
	txa
	sta story_start,y
	rts
}

write_header_byte
; y contains the address in the header
; a contains byte value
; a,x,y are preserved
!ifdef TARGET_C128 {
	sta .tmp
	stx .tmp + 1
	jsr setup_to_write_to_header_c128
	ldx #mem_temp
	stx $02b9
	ldx #$7f
	jsr $02af
	lda .tmp
	ldx .tmp + 1
	rts
} else {
	sta story_start,y
	rts
}

!ifdef TARGET_C128 {
setup_to_write_to_header_c128
	ldx #<story_start_bank_1
	stx mem_temp
	ldx #>story_start_bank_1
	stx mem_temp + 1
	rts

.tmp !byte 0, 0
}
