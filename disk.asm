;TRACE_FLOPPY = 1
;TRACE_FLOPPY_VERBOSE = 1
nonstored_blocks		!byte 0
readblocks_numblocks	!byte 0 
readblocks_currentblock	!byte 0,0 ; 257 = ff 1
readblocks_currentblock_adjusted	!byte 0,0 ; 257 = ff 1
readblocks_mempos		!byte 0,0 ; $2000 = 00 20
device_map	!byte 0,0,0,0 ; For device# 8,9,10,11
boot_device !byte 0
current_disks !byte $ff, $ff, $ff, $ff
disk_info
!ifdef Z3 {
	!fill 71
}
!ifdef Z4 {
	!fill 94
}
!ifdef Z5 {
	!fill 94
}
!ifdef Z8 {
	!fill 120
}
first_unavailable_save_slot_charcode	!byte 0

!zone disk_messages {
prepare_for_disk_msgs
	jsr clear_screen_raw
	; lda #0
	; sta .print_row
	ldx #0
	tay
	jsr set_cursor
	rts

print_insert_disk_msg
; Parameters: y: memory index to start of info for disk in disk_info
	sty .save_y
	; ldx .print_row
	; ldy #2
	; jsr set_cursor
	lda #>insert_msg_1
	ldx #<insert_msg_1
	jsr printstring_raw
	ldy .save_y
; Print disk name
	lda disk_info + 7,y ; Number of tracks
	clc
	adc .save_y
	tay
-	lda disk_info + 8,y
	beq .disk_name_done
	bmi .special_string
	jsr printchar_raw
	iny
	bne - ; Always branch
.special_string
	and #%111
	tax
	lda .special_string_low,x
	sta .save_x
	lda .special_string_high,x
	ldx .save_x
	jsr printstring_raw
	iny
	jmp -
.disk_name_done
	lda #>insert_msg_2
	ldx #<insert_msg_2
	jsr printstring_raw
	ldy .save_y
	lda disk_info + 4,y
	tax
	cmp #10
	bcc +
	lda #$31
	jsr printchar_raw
	txa
	sec
	sbc #10
+	clc
	adc #$30
	jsr printchar_raw
	lda #>insert_msg_3
	ldx #<insert_msg_3
	jsr printstring_raw
	jsr kernel_readchar
	; lda .print_row
	; clc
	; adc #3
	; sta .print_row
	ldy .save_y
	rts
.save_x	!byte 0
.save_y	!byte 0
.print_row	!byte 14
;.device_no	!byte 0
.special_string_128
	!pet "Boot ",0
.special_string_129
	!pet "Story ",0
.special_string_130
	!pet "Save ",0
.special_string_131
	!pet "disk ",0
.special_string_low		!byte <.special_string_128, <.special_string_129, <.special_string_130, <.special_string_131
.special_string_high	!byte >.special_string_128, >.special_string_129, >.special_string_130, >.special_string_131


insert_msg_1
!pet 13,13,"  Please insert ",0
insert_msg_2
!pet 13,"  in drive ",0
insert_msg_3
!pet " [ENTER] ",0
}
	
readblocks
    ; read <n> blocks (each 256 bytes) from disc to memory
    ; set values in readblocks_* before calling this function
    ; register: a,x,y
!ifdef TRACE_FLOPPY {
    jsr newline
    jsr print_following_string
    !pet "readblocks (n,zp,c64) ",0
    lda readblocks_numblocks
    jsr printa
    jsr comma
    lda readblocks_currentblock + 1
    jsr print_byte_as_hex
    lda readblocks_currentblock
    jsr print_byte_as_hex
    jsr comma
    lda readblocks_mempos + 1
    jsr print_byte_as_hex
    lda readblocks_mempos 
    jsr print_byte_as_hex
    jsr newline
}
-   jsr readblock ; read block
    inc readblocks_mempos + 1   ; update mempos,block for next iteration
    inc readblocks_currentblock
    bne +
    inc readblocks_currentblock + 1
+   dec readblocks_numblocks        ; loop
    bne -
    rts

readblock
    ; read 1 block from floppy
    ; $mempos (contains address to store in) [in]
    ; set values in readblocks_* before calling this function
    ; register a,x,y

!ifdef TRACE_FLOPPY {
	jsr print_following_string
	!pet "Readblock: ",0
	lda readblocks_currentblock + 1
	jsr print_byte_as_hex
	lda readblocks_currentblock
	jsr print_byte_as_hex
}
	lda readblocks_currentblock
	sec
	sbc nonstored_blocks
	sta readblocks_currentblock_adjusted
	sta .blocks_to_go
	lda readblocks_currentblock + 1
	sbc #0
	sta readblocks_currentblock_adjusted + 1
	sta .blocks_to_go + 1

    ; convert block to track/sector
	
	lda disk_info + 2 ; Number of disks
	ldx #0 ; Memory index
	ldy #0 ; Disk id
.check_next_disk	
	txa
	clc
	adc disk_info + 3,x
	sta .next_disk_index ; x-value where next disk starts
	; Check if the block we are looking for is on this disk
	lda readblocks_currentblock_adjusted
	sec
	sbc disk_info + 6,x
	sta .blocks_to_go_tmp + 1
	lda readblocks_currentblock_adjusted + 1
	sbc disk_info + 5,x
	sta .blocks_to_go_tmp
	bcc .right_disk_found ; Found the right disk!
	; This is not the right disk. Save # of blocks to go into next disk.
	lda .blocks_to_go_tmp
	sta .blocks_to_go
	lda .blocks_to_go_tmp + 1
	sta .blocks_to_go + 1
	jmp .next_disk ; Not the right disk, keep looking!
; Found the right disk
.right_disk_found
	lda disk_info + 4,x
	sta .device
	lda disk_info + 7,x
	sta .disk_tracks ; # of tracks which have entries
	lda #1
	sta .track
.check_track
	lda disk_info + 8,x
	beq .next_track
	and #%00011111
	sta .sector
	lda .blocks_to_go + 1
	sec
	sbc .sector
	sta .blocks_to_go_tmp + 1
	lda .blocks_to_go
	sbc #0
	sta .blocks_to_go_tmp
	bcc .right_track_found ; Found the right track
	sta .blocks_to_go
	lda .blocks_to_go_tmp + 1
	sta .blocks_to_go + 1
.next_track
	inx
	inc .track
	dec .disk_tracks
	bne .check_track
; Broken config
+	lda #ERROR_CONFIG ; Config info must be incorrect if we get here
	jmp fatalerror
.next_disk
	ldx .next_disk_index
	iny
	cpy disk_info + 2 ; # of disks
	bcs +
	jmp .check_next_disk
+	lda #ERROR_OUT_OF_MEMORY ; Meaning request for Z-machine memory > EOF. Bad message? 
	jmp fatalerror

.right_track_found
	; Add sectors not used at beginning of track
	; .blocks_to_go + 1: logical sector#
	; disk_info + 8,x: # of sectors skipped (3 bits), # of sectors used (5 bits)
	sty .temp_y
!ifdef TRACE_FLOPPY {
	jsr arrow
	lda .track
	jsr print_byte_as_hex
	jsr comma
	lda .blocks_to_go + 1
	jsr print_byte_as_hex
}
	lda disk_info + 8,x
	lsr
	lsr
	lsr
	lsr
	lsr ; a now holds # of sectors at start of track not in use
	sta .skip_sectors
; Initialize track map. Write 0 for sectors not yet used, $ff for sectors used 
	lda disk_info + 8,x
	and #%00011111
	clc
	adc .skip_sectors
	sta .sector_count
	tay
	dey
	lda #0
-	cpy .skip_sectors
	bcs +
	lda #$ff
+	sta .track_map,y
	dey
	bpl -
;	Find right sector.
;		1. Start at 0
;		2. Find next free sector
;		3. Decrease blocks to go. If < 0, we are done
;		4. Mark sector as used.
;		5. Add interleave, go back to 2	
; 1
	lda #0
; 2
-	tay
	lda .track_map,y
	beq +
	iny
	tya
	cpy .sector_count
	bcc -
	lda #0
	beq - ; Always branch
; 3
+	dec .blocks_to_go + 1
	bmi +
; 4
	lda #$ff
	sta .track_map,y
; 5
	tya
	clc
	adc disk_info ; #SECTOR_INTERLEAVE
.check_sector_range	
	cmp .sector_count
	bcc -
	sbc .sector_count ; c is already set
	bcs .check_sector_range ; Always branch
+	sty .sector
!ifdef TRACE_FLOPPY {
	jsr comma
	tya
	jsr print_byte_as_hex
}
; Restore old value of y
	ldy .temp_y
	jmp .have_set_device_track_sector

.track_map 		!fill 21 ; Holds a map of the sectors in a single track
.sector_count 	!byte 0
.skip_sectors 	!byte 0
.temp_y 		!byte 0


    ; convert track/sector to ascii and update drive command
read_track_sector
	; input: a: track, x: sector, y: device#, Word at readblocks_mempos holds storage address
	sta .track
	stx .sector
	sty .device
.have_set_device_track_sector
	lda .track
    jsr conv2dec
    stx .uname_track
    sta .uname_track + 1
    lda .sector
    jsr conv2dec
    stx .uname_sector
    sta .uname_sector + 1

!ifdef TRACE_FLOPPY_VERBOSE {
    jsr space
    jsr dollar
    lda readblocks_mempos + 1
    jsr print_byte_as_hex
    lda readblocks_mempos 
    jsr print_byte_as_hex
    jsr comma
    ldx readblocks_currentblock
    jsr printx
    ;jsr comma
    ;lda #<.uname
    ;ldy #>.uname
    ;jsr printstring
    jsr newline
}
    ; open the channel file
    lda #cname_len
    ldx #<.cname
    ldy #>.cname
    jsr kernel_setnam ; call SETNAM

    lda #$02      ; file number 2
    ldx .device
	tay      ; secondary address 2
    jsr kernel_setlfs ; call SETLFS

    jsr kernel_open     ; call OPEN
    bcs .error    ; if carry set, the file could not be opened

    ; open the command channel

    lda #uname_len
    ldx #<.uname
    ldy #>.uname
    jsr kernel_setnam ; call SETNAM
    lda #$0F      ; file number 15
    ldx .device
    tay      ; secondary address 15
    jsr kernel_setlfs ; call SETLFS

    jsr kernel_open ; call OPEN (open command channel and send U1 command)
    bcs .error    ; if carry set, the file could not be opened

    ; check drive error channel here to test for
    ; FILE NOT FOUND error etc.

    ldx #$02      ; filenumber 2
    jsr kernel_chkin ; call CHKIN (file 2 now used as input)

    lda readblocks_mempos
    sta zp_mempos
    lda readblocks_mempos+1
    sta zp_mempos + 1

    ldy #$00
-   jsr kernel_readchar ; call CHRIN (get a byte from file)
    sta (zp_mempos),Y   ; write byte to memory
    iny
    bne -         ; next byte, end when 256 bytes are read
close_io
    lda #$0F      ; filenumber 15
    jsr kernel_close ; call CLOSE

    lda #$02      ; filenumber 2
    jsr kernel_close ; call CLOSE

    jsr kernel_clrchn ; call CLRCHN
    rts
.error
    ; accumulator contains BASIC error code
    ; most likely errors:
    ; A = $05 (DEVICE NOT PRESENT)
    jsr close_io    ; even if OPEN failed, the file has to be closed
    lda #ERROR_FLOPPY_READ_ERROR
    jsr fatalerror
.cname !text "#"
cname_len = * - .cname

.uname !text "U1 2 0 "
.uname_track !text "18 "
.uname_sector !text "00"
;!ifdef DEBUG {
    !byte 0 ; end of string, so we can print debug messages
;}
uname_len = * - .uname
.track  !byte 0
.sector !byte 0
.device !byte 0
.blocks_to_go !byte 0, 0
.blocks_to_go_tmp !byte 0, 0
.next_disk_index	!byte 0
.disk_tracks	!byte 0

z_ins_restore
!ifdef Z3 {
	jsr restore_game
	beq +
	jmp make_branch_true
+	jmp make_branch_false
}
!ifdef Z4 {
	jsr restore_game
	beq +
	inx
+	jmp z_store_result
}
!ifdef Z5PLUS {
	jsr restore_game
	beq +
	inx
+	jmp z_store_result
}

z_ins_save
!ifdef Z3 {
	jsr save_game
	beq +
	jmp make_branch_true
+	jmp make_branch_false
}
!ifdef Z4 {
	jsr save_game
	jmp z_store_result
}
!ifdef Z5PLUS {
	jsr save_game
	jmp z_store_result
}

!zone save_restore {
.inputlen !byte 0
.filename !pet "!0" ; 0 is changed to slot number
.inputstring !fill 15 ; filename max 16 chars (fileprefix + 14)
.input_alphanum
    ; read a string with only alphanumeric characters into .inputstring
    ; return: x = number of characters read
    ;         .inputstring: null terminated string read (max 20 characters)
    ; modifies a,x,y
    lda #0
    sta .inputlen
-   jsr $ffe4
    cmp #$14 ; delete
    bne +
    ldx .inputlen
    beq -
    dec .inputlen
    jsr $ffd2
    jmp -
+   cmp #$0d ; enter
    beq +
    sec
    sbc #$30
    cmp #$5B-$30
    bcs -
    sbc #$09 ;actually -$0a because C=0
    cmp #$41-$3a
    bcc -
    adc #$39 ;actually +$3a because C=1
    ldx .inputlen
    cpx #14
    bpl -
    sta .inputstring,x
    inc .inputlen
    jsr $ffd2
    jmp -
+   jsr $ffd2 ; return
    ldx .inputlen
    lda #0
    sta .inputstring,x
    rts

.error
    ; accumulator contains BASIC error code
    ; most likely errors:
    ; A = $05 (DEVICE NOT PRESENT)
	sta zp_temp + 1 ; Store error code for printing
    jsr close_io    ; even if OPEN failed, the file has to be closed
	lda #>.disk_error_msg
	ldx #<.disk_error_msg
	jsr printstring_raw
	; Add code to print error code!
    lda #0
    rts
	
list_save_files
	ldx	first_unavailable_save_slot_charcode
	dex
	stx .saveslot_msg + 8
	lda #13
	jsr printchar_raw
	jsr printchar_raw
	lda #0
	ldx disk_info + 1 ; # of save slots
	dex
-	sta .occupied_slots,x
	dex
	bpl -
	; Remember address of row where first entry is printed
	lda zp_screenline
	sta .base_screen_pos
	lda zp_screenline + 1
	sta .base_screen_pos + 1

    ; open the channel file
    lda #1
    ldx #<.dirname
    ldy #>.dirname
    jsr kernel_setnam ; call SETNAM

    lda #2      ; file number 2
    ldx disk_info + 4 ; Device# for save disk
+   ldy #0      ; secondary address 2
    jsr kernel_setlfs ; call SETLFS

    jsr kernel_open     ; call OPEN
    bcs .error    ; if carry set, the file could not be opened

    ldx #2      ; filenumber 2
    jsr kernel_chkin ; call CHKIN (file 2 now used as input)

	; Skip load address and disk title
	ldy #32
-	jsr kernel_readchar
	dey
	bne -

.read_next_line	
	lda #0
	sta zp_temp + 1
	; Read row pointer
	jsr kernel_readchar
	sta zp_temp
	jsr kernel_readchar
	ora zp_temp
	beq .end_of_dir

	jsr kernel_readchar
	jsr kernel_readchar
-	jsr kernel_readchar
	cmp #0
	beq .read_next_line
	cmp #$22 ; Charcode for "
	bne -
	jsr kernel_readchar
	cmp #$21 ; charcode for !
	bne .not_a_save_file
	jsr kernel_readchar
	cmp #$30 ; charcode for 0
	bcc .not_a_save_file
	cmp first_unavailable_save_slot_charcode
;	cmp #$3a ; (charcode for 9) + 1
	bcs .not_a_save_file
	tax
	lda .occupied_slots - $30,x
	bne .not_a_save_file ; Since there is another save file with the same number, we ignore this file.
	txa
	sta .occupied_slots - $30,x
	jsr printchar_raw
	lda #58
	jsr printchar_raw
	lda #32
	jsr printchar_raw
	dec zp_temp + 1
	
-	jsr kernel_readchar
.not_a_save_file	
	cmp #$22 ; Charcode for "
	beq .end_of_name
	bit zp_temp + 1
	bpl - ; Skip printing if not a save file
	jsr printchar_raw
	bne - ; Always branch
.end_of_name
-	jsr kernel_readchar
	cmp #0 ; EOL
	bne -
	bit zp_temp + 1
	bpl .read_next_line ; Skip printing if not a save file
	lda #13
	jsr printchar_raw
	bne .read_next_line
	
.end_of_dir
	jsr close_io

	; Fill in blanks
	ldx #0
-	lda .occupied_slots,x
	bne +
	txa
	ora #$30
	jsr printchar_raw
	lda #58
	jsr printchar_raw
	lda #13
	jsr printchar_raw
+	inx
	cpx disk_info + 1 ; # of save slots
	bcc -
	; Sort list
	ldx #1
	stx .sort_item
-	jsr .insertion_sort_item
	inc .sort_item
	ldx .sort_item
	cpx disk_info + 1; # of save slots
	bcc -
	
	lda #1 ; Signal success
    rts

.insertion_sort_item
	; Parameters: x, .sort_item: item (1-9)
	stx .current_item
--	jsr .calc_screen_address
	stx zp_temp + 2
	sta zp_temp + 3
	ldx .current_item
	dex
	jsr .calc_screen_address
	stx zp_temp
	sta zp_temp + 1
	ldy #0
	lda (zp_temp + 2),y
	cmp (zp_temp),y
	bcs .done_sort
	; Swap items
	ldy #17
-	lda (zp_temp),y
	pha
	lda (zp_temp + 2),y
	sta (zp_temp),y
	pla
	sta (zp_temp + 2),y
	dey
	bpl -
	dec .current_item
	ldx .current_item
	bne --
.done_sort
	rts
.calc_screen_address
	lda .base_screen_pos
	ldy .base_screen_pos + 1
	stx .counter
	clc
-	dec .counter
	bmi +
	adc #40
	tax
	tya
	adc #0
	tay
	txa
	bcc - ; Always branch
+	tax
	tya
	rts		
.dirname
	!pet "$"
.occupied_slots
	!fill 10,0
.disk_error_msg
	!pet 13,"Disk error #",0
.sort_item
	!byte 0
.current_item
	!byte 0
.counter
	!byte 0
.base_screen_pos
	!byte 0,0
.insert_save_disk
	ldx disk_info + 4 ; Device# for save disk
	lda current_disks - 8,x
	sta .last_disk
	beq + ; Save disk is already in drive.
	jsr prepare_for_disk_msgs
	ldy #0
	jsr print_insert_disk_msg
+   rts

.insert_story_disk
	ldy .last_disk
	beq + ; Save disk was in disk before, no need to change
	bmi + ; The drive was empty before, no need to change disk now
	jsr print_insert_disk_msg
	tya
	ldx disk_info + 4 ; Device# for save disk
	sta current_disks - 8,x

+	jsr clear_screen_raw
	ldx #24
	ldy #0
	jmp set_cursor

restore_game
    jsr .insert_save_disk

	; List files on disk
	jsr list_save_files
	beq .restore_failed

	; Pick a slot#
	lda #>.saveslot_msg ; high
	ldx #<.saveslot_msg ; low
	jsr printstring_raw
	jsr .input_alphanum
	cpx #1
	bne .restore_failed
	lda .inputstring
	cmp first_unavailable_save_slot_charcode
	bpl .restore_failed ; not a number (0-9)
	sta .restore_filename + 1

	; Print "Restoring..."
	lda #>.restore_msg
	ldx #<.restore_msg
	jsr printstring_raw

	jsr .swap_pointers_for_save
	
	; Perform restore
	jsr do_restore
    bcs .restore_failed    ; if carry set, a file error has happened

	; Swap in z_pc and stack_ptr
	jsr .swap_pointers_for_save

    jsr .insert_story_disk
	jsr get_page_at_z_pc
	lda #0
	ldx #1
	rts
.restore_failed
    jsr .insert_story_disk
	; Return failed status
	lda #0
	tax
	rts

save_game
    jsr .insert_save_disk

	; List files on disk
	jsr list_save_files
	beq .save_failed

	; Pick a slot#
	lda #>.saveslot_msg ; high
	ldx #<.saveslot_msg ; low
	jsr printstring_raw
	jsr .input_alphanum
	cpx #1
	bne .save_failed
	lda .inputstring
	cmp first_unavailable_save_slot_charcode
	bpl .save_failed ; not a number (0-9)
	sta .filename + 1
	sta .erase_cmd + 3
	
	; Enter a name
	lda #>.savename_msg ; high
	ldx #<.savename_msg ; low
	jsr printstring_raw
	jsr .input_alphanum
	cpx #0
	beq .save_failed
	
	; Print "Saving..."
	lda #>.save_msg
	ldx #<.save_msg
	jsr printstring_raw

	; Erase old file, if any
    lda #5
    ldx #<.erase_cmd
    ldy #>.erase_cmd
    jsr kernel_setnam
    lda #$0f      ; file number 15
    ldx disk_info + 4 ; Device# for save disk
	ldy #$0f      ; secondary address 15
    jsr kernel_setlfs
    jsr kernel_open ; open command channel and send delete command)
    bcs .save_failed  ; if carry set, the file could not be opened
    lda #$0f      ; filenumber 15
    jsr kernel_close
	
	; Swap in z_pc and stack_ptr
	jsr .swap_pointers_for_save
	
	; Perform save
	jsr do_save
    bcs .save_failed    ; if carry set, a save error has happened

	; Swap out z_pc and stack_ptr
	jsr .swap_pointers_for_save

    jsr .insert_story_disk
	lda #0
	ldx #1
	rts
.save_failed
    jsr .insert_story_disk
	; Return failed status
	lda #0
	tax
	rts

do_restore
    lda #3
    ldx #<.restore_filename
    ldy #>.restore_filename
    jsr kernel_setnam
    lda #1      ; file number
    ldx disk_info + 4 ; Device# for save disk
	ldy #1      ; not $01 means: load to address stored in file
    jsr kernel_setlfs
    lda #$00      ; $00 means: load to memory (not verify)
    jsr kernel_load
    php ; store c flag so error can be checked by calling routine
    lda #1 
    jsr kernel_close
    plp ; restore c flag
    rts

do_save
    lda .inputlen
    clc
    adc #2 ; add 2 bytes for prefix
    ldx #<.filename
    ldy #>.filename
    jsr kernel_setnam
    lda #1      ; file# 1
    ldx disk_info + 4 ; Device# for save disk
	ldy #1
    jsr kernel_setlfs
    lda #<(stack_start - zp_bytes_to_save)
    sta $c1
    lda #>(stack_start - zp_bytes_to_save)
    sta $c2
    ldx story_start + header_static_mem + 1
    lda story_start + header_static_mem
    clc
    adc #>story_start
    tay
    lda #$c1      ; start address located in $C1/$C2
    jsr kernel_save
    php ; store c flag so error can be checked by calling routine
    lda #1 
    jsr kernel_close
    plp ; restore c flag
    rts
.last_disk	!byte 0
.saveslot !byte 0
.saveslot_msg	!pet "Slot (0-9, RETURN=cancel): ",0 ; Will be modified to say highest available slot #
.savename_msg	!pet "Comment (RETURN=cancel): ",0
.save_msg	!pet 13,13,"  Saving...",0
.restore_msg	!pet 13,13,"  Restoring...",0
.restore_filename !pet "!0*" ; 0 will be changed to selected slot
.erase_cmd !pet "s:!0*" ; 0 will be changed to selected slot
.swap_pointers_for_save
	ldx #zp_bytes_to_save - 1
-	lda zp_save_start,x
	ldy stack_start - zp_bytes_to_save,x
	sta stack_start - zp_bytes_to_save,x
	sty zp_save_start,x
	dex
	bpl -
	rts
}


	
