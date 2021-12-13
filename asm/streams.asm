; Routines to handle output streams and input streams

!zone streams {
streams_current_entry		!byte 0,0,0,0
streams_stack				!fill 60, 0
streams_stack_items			!byte 0
streams_buffering			!byte 1,1
streams_output_selected		!byte 0, 0, 0, 0

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

} else { ; End of Swedish section
!ifdef DANISH_CHARS {

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

} else { ; End of Danish section
!ifdef GERMAN_CHARS {

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

} else { ; End of German section
!ifdef ITALIAN_CHARS {

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

} else { ; End of Italian section


!ifdef SPANISH_CHARS {

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

} else { ; End of Spanish section

!ifdef FRENCH_CHARS {

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

} else { ; End of French section

; ENGLISH

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


} ; End of non-French section
} ; End of non-Spanish section
} ; End of non-Italian section
} ; End of non-German section
} ; End of non-Danish section
} ; End of non-Swedish section

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
	beq .turn_off_mem_stream
	tax
	lda #0
	sta streams_output_selected - 1,x
	rts
.turn_on_mem_stream
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
	dey
	dex
	bpl -
.add_first_level
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
	dey
	dex
	bpl -
	rts
.remove_first_level
	; Turn off stream 3 output (A is always 0 here)
	sta streams_output_selected + 2
	rts

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
	ldy .streams_tmp + 1
	; Check if legal
	cmp #13
	beq .case_conversion_done
	cmp #$20
	bcc .not_legal
	cmp #$7f
	bcc .is_legal
.not_legal
	sec
	rts
.is_legal
; .case_conversion
	cmp #$41
	bcc .case_conversion_done
	cmp #$5b
	bcs .not_upper_case
	; Upper case. $41 -> $c1
	ora #$80
	bcc .case_conversion_done
.not_upper_case
	cmp #$61
	bcc .case_conversion_done
	cmp #$7b
	bcs .case_conversion_done
	; Lower case. $61 -> $41
	and #$df
.case_conversion_done
	clc
	rts
.match
	lda character_translation_table_out_end,y
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
	rts
	

.z_address
	!byte 0, 0, 0

}
