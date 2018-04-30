; Routines to handle memory

!ifndef USEVM {
read_byte_at_z_address
!zone {
	; Subroutine: Read the contents of a byte address in the Z-machine
	; a,x,y (high, mid, low) contains address
	cmp #0
	bne .too_high
	sty .load + 1
	txa
	clc
	adc #>story_start
	sta .load + 2
.load
	lda $8000
	rts
.too_high
	jsr fatalerror
	!pet "tried to access z-machine memory over 64kb", 0
}
}

read_byte_at_z_pc_then_inc
!zone {
	lda z_pc
	ldx z_pc + 1
	ldy z_pc + 2
!ifdef USEVM {
	jsr vm_read_byte_at_z_address
} else {
	jsr read_byte_at_z_address
}
	inc z_pc + 2
	bne +
	inc z_pc + 1
	bne +
	inc z_pc
+	rts
}
