; --- ZERO PAGE --
; BASIC not much used, so many positions free to use
; memory bank control
zero_datadirection    = $00
zero_processorports   = $01
; available zero page variables (pseudo registers)
zx1                   = $ae
zx2                   = $af

; --- BASIC rom routines ---
basic_printstring     = $ab1e ; write string in a/y (LO </HI >)
basic_printinteger    = $bdcd ; write integer value in a/y

; --- I/O registers ---
reg_bordercolor       = $d020
reg_backgroundcolor   = $d021 

; --- Kernel routines ---
kernel_setcursor      = $e50c ; set cursor to x/y (row/column)
kernel_reset          = $fce2 ; cold reset of the C64
kernel_setlfs         = $ffba ; set file parameters
kernel_setnam         = $ffbd ; set file name
kernel_open           = $ffc0 ; open a file
kernel_close          = $ffc3 ; close a file
kernel_chkin          = $ffc6 ; define file as default input
kernel_chkout         = $ffc9 ; define file as default output
kernel_clrchn         = $ffcc ; close default input/output files
kernel_readchar       = $ffcf ; read byte from default input into a
kernel_printchar      = $ffd2 ; write char in a
