; virtual memory
;
; virtual memory address space
; Z1-Z3: 128 K
; Z4-Z5: 256 K
; Z6-Z8: 512 K

; map structure: one entry for each kB of available virtual memory
; normally on C64 about $2000 - $D000, 
; 1 byte: C64 memory index 
; 2 bytes: Z-machine memory index ( 7 bit ref counter, 1 bit mem | 8 bit mem )

; need 44*3=132 bytes for $2000-$D000, or 56*3 = 168 bytes for $2000-$FFFF
; will store in datasette_buffer

; swapping: bubble up latest used frame, remove from end of mapping array

!ifdef USEVM {
load_dynamic_memory
    jsr fatalerror
    !pet "no vm yet", 0
    rts

prepare_static_high_memory
    rts

read_byte_at_z_address
    rts
}
