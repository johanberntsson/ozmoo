; object table
; see: http://inform-fiction.org/zmachine/standards/z1point1/sect12.html

; globals
num_default_properties !byte 0
objects_start_ptr      !byte 0, 0

; object table opcodes
z_ins_get_sibling
    ; get_sibling object -> (result) ?(label)
    jsr evaluate_all_args
    ldx z_operand_value_low_arr
    lda z_operand_value_high_arr
    jsr calculate_object_address
!ifndef Z4PLUS {
    ldy #5
}
!ifdef Z4PLUS {
    ldy #7
}
    lda (object_tree_ptr),y
    tax
    lda #0
    jmp z_store_result

z_ins_get_child
    ; get_child object -> (result) ?(label)
    jsr evaluate_all_args
    ldx z_operand_value_low_arr
    lda z_operand_value_high_arr
    jsr calculate_object_address
!ifndef Z4PLUS {
    ldy #6
}
!ifdef Z4PLUS {
    ldy #8
}
    lda (object_tree_ptr),y
    tax
    lda #0
    jmp z_store_result

z_ins_get_parent
    ; get_parent object -> (result)
    jsr evaluate_all_args
    ldx z_operand_value_low_arr
    lda z_operand_value_high_arr
    jsr calculate_object_address
!ifndef Z4PLUS {
    ldy #4
}
!ifdef Z4PLUS {
    ldy #6
}
    lda (object_tree_ptr),y
    tax
    lda #0
    jmp z_store_result

z_ins_get_prop_len
    ; get_prop_len property-address -> (result)
    jsr fatalerror
    !pet "TODO z_ins_get_prop_len", 13, 0

z_ins_remove_obj
    ; remove_obj object
    jsr fatalerror
    !pet "TODO z_ins_remove_obj", 13, 0

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
    jsr fatalerror
    !pet "TODO z_ins_jin", 13, 0

z_ins_test_attr
    ; test_attr object attribute ?(label)
    jsr evaluate_all_args
    ldx z_operand_value_low_arr
    lda z_operand_value_high_arr
    jsr calculate_object_address

    lda z_operand_value_low_arr + 1 ; 17
    ; ignore high_arr. Max 48 attributes
    and #$07
    tax
    lda z_operand_value_low_arr + 1
    lsr
    lsr
    lsr
    lsr
    tay
    lda (object_tree_ptr),y
    ora .bitmask,x
    beq +
    jmp make_branch_true
+   jmp make_branch_false
.bitmask !byte 128,64,32,16,8,4,2,1

z_ins_set_attr
    ; set_attr object attribute
    jsr fatalerror
    !pet "TODO z_ins_set_attr", 13, 0

z_ins_clear_attr
    ; clear_attr object attribute
    jsr fatalerror
    !pet "TODO z_ins_clear_attr", 13, 0

z_ins_insert_obj
    ; insert_obj object destination
    jsr fatalerror
    !pet "TODO z_ins_insert_obj", 13, 0

z_ins_get_prop
    ; get_prop object property -> (result)
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
    jsr read_next_byte ; length of object short name (# of zchars)
    ; skip short name
    asl ; a is number of words, multiply by two for number of bytes
    jsr skip_bytes_z_address
    ; loop over the properties until the correct one found
!ifndef Z4PLUS {
.property_loop
    jsr read_next_byte ; size of property block (# data | property number)
    cmp #0
    beq .no_property_found
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
!ifdef DEBUG {
    ldx .property_number
    jsr printx
    lda #$20
    jsr $ffd2
    ldx .property_length
    jsr printx
    lda #$0d
    jsr $ffd2
    lda .property_length
}
    cmp z_operand_value_low_arr + 1; max 63 properties so only low_arr
    beq .property_found
    ; skip property data
-   jsr read_next_byte
    dec .property_length
    bne -
    jmp .property_loop
}
!ifdef Z4PLUS {
    jsr fatalerror
    !pet "TODO z_ins_get_prop support for Z4-Z8", 13, 0
}
.no_property_found
    ; get default property
    lda z_operand_value_low_arr + 1; max 63 properties so only low_arr
    asl ; default property is words (2 bytes each)
    tay
    lda (default_properties_ptr),y
    tax
    iny
    lda (default_properties_ptr),y
!ifdef DEBUG {
    stx object_tree_ptr
    sta object_tree_ptr + 1
}
    jmp z_store_result
.property_found
    jsr read_next_byte
    tax
    lda .property_length
    cmp #1
    bne +
    lda #0
!ifdef DEBUG {
    stx object_tree_ptr
    sta object_tree_ptr + 1
}
    jmp z_store_result
+   cmp #2
    bne +
    jsr read_next_byte
!ifdef DEBUG {
    stx object_tree_ptr
    sta object_tree_ptr + 1
}
    jmp z_store_result
+   jsr fatalerror
    !pet "TODO z_ins_get_prop bad prop length", 13, 0
.property_number !byte 0
.property_length !byte 0

z_ins_get_prop_addr
    ; get_prop_addr object property -> (result)
    jsr fatalerror
    !pet "TODO z_ins_prop_addr", 13, 0

z_ins_get_next_prop
    ; get_next_prop object property -> (result)
    jsr fatalerror
    !pet "TODO z_ins_next_prop", 13, 0

z_ins_put_prop
    ; put_prop object property value
    jsr fatalerror
    !pet "TODO z_ins_put_prop", 13, 0

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
    lda #17
    sta z_operand_value_low_arr + 1
    lda #0
    sta z_operand_value_high_arr
    sta z_operand_value_high_arr + 1
    jsr z_ins_get_prop + 3 ; skip jsr evaluate_all_args
    jsr print_following_string
    !pet "result: ",0
    ldx object_tree_ptr
    jsr printx
    lda #$20
    jsr $ffd2
    ldx object_tree_ptr + 1
    jsr printx
    lda #$0d
    jsr $ffd2
    rts


}
