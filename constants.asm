; I/O registers
background_color = $d021 
border_color     = $d020

; BASIC rom routines
print_string     = $ab1e ; write string in A/Y (LO <, HI >)
print_integer    = $bdcd ; write integer value in A/X

; Kernel routines
print_char       = $FFD2 ; write char in a
setcursor        = $e50c ; set cursor to x/y (row/column)
read_char        = $ffcf ; read char into a
