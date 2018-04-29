; Routines to handle memory
read_byte_at_zmachine_address
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
	!pet "Tried to access Z-machine memory over 64KB", 0
	
}
	
read_byte_at_zmachine_pc_then_inc
!zone {
	lda zmachine_pc
	ldx zmachine_pc + 1
	ldy zmachine_pc + 2
	jsr read_byte_at_zmachine_address
	inc zmachine_pc + 2
	bne +
	inc zmachine_pc + 1
	bne +
	inc zmachine_pc
+	rts
}
