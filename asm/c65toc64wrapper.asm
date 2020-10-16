
basic_header
	;; Auto-detect C64/C65 mode and either way jump into the assembly
	!byte 0x1f,0x20,0xe4,0x07,0x8b,0xc2,0x28,0x34,0x34,0x29,0xb2
	!byte 0x38,0xa7,0x9e
	!pet "2081"
	!byte 0x3a,0xd5,0xfe,0x02,0x30,0x3a,0x9e
	!pet "8225"
	!byte 0x00,0x00,0x00
	

program_start
	;; Set the memory mode to that of the C64
	sei
	lda #$37
	sta $01
	lda #0
	tax
	tay
	taz
	map
	eom

	;; Enable fast CPU for quick depack
	lda #65
	sta 0
	;; Enable IO for DMA
	lda #$47
	sta $d02f
	lda #$53
	sta $d02f
	
	;; Copy a helper routine to $0380 that DMAs the
	;; memory down.
	lda 44
	cmp #$08
	beq in_c64_mode

in_c65_mode:

	ldx #$7f
-	lda transfer_routine,x
	sta $0380,x
	dex
	bpl -
	jmp $0380

in_c64_mode:	

	ldx #$7f
-	lda transfer_routine-$1800,x
	sta $0380,x
	dex
	bpl -
	jmp $0380


transfer_routine
	!pseudopc $0380 {

	;; Work out amount of shift for job, based on C64/C65 mode
	lda 44
	asl
	asl
	sec
	sbc 44
	sta $fd
	lda #$20
	sec
	sbc $fd
	sta dmalist_dst_msb

	;; Set 45/46 for C64 mode from C65 mode end of BASIC marker
	lda 44
	bne +
	lda $82
	sta 45
	lda $83
	sta 46
	lda #$01
	sta 43
	lda #$08
	sta 44
+
	;; Do transfer
	lda #0
	sta $0800 		; and clear $0800 if coming from C65 mode
	sta $d702
	lda #>dmalist
	sta $d701
	lda #<dmalist
	sta $d705

	;; Reset C64 mode KERNAL stuff
	jsr $fda3 ; init I/O
	jsr $fd15 ; set I/O vectors
	lda #>$0400 		; Make sure screen memory set to sensible location
	sta $0288		; before we call screen init $FF5B
	jsr $ff5b ; more init
	jsr $f7a9 ; C65 DOS reinit

	;; Enter programme
 	jmp 2061		
	
dmalist
	;; F011A job, source and dest in 1st MB
	!byte $0A,$80,$00,$81,$00,$00
	;; Single copy of $DFFF bytes
	!byte $00,$FF,$DF
	;; From 2 bytes past end of the wrapper, to skip wrapper and load address
	;; of the relocated programme
	!byte 2+<end_of_wrapper
dmalist_dst_msb
	!byte $20,$00
	;; To $0801
	!byte $01,$08,$00
	;; No modulo
	!byte 0,0
	
	}

end_of_wrapper

