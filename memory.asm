; Routines to handle memory

!ifndef USEVM {
!zone {
read_byte_at_z_address
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
    lda #ERROR_MEMORY_OVER_64KB
	jsr fatalerror

}
}

get_page_at_z_pc
!zone {
	stx mem_temp
	lda z_pc	
	ldx z_pc + 1
	ldy z_pc + 2
	jsr read_byte_at_z_address
	ldy mempointer + 1
	sty z_pc_mempointer + 1
	ldy #0 ; Important: y should always be 0 when exiting this routine!
	sty z_pc_mempointer_is_unsafe
	ldx mem_temp
	rts
}

inc_z_pc_page
!zone {
	inc z_pc_mempointer + 1
	inc z_pc + 1
	bne +
	inc z_pc
+	pha
	lda z_pc + 1
	and #255-vmem_blockmask
	beq .unsafe
	lda z_pc_mempointer + 1
	cmp #>story_start
	bcs .safe
.unsafe
	inc z_pc_mempointer_is_unsafe
.safe
	pla
	rts
}

set_z_pc
; Sets new value of z_pc, and figures out if z_pc_mempointer is still valid.
; Parameters: New value of z_pc in a,x,y
!zone {
	sty z_pc + 2
	cmp z_pc
	bne .unsafe_1
	cpx z_pc + 1
	beq + 
	; Different page. Let's find out if it's the same vmem block.
	txa
	eor z_pc + 1
	and #vmem_blockmask
	bne .unsafe_2
	; z_pc is in same vmem_block unless it's in vmem_cache
	lda z_pc_mempointer + 1
	cmp #>story_start
	bcc .unsafe_2
	; z_pc is in same vmem_block, but different page.
	stx z_pc + 1
!ifdef SMALLBLOCK {
	lda z_pc_mempointer + 1
	eor #1
	sta z_pc_mempointer + 1
} else {
	txa
	and #255-vmem_blockmask
	sta mem_temp
	lda z_pc_mempointer + 1
	and #vmem_blockmask
	clc
	adc mem_temp
	sta z_pc_mempointer + 1
}
+	rts
.unsafe_1
	sta z_pc
.unsafe_2
	stx z_pc + 1
	inc z_pc_mempointer_is_unsafe
	rts
}

