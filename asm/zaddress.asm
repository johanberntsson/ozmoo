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

!ifdef TARGET_X16 {
x16_bank_z_address
	lda z_address + 1
	sta mempointer
	lda z_address
	sta mempointer + 1
	jsr x16_prepare_bankmem
	lda 0
	sta x16_z_address_bank
	lda mempointer
	sta x16_z_adress_pointer
	lda mempointer + 1
	sta x16_z_adress_pointer + 1
}
	rts

dec_z_address
	pha
	dec z_address + 2
	lda z_address + 2
	cmp #$ff
	bne +++ ; No re-banking necessary
	dec z_address + 1
	lda z_address + 1
	cmp #$ff
	bne +
	dec z_address
+
!ifdef TARGET_X16 {
	jsr x16_bank_z_address
}
+++
	pla
	rts

set_z_himem_address
	stx z_address + 2
	sta z_address + 1
	sty z_address
!ifdef TARGET_X16 {
	jmp x16_bank_z_address
} else {
	rts
}

skip_bytes_z_address
	; skip <a> bytes
	clc
	adc z_address + 2
	sta z_address + 2
	bcc +++ ; No re-banking necessary
	inc z_address + 1
	bne +
	inc z_address
+
!ifdef TARGET_X16 {
	jmp x16_bank_z_address
}
+++ rts

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

!ifdef TARGET_X16 {
	lda x16_z_address_bank
	sta 0
	ldy z_address + 2
	lda (x16_z_adress_pointer),y
} else {
	lda z_address
	ldx z_address + 1
	ldy z_address + 2
	jsr read_byte_at_z_address
}
	inc z_address + 2
	bne +++
	inc z_address + 1
	bne +
	inc z_address
+
!ifdef TARGET_X16 {
	pha
;	lda z_address + 1
;	and #%00011111
;	bne +
	jsr x16_bank_z_address
+	pla
}
+++	ldy z_address_temp
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
!ifdef TARGET_X16 {
	jmp x16_bank_z_address
} else {
	rts
}

write_next_byte
; input: value in a 
; a,x,y are preserved
	sta z_address_temp
!ifdef CHECK_ERRORS {
	lda z_address
	bne .write_outside_dynmem
	lda z_address + 2
	cmp dynmem_size
	lda z_address + 1
	sbc dynmem_size + 1
	bcs .write_outside_dynmem
}

!ifdef TARGET_X16 {
	txa
	pha
	tya
	pha

	lda x16_z_address_bank
	sta 0
	lda z_address_temp
	ldy z_address + 2
	sta (x16_z_adress_pointer),y

	pla
	tay
	pla
	tax
	lda z_address_temp
} else ifdef TARGET_C128 {
	txa
	pha
	tya
	pha
	lda z_address + 2
	sta mem_temp
	lda z_address + 1
	clc
	adc #>story_start_far_ram
	sta mem_temp + 1
	lda z_address_temp
	ldy #0
	+write_far_byte mem_temp
	pla
	tay
	pla
	tax
	lda z_address_temp
} else ifdef TARGET_MEGA65 {
	lda z_address + 2
	sta dynmem_pointer
	lda z_address + 1
	sta dynmem_pointer + 1
	ldz #0
	lda z_address_temp
	sta [dynmem_pointer],z
} else {
	; not TARGET_X16, TARGET_C128 or MEGA65
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
	bne +++
	inc z_address + 1
	bne +
	inc z_address
+
!ifdef TARGET_X16 {
	pha
	; lda z_address + 1
	; and #%00011111
	; bne +
	jsr x16_bank_z_address
+	pla
}
+++	rts

!ifdef CHECK_ERRORS {
.write_outside_dynmem
	lda #ERROR_WRITE_ABOVE_DYNMEM
	jsr fatalerror
}
	
	
} ; End zone zaddress
