first_unavailable_save_slot_charcode	!byte 0
current_disks !byte $ff, $ff, $ff, $ff
boot_device !byte 0
ask_for_save_device !byte $ff

!ifndef VMEM {
disk_info
	!byte 0, 0, 1  ; Interleave, save slots, # of disks
	!byte 8, 8, 0, 0, 0, 130, 131, 0 
} else {

device_map !byte 0,0,0,0

nonstored_blocks		!byte 0
readblocks_numblocks	!byte 0 
readblocks_currentblock	!byte 0,0 ; 257 = ff 1
readblocks_currentblock_adjusted	!byte 0,0 ; 257 = ff 1
readblocks_mempos		!byte 0,0 ; $2000 = 00 20
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

.readblock_from_reu
	ldx readblocks_currentblock_adjusted
	ldy readblocks_currentblock_adjusted + 1
	inx
	bne +
	iny
+	tya
	ldy readblocks_mempos + 1 ; Assuming lowbyte is always 0 (which it should be)
	jmp copy_page_from_reu

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

	; Check if game has been cached to REU
	bit use_reu
	bvs .readblock_from_reu

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
	and #%00111111
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
!ifndef UNSAFE {
; Broken config
	lda #ERROR_CONFIG ; Config info must be incorrect if we get here
	jmp fatalerror
}
.next_disk
	ldx .next_disk_index
	iny
!ifdef UNSAFE {
	jmp .check_next_disk
} else {
	cpy disk_info + 2 ; # of disks
	bcs +
	jmp .check_next_disk
+	lda #ERROR_OUT_OF_MEMORY ; Meaning request for Z-machine memory > EOF. Bad message? 
	jmp fatalerror
}

.right_track_found
	; Add sectors not used at beginning of track
	; .blocks_to_go + 1: logical sector#
	; disk_info + 8,x: # of sectors skipped / 2 (2 bits), # of sectors used (6 bits)
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
	lsr	
	and #%00000110; a now holds # of sectors at start of track not in use
	sta .skip_sectors
; Initialize track map. Write 0 for sectors not yet used, $ff for sectors used 
	lda disk_info + 8,x
	and #%00111111
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

.track_map 		!fill 40 ; Holds a map of the sectors in a single track
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
    jsr kernal_setnam ; call SETNAM

    lda #$02      ; file number 2
    ldx .device
	tay      ; secondary address 2
    jsr kernal_setlfs ; call SETLFS

    jsr kernal_open     ; call OPEN
    bcs .error    ; if carry set, the file could not be opened

    ; open the command channel

    lda #uname_len
    ldx #<.uname
    ldy #>.uname
    jsr kernal_setnam ; call SETNAM
    lda #$0F      ; file number 15
    ldx .device
    tay      ; secondary address 15
    jsr kernal_setlfs ; call SETLFS

    jsr kernal_open ; call OPEN (open command channel and send U1 command)
    bcs .error    ; if carry set, the file could not be opened

    ; check drive error channel here to test for
    ; FILE NOT FOUND error etc.

    ldx #$02      ; filenumber 2
    jsr kernal_chkin ; call CHKIN (file 2 now used as input)

    lda readblocks_mempos
    sta zp_mempos
    lda readblocks_mempos+1
    sta zp_mempos + 1

    ldy #$00
-   jsr kernal_readchar ; call CHRIN (get a byte from file)
    sta (zp_mempos),Y   ; write byte to memory
    iny
    bne -         ; next byte, end when 256 bytes are read
	jmp close_io
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
    !byte 0 ; end of string, so we can print debug messages

uname_len = * - .uname
.track  !byte 0
.sector !byte 0
.device !byte 0
.blocks_to_go !byte 0, 0
.blocks_to_go_tmp !byte 0, 0
.next_disk_index	!byte 0
.disk_tracks	!byte 0
} ; End of !ifdef VMEM

close_io
    lda #$0F      ; filenumber 15
    jsr kernal_close ; call CLOSE

    lda #$02      ; filenumber 2
    jsr kernal_close ; call CLOSE

    jmp kernal_clrchn ; call CLRCHN

!zone disk_messages {
prepare_for_disk_msgs
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
	and #%00000111
	tax
	lda .special_string_low,x
	sta .save_x
	lda .special_string_high,x
	ldx .save_x
	jsr printstring_raw
	iny
	bne - ; Always branch
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
	;jsr kernal_readchar ; this shows the standard kernal prompt (not good)
-	jsr kernal_getchar
    beq -
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
!pet 13,"  Please insert ",0
insert_msg_2
!pet 13,"  in drive ",0
insert_msg_3
!pet " [ENTER] ",0
}


!ifdef VMEM {
z_ins_restart
	; Find right device# for boot disk

	ldx disk_info + 3
	lda disk_info + 4,x
	cmp #10
	bcc +
	inc .restart_code_string + 12
	sec
	sbc #10
+	ora #$30
	sta .restart_code_string + 13
	
	; Check if disk is in drive
	lda disk_info + 4,x
	tay
	txa
	cmp current_disks - 8,y
	beq +
	jsr print_insert_disk_msg
+

	; Copy restart code
	ldx #.restart_code_end - .restart_code_begin
-	lda .restart_code_begin - 1,x
	sta .restart_code_address - 1,x
	dex
	bne -

	; Setup	key sequence
	ldx #0
-	lda .restart_keys,x
	beq +
	sta 631,x
	inx
	bne - ; Always branch
+	stx 198
	jsr clear_screen_raw
	; lda #147
	; jsr $ffd2
	lda #z_exe_mode_exit
	sta z_exe_mode
	rts
.restart_keys
;	!pet "lO",34,":*",34,",08:",131,0
	!pet "sY3e4",13,0

.restart_code_address = 30000

.restart_code_begin
.restart_code_string_final_pos = .restart_code_string - .restart_code_begin + .restart_code_address
	ldx #0
-	lda .restart_code_string_final_pos,x
	beq +
	jsr $ffd2
	inx
	bne -
	; Setup	key sequence
+	lda #131
	sta 631
	lda #1
	sta 198
	rts
		
.restart_code_string
	!pet 147,17,17,"    ",34,":*",34,",08",19,0
; .restart_code_keys
	; !pet 131,0
.restart_code_end

}

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
	jsr turn_on_cursor
    lda #0
    sta .inputlen
-   jsr kernal_getchar
    cmp #$14 ; delete
    bne +
    ldx .inputlen
    beq -
    dec .inputlen
	pha
	jsr turn_off_cursor
	pla
    jsr s_printchar
	jsr turn_on_cursor
    jmp -
+   cmp #$0d ; enter
    beq .input_done
	cmp #$20
	beq .char_is_ok
    sec
    sbc #$30
    cmp #$5B-$30
    bcs -
    sbc #$09 ;actually -$0a because C=0
    cmp #$41-$3a
    bcc -
    adc #$39 ;actually +$3a because C=1
.char_is_ok
    ldx .inputlen
    cpx #14
    bcs -
    sta .inputstring,x
    inc .inputlen
    jsr s_printchar
	jsr update_cursor
    jmp -
.input_done
	pha
	jsr turn_off_cursor
	pla
	jsr s_printchar ; return
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
	lda #13
	jsr s_printchar
	ldx	first_unavailable_save_slot_charcode
	dex
	stx .saveslot_msg + 9
	ldx disk_info + 1 ; # of save slots
	lda #0
-	sta .occupied_slots - 1,x
	dex
	bne -
	; Remember address of row where first entry is printed
	lda zp_screenline
	sta .base_screen_pos
	lda zp_screenline + 1
	sta .base_screen_pos + 1

    ; open the channel file
    lda #1
    ldx #<.dirname
    ldy #>.dirname
    jsr kernal_setnam ; call SETNAM

    lda #2      ; file number 2
    ldx disk_info + 4 ; Device# for save disk
+   ldy #0      ; secondary address 2
    jsr kernal_setlfs ; call SETLFS

    jsr kernal_open     ; call OPEN
    bcs .error    ; if carry set, the file could not be opened

    ldx #2      ; filenumber 2
    jsr kernal_chkin ; call CHKIN (file 2 now used as input)

	; Skip load address and disk title
	ldy #32
-	jsr kernal_readchar
	dey
	bne -

.read_next_line	
	lda #0
	sta zp_temp + 1
	; Read row pointer
	jsr kernal_readchar
	sta zp_temp
	jsr kernal_readchar
	ora zp_temp
	beq .end_of_dir

	jsr kernal_readchar
	jsr kernal_readchar
-	jsr kernal_readchar
	cmp #0
	beq .read_next_line
	cmp #$22 ; Charcode for "
	bne -
	jsr kernal_readchar
	cmp #$21 ; charcode for !
	bne .not_a_save_file
	jsr kernal_readchar
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
	
-	jsr kernal_readchar
.not_a_save_file	
	cmp #$22 ; Charcode for "
	beq .end_of_name
	bit zp_temp + 1
	bpl - ; Skip printing if not a save file
	jsr printchar_raw
	bne - ; Always branch
.end_of_name
-	jsr kernal_readchar
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
	beq .dont_print_insert_save_disk ; Save disk is already in drive.
	jsr prepare_for_disk_msgs
	ldy #0
	jsr print_insert_disk_msg
	ldx disk_info + 4 ; Device# for save disk
	lda #0
	sta current_disks - 8,x
	beq .insert_done
.dont_print_insert_save_disk	
	ldx #0
	ldy #5
-	jsr kernal_delay_1ms
	dex
	bne -
	dey
	bne -
.insert_done
    ldx #0
!ifdef Z5PLUS {
	jmp erase_window
} else {
    jsr erase_window
	ldx window_start_row + 1 ; First line in lower window
	ldy #0
	jmp set_cursor
}	
	

.insert_story_disk
	ldy .last_disk
	beq + ; Save disk was in drive before, no need to change
	bmi + ; The drive was empty before, no need to change disk now
	jsr print_insert_disk_msg
	tya
	ldx disk_info + 4 ; Device# for save disk
	sta current_disks - 8,x
+	ldx #0
    jmp erase_window

maybe_ask_for_save_device
	lda ask_for_save_device
	beq .dont_ask
	lda #0
	sta ask_for_save_device
.ask_again
	lda #>.save_device_msg ; high
	ldx #<.save_device_msg ; low
	jsr printstring_raw
	jsr .input_alphanum
	cpx #0
	beq .dont_ask
	cpx #3
	bcs .ask_again
	; One or two digits
	cpx #1
	bne .two_digits
	lda .inputstring
	and #1
	ora #8
	bne .store_device ; Always jump
.two_digits
	lda .inputstring + 1
	and #1
	ora #10
.store_device
	sta disk_info + 4
.dont_ask
	rts
	
restore_game
	jsr maybe_ask_for_save_device

    jsr .insert_save_disk

	; List files on disk
	jsr list_save_files
	beq .restore_failed

	; Pick a slot#
	lda #>.saveslot_msg_restore ; high
	ldx #<.saveslot_msg_restore ; low
	jsr printstring_raw
	lda #>.saveslot_msg ; high
	ldx #<.saveslot_msg ; low
	jsr printstring_raw
	jsr .input_alphanum
	cpx #1
	bne .restore_failed
	lda .inputstring
	cmp first_unavailable_save_slot_charcode
	bpl .restore_failed ; not a number (0-9)
	tax
	lda .occupied_slots - $30,x
	beq .restore_failed ; If the slot is unoccupied, fail.
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
	lda use_reu
	bmi +
    jsr .insert_story_disk
+	jsr get_page_at_z_pc
	lda #0
	ldx #1
	rts
.restore_failed
	lda use_reu
	bmi +
    jsr .insert_story_disk
	; Return failed status
+	lda #0
	tax
	rts

save_game

	jsr maybe_ask_for_save_device

    jsr .insert_save_disk

	; List files on disk
	jsr list_save_files
	beq .restore_failed

	; Pick a slot#
	lda #>.saveslot_msg_save ; high
	ldx #<.saveslot_msg_save ; low
	jsr printstring_raw
	lda #>.saveslot_msg ; high
	ldx #<.saveslot_msg ; low
	jsr printstring_raw
	jsr .input_alphanum
	cpx #1
	bne .restore_failed
	lda .inputstring
	cmp first_unavailable_save_slot_charcode
	bpl .restore_failed ; not a number (0-9)
	sta .filename + 1
	sta .erase_cmd + 3
	
	; Enter a name
	lda #>.savename_msg ; high
	ldx #<.savename_msg ; low
	jsr printstring_raw
	jsr .input_alphanum
	cpx #0
	beq .restore_failed
	
	; Print "Saving..."
	lda #>.save_msg
	ldx #<.save_msg
	jsr printstring_raw

	; Erase old file, if any
    lda #5
    ldx #<.erase_cmd
    ldy #>.erase_cmd
    jsr kernal_setnam
    lda #$0f      ; file number 15
    ldx disk_info + 4 ; Device# for save disk
	ldy #$0f      ; secondary address 15
    jsr kernal_setlfs
    jsr kernal_open ; open command channel and send delete command)
    bcs .restore_failed  ; if carry set, the file could not be opened
    lda #$0f      ; filenumber 15
    jsr kernal_close
	
	; Swap in z_pc and stack_ptr
	jsr .swap_pointers_for_save
	
	; Perform save
	jsr do_save
    bcs .restore_failed    ; if carry set, a save error has happened

	; Swap out z_pc and stack_ptr
	jsr .swap_pointers_for_save

 	lda use_reu
	bmi +
	jsr .insert_story_disk
+	lda #0
	ldx #1
	rts

do_restore
    lda #3
    ldx #<.restore_filename
    ldy #>.restore_filename
    jsr kernal_setnam
    lda #1      ; file number
    ldx disk_info + 4 ; Device# for save disk
	ldy #1      ; not $01 means: load to address stored in file
    jsr kernal_setlfs
    lda #$00      ; $00 means: load to memory (not verify)
    jsr kernal_load
    php ; store c flag so error can be checked by calling routine
    lda #1 
    jsr kernal_close
    plp ; restore c flag
    rts

do_save
    lda .inputlen
    clc
    adc #2 ; add 2 bytes for prefix
    ldx #<.filename
    ldy #>.filename
    jsr kernal_setnam
    lda #1      ; file# 1
    ldx disk_info + 4 ; Device# for save disk
	ldy #1
    jsr kernal_setlfs
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
    jsr kernal_save
    php ; store c flag so error can be checked by calling routine
    lda #1 
    jsr kernal_close
    plp ; restore c flag
    rts
.last_disk	!byte 0
.saveslot !byte 0
.saveslot_msg_save	!pet 13,"Save to",0 ; Will be modified to say highest available slot #
.saveslot_msg_restore	!pet 13,"Restore from",0 ; Will be modified to say highest available slot #
.saveslot_msg	!pet " slot (0-9, RETURN=cancel): ",0 ; Will be modified to say highest available slot #
.savename_msg	!pet "Comment (RETURN=cancel): ",0
.save_msg	!pet 13,"Saving...",13,0
.restore_msg	!pet 13,"Restoring...",13,0
.save_device_msg !pet 13,"Device# (8-11, RETURN=default): ",0
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


	
