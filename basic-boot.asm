; A BASIC booter, encodes `10 SYS <address>`.
; Macrofied from http://www.pouet.net/topic.php?which=6541

!source "constants.asm"

!macro start_at .address {
  * = basic
  !byte $0c,$08,$00,$00,$9e
  !if .address >= 10000 { !byte 48 + ((.address / 10000) % 10) }
  !if .address >=  1000 { !byte 48 + ((.address /  1000) % 10) }
  !if .address >=   100 { !byte 48 + ((.address /   100) % 10) }
  !if .address >=    10 { !byte 48 + ((.address /    10) % 10) }
  !byte $30 + (.address % 10), $00, $00, $00
  * = .address
}

; A cooler example is to write
;
;   10 SYS <address>: REM <backspaces>Your comment
;
; When the user types LIST, he will just see
;
;   10 Your comment
;
; but still be able to run it.
; For this, see http://codebase64.org/doku.php?id=base:acme-macro-tut

