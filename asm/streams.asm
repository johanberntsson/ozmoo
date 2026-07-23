; Routines to handle output streams and input streams

!zone streams {
streams_current_entry		!byte 0,0,0,0
streams_stack				!fill 60, 0
streams_stack_items			!byte 0
streams_buffering			!byte 1,1
streams_output_selected		!byte 0, 0, 0, 0
!ifdef Z6 {
; The width of the text sent to stream 3, which the game reads back from
; header word $30 when the stream closes (z-spec 7.1.2.1.1) -- Shogun sizes
; its whole menu screen by measuring strings this way. A character is one
; unit here; a newline ends the line, and the widest line is the answer.
; cur and max must stay adjacent: the stack push/pop moves all four bytes.
streams_width_cur			!byte 0,0
streams_width_max			!byte 0,0
streams_width_stack			!fill 60, 0
!ifdef Z6_PIXEL_UNITS {
.swm_val					!byte 0,0	; the measured width while it is scaled into units
}
; The v6 formatted table (a width operand on output_stream 3): the table
; gets the print_form format -- one record per line, a length word then the
; characters, ended by a zero word -- word-wrapped to the width. Arthur's
; parser errors go through this ("I beg your pardon?" buffered, then
; print_form). Per level: the wrap width in units (0 means the plain v5
; format), the characters on the current line, and how many of them follow
; the last space ($ff: no space yet). The pad byte keeps the entry four
; bytes, the stride of the stack copies.
streams_form_width			!byte 0
streams_form_line_len		!byte 0
streams_form_since_space	!byte 0
							!byte 0
streams_form_stack			!fill 60, 0
.form_char	!byte 0
.form_len	!byte 0
.form_addr	!byte 0,0
.form_idx	!byte 0
}

.streams_tmp	!byte 0,0,0
.current_character !byte 0

!ifdef SWEDISH_CHARS {

; SWEDISH

; All mapped PETSCII codes for input:
;
; $dd ; Å = ]
; $dc ; Ö = £
; $db ; Ä = [
; $bf ; Backslash => (somewhat) backslash-like graphic character
; $b1 ; é = CBM-e
; $af ; Underscore = underscore-like graphic character
; $a5 ; Pipe = pipe-like graphic character (using $a5 since $dd is used for an accented char)
; $a0 ; Convert shift-space to regular space
; $9d ; Cursor left
; $91 ; Cursor up
; $8b ; F6
; $8a ; F4
; $89 ; F2
; $88 ; F7
; $87 ; F5
; $86 ; F3
; $5d ; å = ]
; $5c ; ö = £
; $5b ; ä = [
; $1d ; Cursor right
; $14 ; Backspace
; $11 ; Cursor down

character_translation_table_in
; NOTE: Must be sorted on PETSCII value, descending!
; PETSCII codes, mapped *FROM*
!byte $dd, $dc, $db, $bf, $b1, $af, $a5, $a0, $9d, $91, $8b, $8a, $89, $88, $87, $86, $5d, $5c, $5b, $1d, $14, $11
character_translation_table_in_end
; ZSCII codes, mapped *TO*
!byte $ca, $9f, $9e, $5c, $aa, $5f, $7c, $20, $83, $81, $8a, $88, $86, $8b, $89, $87, $c9, $9c, $9b, $84, $08, $82
character_translation_table_in_mappings_end


; All mapped ZSCII codes for output:
;
; $ca ; Å = Shift-]
; $c9 ; å = ]
; $aa ; é = CBM-e
; $9f ; Ö = Shift-£
; $9e ; Ä = Shift-[
; $9c ; ö = £
; $9b ; ä = [
; $7e ; ~ => -
; $7d ; } => )
; $7c ; Pipe = pipe-like graphic character (using $a5 since $dd is used for an accented char)
; $7b ; { => (
; $60 ; Grave accent => quote
; $5f ; Underscore = underscore-like graphic character
; $5d ; ] = )
; $5c ; Backslash => (somewhat) backslash-like graphic character
; $5b ; [ = (

character_translation_table_out
; NOTE: Must be sorted on ZSCII value, descending!
; ZSCII codes, mapped *FROM*
!byte $ca, $c9, $aa, $9f, $9e, $9c, $9b, $7e, $7d, $7c, $7b, $60, $5f, $5d, $5c, $5b 
character_translation_table_out_end
; PETSCII codes, mapped *TO*
!byte $dd, $5d, $b1, $dc, $db, $5c, $5b, $2d, $29, $a5, $28, $27, $af, $29, $bf, $28
character_translation_table_out_mappings_end


character_downcase_table
; NOTE: This maps from uppercase (source) ZSCII to lowercase (target) ZSCII. Must be sorted on source ZSCII value, descending!
!byte $ca, $9f, $9e
character_downcase_table_end
!byte $c9, $9c, $9b
character_downcase_table_mappings_end

; End of Swedish section
} else ifdef DANISH_CHARS {

; DANISH

; All mapped PETSCII codes for input:
;
; $dd ; Å = ]
; $dc ; Ø = £
; $db ; Æ = [
; $bf ; Backslash => (somewhat) backslash-like graphic character
; $b1 ; é = CBM-e
; $af ; Underscore = underscore-like graphic character
; $a5 ; Pipe = pipe-like graphic character (using $a5 since $dd is used for an accented char)
; $a0 ; Convert shift-space to regular space
; $9d ; Cursor left
; $91 ; Cursor up
; $8b ; F6
; $8a ; F4
; $89 ; F2
; $88 ; F7
; $87 ; F5
; $86 ; F3
; $5d ; å = ]
; $5c ; ø = £
; $5b ; æ = [
; $1d ; Cursor right
; $14 ; Backspace
; $11 ; Cursor down

character_translation_table_in
; NOTE: Must be sorted on PETSCII value, descending!
; PETSCII codes, mapped *FROM*
!byte $dd, $dc, $db, $bf, $b1, $af, $a5, $a0, $9d, $91, $8b, $8a, $89, $88, $87, $86, $5d, $5c, $5b, $1d, $14, $11
character_translation_table_in_end
; ZSCII codes, mapped *TO*
!byte $ca, $cc, $d4, $5c, $aa, $5f, $7c, $20, $83, $81, $8a, $88, $86, $8b, $89, $87, $c9, $cb, $d3, $84, $08, $82 
character_translation_table_in_mappings_end


; All mapped ZSCII codes for output:
;
; $d4 ; Æ = Shift-[
; $d3 ; æ = [
; $cc ; Ø = Shift-£
; $cb ; ø = £
; $ca ; Å = Shift-]
; $c9 ; å = ]
; $aa ; é = CBM-e
; $7e ; ~ => -
; $7d ; } => )
; $7c ; Pipe = pipe-like graphic character (using $a5 since $dd is used for an accented char)
; $7b ; { => (
; $60 ; Grave accent => quote
; $5f ; Underscore = underscore-like graphic character
; $5d ; ] = )
; $5c ; Backslash => (somewhat) backslash-like graphic character
; $5b ; [ = (

character_translation_table_out
; NOTE: Must be sorted on ZSCII value, descending!
; ZSCII codes, mapped *FROM*
!byte $d4, $d3, $cc, $cb, $ca, $c9, $aa, $7e, $7d, $7c, $7b, $60, $5f, $5d, $5c, $5b 
character_translation_table_out_end
; PETSCII codes, mapped *TO*
!byte $db, $5b, $dc, $5c, $dd, $5d, $b1, $2d, $29, $a5, $28, $27, $af, $29, $bf, $28
character_translation_table_out_mappings_end

character_downcase_table
; NOTE: This maps from uppercase (source) ZSCII to lowercase (target) ZSCII. Must be sorted on source ZSCII value, descending!
!byte $d4, $cc, $ca
character_downcase_table_end
!byte $d3, $cb, $c9
character_downcase_table_mappings_end

; End of Danish section
} else ifdef GERMAN_CHARS {

; GERMAN

; All mapped PETSCII codes for input:
;
; $dd ; Ä => ]
; $db ; Ö => [
; $c0 ; Ü => @
; $bf ; Backslash => (somewhat) backslash-like graphic character
; $af ; Underscore = underscore-like graphic character
; $a5 ; Pipe = pipe-like graphic character (using $a5 since $dd is used for an accented char)
; $a0 ; Convert shift-space to regular space
; $9d ; Cursor left
; $91 ; Cursor up
; $8b ; F6
; $8a ; F4
; $89 ; F2
; $88 ; F7
; $87 ; F5
; $86 ; F3
; $5f ; ß = left-arrow
; $5d ; ä = ]
; $5c ; £
; $5b ; ö = [
; $40 ; ü = @
; $1d ; Cursor right
; $14 ; Backspace
; $11 ; Cursor down

character_translation_table_in
; NOTE: Must be sorted on PETSCII value, descending!
; PETSCII codes, mapped *FROM*
!byte $dd, $db, $c0, $bf, $af, $a5, $a0, $9d, $91, $8b, $8a, $89, $88, $87, $86, $5f, $5d, $5c, $5b, $40, $1d, $14, $11
character_translation_table_in_end
; ZSCII codes, mapped *TO*
!byte $9e, $9f, $a0, $5c, $5f, $7c, $20, $83, $81, $8a, $88, $86, $8b, $89, $87, $a1, $9b, $db, $9c, $9d, $84, $08, $82 
character_translation_table_in_mappings_end


; All mapped ZSCII codes for output:
;
; $db ; £
; $a1 ; ß = left-arrow
; $a0 ; Ü = Shift-@
; $9f ; Ö = Shift-[
; $9e ; Ä = Shift-]
; $9d ; ü = @
; $9c ; ö = [
; $9b ; ä = ]
; $7e ; ~ => -
; $7d ; } => )
; $7c ; Pipe = pipe-like graphic character (using $a5 since $dd is used for an accented char)
; $7b ; { => (
; $60 ; Grave accent => quote
; $5f ; Underscore = underscore-like graphic character
; $5d ; ] = )
; $5c ; Backslash => (somewhat) backslash-like graphic character
; $5b ; [ = (

character_translation_table_out
; NOTE: Must be sorted on ZSCII value, descending!
; ZSCII codes, mapped *FROM*
!byte $db, $a1, $a0, $9f, $9e, $9d, $9c, $9b, $7e, $7d, $7c, $7b, $60, $5f, $5d, $5c, $5b 
character_translation_table_out_end
; PETSCII codes, mapped *TO*
!byte $5c, $5f, $c0, $db, $dd, $40, $5b, $5d, $2d, $29, $a5, $28, $27, $af, $29, $bf, $28
character_translation_table_out_mappings_end

character_downcase_table
; NOTE: This maps from uppercase (source) ZSCII to lowercase (target) ZSCII. Must be sorted on source ZSCII value, descending!
!byte $a0, $9f, $9e
character_downcase_table_end
!byte $9d, $9c, $9b
character_downcase_table_mappings_end

; End of German section
} else ifdef ITALIAN_CHARS {

; ITALIAN

; All mapped PETSCII codes for input:
;
; $dd ; Pipe = pipe-like graphic character
; $bf ; Backslash => (somewhat) backslash-like graphic character
; $bb ; É (CBM-f)
; $b9 ; ò (CBM-o)
; $b8 ; ù (CBM-u)
; $b6 ; Ò (CBM-l)
; $b5 ; Ù (CBM-j)
; $b2 ; é (CBM-r)
; $b1 ; è (CBM-e)
; $b0 ; à (CBM-a)
; $af ; Underscore = underscore-like graphic character
; $ad ; À (CBM-z)
; $ac ; È (CBM-d)
; $a2 ; ì (CBM-i)
; $a1 ; Ì (CBM-k)
; $a0 ; Convert shift-space to regular space
; $9d ; Cursor left
; $91 ; Cursor up
; $8b ; F6
; $8a ; F4
; $89 ; F2
; $88 ; F7
; $87 ; F5
; $86 ; F3
; $5c ; £
; $1d ; Cursor right
; $14 ; Backspace
; $11 ; Cursor down

character_translation_table_in
; NOTE: Must be sorted on PETSCII value, descending!
; PETSCII codes, mapped *FROM*
!byte $dd, $bf, $bb, $b9, $b8, $b6, $b5, $b2, $b1, $b0, $af, $ad, $ac, $a2, $a1, $a0, $9d, $91, $8b, $8a, $89, $88, $87, $86, $5c, $1d, $14, $11
character_translation_table_in_end
; ZSCII codes, mapped *TO*
!byte $7c, $5c, $b0, $b8, $b9, $bd, $be, $aa, $b6, $b5, $5f, $ba, $bb, $b7, $bc, $20, $83, $81, $8a, $88, $86, $8b, $89, $87, $db, $84, $08, $82
character_translation_table_in_mappings_end

; All mapped ZSCII codes for output:
;
; $db ; £
; $be ; Ù
; $bd ; Ò
; $bc ; Ì
; $bb ; È
; $ba ; À
; $b9 ; ù
; $b8 ; ò
; $b7 ; ì
; $b6 ; è
; $b5 ; à
; $b0 ; É
; $aa ; é
; $7e ; ~ => -
; $7d ; } => )
; $7c ; Pipe = pipe-like graphic character
; $7b ; { => (
; $60 ; Grave accent => quote
; $5f ; Underscore = underscore-like graphic character
; $5c ; Backslash => (somewhat) backslash-like graphic character

character_translation_table_out
; NOTE: Must be sorted on ZSCII value, descending!
; ZSCII codes, mapped *FROM*
!byte $db, $be, $bd, $bc, $bb, $ba, $b9, $b8, $b7, $b6, $b5, $b0, $aa, $7e, $7d, $7c, $7b, $60, $5f, $5c 
character_translation_table_out_end
; PETSCII codes, mapped *TO*
!byte $5c, $b5, $b6, $a1, $ac, $ad, $b8, $b9, $a2, $b1, $b0, $bb, $b2, $2d, $29, $dd, $28, $27, $af, $bf
character_translation_table_out_mappings_end

character_downcase_table
; NOTE: This maps from uppercase (source) ZSCII to lowercase (target) ZSCII. Must be sorted on source ZSCII value, descending!
!byte $be, $bd, $bc, $bb, $ba, $b0
character_downcase_table_end
!byte $b9, $b8, $b7, $b6, $b5, $aa
character_downcase_table_mappings_end

; End of Italian section
} else ifdef SPANISH_CHARS {

; SPANISH

; All mapped PETSCII codes for input:
;
; $dd ; Pipe = pipe-like graphic character
; $bf ; Backslash => (somewhat) backslash-like graphic character
; $b9 ; ó          (CBM-o)
; $b8 ; ú          (CBM-u)
; $b7 ; ü          (CBM-y)
; $b6 ; Ó          (CBM-l)
; $b5 ; Ú          (CBM-j)
; $b4 ; Ü          (CBM-h)
; $b3 ; inverted ? (CBM-w)
; $b1 ; é          (CBM-e)
; $b0 ; á          (CBM-a)
; $af ; Underscore = underscore-like graphic character
; $ad ; Á          (CBM-z)
; $ac ; É          (CBM-d)
; $ab ; inverted ! (CBM-q)
; $aa ; ñ          (CBM-n)
; $a7 ; Ñ          (CBM-m)
; $a2 ; í          (CBM-i)
; $a1 ; Í          (CBM-k)
; $a0 ; Convert shift-space to regular space
; $9d ; Cursor left
; $91 ; Cursor up
; $8b ; F6
; $8a ; F4
; $89 ; F2
; $88 ; F7
; $87 ; F5
; $86 ; F3
; $5c ; £
; $1d ; Cursor right
; $14 ; Backspace
; $11 ; Cursor down

character_translation_table_in
; NOTE: Must be sorted on PETSCII value, descending!
; PETSCII codes, mapped *FROM*
!byte $dd, $bf, $b9, $b8, $b7, $b6, $b5, $b4, $b3, $b1, $b0, $af, $ad, $ac, $ab, $aa, $a7, $a2, $a1, $a0, $9d, $91, $8b, $8a, $89, $88, $87, $86, $5c, $1d, $14, $11
character_translation_table_in_end
; ZSCII codes, mapped *TO*
!byte $7c, $5c, $ac, $ad, $9d, $b2, $b3, $a0, $df, $aa, $a9, $5f, $af, $b0, $de, $ce, $d1, $ab, $b1, $20, $83, $81, $8a, $88, $86, $8b, $89, $87, $db, $84, $08, $82 
character_translation_table_in_mappings_end


; All mapped ZSCII codes for output:
;
; $df ; inverted ?
; $de ; inverted !
; $db ; £
; $d1 ; Ñ
; $ce ; ñ
; $b3 ; Ú
; $b2 ; Ó
; $b1 ; Í
; $b0 ; É
; $af ; Á
; $ad ; ú
; $ac ; ó
; $ab ; í
; $aa ; é
; $a9 ; á
; $a0 ; Ü
; $9d ; ü
; $7e ; ~ => -
; $7d ; } => )
; $7c ; Pipe = pipe-like graphic character
; $7b ; { => (
; $60 ; Grave accent => quote
; $5f ; Underscore = underscore-like graphic character
; $5c ; Backslash => (somewhat) backslash-like graphic character

character_translation_table_out
; NOTE: Must be sorted on ZSCII value, descending!
; ZSCII codes, mapped *FROM*
!byte $df, $de, $db, $d1, $ce, $b3, $b2, $b1, $b0, $af, $ad, $ac, $ab, $aa, $a9, $a0, $9d, $7e, $7d, $7c, $7b, $60, $5f, $5c 
character_translation_table_out_end
; PETSCII codes, mapped *TO*
!byte $b3, $ab, $5c, $a7, $aa, $b5, $b6, $a1, $ac, $ad, $b8, $b9, $a2, $b1, $b0, $b4, $b7, $2d, $29, $dd, $28, $27, $af, $bf
character_translation_table_out_mappings_end

character_downcase_table
; NOTE: This maps from uppercase (source) ZSCII to lowercase (target) ZSCII. Must be sorted on source ZSCII value, descending!
!byte $d1, $b3, $b2, $b1, $b0, $af, $a0
character_downcase_table_end
!byte $ce, $ad, $ac, $ab, $aa, $a9, $9d
character_downcase_table_mappings_end

; End of Spanish section
} else ifdef FRENCH_CHARS {

; FRENCH

; All mapped PETSCII codes for input:
;
; $df ; Œ
; $de ; Û 
; $dd ; Pipe = pipe-like graphic character
; $dc ; »
; $db ; «
; $bf ; Backslash => (somewhat) backslash-like graphic character
; $be ; Ç
; $bd ; À
; $bc ; ç
; $bb ; Ë 
; $b9 ; ô
; $b8 ; û
; $b6 ; Ô 
; $b5 ; ü
; $b4 ; ù
; $b3 ; é 
; $b2 ; è 
; $b1 ; ê 
; $b0 ; â
; $af ; Underscore = underscore-like graphic character
; $ae ; à
; $ad ; Â
; $ac ; ë
; $ab ; É
; $aa ; Ù
; $a8 ; Î 
; $a7 ; Ü
; $a6 ; Ï
; $a5 ; È
; $a4 ; Æ
; $a3 ; Ê
; $a2 ; î
; $a1 ; ï
; $a0 ; Convert shift-space to regular space
; $9d ; Cursor left
; $91 ; Cursor up
; $8b ; F6
; $8a ; F4
; $89 ; F2
; $88 ; F7
; $87 ; F5
; $86 ; F3
; $5d ; œ
; $5c ; £
; $5b ; æ
; $1d ; Cursor right
; $14 ; Backspace
; $11 ; Cursor down

character_translation_table_in
; NOTE: Must be sorted on PETSCII value, descending!
; PETSCII codes, mapped *FROM*
!byte $df, $de, $dd, $dc, $db, $bf, $be, $bd, $bc, $bb, $b9, $b8, $b6, $b5, $b4, $b3, $b2, $b1, $b0, $af, $ae, $ad, $ac, $ab, $aa, $a8, $a7, $a6, $a5, $a4, $a3, $a2, $a1, $a0, $9d, $91, $8b, $8a, $89, $88, $87, $86, $5d, $5c, $5b, $1d, $14, $11
character_translation_table_in_end
; ZSCII codes, mapped *TO*
!byte $dd, $c8, $7c, $a2, $a3, $5c, $d6, $ba, $d5, $a7, $c2, $c3, $c7, $9d, $b9, $aa, $b6, $c0, $bf, $5f, $b5, $c4, $a4, $b0, $be, $c6, $a0, $a8, $bb, $d4, $c5, $c1, $a5, $20, $83, $81, $8a, $88, $86, $8b, $89, $87, $dc, $db, $d3, $84, $08, $82
character_translation_table_in_mappings_end


; All mapped ZSCII codes for output:
;
; $dd ; Œ 
; $dc ; œ
; $db ; £
; $d6 ; Ç
; $d5 ; ç
; $d4 ; Æ
; $d3 ; æ
; $c8 ; Û 
; $c7 ; Ô 
; $c6 ; Î 
; $c5 ; Ê 
; $c4 ; Â
; $c3 ; û 
; $c2 ; ô
; $c1 ; î
; $c0 ; ê 
; $bf ; â
; $be ; Ù 
; $bb ; È
; $ba ; À
; $b9 ; ù
; $b6 ; è 
; $b5 ; à
; $b0 ; É 
; $aa ; é 
; $a8 ; Ï 
; $a7 ; Ë 
; $a6 ; ÿ => y
; $a5 ; ï
; $a4 ; ë
; $a3 ; «
; $a2 ; »
; $a0 ; Ü 
; $9f ; Ö => O
; $9e ; Ä => A
; $9d ; ü
; $9c ; ö => o
; $9b ; ä => a
; $7e ; ~ => -
; $7d ; } => )
; $7c ; Pipe = pipe-like graphic character
; $7b ; { => (
; $60 ; Grave accent => quote
; $5f ; Underscore = underscore-like graphic character
; $5d ; ] => )
; $5c ; Backslash => (somewhat) backslash-like graphic character
; $5b ; [ => (

character_translation_table_out
; NOTE: Must be sorted on ZSCII value, descending!
; ZSCII codes, mapped *FROM*
!byte $dd, $dc, $db, $d6, $d5, $d4, $d3, $c8, $c7, $c6, $c5, $c4, $c3, $c2, $c1, $c0, $bf, $be, $bb, $ba, $b9, $b6, $b5, $b0, $aa, $a8, $a7, $a6, $a5, $a4, $a3, $a2, $a0, $9f, $9e, $9d, $9c, $9b, $7e, $7d, $7c, $7b, $60, $5f, $5d, $5c, $5b
character_translation_table_out_end
; PETSCII codes, mapped *TO*
!byte $df, $5d, $5c, $be, $bc, $a4, $5b, $de, $b6, $a8, $a3, $ad, $b8, $b9, $a2, $b1, $b0, $aa, $a5, $bd, $b4, $b2, $ae, $ab, $b3, $a6, $bb, $59, $a1, $ac, $db, $dc, $a7, $cf, $c1, $b5, $4f, $41, $2d, $29, $dd, $28, $27, $af, $29, $bf, $28
character_translation_table_out_mappings_end


character_downcase_table
; NOTE: This maps from uppercase (source) ZSCII to lowercase (target) ZSCII. Must be sorted on source ZSCII value, descending!
!byte $dd, $d6, $d4, $c8, $c7, $c6, $c5, $c4, $be, $bb, $ba, $b0, $a8, $a7, $a0
character_downcase_table_end
!byte $dc, $d5, $d3, $c3, $c2, $c1, $c0, $bf, $b9, $b6, $b5, $aa, $a5, $a4, $9d
character_downcase_table_mappings_end

; End of French section
} else { 

; Default: ENGLISH

; NOTE: Must be sorted on PETSCII value, descending!

; All mapped PETSCII codes for input:
:
; $dd ; Pipe = pipe-like graphic character
; $bf ; Backslash => (somewhat) backslash-like graphic character
; $af ; Underscore = underscore-like graphic character
; $a0 ; Convert shift-space to regular space
; $9d ; Cursor left
; $91 ; Cursor up
; $8b ; F6
; $8a ; F4
; $89 ; F2
; $88 ; F7
; $87 ; F5
; $86 ; F3
; $5c ; £
; $1d ; Cursor right
; $14 ; Backspace
; $11 ; Cursor down

character_translation_table_in
; PETSCII codes, mapped *FROM*
!byte $dd, $bf, $af, $a0, $9d, $91, $8b, $8a, $89, $88, $87, $86, $5c, $1d, $14, $11
character_translation_table_in_end
; ZSCII codes, mapped *TO*
!byte $7c, $5c, $5f, $20, $83, $81, $8a, $88, $86, $8b, $89, $87, $db, $84, $08, $82
character_translation_table_in_mappings_end


; All mapped ZSCII codes for output:
;
; $db ; £
; $7e ; ~ => -
; $7d ; } => )
; $7c ; Pipe = pipe-like graphic character
; $7b ; { => (
; $60 ; Grave accent => quote
; $5f ; Underscore = underscore-like graphic character
; $5c ; Backslash => (somewhat) backslash-like graphic character

character_translation_table_out
; NOTE: Must be sorted on ZSCII value, descending!
; ZSCII codes, mapped *FROM*
!byte $db, $7e, $7d, $7c, $7b, $60, $5f, $5c 
character_translation_table_out_end
; PETSCII codes, mapped *TO*
!byte $5c, $2d, $29, $dd, $28, $27, $af, $bf
character_translation_table_out_mappings_end

; End of English section
} 

!if character_translation_table_in_end - character_translation_table_in != character_translation_table_in_mappings_end - character_translation_table_in_end {
	!error "character_translation_table_in tables of different lengths!";
}
!if character_translation_table_out_end - character_translation_table_out != character_translation_table_out_mappings_end - character_translation_table_out_end {
	!error "character_translation_table_out tables of different lengths!";
}
!ifdef character_downcase_table {
!if character_downcase_table_end - character_downcase_table != character_downcase_table_mappings_end - character_downcase_table_end {
	!error "character_downcase_table tables of different lengths!";
}
}

	
streams_init
	; Setup/Reset streams handling
	; input: 
	; output:
	; side effects: Sets all variables/tables to their starting values
	; used registers: a
	lda #0
	sta streams_stack_items
	sta streams_output_selected + 1
	sta streams_output_selected + 2
	sta streams_output_selected + 3
!ifdef Z6 {
	sta streams_form_width
}
	lda #1
	sta streams_buffering
	sta streams_buffering + 1
	sta streams_output_selected
	rts
	
streams_print_output
	; Print a ZSCII character
	; input:  character in a
	; output:
	; side effects: -
	; affected registers: p
	cmp #0
	beq .return
	pha
	lda streams_output_selected + 2
	bne .mem_write
	lda streams_output_selected
	beq .pla_and_return
	pla
!ifdef Z6 {
	; If the current window is in font 3 (character graphics), map the glyph
	; to the target's native box-drawing PETSCII before it enters the buffer,
	; so every screen target renders it through the usual charset path.
	jsr font3_translate
	bcc +
	jmp printchar_buffered
+
}
	jsr translate_zscii_to_petscii
	bcs .could_not_convert
	jmp printchar_buffered
.could_not_convert
!ifdef DEBUG {
	jmp print_bad_zscii_code_buffered
} else {
	rts
}
.mem_write
	stx s_stored_x
	sty s_stored_y
!ifdef Z6 {
	pla					; peek at the character for the width count
	pha
	cmp #13
	bne .mw_count
	jsr .streams_line_done
	jmp .mw_counted
.mw_count
	inc streams_width_cur
	bne .mw_counted
	inc streams_width_cur + 1
.mw_counted
	lda streams_form_width
	bne .mw_formatted
}
	ldx streams_current_entry + 2
	lda streams_current_entry + 3
	jsr streams_set_z_address
	pla
	jsr write_next_byte
	
	; lda streams_current_entry + 2
	; sta .print_byte_to_mem + 1
	; lda streams_current_entry + 3
	; sta .print_byte_to_mem + 2
	; pla
; .print_byte_to_mem
	; sta $8000 ; Will be modified!
	inc streams_current_entry + 2
	bne +
	inc streams_current_entry + 3
+	jsr streams_unset_z_address
	ldx s_stored_x
	ldy s_stored_y
.return
	rts
.pla_and_return
	pla
	rts

!ifdef Z6 {
.mw_formatted
	; This level was opened with a width operand, so the table gets the
	; print_form format. A record's length word is the two bytes just
	; before its characters; it stays unwritten until the line ends
	; (here on a newline or a wrap, or at close), so the write pointer
	; always sits after the last character and the open record starts
	; line_len + 2 bytes behind it.
	ldx streams_current_entry + 2
	lda streams_current_entry + 3
	jsr streams_set_z_address
	pla
	cmp #13
	bne .mwf_char
	jmp .mwf_line_end
.mwf_char
	sta .form_char
	jsr write_next_byte
	jsr .form_advance_cur
	inc streams_form_line_len
	lda .form_char
	cmp #32
	bne +
	lda #0
	sta streams_form_since_space
	beq .mwf_check_width
+	lda streams_form_since_space
	cmp #$ff
	beq .mwf_check_width
	inc streams_form_since_space
.mwf_check_width
	lda streams_form_line_len
	cmp streams_form_width
	bcc .mwf_within
	bne .mwf_wrap
.mwf_within
	jmp .mwf_done
.mwf_wrap
	; the line is one character over the width: wrap it
	lda streams_form_since_space
	cmp #$ff
	beq .mwf_hard_break
	; break at the last space, which the new record's length word
	; overwrites; the characters after the space move up one byte,
	; copied from the top so the shift is safe in place
	lda streams_current_entry + 2
	sec
	sbc #1
	sta .form_addr
	lda streams_current_entry + 3
	sbc #0
	sta .form_addr + 1
	ldx streams_form_since_space
	beq .mwf_shifted
.mwf_shift
	stx .form_idx
	ldx .form_addr
	lda .form_addr + 1
	jsr set_z_address
	jsr read_next_byte
	jsr write_next_byte	; the read left the address one byte up
	lda .form_addr
	bne +
	dec .form_addr + 1
+	dec .form_addr
	ldx .form_idx
	dex
	bne .mwf_shift
.mwf_shifted
	lda streams_form_line_len
	sec
	sbc streams_form_since_space
	tay
	dey			; the space is dropped, not part of the record
	jsr .form_write_len
	lda streams_form_since_space
	sta streams_form_line_len
	lda #$ff
	sta streams_form_since_space
	jsr .form_advance_cur
	jmp .mwf_done
.mwf_hard_break
	; no space to break at: the record keeps exactly width characters
	; and the overflowing one moves up two bytes, past where the new
	; record's length word will go
	lda streams_current_entry + 2
	sec
	sbc #1
	tax
	lda streams_current_entry + 3
	sbc #0
	jsr set_z_address
	jsr read_next_byte
	sta .form_char
	jsr read_next_byte	; step over the length word's first byte
	lda .form_char
	jsr write_next_byte
	ldy streams_form_width
	jsr .form_write_len
	lda #1
	sta streams_form_line_len
	lda #$ff
	sta streams_form_since_space
	jsr .form_advance_cur
	jsr .form_advance_cur
	jmp .mwf_done
.mwf_line_end
	ldy streams_form_line_len
	jsr .form_write_len
	jsr .form_advance_cur	; leave the next record's length word open
	jsr .form_advance_cur
	lda #0
	sta streams_form_line_len
	lda #$ff
	sta streams_form_since_space
.mwf_done
	jsr streams_unset_z_address
	ldx s_stored_x
	ldy s_stored_y
	rts

.form_advance_cur
	inc streams_current_entry + 2
	bne +
	inc streams_current_entry + 3
+	rts

.form_write_len
	; Close the open record: write its length word, value in y. The
	; word sits line_len + 2 bytes behind the write pointer.
	sty .form_len
	lda streams_current_entry + 2
	sec
	sbc streams_form_line_len
	tax
	lda streams_current_entry + 3
	sbc #0
	sta .form_addr + 1
	txa
	sec
	sbc #2
	tax
	bcs +
	dec .form_addr + 1
+	lda .form_addr + 1
	jsr set_z_address
	lda #0
	jsr write_next_byte
	lda .form_len
	jmp write_next_byte
}

z_ins_output_stream
	; Set output stream held in z_operand 0
	; input:  z_operand 0: 1..4 to enable, -1..-4 to disable. If enabling stream 3, also provide z_operand 1: z_address of table
	; output:
	; side effects: Uses zp_temp (2 bytes)
	; used registers: a,x,y
	bit z_operand_value_low_arr
	bmi .negative
	lda z_operand_value_low_arr
!ifdef CHECK_ERRORS {
	beq .unsupported_stream
	cmp #5
	bcs .unsupported_stream
}
	tax
	lda #1
	sta streams_output_selected - 1,x
	cpx #3
	beq .turn_on_mem_stream
	rts
!ifdef CHECK_ERRORS {
.unsupported_stream
	lda #ERROR_UNSUPPORTED_STREAM
	jsr fatalerror
}
.negative
	lda z_operand_value_low_arr
!ifdef CHECK_ERRORS {
	cmp #-4
	bmi .unsupported_stream
}
	eor #$ff
	clc
	adc #1
	cmp #3
	bne +
	jmp .turn_off_mem_stream
+	tax
	lda #0
	sta streams_output_selected - 1,x
	rts
.turn_on_mem_stream
!ifdef DEBUG_SCREENLOG {
	lda #10
	jsr screenlog_hook
}
	lda streams_stack_items
	beq .add_first_level
!ifdef CHECK_ERRORS {
	cmp #16
	bcs .stream_nesting_error
}
	asl
	asl
	tay
	; Move current level to stack
	ldx #3
-	lda streams_current_entry,x
	sta streams_stack - 4 + 3,y
!ifdef Z6 {
	lda streams_width_cur,x
	sta streams_width_stack - 4 + 3,y
	lda streams_form_width,x
	sta streams_form_stack - 4 + 3,y
}
	dey
	dex
	bpl -
.add_first_level
!ifdef Z6 {
	; this level's text starts unmeasured
	lda #0
	sta streams_width_cur
	sta streams_width_cur + 1
	sta streams_width_max
	sta streams_width_max + 1
	; a third operand asks for the formatted (print_form) table,
	; word-wrapped: >= 0 names a window whose width is used, < 0 is a
	; box -width units wide (z-spec 1.0 and dfrotz agree; Infocom's v6
	; games always pass 0, window 0)
	sta streams_form_width
	sta streams_form_line_len
	lda #$ff
	sta streams_form_since_space
	lda z_operand_count
	cmp #3
	bcc .form_no_width
	lda z_operand_value_high_arr + 2
	bmi .form_box_width
	lda z_operand_value_low_arr + 2
	and #7
	tax
	lda window_x_size,x
	bne .form_set_width
.form_no_wrap
	lda #254	; wider than any line gets: the format without the wrap
	bne .form_set_width	; always
.form_box_width
	lda #0
	sec
	sbc z_operand_value_low_arr + 2
	tax
	lda #0
	sbc z_operand_value_high_arr + 2
	bne .form_no_wrap	; 256 units or wider: wrap never triggers
	txa
	cmp #255
	bcs .form_no_wrap
.form_set_width
	sta streams_form_width
.form_no_width
}
	; Setup pointer to start of table
	lda z_operand_value_low_arr + 1
	sta streams_current_entry
	lda z_operand_value_high_arr + 1
;	clc
;	adc #>story_start
	sta streams_current_entry + 1
	; Setup pointer to current storage location
	lda streams_current_entry
	clc
	adc #2
	sta streams_current_entry + 2
	lda streams_current_entry + 1
	adc #0
	sta streams_current_entry + 3
	inc streams_stack_items
	rts
!ifdef CHECK_ERRORS {
.stream_nesting_error
	lda #ERROR_STREAM_NESTING_ERROR
	jsr fatalerror
}
.turn_off_mem_stream
	lda streams_stack_items
!ifdef CHECK_ERRORS {
	beq .stream_nesting_error
}
!ifdef Z6 {
	; a formatted (width-operand) table ends with its last record and a
	; zero word; it has no character count at the start
	lda streams_form_width
	beq .form_plain_close
	ldx streams_current_entry + 2
	lda streams_current_entry + 3
	jsr streams_set_z_address
	ldy streams_form_line_len
	jsr .form_write_len	; a zero-length record is itself the terminator
	lda streams_form_line_len
	beq .form_closed
	ldx streams_current_entry + 2
	lda streams_current_entry + 3
	jsr set_z_address
	lda #0
	jsr write_next_byte
	lda #0
	jsr write_next_byte
.form_closed
	jsr streams_unset_z_address
	jmp .mem_stream_closed
.form_plain_close
}
	; Copy length to first word in table

	ldx streams_current_entry
	lda streams_current_entry + 1
	jsr streams_set_z_address
	
	; lda streams_current_entry
	; sta zp_temp
	; lda streams_current_entry + 1
	; sta zp_temp + 1
	lda streams_current_entry + 2
	sec
	sbc #2
	tay
	lda streams_current_entry + 3
	sbc #0
	tax
	tya
	sec
	sbc streams_current_entry
	tay
	txa
	sbc streams_current_entry + 1
	jsr write_next_byte
	tya
	jsr write_next_byte
	jsr streams_unset_z_address

	; ldy #1
	; sta (zp_temp),y
	; txa
	; sbc zp_temp + 1
	; dey
	; sta (zp_temp),y

.mem_stream_closed
!ifdef Z6 {
	; close the last line and hand the game the width of the text it
	; buffered, in header word $30 (z-spec 7.1.2.1.1)
	jsr .streams_line_done
	ldy #header_stream_3_width_units
	lda streams_width_max + 1
	ldx streams_width_max
!ifdef Z6_PIXEL_UNITS {
	; The count is characters; the header wants UNITS, and a unit is an art
	; pixel with Z6_PIXEL_UNITS. Arthur right-aligns its status line by
	; measuring the text here and then set_cursor'ing to (width - measured),
	; so a count left in cells puts the line a quarter of the way across.
	; The measured text can be wider than 255 units, so scale the whole word.
	stx .swm_val
	sta .swm_val + 1
!for .i, 1, Z6_UNIT_W_SHIFT {
	asl .swm_val
	rol .swm_val + 1
}
	lda .swm_val + 1
	ldx .swm_val
}
	jsr write_header_word
!ifdef DEBUG_SCREENLOG {
	lda #11
	jsr screenlog_hook
	lda streams_width_max + 1
	ldx streams_width_max
	jsr screenlog_extra
}
}
	; Pop item off stack
	dec streams_stack_items
	lda streams_stack_items
	beq .remove_first_level
	asl
	asl
	tay
	; Move top stack entry to current level
	ldx #3
-	lda streams_stack - 4 + 3,y
	sta streams_current_entry,x
!ifdef Z6 {
	lda streams_width_stack - 4 + 3,y
	sta streams_width_cur,x
	lda streams_form_stack - 4 + 3,y
	sta streams_form_width,x
}
	dey
	dex
	bpl -
	rts
.remove_first_level
	; Turn off stream 3 output (A is always 0 here)
	sta streams_output_selected + 2
	rts

!ifdef Z6 {
.streams_line_done
	; a line of stream 3 text ended: keep it if it is the widest, and let
	; the next start from nothing
	lda streams_width_cur + 1
	cmp streams_width_max + 1
	bcc .sld_shorter
	bne .sld_wider
	lda streams_width_cur
	cmp streams_width_max
	bcc .sld_shorter
.sld_wider
	lda streams_width_cur
	sta streams_width_max
	lda streams_width_cur + 1
	sta streams_width_max + 1
.sld_shorter
	lda #0
	sta streams_width_cur
	sta streams_width_cur + 1
	rts
}

!ifndef NO_DEFAULT_UNICODE_MAP {
default_unicode_out
!pet "aouAOUs\"\"eiyEIaeiouyAEIOUYaeiouAEIOUaeiouAEIOUaAoOanoANOaAcCttTTLoO!?" 
}

translate_zscii_to_petscii
	; Return PETSCII code *OR* set carry if this ZSCII character is unsupported
	sty .streams_tmp + 1
	ldy #character_translation_table_out_end - character_translation_table_out - 1
-	cmp character_translation_table_out,y
	bcc .no_match
	beq .match
	dey
	bpl -
.no_match
!ifndef NO_DEFAULT_UNICODE_MAP {
	cmp #155
	bcc .no_mapping
	cmp #224
	bcs .no_mapping
	tay
	lda default_unicode_out - 155,y
	bne .ldy_and_return ; Always branch
.no_mapping
}
; .case_conversion
	ldy .streams_tmp + 1
	cmp #$61
	bcc .not_lower_case
	cmp #$7b
	bcs .not_lower_or_upper_case
	; Lower case. $61 -> $41
	and #$df
;	clc ; Already clear
	rts
.not_lower_case
	cmp #$41
	bcc .not_lower_or_upper_case
	cmp #$5b
	bcs .not_lower_or_upper_case
	; Upper case. $41 -> $c1
	ora #$80
;	clc ; Already clear
	rts
.not_lower_or_upper_case
	; Check if legal
	cmp #13
	beq .is_legal
	cmp #$20
	bcc .not_legal
	cmp #$7f
	bcc .is_legal
.not_legal
	sec
	rts
.is_legal
	clc
	rts
.match
	lda character_translation_table_out_end,y
.ldy_and_return
	ldy .streams_tmp + 1
	clc
	rts

streams_set_z_address
	ldy z_address
	sty .z_address
	ldy z_address + 1
	sty .z_address + 1
	ldy z_address + 2
	sty .z_address + 2
	jmp set_z_address

streams_unset_z_address
	ldx #2
-	lda .z_address,x
	sta z_address,x
	dex
	bpl -
!ifdef TARGET_X16 {
	jmp x16_bank_z_address
} else {
	rts
}

.z_address
	!byte 0, 0, 0

}
