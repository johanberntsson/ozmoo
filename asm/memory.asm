; Routines to handle memory

inc_z_pc_page
!zone {
	pha
	inc z_pc_mempointer + 1
	inc z_pc + 1
!ifdef VMEM {
	bne +
	inc z_pc
+
!ifdef REUBOOST {
	; If REU Boost Mode is enabled, we must always search for the next page
	bit reu_boost_mode
	bmi get_page_at_z_pc_did_pha
}
	lda z_pc + 1
	and #vmem_indiv_block_mask
	beq get_page_at_z_pc_did_pha
	lda z_pc_mempointer + 1
	cmp #>story_start
	bcc get_page_at_z_pc_did_pha
} else {
; No vmem
	!ifdef TARGET_MEGA65 {
		bne +
		inc z_pc
		inc z_pc_mempointer + 2
+		
	} else {
		!ifndef TARGET_PLUS4 {
			lda z_pc + 1
			cmp #(first_banked_memory_page - (>story_start))
			bcs get_page_at_z_pc_did_pha
		}
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

!ifndef TARGET_MEGA65 {	
	!ifdef VMEM {
		cmp z_pc
		bne .unsafe_1
	}
		cpx z_pc + 1
		beq .same_page 
		; Different page.
	!ifdef VMEM {
		; Let's find out if it's the same vmem block.
		!ifdef REUBOOST {
			; In REU Boost Mode, a vmem block is just 1 page
			; so now we have to retrieve a new page
			bit reu_boost_mode
			bmi .unsafe_2
		}
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
	; !ifdef TARGET_MEGA65 {
		; ; This is probably broken/incomplete, but is currently not used anyway
		; stx z_pc_mempointer + 1
		; sta z_pc
		; sta z_pc_mempointer + 2
	; } else {
	; Non-VMEM build for C64 or Plus/4
		txa
		clc
		adc #>story_start
		sta z_pc_mempointer + 1
	; }	
	}
.same_page
		rts
.unsafe_1
}
	sta z_pc
.unsafe_2
	stx z_pc + 1
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
	cmp nonstored_pages
	bcs .not_in_dynmem_block
	; This is in a dynmem block
	adc #>story_start_far_ram ; Carry already clear
	sta mem_temp + 1
	ldx #0
-	cmp vmem_cache_page_index,x
	bne +
	lda vmem_cache_bank_index,x
	bne .found_it ; The page we're looking for belongs to bank 1, so this is a match!
	lda mem_temp + 1
+	inx
	cpx #vmem_cache_count
	bcc -
	; Block not found, will copy it to vmem_cache
	jsr get_free_vmem_buffer
	tay
	lda #1
	sta vmem_cache_bank_index,x
	lda mem_temp + 1
	sta vmem_cache_page_index,x
	ldx #1
	jsr copy_page_c128
	ldx vmem_cache_cnt
	stx mem_temp + 1
	jsr inc_vmem_cache_cnt
	ldx mem_temp + 1
.found_it
	txa
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
!ifdef TARGET_MEGA65 {
	ldy mempointer + 2
	sty z_pc_mempointer + 2
}
	ldy #0 ; Important: y should always be 0 when exiting this routine!
	ldx mem_temp
	pla
	rts
}

!zone {
!ifdef TARGET_C128 {
copy_page_c128_via_reu

	+disable_interrupts
	stx .load_bank_again + 1
	sty .load_dest_page + 1

	tay
	cmp #$10
	bcc + ; If source address < $1000, it's always in bank 0
	; Copy bank bit to VIC bank selection bit, which also controls REU bank
	txa
	lsr
	ror
	lsr ; Bank bit is now in bit 6
	ora $d506
	sta $d506
+	

	lda #0
	tax
	clc
	jsr store_reu_transfer_params

	lda #0
	sta allow_2mhz_in_40_col
	sta reg_2mhz	;CPU = 1MHz

	lda #%10100000;  c128 -> REU with delayed execution
	sta reu_command
.load_bank_again
	ldx #00  ; This value is altered at the start of this routine
	beq +
	jsr perform_reu_copy_bank_1
+
;	sta c128_mmu_load_pcrb,x
	sta c128_mmu_load_pcrb
	lda $ff00
	sta $ff00
	sta c128_mmu_load_pcra

.load_dest_page
	ldy #00 ; This value is altered at the start of this routine
	sty reu_c64base + 1

;	ldx .load_bank_again + 1 ; Already loaded
	cpy #$10
	bcs + ; If source address >= $1000, use the bank in x
	ldx #0 ; Source address < $1000, set bank to 0
	; Copy bank bit to VIC bank selection bit, which also controls REU bank
+	txa
	lsr
	ror
	lsr ; Bank bit is now in bit 6
	sta .ora_bank_bit + 1
	lda $d506
	and #%00111111
.ora_bank_bit
	ora #0
	sta $d506

	lda #%10100001;  REU -> c128 with delayed execution
	sta reu_command

	ldx .load_bank_again + 1
	beq +
	jsr perform_reu_copy_bank_1
+
;	ldx .load_bank_again + 1 ; Already loaded
	sta c128_mmu_load_pcrb
;	sta c128_mmu_load_pcrb,x
	lda $ff00
	sta $ff00

	sta c128_mmu_load_pcra

	lda $d506
	and #%00111111
	sta $d506

	+enable_interrupts
	jmp restore_2mhz

copy_page_c128_src
; a = source
; y = destination
; x = bank (0 or 1)

!pseudopc copy_page_c128 {
	sta .copy + 2
	sty .copy + 5

; Skip speed decrease if we can
	bit COLS_40_80
!if SUPPORT_REU = 1 {
	bpl ++
	bit use_reu
	bpl +
	jmp copy_page_c128_via_reu
++	
} else {
	bmi + ; In 80 col mode, there is no reason to lower speed
}
	bit $d011
	bmi + ; If we're at raster line > 255, stay at 2 MHz
	lda $d012
	cmp #52
	bcs + ; If at line 52-255, stay at 2 Mhz
	cmp #19
	bcc + ; If at line 0-18, stay at 2 MHz
	; Go down to 1 MHz, to avoid screen glitches
	lda #0
	sta reg_2mhz	;CPU = 1MHz

+	+disable_interrupts
	sta c128_mmu_load_pcrb,x
-   ldy #0
.copy
	lda $8000,y
	sta $8000,y
	iny
	bne .copy
	sta c128_mmu_load_pcra
	+enable_interrupts
	rts

!if SUPPORT_REU = 1 {
perform_reu_copy_bank_1
	sta c128_mmu_load_pcrc
	lda $ff00
	sta $ff00
	sta c128_mmu_load_pcra
	rts
}

read_word_from_far_dynmem
; a = zp vector pointing to base address
; y = offset from address in zp vector
; Returns word in a,x (byte 1, byte 2)
; y retains its value
	sta .read_word + 1
	sta .read_word_2 + 1
!ifdef SMOOTHSCROLL {
	jsr wait_smoothscroll_min
}
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

write_word_to_far_dynmem
; zp vector pointing to base address must be stored in
;   write_word_far_dynmem_zp_1 and write_word_far_dynmem_zp_2 before call 
; a,x = value (byte 1, byte 2)
; y = offset from address in zp vector
; y is increased by 1
!ifdef SMOOTHSCROLL {
	jsr wait_smoothscroll_min
}
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

write_word_far_dynmem_zp_1 = .write_word + 1
write_word_far_dynmem_zp_2 = .write_word_2 + 1

} ; pseudopc
copy_page_c128_src_end

} else { ; not TARGET_C128

!zone copy_page {
copy_page
; a = source
; y = destination

!ifdef TARGET_MEGA65 {
	sta .cp_dma_source_address + 1
	sty .cp_dma_dest_address + 1
	ldy #0
	+disable_interrupts
	jsr mega65io
	sty $d702 ; DMA list is in bank 0
	lda #>.cp_dma_list
	sta $d701
	lda #<.cp_dma_list
	sta $d705 
	+enable_interrupts
	clc
	rts
	
.cp_dma_list
	!byte $0b ; Use 12-byte F011B DMA list format
	!byte $00 ; End of options
.cp_dma_command_lsb				!byte 0		; 0 = Copy
.cp_dma_count					!word $100	; Always copy one page
.cp_dma_source_address			!word 0
.cp_dma_source_bank_and_flags	!byte 0
.cp_dma_dest_address			!word 0
.cp_dma_dest_bank_and_flags		!byte 0
.cp_dma_command_msb				!byte 0		; 0 for linear addressing for both src and dest
.cp_dma_modulo					!word 0		; Ignored, since we're not using the MODULO flag

read_word_from_far_dynmem
; a = zp vector pointing to base address
; y = offset from address in zp vector
; Returns word in a,x (byte 1, byte 2)
; y retains its value
	tax
	lda 0,x
	sta dynmem_pointer
	lda 1,x
	sta dynmem_pointer + 1
	tya
	taz
	inz
	lda [dynmem_pointer],z
	tax
	dez
	lda [dynmem_pointer],z
	rts

write_word_to_far_dynmem
; zp vector pointing to base address must be stored in
;   write_word_far_dynmem_zp_1 and write_word_far_dynmem_zp_2 before call 
; a,x = value (byte 1, byte 2)
; y = offset from address in zp vector
; y is increased by 1
	pha
.write_word
	lda $fb
	sta dynmem_pointer
	inc .write_word_2 + 1
.write_word_2
	lda $fc
	sta dynmem_pointer + 1
	tya
	taz
	pla
	sta [dynmem_pointer],z
	txa
	inz
	iny
	sta [dynmem_pointer],z
	dec .write_word_2 + 1
	rts

write_word_far_dynmem_zp_1 = .write_word + 1
write_word_far_dynmem_zp_2 = .write_word_2 + 1

} else { ; not TARGET_MEGA65

; This is not for C128 or MEGA65


!if SUPPORT_REU = 1 {
	bit use_reu
	bmi .reu_copy
}
	sta .copy + 2
	sty .copy + 5
	+disable_interrupts
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
	+enable_interrupts
	rts

!if SUPPORT_REU = 1 {
.reu_copy
	sty .load_dest_page + 1
	tay
	lda #0
	tax
	clc
	jsr store_reu_transfer_params
	lda #%10100000;  c64 -> REU with delayed execution
	sta reu_command
	+disable_interrupts
	+set_memory_all_ram_unsafe
	+before_dynmem_read
	lda $ff00
	sta $ff00
	+after_dynmem_read
	+set_memory_no_basic_unsafe

.load_dest_page
	ldy #00 ; This value is altered at the start of this routine
	sty reu_c64base + 1
	lda #%10100001;  REU -> c64 with delayed execution
	sta reu_command
	+set_memory_all_ram_unsafe
	+before_dynmem_read
	lda $ff00
	sta $ff00
	+after_dynmem_read
	+set_memory_no_basic_unsafe
	+enable_interrupts

	rts
}


} ; Not TARGET_MEGA65

} ; end zone

} ; not TARGET_C128
}



read_header_word
; y contains the address in the header
; Returns: Value in a,x
; y retains its original value
!ifdef FAR_DYNMEM {
	jsr setup_to_write_to_header_far_ram
	txa
	jmp read_word_from_far_dynmem
} else {
	iny
	lda story_start,y
	tax
	dey
	lda story_start,y
	rts
; }
}

write_header_word
; y contains the address in the header
; a,x contains word value
; a,x,y are destroyed
!ifdef FAR_DYNMEM {
	stx .tmp
	jsr setup_to_write_to_header_far_ram
	stx write_word_far_dynmem_zp_1
	stx write_word_far_dynmem_zp_2
	ldx .tmp
	jmp write_word_to_far_dynmem
} else {
	sta story_start,y
	iny
	txa
	sta story_start,y
	rts
; }
}

write_header_byte
; y contains the address in the header
; a contains byte value
; a,x,y are preserved
!ifdef TARGET_C128 {
	sta .tmp
	stx .tmp + 1
	jsr setup_to_write_to_header_far_ram
	stx $02b9
	ldx #$7f
	jsr $02af
	lda .tmp
	ldx .tmp + 1
	rts
} else {
!ifdef TARGET_MEGA65 {
	sty dynmem_pointer
	ldz #0
	stz dynmem_pointer + 1
	sta [dynmem_pointer],z
	rts
} else {
	sta story_start,y
	rts
}
}

!ifdef FAR_DYNMEM {
setup_to_write_to_header_far_ram
	ldx #<story_start_far_ram
	stx mem_temp
	ldx #>story_start_far_ram
	stx mem_temp + 1
	ldx #mem_temp
	rts

.tmp !byte 0, 0
}

