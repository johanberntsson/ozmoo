; z_address !byte 0,0,0
; z_address_temp !byte 0
!ifdef Z7 {
string_offset !byte 0,0,0
routine_offset !byte 0,0,0
}


!zone zaddress {

set_z_address
	stx z_address + 2
	sta z_address + 1
	lda #$0
	sta z_address
	rts

dec_z_address
	pha
	dec z_address + 2
	lda z_address + 2
	cmp #$ff
	bne +
	dec z_address + 1
	lda z_address + 1
	cmp #$ff
	bne +
	dec z_address
+   pla
	rts

set_z_himem_address
	stx z_address + 2
	sta z_address + 1
	sty z_address
	rts

skip_bytes_z_address
	; skip <a> bytes
	clc
	adc z_address + 2
	sta z_address + 2
	bcc +
	inc z_address + 1
	bne +
	inc z_address
+   rts

!ifdef DEBUG {
print_z_address
	jsr dollar
	lda z_address + 1 ; low
	jsr print_byte_as_hex
	lda z_address + 2 ; high
	jsr print_byte_as_hex
	jmp newline
}

get_z_himem_address
	ldy z_address
	; fall through to get_z_address
get_z_address
	; input: 
	; output: a,x
	; side effects: 
	; used registers: a,x
	ldx z_address + 2 ; low
	lda z_address + 1 ; high
	rts

read_next_byte
	; input: 
	; output: a
	; side effects: z_address
	; used registers: a,x
	sty z_address_temp
	lda z_address
	ldx z_address + 1
	ldy z_address + 2
	jsr read_byte_at_z_address
	inc z_address + 2
	bne +
	inc z_address + 1
	bne +
	inc z_address
+   ldy z_address_temp
	rts

set_z_paddress
	; convert a/x to paddr in z_address
	; input: a,x
	; output: 
	; side effects: z_address
	; used registers: a,x
	; example: $031b -> $00, $0c, $6c (Z5)
	sta z_address + 1
	txa
	asl
	sta z_address + 2
	rol z_address + 1
	lda #$0
	rol
!ifdef Z4PLUS {
	asl z_address + 2
	rol z_address + 1
	rol
}
!ifdef Z8 {
	asl z_address + 2
	rol z_address + 1
	rol
}
	sta z_address
!ifdef Z7 {
	lda z_address + 2
	clc
	adc string_offset + 2
	sta z_address + 2
	lda z_address + 1
	adc string_offset + 1
	sta z_address + 1
	lda z_address
	adc string_offset
	sta z_address
}	
	rts

write_next_byte
; input: value in a 
; a,x,y are preserved
	sta z_address_temp
!ifndef UNSAFE {
	lda z_address
	bne .write_outside_dynmem
	lda z_address + 2
	cmp dynmem_size
	lda z_address + 1
	sbc dynmem_size + 1
	bcs .write_outside_dynmem
}

!ifdef TARGET_C128 {
	txa
	pha
	tya
	pha
	lda z_address + 2
	sta mem_temp
	lda z_address + 1
	clc
	adc #>story_start_bank_1
	sta mem_temp + 1
	ldx #mem_temp
	stx $02b9
	ldx #$7f
	ldy #0
	lda z_address_temp
	jsr $02af ; y has correct value already
	pla
	tay
	pla
	tax
	lda z_address_temp
} else { 
	; not TARGET_C128
	lda z_address + 2
	sta .write_byte + 1
	lda z_address + 1
	clc
	adc #>story_start
	sta .write_byte + 2
	lda z_address_temp
.write_byte
	sta $8000 ; This address is modified above
}

	inc z_address + 2
	bne +
	inc z_address + 1
	bne +
	inc z_address
+	rts

!ifndef UNSAFE {
.write_outside_dynmem
	lda #ERROR_WRITE_ABOVE_DYNMEM
	jsr fatalerror
}
	
	
} ; End zone zaddress
