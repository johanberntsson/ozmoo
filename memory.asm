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
	jsr fatalerror
	!pet "tried to access z-machine memory over 64kb", 0

read_word_at_z_address
	; Subroutine: Read the contents of a two consequtive byte addresses in the Z-machine
	; a,x,y (high, mid, low) contains first address.
	; Returns: values in a,x  (first byte, second byte)
	cmp #0
	bne .too_high
	sty mempointer
	txa
	clc
	adc #>story_start
	sta mempointer + 1
	ldy #1
	lda (mempointer),y
	tax
	dey
	lda (mempointer),y
	rts
}
}

read_byte_at_z_pc_then_inc
!zone {
	stx mem_temp
	sty mem_temp + 1
	lda z_pc	
	ldx z_pc + 1
	ldy z_pc + 2
	jsr read_byte_at_z_address
	inc z_pc + 2
	bne +
	inc z_pc + 1
	bne +
	inc z_pc
+	ldx mem_temp
	ldy mem_temp + 1
	rts
}

read_word_at_z_pc_then_inc
	; Returns: values in a,x  (first byte, second byte)
!zone {
	sty mem_temp  ; to be able to restore y when exiting
    lda z_pc	
    ldx z_pc + 1
	ldy z_pc + 2
	cpy #$ff
	beq .read_across_page_boundary
	jsr read_word_at_z_address
    inc z_pc + 2
	inc z_pc + 1
	bne +
	inc z_pc
+   inc z_pc + 2
	bne +
	inc z_pc + 1
	bne +
	inc z_pc
+	ldy mem_temp ; restore y
	rts
.read_across_page_boundary
	ldy #2 
	sty mem_temp + 1 ; loop counter
-   lda z_pc	
    ldx z_pc + 1
	ldy z_pc + 2
	jsr read_byte_at_z_address
	pha
    inc z_pc + 2
	bne +
	inc z_pc + 1
	bne +
	inc z_pc
+   dec mem_temp + 1
    bne -
    pla
    tax
    pla
	ldy mem_temp ; restore y
	rts
}
