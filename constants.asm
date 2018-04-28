; I/O registers
reg_backgroundcolor   = $d021 
reg_bordercolor       = $d020

; BASIC rom routines
basic_printstring     = $ab1e ; write string in A/Y (LO <, HI >)
basic_printinteger    = $bdcd ; write integer value in A/X

; Kernel routines
kernel_setnam         = $FFBD ; set file name
kernel_setlfs         = $FFBA ; set file parameters
kernel_open           = $FFC0 ; open a file
kernel_close          = $FFC3 ; close a file
kernel_chkin          = $FFC6 ; define file as default input
kernel_chkout         = $FFC9 ; define file as default output
kernel_clrchn         = $FFCC ; close default input/output files
kernel_readchar       = $FFCF ; read byte from default input into a
kernel_printchar      = $FFD2 ; write char in a
kernel_setcursor      = $e50c ; set cursor to x/y (row/column)
