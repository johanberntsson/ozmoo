; C64 Program Header
    .word   basicstub
    *=$801
basicstub
    .(
        .word   end, 1
        .byt    $9e,"2061",0
end     .word   0
        .)
entry
        sta $D020,3
        rts

