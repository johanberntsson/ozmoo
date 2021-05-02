; see: http://inform-fiction.org/zmachine/standards/z1point1/sect12.html

; globals
num_default_properties !byte 0
objects_start_ptr      !byte 0, 0

; object table opcodes
z_ins_get_sibling
	; get_sibling object -> (result) ?(label)
!ifndef Z4PLUS {
	lda #5
} else {
	lda #9
}
	bne .get_sibling_child ; Always branch

z_ins_get_child
	; get_child object -> (result) ?(label)
!ifndef Z4PLUS {
	lda #6
} else  {
	lda #11
}
.get_sibling_child
	; check if object is 0
	ldx z_operand_value_low_arr
	bne +
	ldx z_operand_value_high_arr
	bne +
	; object is 0, store 0 and return false
!ifdef DEBUG {
	jsr print_following_string
	!pet "WARNING: get_child called with object 0",13,0
}
	ldx #0
	lda #0
	jsr z_store_result
	jmp make_branch_false
+	pha
	ldx z_operand_value_low_arr
	lda z_operand_value_high_arr
	jsr calculate_object_address
	pla
	tay

	+before_dynmem_read
!ifndef Z4PLUS {

!ifdef TARGET_C128 {
	lda #object_tree_ptr
	sta $02aa
	ldx #$7f
	jsr $02a2
} else {
	lda (object_tree_ptr),y
}

	pha ; Value is zero if object is zero, non-zero if object is non-zero
	tax
	lda #0
} else  {

!ifdef TARGET_C128 {
	lda #object_tree_ptr
	dey
	jsr read_word_from_bank_1_c128
	stx object_temp
	tay
	ora object_temp
	pha
	tya
} else {
	lda (object_tree_ptr),y
	tax
	dey
	ora (object_tree_ptr),y
	pha ; Value is zero if object is zero, non-zero if object is non-zero
	lda (object_tree_ptr),y
}

}
	+after_dynmem_read

	jsr z_store_result
	pla ; Value is zero if object is zero, non-zero if object is non-zero
	bne .get_child_branch_true
	jmp make_branch_false
.get_child_branch_true
	jmp make_branch_true

z_ins_get_parent
	; get_parent object -> (result)
	ldx z_operand_value_low_arr
	lda z_operand_value_high_arr
	jsr calculate_object_address

	+before_dynmem_read
!ifndef Z4PLUS {
	ldy #4

!ifdef TARGET_C128 {
	lda #object_tree_ptr
	sta $02aa
	ldx #$7f
	jsr $02a2
} else {
	lda (object_tree_ptr),y
}

	tax
	lda #0
} else  {

!ifdef TARGET_C128 {
	ldy #6
	lda #object_tree_ptr
	jsr read_word_from_bank_1_c128
} else {
	ldy #7
	lda (object_tree_ptr),y
	tax
	dey
	lda (object_tree_ptr),y
}

}
	+after_dynmem_read
	jmp z_store_result

z_ins_get_prop_len
	; get_prop_len property-address -> (result)
	ldx z_operand_value_low_arr
	lda z_operand_value_high_arr
	cpx #0
	bne +
	cmp #0
	bne +
	; get_prop_len 0 must return 0
	jmp z_store_result
+   jsr set_z_address
	; z_address currently at start of prop data
	; need to back 1 step to the property length byte
	jsr dec_z_address
	jsr read_next_byte
!ifdef Z4PLUS {
	pha
	and #$80
	bne +
	; this is a 1-byte property block, check bit 6
	lda #1
	sta .property_length
	pla
	and #$40
	beq ++
	inc .property_length
	bne ++ ; always jump
+   ; this is byte 2 of a 2-byte property block
	pla
	and #$3f
	sta .property_length
	bne ++
	lda #64
	sta .property_length
} else {
	lsr
	lsr
	lsr
	lsr
	lsr
	sta .property_length
	inc .property_length
}
++  ldx .property_length
	lda #0
	jmp z_store_result

.zp_object = zp_mempos
.zp_parent = object_tree_ptr  ; won't be used at the same time
.zp_sibling = object_tree_ptr ; won't be used at the same time
.zp_dest = object_tree_ptr    ; won't be used at the same time
; .object_num !byte 0,0
.parent_num !byte 0,0
.child_num !byte 0,0
.sibling_num !byte 0,0        ; won't be used at the same time
.dest_num = .sibling_num      ; won't be used at the same time

z_ins_remove_obj
	; remove_obj object
z_ins_remove_obj_body
	; get object number
	ldx z_operand_value_low_arr
	lda z_operand_value_high_arr
	sta object_num
	stx object_num + 1
	; find object in dynmem
	;lda object_num
	;ldx object_num + 1
	jsr calculate_object_address
	lda object_tree_ptr
	sta .zp_object
	lda object_tree_ptr + 1
	sta .zp_object + 1
	
	; get parent number
	+before_dynmem_read
!ifdef Z4PLUS {
	ldy #6  ; parent

!ifdef TARGET_C128 {
	lda #.zp_object
	jsr read_word_from_bank_1_c128
	sta .parent_num
	stx .parent_num + 1
} else {
	lda (.zp_object),y
	sta .parent_num
	iny
	lda (.zp_object),y
	sta .parent_num + 1
}

} else {
	ldy #4  ; parent
	lda #0
	sta .parent_num

!ifdef TARGET_C128 {
	lda #.zp_object
	sta $02aa
	ldx #$7f
	jsr $02a2
} else {
	lda (.zp_object),y
}

	sta .parent_num + 1
}
	+after_dynmem_read

	; is there a parent?
	lda .parent_num
	ora .parent_num + 1
	bne .has_parent
	; no parent, nothing to do
	jmp .remove_obj_done
.has_parent
	; yes, there is a parent...
	; find parent in dynmen
	lda .parent_num
	ldx .parent_num + 1
	jsr calculate_object_address

	; get child number
	+before_dynmem_read
!ifdef Z4PLUS {
	ldy #10  ; child

!ifdef TARGET_C128 {
	lda #.zp_parent
	jsr read_word_from_bank_1_c128
	sta .child_num
	stx .child_num + 1
} else {
	lda (.zp_parent),y
	sta .child_num
	iny
	lda (.zp_parent),y
	sta .child_num + 1
}

} else {
	ldy #6  ; child
	lda #0
	sta .child_num

!ifdef TARGET_C128 {
	lda #.zp_parent
	sta $02aa
	ldx #$7f
	jsr $02a2
} else {
	lda (.zp_parent),y
}

	sta .child_num + 1
}
	+after_dynmem_read

	; child_num == object_num?
	lda .child_num
	cmp object_num
	bne .not_child
	lda .child_num + 1
	cmp object_num + 1
	bne .not_child
	
	; object is the child of parent
	; set child of parent to object's sibling

	+before_dynmem_read
!ifdef Z4PLUS {
	ldy #8  ; sibling

!ifdef TARGET_C128 {
	lda #.zp_object
	jsr read_word_from_bank_1_c128
	ldy #.zp_parent
	sty write_word_c128_zp_1
	sty write_word_c128_zp_2
	ldy #10
	jsr write_word_to_bank_1_c128
} else {
	lda (.zp_object),y
	pha
	iny
	lda (.zp_object),y
	ldy #11  ; child+1
	sta (.zp_parent),y
	dey
	pla
	sta (.zp_parent),y
}

} else {
	ldy #5  ; sibling

!ifdef TARGET_C128 {
	lda #.zp_object
	sta $02aa
	ldx #$7f
	jsr $02a2
} else {
	lda (.zp_object),y
}

	ldy #6  ; child

!ifdef TARGET_C128 {
	ldx #.zp_parent
	stx $02b9
	ldx #$7f
	jsr $02af
} else {
	sta (.zp_parent),y
}

}
	+after_dynmem_read

	jmp .remove_obj_done
.not_child
	; find sibling in dynmen
	lda .child_num
	ldx .child_num + 1
	sta .sibling_num
	stx .sibling_num + 1

	+before_dynmem_read
-
	lda .sibling_num
	ldx .sibling_num + 1
	jsr calculate_object_address

	; get next sibling number
!ifdef Z4PLUS {
	ldy #8  ; sibling

!ifdef TARGET_C128 {
	lda #.zp_sibling
	jsr read_word_from_bank_1_c128
	sta .sibling_num
	stx .sibling_num + 1
} else {
	lda (.zp_sibling),y
	sta .sibling_num
	iny
	lda (.zp_sibling),y
	sta .sibling_num + 1
}

} else {
	ldy #5  ; sibling
	lda #0
	sta .sibling_num

!ifdef TARGET_C128 {
	lda #.zp_sibling
	sta $02aa
	ldx #$7f
	jsr $02a2
} else {
	lda (.zp_sibling),y
}

	sta .sibling_num + 1
}

	; while sibling != object
	lda .sibling_num
	cmp object_num
	bne -
	lda .sibling_num + 1
	cmp object_num + 1
	bne -

	; .zp_sibling.sibling == object. set to object.sibling instead
!ifdef Z4PLUS {
	ldy #8  ; sibling

!ifdef TARGET_C128 {
	lda #.zp_sibling
	sta write_word_c128_zp_1
	sta write_word_c128_zp_2
	lda #.zp_object
	jsr read_word_from_bank_1_c128
	jsr write_word_to_bank_1_c128
} else {
	lda (.zp_object),y
	sta (.zp_sibling),y
	iny
	lda (.zp_object),y
	sta (.zp_sibling),y
}

} else {
	ldy #5  ; sibling

!ifdef TARGET_C128 {
	lda #.zp_object
	sta $02aa
	ldx #$7f
	jsr $02a2
	ldx #.zp_sibling
	stx $02b9
	ldx #$7f
	jsr $02af
} else {
	lda (.zp_object),y
	sta (.zp_sibling),y
}


}
	+after_dynmem_read

.remove_obj_done
	; always set obj.parent and obj.sibling to 0
	lda #0
!ifdef Z4PLUS {
	ldy #6  ; parent

!ifdef TARGET_C128 {
	lda #.zp_object
	sta write_word_c128_zp_1
	sta write_word_c128_zp_2
	lda #0
	tax
	jsr write_word_to_bank_1_c128 ; increases y by 1
	lda #0
	tax
	iny ; sibling (8)
	jsr write_word_to_bank_1_c128
} else {
	sta (.zp_object),y
	iny
	sta (.zp_object),y
	iny ; sibling (8)
	sta (.zp_object),y
	iny
	sta (.zp_object),y
}


} else {
	ldy #4  ; parent

!ifdef TARGET_C128 {
	lda #.zp_object
	sta write_word_c128_zp_1
	sta write_word_c128_zp_2
	lda #0
	tax
	jmp write_word_to_bank_1_c128 ; increases y by 1
} else {
	sta (.zp_object),y
	iny ; sibling (5)
	sta (.zp_object),y
}

}
	rts

find_attr
	; find attribute
	; output: 
	;   y = index to attribute byte relative object_tree_ptr
	;   x = bit to set/clear, use .bitmask)
	;   x and y also stored in .bitmask_index and .attribute_index
	; need to call evaluate_all_args before find_attr
	ldx z_operand_value_low_arr
	lda z_operand_value_high_arr
	jsr calculate_object_address
	lda z_operand_value_low_arr + 1
	; ignore high_arr. Max 48 attributes
	and #$07
	sta .bitmask_index
	tax
	lda z_operand_value_low_arr + 1
	lsr
	lsr
	lsr
	tay
	sta .attribute_index
	rts
.bitmask !byte 128,64,32,16,8,4,2,1
.bitmask_index !byte 0
.attribute_index !byte 0

z_ins_print_obj
	; print_obj object
	ldx z_operand_value_low_arr
	lda z_operand_value_high_arr
;	jmp print_obj ; Not needed since print_obj follows just after

print_obj
	jsr calculate_object_address

!ifdef Z4PLUS {
	ldy #13
} else {
	ldy #8
}

	+before_dynmem_read
!ifdef TARGET_C128 {
	dey
	lda #object_tree_ptr
	jsr read_word_from_bank_1_c128
} else {
	lda (object_tree_ptr),y ; low byte
	tax
	dey
	lda (object_tree_ptr),y ; high byte
}
	+after_dynmem_read

	jsr set_z_address
	jsr read_next_byte ; length of object short name
	jmp print_addr

z_ins_jin
	; jin obj1 obj2 ?(label)
	ldx z_operand_value_low_arr
	lda z_operand_value_high_arr
	jsr calculate_object_address

	+before_dynmem_read
!ifndef Z4PLUS {
	ldy #4  ; parent

!ifdef TARGET_C128 {
	lda #object_tree_ptr
	sta $02aa
	ldx #$7f
	jsr $02a2
} else {
	lda (object_tree_ptr),y
}

	cmp z_operand_value_low_arr + 1
	bne .branch_false
	beq .branch_true
} else {
	ldy #6  ; parent

!ifdef TARGET_C128 {
	lda #object_tree_ptr
	jsr read_word_from_bank_1_c128
	cmp z_operand_value_high_arr + 1
	bne .branch_false
	cpx z_operand_value_low_arr + 1
} else {
	lda (object_tree_ptr),y
	cmp z_operand_value_high_arr + 1
	bne .branch_false
	iny
	lda (object_tree_ptr),y
	cmp z_operand_value_low_arr + 1
}

	bne .branch_false
	beq .branch_true ; Always branch
}

z_ins_test_attr
	; test_attr object attribute ?(label)
	jsr find_attr

	+before_dynmem_read
!ifdef TARGET_C128 {
	lda #object_tree_ptr
	sta $02aa
	ldx #$7f
	jsr $02a2
	ldx .bitmask_index
} else {
	lda (object_tree_ptr),y
}
	and .bitmask,x
	beq .branch_false
.branch_true 
	+after_dynmem_read
	jmp make_branch_true
.branch_false
	+after_dynmem_read
	jmp make_branch_false

z_ins_set_attr
	; set_attr object attribute
	; don't continue if object = 0
	lda z_operand_value_low_arr
	bne .do_set_attr
	lda z_operand_value_high_arr
	beq .done
.do_set_attr
	jsr find_attr
	+before_dynmem_read
!ifdef TARGET_C128 {
	lda #object_tree_ptr
	sta $02aa
	sta $02b9
	ldx #$7f
	jsr $02a2
	sta object_temp
	ldx .bitmask_index
	and .bitmask,x
	bne +
	lda object_temp
	ora .bitmask,x
	ldx #$7f
	jmp $02af
} else {
	lda (object_tree_ptr),y
	ora .bitmask,x
	sta (object_tree_ptr),y
}
+
	+after_dynmem_read
.done
	rts

z_ins_clear_attr
	; clear_attr object attribute
	; don't continue if object = 0
	lda z_operand_value_low_arr
	bne .do_clear_attr
	lda z_operand_value_high_arr
	beq .done
.do_clear_attr
	jsr find_attr
	+before_dynmem_read
!ifdef TARGET_C128 {
	lda #object_tree_ptr
	sta $02aa
	sta $02b9
	ldx #$7f
	jsr $02a2
	sta object_temp
	ldx .bitmask_index
	and .bitmask,x
	beq +
	lda object_temp
	eor .bitmask,x
	ldx #$7f
	jmp $02af
} else {
	lda (object_tree_ptr),y
	and .bitmask,x
	beq +
	lda (object_tree_ptr),y
	eor .bitmask,x
	sta (object_tree_ptr),y
}
+
	+after_dynmem_read
	rts

z_ins_insert_obj
	; insert_obj object destination
	jsr z_ins_remove_obj_body ; will set .zp_object and object_num
	; calculate destination address
	ldx z_operand_value_low_arr + 1
	lda z_operand_value_high_arr + 1
	jsr calculate_object_address
	lda object_tree_ptr
	sta .zp_dest
	lda object_tree_ptr + 1
	sta .zp_dest + 1
	; get destination number
	ldx z_operand_value_low_arr + 1
	lda z_operand_value_high_arr + 1
	sta .dest_num
	stx .dest_num + 1
!ifdef Z4PLUS {
	; object.parent = destination
	ldy #6 ; parent

	+before_dynmem_read
!ifdef TARGET_C128 {
	lda #.zp_object
	sta write_word_c128_zp_1
	sta write_word_c128_zp_2
	lda .dest_num
	ldx .dest_num + 1
	jsr write_word_to_bank_1_c128 ; increases y by 1
	ldy #10 ; child
	lda #.zp_dest
	jsr read_word_from_bank_1_c128
	ldy #8
	jsr write_word_to_bank_1_c128 ; increases y by 1
	lda #.zp_dest
	sta write_word_c128_zp_1
	sta write_word_c128_zp_2
	lda object_num
	ldx object_num + 1
	ldy #10
	+after_dynmem_read
	jmp write_word_to_bank_1_c128 ; increases y by 1
} else {
	lda .dest_num
	sta (.zp_object),y
	iny
	lda .dest_num + 1
	sta (.zp_object),y
	; object.sibling = destination.child
	ldy #10 ; child
	lda (.zp_dest),y
	pha
	iny
	lda (.zp_dest),y
	ldy #9 ; sibling + 1
	sta (.zp_object),y
	dey
	pla
	sta (.zp_object),y
	; destination.child = object
	ldy #10 ; child
	lda object_num
	sta (.zp_dest),y
	iny
	lda object_num + 1
	sta (.zp_dest),y
	+after_dynmem_read
	rts
}

} else {

!ifdef TARGET_C128 {
	; object.parent = destination
	lda #.zp_object
	sta $02b9
	ldx #$7f
	ldy #4 ; parent
	lda .dest_num + 1
	jsr $02af
	; object.sibling = destination.child
	lda #.zp_dest
	sta $02aa
	ldy #6; child
	ldx #$7f
	jsr $02a2
	dey
	ldx #$7f
	jsr $02af
	; destination.child = object
	lda #.zp_dest
	sta $02b9
	ldy #6 ; child
	lda object_num + 1
	ldx #$7f
	+after_dynmem_read
	jmp $02af
	
} else {
	; object.parent = destination
	ldy #4 ; parent
	lda .dest_num + 1
	sta (.zp_object),y
	; object.sibling = destination.child
	ldy #6; child
	lda (.zp_dest),y
	dey ; sibling (4)
	sta (.zp_object),y
	; destination.child = object
	ldy #6 ; child
	lda object_num + 1
	sta (.zp_dest),y
	+after_dynmem_read
	rts
}

}

calculate_property_length_number
	; must call set_z_address before this subroutine
	; output: updates .property_number, .property_length
	; .property_length = 0 if end of property list
	lda #0
	sta .property_number
	sta .property_length
	jsr read_next_byte ; size of property block (# data | property number)
	cmp #0 ; can't trust the zero flag after a call to read_next_byte
	beq .end_pf_property_list
!ifdef Z4PLUS {
	pha
	and #$3f ; property number
	sta .property_number
	pla
	pha
	and #$80
	bne .two_bytes
	lda #1
	sta .property_length
	pla
	and #$40
	beq +
	inc .property_length
+   rts
.two_bytes
	pla ; we don't care about byte 1, bit 6 anymore
	jsr read_next_byte ; property_length
	and #$3f ; property number
	sta .property_length
	bne .end_pf_property_list
	lda #64
	sta .property_length
} else {
	pha
	and #$1f ; property number
	sta .property_number
	pla
	lsr
	lsr
	lsr
	lsr
	lsr
	sta .property_length
	inc .property_length
}
.end_pf_property_list
	rts
.property_number !byte 0
.property_length !byte 0

find_first_prop
	; output: z_address is set to property block, or 0,0 if not set in obj
	ldx z_operand_value_low_arr
	lda z_operand_value_high_arr
	jsr calculate_object_address
!ifdef Z4PLUS {
	ldy #13
} else {
	ldy #8
}

	+before_dynmem_read
!ifdef TARGET_C128 {
	dey
	lda #object_tree_ptr
	jsr read_word_from_bank_1_c128
} else {
	lda (object_tree_ptr),y ; low byte
	tax
	dey
	lda (object_tree_ptr),y ; high byte
}
	+after_dynmem_read

	pha ; a is destroyed by set_z_address
	jsr set_z_address
	pla
	bne +
	cpx #0
	bne +
	rts ; 0,0: no prop block exists, do nothing
+	jsr read_next_byte ; length of object short name (# of zchars)
	; skip short name (2 * bytes, since in words)
	pha ; a is destroyed by skip_bytes_z_address
	jsr skip_bytes_z_address
	pla
	jmp skip_bytes_z_address

find_prop
	; call find_first_prop before calling find_prop
	; output: x,a = address to property block, or 0,0 if not found
	; (also stored in .find_prop_result)
	; loop over the properties until the correct one found
	jsr get_z_address
	bne .property_loop
	cpx #0
	beq .find_prop_not_found ; 0,0: not a valid property block
.property_loop
	jsr calculate_property_length_number
	lda .property_number
	cmp z_operand_value_low_arr + 1; max 63 properties so only low_arr
	beq .find_prop_found
	bcc .find_prop_not_found
	; skip property data
	lda .property_length
	jsr skip_bytes_z_address
	jmp .property_loop
.find_prop_not_found
	ldx #0
	lda #0
	stx .find_prop_result
	sta .find_prop_result + 1
	rts
.find_prop_found
	jsr get_z_address
	stx .find_prop_result
	sta .find_prop_result + 1
	rts
.find_prop_result !byte 0,0 ; x,a

z_ins_get_prop
	; get_prop object property -> (result)
	jsr find_first_prop
	jsr find_prop
	cmp #0
	bne .property_found
	; no property found, get default property
	lda z_operand_value_low_arr + 1; max 63 properties so only low_arr
	asl ; default property is words (2 bytes each)
	tay
	dey

	+before_dynmem_read
!ifdef TARGET_C128 {
	dey
	lda #default_properties_ptr
	jsr read_word_from_bank_1_c128
} else {
	lda (default_properties_ptr),y
	tax
	dey
	lda (default_properties_ptr),y
}
	+after_dynmem_read	
	jmp .return_property_result
.property_found
	lda .property_length
	cmp #1
	bne .not_one
	; property length is 1
	jsr read_next_byte
	tax
	lda #0
	jmp .return_property_result
.not_one
	; property length is 2
	jsr read_next_byte
	pha
	jsr read_next_byte
	tax
	pla
.return_property_result
	jmp z_store_result
!ifndef UNSAFE {
.bad_prop_len
	; error. only 1 or 2 allowed
	lda #ERROR_BAD_PROPERTY_LENGTH
	jsr fatalerror
}

z_ins_get_prop_addr
	; get_prop_addr object property -> (result)
	jsr find_first_prop
	jsr find_prop
	jmp z_store_result

z_ins_get_next_prop
	; get_next_prop object property -> (result)
	jsr find_first_prop
	ldx z_operand_value_low_arr + 1
	beq + ; property == 0, return first property number
	; find the property, and return next number
	jsr find_prop
	; skip property data
-   jsr read_next_byte
	dec .property_length
	bne -
+   jsr calculate_property_length_number
	ldx .property_number
	lda #0
	jmp z_store_result

z_ins_put_prop
	; put_prop object property value
	jsr find_first_prop
	jsr find_prop
	jsr set_z_address
	
	; stx zp_mempos
	; clc
	; adc #>story_start
	; sta zp_mempos + 1
	lda .property_length
	cmp #1
	beq .write_byte
!ifndef UNSAFE {
	cmp #2
	bne .bad_prop_len
}
	lda z_operand_value_high_arr + 2
	jsr write_next_byte
.write_byte
	lda z_operand_value_low_arr + 2
	jmp write_next_byte
	; ldy #0
	; sta (zp_mempos),y
	; rts
; .write_word   
	
	; ldy #0
	; lda z_operand_value_high_arr + 2
	; sta (zp_mempos),y
	; iny 
	; lda z_operand_value_low_arr + 2
	; sta (zp_mempos),y
	; rts

parse_object_table
	ldy #header_object_table
	jsr read_header_word
	; property defaults table
	stx default_properties_ptr
	clc
!ifdef TARGET_C128 {
	adc #>story_start_bank_1
} else {
	adc #>story_start
}
	sta default_properties_ptr + 1
!ifndef Z4PLUS {
	lda #62 ; 31 words
}
!ifdef Z4PLUS {
	lda #126 ; 63 words
}
	sta num_default_properties
	; store start of objects
	clc
	adc default_properties_ptr
	tay
	lda default_properties_ptr + 1
	adc #0
	tax
	tya
	sec
!Ifdef Z3 {
	sbc #9
} else {
	sbc #14
}
	sta objects_start_ptr
	txa
	sbc #0
	sta objects_start_ptr + 1
	rts

calculate_object_address
	; subroutine: calculate address for object
	; input: a,x object index (high/low)
	; output: object address in object_tree_ptr
	; used registers: a,x,y
	; side effects:
!ifdef Z3 {
	; To get address, multiply by 9 (Calculate 8 * obj# + obj#)
;	dex ;  (object_start_ptr points 9 bytes before first obj, so no need for dex)

	stx object_tree_ptr
	lda #0
	sta object_tree_ptr + 1
	txa
	asl ; * 2
	rol object_tree_ptr + 1 ; * 2
	asl ; * 4
	rol object_tree_ptr + 1 ; * 4
	asl ; * 8
	rol object_tree_ptr + 1 ; * 8
	adc object_tree_ptr ; C is already 0
	tax
	lda object_tree_ptr + 1
	adc #0

	; Object offset is now in a,x (high, low). Just need to add start address of object 0
	; Ofcourse object 0 doesn't exist, but objects_start_ptr points to it, to make calculations faster
	tay
	txa
	adc objects_start_ptr
	sta object_tree_ptr
	tya
	adc objects_start_ptr + 1
	sta object_tree_ptr + 1
	
} else {
	; To get address, multiply by 14 (Calculate (8 * obj# - obj#) * 2)
;	dex ;  (object_start_ptr points 14 bytes before first obj, so no need for dex)
;	cpx #$ff
;	bne +
;	sbc #1
;+	
	stx object_temp
	sta object_temp + 1
	sta object_tree_ptr + 1
	txa
	asl ; * 2
	rol object_tree_ptr + 1
	asl ; * 4
	rol object_tree_ptr + 1
	asl ; * 8
	rol object_tree_ptr + 1
	sec
	sbc object_temp ; * 7
	tax
	lda	object_tree_ptr + 1
	sbc object_temp + 1
	sta object_tree_ptr + 1
	txa
	asl ; * 14
	rol object_tree_ptr + 1
	
	; Object offset is now in (object_tree_ptr + 1),a (high, low). Just need to add start address of object 0
	; Ofcourse object 0 doesn't exist, but objects_start_ptr points to it, to make calculations faster
	adc objects_start_ptr
	sta object_tree_ptr
	lda object_tree_ptr + 1
	adc objects_start_ptr + 1
	sta object_tree_ptr + 1
}
	rts
	
