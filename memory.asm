; Routines to handle memory
read_zmachine_address
	; Subroutine: Read the contents of a byte address in the Z-machine
	; x,y (low, high) contains address
	stx .load + 1
	tya
	clc
	adc #<mem_start
	sta .load + 2
.load
	lda $8000
	rts

	