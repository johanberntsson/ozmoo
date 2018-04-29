zmachine_pc	!byte 0, 0, 0

zmachine_init
!zone {
	lda story_start + header_initial_pc
	sta zmachine_pc + 1
	lda story_start + header_initial_pc + 1
	sta zmachine_pc + 2
	rts
}
