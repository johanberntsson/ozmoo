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

read_byte_at_z_pc_then_inc
!zone {
	stx mem_temp
	sty mem_temp + 1
	lda #0
	sta z_pc_mempointer_is_unsafe
	lda z_pc	
	ldx z_pc + 1
	ldy z_pc + 2
	jsr read_byte_at_z_address
	inc z_pc + 2
	bne +
	inc z_pc_mempointer_is_unsafe ; Signal that a page boundary was crossed
	inc z_pc + 1
	bne +
	inc z_pc
+	ldx mempointer + 1
	stx z_pc_mempointer + 1
	ldx mem_temp
	ldy mem_temp + 1
	rts
}

inc_z_pc_page
!zone {
	inc z_pc_mempointer_is_unsafe
	inc z_pc + 1
	bne +
	inc z_pc
+	rts
}
