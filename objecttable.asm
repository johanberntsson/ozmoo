; see: http://inform-fiction.org/zmachine/standards/z1point1/sect12.html

;TRACE_TREE = 1 ; trace get_parent, get_sibling, get_child
;TRACE_OBJ = 1 ; trace remove_obj, jin, insert_obj
;TRACE_ATTR = 1 ; trace find_attr, set_attr, clear_attr
;TRACE_PROP = 1  ; trace get_prop_len, get_next_prop
;TRACE_FROTZ = 1 ; give Frotz-style messages

; globals
num_default_properties !byte 0
objects_start_ptr      !byte 0, 0

; object table opcodes
z_ins_get_sibling
    ; get_sibling object -> (result) ?(label)
!ifdef TRACE_TREE {
    jsr print_following_string
    !pet "get_sibling obj: ",0
}
!ifndef Z4PLUS {
    lda #5
} else {
    lda #9
}
	bne .get_sibling_child ; Always branch

z_ins_get_child
    ; get_child object -> (result) ?(label)
!ifdef TRACE_FROTZ {
    jsr print_following_string
    !pet "@get_child  ",0
    ldx z_operand_value_low_arr
    lda z_operand_value_high_arr
    jsr print_obj
    jsr newline
}
!ifdef TRACE_TREE {
    jsr print_following_string
    !pet "get_child obj: ",0
}
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
!ifdef TRACE_TREE {
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
!ifdef TRACE_TREE {
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
!ifdef TRACE_FROTZ {
    jsr print_following_string
    !pet "@get_parent ",0
    ldx z_operand_value_low_arr
    lda z_operand_value_high_arr
    jsr print_obj
    jsr newline
}
!ifdef TRACE_TREE {
    jsr print_following_string
    !pet "get_parent obj: ",0
}
    ldx z_operand_value_low_arr
    lda z_operand_value_high_arr
!ifdef TRACE_TREE {
    jsr printx
    jsr comma
    jsr printa
    jsr space
}
    jsr calculate_object_address
!ifdef TRACE_TREE {
    ldx object_tree_ptr
    jsr printx
    jsr comma
    ldx object_tree_ptr + 1
    jsr printx
    jsr space
}
!ifndef Z4PLUS {
    ldy #4
    ldx #0
    lda (object_tree_ptr),y
    tax
    lda #0
} else  {
    ldy #7
    lda (object_tree_ptr),y
    tax
    dey
    lda (object_tree_ptr),y
}
!ifdef TRACE_TREE {
    jsr printx
    jsr newline
}
    jmp z_store_result

z_ins_get_prop_len
    ; get_prop_len property-address -> (result)
!ifdef TRACE_PROP {
    jsr print_following_string
    !pet "get_prop_len property-address: ",0
    ldx z_operand_value_low_arr
    jsr printx
    jsr space
    ldx z_operand_value_high_arr
    jsr printx
    jsr space
}
    ldx z_operand_value_low_arr
    lda z_operand_value_high_arr
    cpx #0
    bne +
    cmp #0
    bne +
    ; get_prop_len 0 must return 0
!ifdef TRACE_PROP {
    jsr printx
    jsr newline
}
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
!ifdef TRACE_PROP {
    jsr printx
    jsr newline
}
    jmp z_store_result

.zp_object = zp_mempos
.zp_parent = object_tree_ptr  ; won't be used at the same time
.zp_sibling = object_tree_ptr ; won't be used at the same time
.zp_dest = object_tree_ptr    ; won't be used at the same time
.object_num !byte 0,0
.parent_num !byte 0,0
.child_num !byte 0,0
.sibling_num !byte 0,0        ; won't be used at the same time
.dest_num = .sibling_num      ; won't be used at the same time
z_ins_remove_obj
    ; remove_obj object
    ; get object number
    ldx z_operand_value_low_arr
    lda z_operand_value_high_arr
    sta .object_num
    stx .object_num + 1
    ; find object in dynmem
    ;lda .object_num
    ;ldx .object_num + 1
    jsr calculate_object_address
    lda object_tree_ptr
    sta .zp_object
    lda object_tree_ptr + 1
    sta .zp_object + 1
    ; get parent number
!ifdef Z4PLUS {
    ldy #6  ; parent
    lda (.zp_object),y
    sta .parent_num
    iny
    lda (.zp_object),y
    sta .parent_num + 1
} else {
    ldy #4  ; parent
    lda #0
    sta .parent_num
    lda (.zp_object),y
    sta .parent_num + 1
}
!ifdef TRACE_OBJ {
    jsr print_following_string
    !pet "remove_obj: obj ", 0
    lda .object_num
    jsr printa
    jsr comma
    lda .object_num + 1
    jsr printa
    jsr print_following_string
    !pet " parent ", 0
    lda .parent_num
    jsr printa
    jsr comma
    lda .parent_num + 1
    jsr printa
    jsr space
}
    ; is there a parent?
    lda .parent_num
    bne .has_parent
    lda .parent_num + 1
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
!ifdef Z4PLUS {
    ldy #10  ; child
    lda (.zp_parent),y
    sta .child_num
    iny
    lda (.zp_parent),y
    sta .child_num + 1
} else {
    ldy #6  ; child
    lda #0
    sta .child_num
    lda (.zp_parent),y
    sta .child_num + 1
}
!ifdef TRACE_OBJ {
    jsr print_following_string
    !pet " child ", 0
    lda .child_num
    jsr printa
    jsr comma
    lda .child_num + 1
    jsr printa
}
    ; num_child == num_object?
    lda .child_num
    cmp .object_num
    bne .not_child
    lda .child_num + 1
    cmp .object_num + 1
    bne .not_child
    ; object is the child of parent
    ; set child of parent to object's sibling
!ifdef Z4PLUS {
    ldy #8  ; sibling
    lda (.zp_object),y
    pha
    iny
    lda (.zp_object),y
    ldy #11  ; child+1
    sta (.zp_parent),y
    dey
    pla
    sta (.zp_parent),y
} else {
    ldy #5  ; sibling
    lda (.zp_object),y
    ldy #6  ; child
    sta (.zp_parent),y
}
!ifdef TRACE_OBJ {
    jsr print_following_string
    !pet " directchild", 0
}
    jmp .remove_obj_done
.not_child
    ; find sibling in dynmen
    lda .child_num
    ldx .child_num + 1
    sta .sibling_num
    stx .sibling_num + 1
-
    lda .sibling_num
    ldx .sibling_num + 1
    jsr calculate_object_address
    ; get next sibling number
!ifdef Z4PLUS {
    ldy #8  ; sibling
    lda (.zp_sibling),y
    sta .sibling_num
    iny
    lda (.zp_sibling),y
    sta .sibling_num + 1
} else {
    ldy #5  ; sibling
    lda #0
    sta .sibling_num
    lda (.zp_sibling),y
    sta .sibling_num + 1
}
    ; while sibling != object
    lda .sibling_num
    cmp .object_num
    bne -
    lda .sibling_num + 1
    cmp .object_num + 1
    bne -
    ; .zp_sibling.sibling == object. set to object.sibling instead
!ifdef Z4PLUS {
    ldy #8  ; sibling
    lda (.zp_object),y
    sta (.zp_sibling),y
    iny
    lda (.zp_object),y
    sta (.zp_sibling),y
} else {
    ldy #5  ; sibling
    lda (.zp_object),y
    sta (.zp_sibling),y
}
!ifdef TRACE_OBJ {
    jsr print_following_string
    !pet " sibling", 0
}
.remove_obj_done
    ; always set obj.parent and obj.sibling to 0
    lda #0
!ifdef Z4PLUS {
    ldy #6  ; parent
    sta (.zp_object),y
    iny
    sta (.zp_object),y
    iny ; sibling (8)
    sta (.zp_object),y
    iny
    sta (.zp_object),y
} else {
    ldy #4  ; parent
    sta (.zp_object),y
    iny ; sibling (5)
    sta (.zp_object),y
}
!ifdef TRACE_OBJ {
    jsr newline
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
    sta .bitmask_index
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
    sta .attribute_index
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
.bitmask_index !byte 0
.attribute_index !byte 0

z_ins_print_obj
    ; print_obj object
    ldx z_operand_value_low_arr
    lda z_operand_value_high_arr
    jmp print_obj

print_obj
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
    !pet "jin obj1 obj2: ", 0
    ldx z_operand_value_low_arr
    jsr printx
    jsr space
    ldx z_operand_value_high_arr
    jsr printx
    jsr space
    ldx z_operand_value_low_arr + 1
    jsr printx
    jsr space
    ldx z_operand_value_high_arr + 1
    jsr printx
    jsr newline
}
    ldx z_operand_value_low_arr
    lda z_operand_value_high_arr
    jsr calculate_object_address
!ifndef Z4PLUS {
    ldy #4  ; parent
    lda (object_tree_ptr),y
    cmp z_operand_value_low_arr + 1
    bne .branch_false
    beq .branch_true
} else {
    ldy #6  ; parent
    lda (object_tree_ptr),y
    cmp z_operand_value_high_arr + 1
    bne .branch_false
    iny
    lda (object_tree_ptr),y
    cmp z_operand_value_low_arr + 1
    bne .branch_false
    beq .branch_true
}

z_ins_test_attr
    ; test_attr object attribute ?(label)
!ifdef TRACE_FROTZ {
    jsr print_following_string
    !pet "@test_attr ",0
    ldx z_operand_value_low_arr
    lda z_operand_value_high_arr
    jsr print_obj
    jsr space
    ldx z_operand_value_low_arr + 1
    jsr printx
    jsr newline
}
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
    jsr find_attr
!ifdef TRACE_FROTZ {
    jsr print_following_string
    !pet "@set_attr  ", 0
    ldx z_operand_value_low_arr
    lda z_operand_value_high_arr
    jsr print_obj
    jsr space
    ldx z_operand_value_low_arr + 1
    jsr printx
    jsr newline
}
!ifdef TRACE_ATTR {
    jsr print_following_string
    !pet "set_attr object attr: ", 0
    ldx z_operand_value_low_arr
    jsr printx
    jsr space
    ldx z_operand_value_high_arr
    jsr printx
    jsr space
    ldx z_operand_value_low_arr + 1
    jsr printx
    jsr space
    ldx z_operand_value_high_arr + 1
    jsr printx
    jsr space
}
    ; don't continue if object = 0
    ldx z_operand_value_low_arr
    bne .do_set_attr
    ldx z_operand_value_high_arr
    bne .do_set_attr
!ifdef TRACE_ATTR {
    jsr newline
}
    rts
.do_set_attr
    ldx .bitmask_index
    ldy .attribute_index
    lda (object_tree_ptr),y
!ifdef TRACE_ATTR {
    lda .bitmask,x
    jsr printa
    jsr comma
    lda (object_tree_ptr),y
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
    jsr find_attr
!ifdef TRACE_FROTZ {
    jsr print_following_string
    !pet "@clear_attr object ", 0
    ldx z_operand_value_low_arr
    lda z_operand_value_high_arr
    jsr print_obj
    jsr space
    ldx z_operand_value_low_arr + 1
    jsr printx
    jsr newline
}
!ifdef TRACE_ATTR {
    jsr print_following_string
    !pet "clear_attr object attr: ", 0
    ldx z_operand_value_low_arr
    jsr printx
    jsr space
    ldx z_operand_value_high_arr
    jsr printx
    jsr space
    ldx z_operand_value_low_arr + 1
    jsr printx
    jsr space
    ldx z_operand_value_high_arr + 1
    jsr printx
    jsr space
}
    ; don't continue if object = 0
    ldx z_operand_value_low_arr
    bne .do_clear_attr
    ldx z_operand_value_high_arr
    bne .do_clear_attr
!ifdef TRACE_ATTR {
    jsr newline
}
    rts
.do_clear_attr
    ldx .bitmask_index
    ldy .attribute_index
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
!ifdef TRACE_OBJ {
    jsr print_following_string
    !pet "insert_obj obj dest: ",0
}
    jsr z_ins_remove_obj ; will set .zp_object and .object_num
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
!ifdef TRACE_OBJ {
    lda .object_num
    jsr printa
    jsr comma
    lda .object_num + 1
    jsr printa
    jsr space
    lda .dest_num
    jsr printa
    jsr comma
    lda .dest_num + 1
    jsr printa
    jsr space
}
!ifdef Z4PLUS {
    ; object.parent = destination
    ldy #6 ; parent
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
    lda .object_num
    sta (.zp_dest),y
    iny
    lda .object_num + 1
    sta (.zp_dest),y
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
    lda .object_num + 1
    sta (.zp_dest),y
}
!ifdef TRACE_OBJ {
    ldy #4 ; parent
    lda (.zp_object),y
    jsr printa
    jsr space
    jsr newline
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
!ifdef TRACE_PROP {
    ;jsr printa
    ;jsr comma
}
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
!ifdef TRACE_PROP {
    ;jsr printa
}
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
!ifdef TRACE_PROP {
    ;jsr space
}
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
    lda (object_tree_ptr),y ; low byte
    tax
    dey
    lda (object_tree_ptr),y ; high byte
    pha ; a is destroyed by set_z_address
    jsr set_z_address
    pla
    bne +
    cpx #0
    bne +
    rts ; 0,0: no prop block exists, do nothing
+    jsr read_next_byte ; length of object short name (# of zchars)
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
    cmp #0
    beq .find_prop_not_found
!ifdef TRACE_PROP {
    lda #46 ; .
    jsr kernel_printchar
    ldx .property_number
    jsr printx
    jsr space
    ldx .property_length
    jsr printx
    jsr newline
}
    lda .property_number
    cmp z_operand_value_low_arr + 1; max 63 properties so only low_arr
    beq .find_prop_found
    ; skip property data
-   jsr read_next_byte
    dec .property_length
    bne -
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
!ifdef TRACE_PROP {
    pha
    jsr print_following_string
    !pet "get_prop obj prop: ", 0
    ldx z_operand_value_low_arr
    jsr printx
    jsr space
    ldx z_operand_value_low_arr + 1
    jsr printx
    lda #58 ; :
    jsr kernel_printchar
    ldy .property_number
    jsr printy
    jsr space
    ldy .property_length
    jsr printy
    lda #58 ; :
    jsr kernel_printchar
    pla
}
    cmp #0
    bne .property_found
    ; no property found, get default property
    lda z_operand_value_low_arr + 1; max 63 properties so only low_arr
    asl ; default property is words (2 bytes each)
    tay
    dey
    lda (default_properties_ptr),y
    tax
    dey
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
    jmp .proplength_one_or_more
.proplength_not_two
    cmp #0
    bne .proplength_one_or_more
    lda #ERROR_BAD_PROPERTY_LENGTH
    jsr fatalerror
.proplength_one_or_more
    ldx .prop_result + 1
    lda .prop_result 
.return_property
!ifdef TRACE_PROP {
    jsr printx
    jsr space
    jsr printa
    jsr newline
}
    jmp z_store_result
.prop_result !byte 0,0

z_ins_get_prop_addr
    ; get_prop_addr object property -> (result)
    jsr find_first_prop
    jsr find_prop
!ifdef TRACE_PROP {
    pha
    txa
    pha
    jsr print_following_string
    !pet "get_prop_addr object property: ", 0
    ldx z_operand_value_low_arr
    jsr printx
    jsr space
    ldx z_operand_value_low_arr + 1
    jsr printx
    lda #58 ; :
    jsr kernel_printchar
    ldy .property_number
    jsr printy
    jsr space
    ldy .property_length
    jsr printy
    lda #58 ; :
    jsr kernel_printchar
    jsr get_z_address
    jsr printx
    jsr space
    jsr printa
    jsr newline
    pla
    tax
    pla
}
    jmp z_store_result

z_ins_get_next_prop
    ; get_next_prop object property -> (result)
!ifdef TRACE_PROP {
    jsr print_following_string
    !pet "get_next_prop object property: ", 13, 0
}
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
    stx zp_mempos
    clc
    adc #>story_start
    sta zp_mempos + 1
!ifdef TRACE_PROP {
    jsr print_following_string
    !pet "put_prop object property: ", 0
    ldx z_operand_value_low_arr
    jsr printx
    jsr space
    ldx z_operand_value_low_arr + 1
    jsr printx
    jsr space
    ldx z_operand_value_low_arr + 2
    jsr printx
    lda #58 ; :
    jsr kernel_printchar
    ldy .property_number
    jsr printy
    jsr space
    ldy .property_length
    jsr printy
    lda #58 ; :
    jsr kernel_printchar
    jsr space
}
    lda .property_length
    cmp #1
    bne +
    ldx z_operand_value_low_arr + 2
    ldy #0
    sta (zp_mempos),y
!ifdef TRACE_PROP {
    jsr newline
}
    rts
+   cmp #2
    bne +
    ldy #0
    lda z_operand_value_high_arr + 2
    sta (zp_mempos),y
    iny 
    lda z_operand_value_low_arr + 2
    sta (zp_mempos),y
!ifdef TRACE_PROP {
    jsr newline
}
    rts
+   lda #ERROR_BAD_PROPERTY_LENGTH
    jsr fatalerror

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
    jsr z_ins_get_prop
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
