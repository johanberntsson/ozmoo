; object table
; see: http://inform-fiction.org/zmachine/standards/z1point1/sect12.html

;TRACE_GETPSC = 1 ; trace get_parent, get_sibling, get_child
;TRACE_OBJ = 1 ; trace remove_obj, jin, insert_obj
;TRACE_ATTR = 1 ; trace find_attr, set_attr, clear_attr
TRACE_PROP = 1  ; trace get_prop_len, 

; globals
num_default_properties !byte 0
objects_start_ptr      !byte 0, 0

; object table opcodes
z_ins_get_sibling
    ; get_sibling object -> (result) ?(label)
!ifdef TRACE_GETPSC {
    jsr print_following_string
    !pet "get_sibling obj: ",0
}
!ifndef Z4PLUS {
    lda #5
} else {
    lda #8
}
	bne .get_parent_sibling_child ; Always branch

z_ins_get_child
    ; get_child object -> (result) ?(label)
!ifdef TRACE_GETPSC {
    jsr print_following_string
    !pet "get_child obj: ",0
}
!ifndef Z4PLUS {
    lda #6
} else  {
    lda #11
}
.get_parent_sibling_child
	pha
    jsr evaluate_all_args
!ifdef TRACE_GETPSC {
    ldx z_operand_value_low_arr
    jsr printx
    jsr space
}
    ldx z_operand_value_low_arr
    lda z_operand_value_high_arr
    jsr calculate_object_address
	pla
	tay
!ifndef Z4PLUS {
    lda (object_tree_ptr),y
	pha ; Value is zero if object is zero, non-zero if object is non-zero
    tax
    lda #0
} else  {
    lda (object_tree_ptr),y
    tax
	dey
    ora (object_tree_ptr),y
	pha ; Value is zero if object is zero, non-zero if object is non-zero
    lda (object_tree_ptr),y
}
!ifdef TRACE_GETPSC {
    pha
    txa
    pha
    jsr printx
    jsr newline
    pla
    tax
    pla
}
    jsr z_store_result
	pla ; Value is zero if object is zero, non-zero if object is non-zero
	bne .get_child_branch_true
	jmp make_branch_false
.get_child_branch_true
	jmp make_branch_true

z_ins_get_parent
    ; get_parent object -> (result)
!ifdef TRACE_GETPSC {
    jsr print_following_string
    !pet "get_parent obj: ",0
}
!ifndef Z4PLUS {
    lda #4
} else {
    lda #6
}
	pha
    jsr evaluate_all_args
!ifdef TRACE_GETPSC {
    ldx z_operand_value_low_arr
    jsr printx
    jsr space
}
    ldx z_operand_value_low_arr
    lda z_operand_value_high_arr
    jsr calculate_object_address
	pla
	tay
!ifndef Z4PLUS {
    lda (object_tree_ptr),y
    tax
    lda #0
} else  {
    lda (object_tree_ptr),y
    tax
    lda (object_tree_ptr),y
}
!ifdef TRACE_GETPSC {
    pha
    txa
    pha
    jsr printx
    jsr newline
    pla
    tax
    pla
}
    jmp z_store_result

z_ins_get_prop_len
    ; get_prop_len property-address -> (result)
    jsr evaluate_all_args
!ifdef TRACE_PROP {
    jsr print_following_string
    !pet "get_prop_len property-address: ",0
    ldx z_operand_value_low_arr
    jsr printx
    jsr space
    ldx z_operand_value_high_arr
    jsr printx
    jsr newline
}
    ldx z_operand_value_low_arr
    bne +
    lda z_operand_value_high_arr
    bne +
    ; get_prop_len 0 must return 0
    jmp z_store_result
+   jsr set_z_address
    jsr calculate_property_length_number
    ldx .property_length
    lda #0
    jmp z_store_result

z_ins_remove_obj
    ; remove_obj object
    jsr evaluate_all_args
!ifdef TRACE_OBJ {
    jsr print_following_string
    !pet "remove_obj object: ", 13, 0
}
    ldx z_operand_value_low_arr
    lda z_operand_value_high_arr
    jsr calculate_object_address
    lda object_tree_ptr
    sta zp_mempos
    lda object_tree_ptr + 1
    sta zp_mempos + 1
!ifndef Z4PLUS {
    ; get parent
    ldy #4  ; parent
    lda (zp_mempos),y
    bne +
    ; no parent, so no action
    rts
+   tax
    lda #0
    sta (zp_mempos),y ; set obj.parent = null
    jsr calculate_object_address
    ldy #6  ; child
    lda (object_tree_ptr),y
    cmp z_operand_value_low_arr 
    bne +
    ; set parent.child = obj.sibling
    ldy #5 ; sibling
    lda (zp_mempos),y
    iny
    sta (object_tree_ptr),y
    rts
+   ; look for obj in sibling chain
    ; a = parent.child, a != obj
-   tax
    lda #0
    jsr calculate_object_address
    ldy #5 ; sibling
    lda (object_tree_ptr),y
    cmp z_operand_value_low_arr 
    bne -
    ; found obj in the sibling list
    lda (zp_mempos),y            ; obj.sibling
    lda (object_tree_ptr),y 
    lda #0
    sta (zp_mempos),y            ; obj.sibling = null
    rts
}
!ifdef Z4PLUS {
    jsr fatalerror
    !pet "TODO z_ins_remove_obj Z4-Z8", 13, 0
}

find_attr
    ; find attribute
    ; output: 
    ;   y = index to attribute byte relative object_tree_ptr
    ;   x = bit to set/clear, use .bitmask)
    jsr evaluate_all_args
    ldx z_operand_value_low_arr
    lda z_operand_value_high_arr
    jsr calculate_object_address
!ifdef TRACE_ATTR {
    ldx z_operand_value_low_arr
    jsr printx
    lda #40 ; (
    jsr kernel_printchar
    ldx object_tree_ptr
    jsr printx
    lda #44 ; ,
    jsr kernel_printchar
    ldx object_tree_ptr + 1
    jsr printx
    lda #41 ; )
    jsr kernel_printchar
    ldx z_operand_value_low_arr + 1
    jsr printx
    jsr space
}
    lda z_operand_value_low_arr + 1
    ; ignore high_arr. Max 48 attributes
    and #$07
    tax
!ifdef TRACE_ATTR {
    lda #$78 ; X
    jsr kernel_printchar
    jsr printx
    jsr space
}
    lda z_operand_value_low_arr + 1
    lsr
    lsr
    lsr
    tay
!ifdef TRACE_ATTR {
    txa
    pha
    lda #$79 ; Y
    jsr kernel_printchar
    jsr printy
    jsr space
    pla
    tax
}
    rts
.bitmask !byte 128,64,32,16,8,4,2,1

z_ins_print_obj
    ; print_obj object
    jsr evaluate_all_args
    ldx z_operand_value_low_arr
    lda z_operand_value_high_arr
    jsr calculate_object_address
!ifndef Z4PLUS {
    ldy #8
}
!ifdef Z4PLUS {
    ldy #13
}
    lda (object_tree_ptr),y ; low byte
    tax
    dey
    lda (object_tree_ptr),y ; high byte
    jsr set_z_address
    jsr read_next_byte ; length of object short name
    jmp print_addr

z_ins_jin
    ; jin obj1 obj2 ?(label)
!ifdef TRACE_OBJ {
    jsr print_following_string
    !pet "jin obj1 obj2: ", 13, 0
}
    jsr evaluate_all_args
    ldx z_operand_value_low_arr
    lda z_operand_value_high_arr
    jsr calculate_object_address
!ifndef Z4PLUS {
    ldy #4  ; parent
    lda (object_tree_ptr),y
    cmp z_operand_value_low_arr + 1
    bne .branch_false
    beq .branch_true
}
!ifdef Z4PLUS {
    ldy #6  ; parent
    lda (object_tree_ptr),y
    cmp z_operand_value_low_arr + 1
    bne .branch_false
    iny
    lda (object_tree_ptr),y
    cmp z_operand_value_high_arr + 1
    bne .branch_false
    beq .branch_true
}

z_ins_test_attr
    ; test_attr object attribute ?(label)
!ifdef TRACE_ATTR {
    jsr print_following_string
    !pet "test_attr obj attr: ",0
}
    jsr find_attr
    lda (object_tree_ptr),y
!ifdef TRACE_ATTR {
    jsr printa
    jsr space
}
    and .bitmask,x
    beq .branch_false
.branch_true 
!ifdef TRACE_ATTR {
    jsr print_following_string
    !pet "true",13,0
}
    jmp make_branch_true
.branch_false
!ifdef TRACE_ATTR {
    jsr print_following_string
    !pet "false",13,0
}
   jmp make_branch_false

z_ins_set_attr
    ; set_attr object attribute
!ifdef TRACE_ATTR {
    jsr print_following_string
    !pet "set_attr object attr: ", 0
}
    jsr find_attr
    lda (object_tree_ptr),y
!ifdef TRACE_ATTR {
    jsr printa
    jsr space
}
    ora .bitmask,x
    sta (object_tree_ptr),y
!ifdef TRACE_ATTR {
    jsr printa
    jsr newline
}
    rts

z_ins_clear_attr
    ; clear_attr object attribute
!ifdef TRACE_ATTR {
    jsr print_following_string
    !pet "clear_attr object attr: ", 0
}
    jsr find_attr
    lda (object_tree_ptr),y
!ifdef TRACE_ATTR {
    jsr printa
    jsr space
}
    and .bitmask,x
    beq +
    lda (object_tree_ptr),y
    eor .bitmask,x
    sta (object_tree_ptr),y
+
!ifdef TRACE_ATTR {
    jsr printa
    jsr newline
}
    rts

z_ins_insert_obj
    ; insert_obj object destination
    jsr evaluate_all_args
!ifdef TRACE_OBJ {
    jsr print_following_string
    !pet "insert_obj object destination: ",0
    ldx z_operand_value_low_arr
    jsr printx
    jsr newline
}
    ; calculate and store object address
    ldx z_operand_value_low_arr
    lda z_operand_value_high_arr
    jsr calculate_object_address
    lda object_tree_ptr
    sta zp_mempos
    lda object_tree_ptr + 1
    sta zp_mempos + 1
    ; calculate destination address
    ldx z_operand_value_low_arr + 1
    lda z_operand_value_high_arr + 1
    jsr calculate_object_address
    ; now move object to destination
!ifndef Z4PLUS {
    ; set current child of destination as object's sibling
    ldy #6 ; child
    lda (object_tree_ptr),y
    ldy #5 ; sibling
    sta (zp_mempos),y
    ; set object as destination's child
    lda z_operand_value_low_arr
    ldy #6  ; child
    sta (object_tree_ptr),y
    ; set destination as object's parent
    lda z_operand_value_low_arr + 1
    ldy #4  ; parent
    sta (zp_mempos),y
}
!ifdef Z4PLUS {
    ; set current child of destination as object's sibling
    ldy #10 ; child
    lda (object_tree_ptr),y
    ldy #8 ; sibling
    sta (zp_mempos),y
    ldy #11 ; child
    lda (object_tree_ptr),y
    ldy #9 ; sibling
    sta (zp_mempos),y
    ; set object as destination's child
    lda z_operand_value_low_arr
    ldy #10  ; child
    sta (object_tree_ptr),y
    lda z_operand_value_high_arr
    iny
    sta (object_tree_ptr),y
    ; set destination as object's parent
    lda z_operand_value_low_arr + 1
    ldy #6  ; parent
    sta (zp_mempos),y
    lda z_operand_value_high_arr + 1
    iny
    sta (zp_mempos),y
}
    rts

calculate_property_length_number
    ; must call set_z_address before this subroutine
    ; output: updates .property_number, .property_length
    ; .property_length = 0 if end of property list
    lda #0
    sta .property_number
    sta .property_length
    jsr read_next_byte ; size of property block (# data | property number)
    cmp #0
    beq +
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
+   rts
.property_number !byte 0
.property_length !byte 0

find_first_prop
    ; output: x,a = address to property block, or 0,0 if not found
    ldx z_operand_value_low_arr
    lda z_operand_value_high_arr
    jsr calculate_object_address
!ifndef Z4PLUS {
    ldy #8
}
!ifdef Z4PLUS {
    ldy #13
}
    lda (object_tree_ptr),y ; low byte
    tax
    dey
    lda (object_tree_ptr),y ; high byte
    jsr set_z_address
    jsr read_next_byte ; length of object short name (# of zchars)
    ; skip short name
    asl ; a is number of words, multiply by two for number of bytes
    jmp skip_bytes_z_address

find_prop
    ; call find_first_prop before calling find_prop
    ; output: x,a = address to property block, or 0,0 if not found
    ; loop over the properties until the correct one found
!ifndef Z4PLUS {
.property_loop
    jsr calculate_property_length_number
    lda .property_length
    cmp #0
    beq .find_prop_not_found
!ifdef DEBUG {
    lda #46
    jsr $ffd2
    ldx .property_number
    jsr printx
    jsr space
    ldx .property_length
    jsr printx
    jsr newline
}
    lda .property_length
    cmp z_operand_value_low_arr + 1; max 63 properties so only low_arr
    beq .find_prop_found
    ; skip property data
-   jsr read_next_byte
    dec .property_length
    bne -
    jmp .property_loop
}
!ifdef Z4PLUS {
    jsr fatalerror
    !pet "TODO z_ins_get_prop_addr support for Z4-Z8", 13, 0
}
.find_prop_not_found
    ldx #0
    lda #0
    rts
.find_prop_found
    jmp get_z_address

z_ins_get_prop
    ; get_prop object property -> (result)
    jsr evaluate_all_args
!ifdef TRACE_PROP {
    jsr print_following_string
    !pet "get_prop object property: ", 0
    ldx z_operand_value_low_arr
    jsr printx
    jsr space
    ldx z_operand_value_high_arr
    jsr printx
    jsr space
}
    jsr find_first_prop
    jsr find_prop
    cmp #0
    bne .property_found
    ; no property found, get default property
    lda z_operand_value_low_arr + 1; max 63 properties so only low_arr
    asl ; default property is words (2 bytes each)
    tay
    lda (default_properties_ptr),y
    tax
    iny
    lda (default_properties_ptr),y
    jmp .return_property
.property_found
    ; property found
    lda #0
    sta .prop_result + 1
    jsr read_next_byte
    sta .prop_result
    lda .property_length
    cmp #2
    bne .proplength_not_two
    jsr read_next_byte
    sta .prop_result + 1
.proplength_not_two
    cmp #0
    bne .proplength_one_or_more
    jsr fatalerror
    !pet "z_ins_get_prop bad length", 13, 0
.proplength_one_or_more
    ldx .prop_result + 1
    lda .prop_result 
.return_property
    jsr z_store_result
!ifdef TRACE_PROP {
    jsr printx
    jsr space
    jsr printa
    jsr newline
}
    rts
.prop_result !byte 0,0

z_ins_get_prop_addr
    ; get_prop_addr object property -> (result)
!ifdef TRACE_PROP {
    jsr print_following_string
    !pet "get_prop_addr object property: ", 13, 0
}
    jsr evaluate_all_args
    jsr find_first_prop
    jsr find_prop
    jmp z_store_result

z_ins_get_next_prop
    ; get_next_prop object property -> (result)
!ifdef TRACE_PROP {
    jsr print_following_string
    !pet "get_next_prop object property: ", 13, 0
}
    jsr evaluate_all_args
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
!ifdef TRACE_PROP {
    jsr print_following_string
    !pet "put_prop object property: ", 13, 0
}
    jsr evaluate_all_args
    jsr find_first_prop
    jsr find_prop
    jsr get_z_address
    stx zp_mempos
    sta zp_mempos + 1
    ldy #1
    lda .property_length
    cmp #1
    bne +
    ldx z_operand_value_low_arr + 2
    sta (zp_mempos),y
+   cmp #2
    bne +
    ldx z_operand_value_low_arr + 2
    sta (zp_mempos),y
    iny 
    ldx z_operand_value_high_arr + 2
    sta (zp_mempos),y
+   jsr fatalerror
    !pet "z_ins_put_prop bad length", 13, 0

parse_object_table
    lda story_start + header_object_table     ; high byte
    ldx story_start + header_object_table + 1 ; low byte
    ; property defaults table
    stx default_properties_ptr
    clc
    adc #>story_start
    sta default_properties_ptr + 1
!ifndef Z4PLUS {
    ldx #62 ; 31 words
}
!ifdef Z4PLUS {
    ldx #126 ; 63 words
}
    stx num_default_properties
    ; store start of objects
    lda default_properties_ptr
    clc
    adc num_default_properties
    sta objects_start_ptr
    lda default_properties_ptr + 1
    adc #0
    sta objects_start_ptr + 1
    rts

calculate_object_address
    ; subroutine: calculate address for object
    ; input: a,x object index (high/low)
    ; output: object address in object_tree_ptr
    ; used registers: a,x
    ; side effects:
    stx multiplier
    sta multiplier + 1
    ; a/x is one too high (object table is 1-indexed)
    cpx #0
    bne +
    dec multiplier + 1
+   dec multiplier
!ifndef Z4PLUS {
    lda #9
}
!ifdef Z4PLUS {
    lda #14
}
    sta multiplicand
    lda #0
    sta multiplicand + 1
    jsr mult16
    ; add to the start of the object area
    lda product
    clc
    adc objects_start_ptr
    sta object_tree_ptr
    lda product + 1
    adc objects_start_ptr + 1
    sta object_tree_ptr + 1
    rts

!ifdef DEBUG {
test_object_table
    lda #13
    sta z_operand_value_low_arr
    lda #2
    sta z_operand_value_low_arr + 1
    lda #0
    sta z_operand_value_high_arr
    sta z_operand_value_high_arr + 1
    jsr z_ins_get_prop + 3 ; skip jsr evaluate_all_args
    jsr print_following_string
    !pet "result: ",0
    ldx .prop_result
    jsr printx
    jsr space
    ldx .prop_result + 1
    jsr printx
    jsr newline
    rts
}
