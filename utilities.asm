; various utility functions
; - conv2dec

conv2dec
    ; convert a to decimal in x,a
    ; for example a=$#0f -> x='1', a='5'
    ldx #$30 ; store '0' in x
-   cmp #10
    bcc +    ; a < 10
    inx
    sec
    sbc #10
    jmp -
+   adc #$30
    rts
