; opcodes that access the object table
; 
; clear_attr object attribute
; get_child object -> (result) ?(label)
; get_next_prop object property -> (result)
; get_parent object -> (result)
; get_prop object property -> (result)
; get_prop_addr object property -> (result)
; get_prop_len property-address -> (result)
; get_sibling object -> (result) ?(label)
; insert_obj object destination
; jin obj1 obj2 ?(label)
; print_obj object
; put_prop object property value
; remove_obj object
; set_attr object attribute
; test_attr object attribute ?(label)

parse_object_table
    rts

!ifdef DEBUG {
test_object_table
    rts
}
