; object table opcodes
z_ins_get_sibling
    ; get_sibling object -> (result) ?(label)
    ; TODO: Implementation
    rts

z_ins_get_child
    ; get_child object -> (result) ?(label)
    ; TODO: Implementation
    rts

z_ins_get_parent
    ; get_parent object -> (result)
    ; TODO: Implementation
    rts

z_ins_get_prop_len
    ; get_prop_len property-address -> (result)
    ; TODO: Implementation
    rts

z_ins_remove_obj
    ; remove_obj object
    ; TODO: Implementation
    rts

z_ins_print_obj
    ; print_obj object
    ; TODO: Implementation
    rts

z_ins_jin
    ; jin obj1 obj2 ?(label)
    ; TODO: Implementation
    rts

z_ins_test_attr
    ; test_attr object attribute ?(label)
    ; TODO: Implementation
    rts

z_ins_set_attr
    ; set_attr object attribute
    ; TODO: Implementation
    rts

z_ins_clear_attr
    ; clear_attr object attribute
    ; TODO: Implementation
    rts

z_ins_insert_obj
    ; insert_obj object destination
    ; TODO: Implementation
    rts

z_ins_get_prop
    ; get_prop object property -> (result)
    ; TODO: Implementation
    rts

z_ins_get_prop_addr
    ; get_prop_addr object property -> (result)
    ; TODO: Implementation
    rts

z_ins_get_next_prop
    ; get_next_prop object property -> (result)
    ; TODO: Implementation
    rts

z_ins_put_prop
    ; put_prop object property value
    ; TODO: Implementation
    rts

parse_object_table
    rts

!ifdef DEBUG {
test_object_table
    rts
}
