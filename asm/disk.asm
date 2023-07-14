!zone disk {

first_unavailable_save_slot_charcode	!byte 0
; current_disks holds $ff for a drive which doesn't contain an Ozmoo disk OR
; the index into disk_info where information about this disk starts *MINUS 3*
; So 0 means save disk, 8 means boot disk or boot/story disk etc.
current_disks !byte $ff, $ff, $ff, $ff,$ff, $ff, $ff, $ff
boot_device !byte 0
ask_for_save_device !byte $ff

!ifdef TARGET_MEGA65 {

mega65io
    ; enable C65GS/VIC-IV IO registers
    ;
    ; (they will only be active until the first access
    ; so mega65io needs to be called before any extended I/O)
    lda #$47
    sta $d02f
    lda #$53
    sta $d02f
    rts

nonstored_pages			!byte 0

m65_run_dma
	
	jsr mega65io
	lda #0
	sta $d702 ; DMA list is in bank 0
	lda #>dma_list
	sta $d701
	lda #<dma_list
	sta $d705 
	cli
	clc
	rts	

dma_list
	!byte $0b ; Use 12-byte F011B DMA list format
	!byte $80 ; Set source address bit 20-27
dma_source_address_top		!byte 0
	!byte $81 ; Set destination address bit 20-27
dma_dest_address_top		!byte 0
	!byte $00 ; End of options
dma_command_lsb			!byte 0		; 0 = Copy
dma_count					!word $100	; Always copy one page
dma_source_address			!word 0
dma_source_bank_and_flags	!byte 0
dma_dest_address			!word 0
dma_dest_bank_and_flags	!byte 0
dma_command_msb			!byte 0		; 0 for linear addressing for both src and dest
dma_modulo					!word 0		; Ignored, since we're not using the MODULO flag

}

!ifndef VMEM {
;	!ifdef TARGET_MEGA65 {
disk_info
		!byte 0, 0, 2  ; Interleave, save slots, # of disks
		!byte 8, 8, 0, 0, 0, 130, 131, 0 
		!pet 11, 8, 0, 0, 0, 128, "/ ", 129, 131, 0 
	; } else { 
; disk_info
		; !byte 0, 0, 1  ; Interleave, save slots, # of disks
		; !byte 8, 8, 0, 0, 0, 130, 131, 0 
	; }
} else {
; VMEM

device_map !byte 0,0,0,0,0,0,0,0

nonstored_pages			!byte 0
readblocks_numblocks	!byte 0 
readblocks_currentblock	!byte 0,0 ; 257 = ff 1
readblocks_currentblock_adjusted	!byte 0,0 ; 257 = ff 1
readblocks_mempos		!byte 0,0 ; $2000 = 00 20
disk_info
!ifndef Z4PLUS {
	!fill 71
}
!ifdef Z4 {
	!fill 94
}
!ifdef Z5 {
	!fill 94
}
!ifdef Z7PLUS {
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

!if SUPPORT_REU = 1 {
.readblock_from_reu
	ldx readblocks_currentblock_adjusted
	ldy readblocks_currentblock_adjusted + 1
	; Statmem begins on page 1 (page 0 is reserved for copy operations)
	inx
	bne +
	iny
+
	tya
	ldy readblocks_mempos + 1 ; Assuming lowbyte is always 0 (which it should be)
	jmp copy_page_from_reu
}
readblock
	; read 1 block from floppy
	; $mempos (contains address to store in) [in]
	; set values in readblocks_* before calling this function
	; register a,x,y

!ifdef SMOOTHSCROLL {
	jsr wait_smoothscroll
}

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
	sbc nonstored_pages
	sta readblocks_currentblock_adjusted
	sta .blocks_to_go
	lda readblocks_currentblock + 1
	sbc #0
	sta readblocks_currentblock_adjusted + 1
	sta .blocks_to_go + 1

!if SUPPORT_REU = 1 {
	; Check if game has been cached to REU
	bit use_reu
	bvs .readblock_from_reu
}
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
!ifdef CHECK_ERRORS {
; Broken config
	lda #ERROR_CONFIG ; Config info must be incorrect if we get here
	jmp fatalerror
}
.next_disk
	ldx .next_disk_index
	iny
!ifdef CHECK_ERRORS {
	cpy disk_info + 2 ; # of disks
	bcs +
	jmp .check_next_disk
+	lda #ERROR_OUT_OF_MEMORY ; Meaning request for Z-machine memory > EOF. Bad message? 
	jmp fatalerror
} else {
	jmp .check_next_disk
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
	jsr convert_byte_to_two_digits
	stx .uname_track
	sta .uname_track + 1
	lda .sector
	jsr convert_byte_to_two_digits
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

!ifdef TARGET_C128 {
	lda #0
	sta allow_2mhz_in_40_col
	sta reg_2mhz	;CPU = 1MHz
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
!ifdef TARGET_C128 {
	lda #$00
	tax
	jsr kernal_setbnk
}
	jsr kernal_open     ; call OPEN
	bcs is_error    ; if carry set, the file could not be opened

	; open the command channel

	lda #uname_len
	ldx #<.uname
	ldy #>.uname
	jsr kernal_setnam ; call SETNAM
	lda #$0F      ; file number 15
	ldx .device
	tay      ; secondary address 15
	jsr kernal_setlfs ; call SETLFS
!ifdef TARGET_C128 {
	lda #$00
	tax
	jsr kernal_setbnk
}
	jsr kernal_open ; call OPEN (open command channel and send U1 command)
	bcs is_error    ; if carry set, the file could not be opened

	; DEBUG print
;	lda #>.uname
;	ldx #<.uname
;	jsr printstring_raw
;	lda #$0d
;	jsr s_printchar
	
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
!ifdef TARGET_C128 {
	jsr close_io
	jmp restore_2mhz
} else {
	jmp close_io
}

.cname !text "#"
cname_len = * - .cname
.uname !text "U1 2 0 "
.uname_track !text "18 "
.uname_sector !text "00"
uname_len = * - .uname
	!byte 0 ; end of string, so we can print debug messages

is_error
	; accumulator contains BASIC error code
	; most likely errors:
	; A = $05 (DEVICE NOT PRESENT)
	jmp disk_error


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
	jsr s_printchar
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
	jsr convert_byte_to_two_digits
	cpx #$30
	beq +
	pha
	txa
	jsr s_printchar
	pla
+	jsr s_printchar
	lda #>insert_msg_3
	ldx #<insert_msg_3
	jsr printstring_raw
!ifdef SMOOTHSCROLL {
	jsr wait_smoothscroll
}
	;jsr kernal_readchar ; this shows the standard kernal prompt (not good)
-	jsr kernal_getchar
	beq -

	ldy .save_y
	rts
.save_x	!byte 0
.save_y	!byte 0
.print_row	!byte 14
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

!ifdef RESTART_SUPPORTED {
z_ins_restart
	; insert device# for boot disk in LOAD command
	lda disk_info + 4 + 8 ; Device# for story disk (typically 8)
	jsr convert_byte_to_two_digits
	stx .device_no
	sta .device_no + 1

	; Check if disk is in drive
	ldy disk_info + 4 + 8 ; Device# for story disk (typically 8)
;	lda disk_info + 4,x
;	tay
;	txa
	lda #8; Index of story disk in disk_info - 3
	cmp current_disks - 8,y
	beq +
	tay
	jsr print_insert_disk_msg
+

!ifndef TARGET_MEGA65 {
	!if SUPPORT_REU = 1 {
		lda use_reu
		beq +
		; Write the game id as a signature to say that REU is already loaded.
		ldx #3
-		lda game_id,x
		sta reu_filled,x
		dex
		bpl -
+
	}
}

!ifdef TARGET_MEGA65 {
	; ; reset will autoboot the game again from disk
	; jmp kernal_reset
	lda #$00
	ldx #$04
	sta $d060
	stx $d061
	sta $d062
	sta $d063

	lda #$40
	sta $d031
	lda #$09
	sta $D016


	; Enable VIC-II hot registers
	lda $d05d
	ora #$80
	sta $d05d
	
	lda #$0
	sta $d02f
	sta $d02f
	lda #$17
	sta reg_screen_char_mode

	+disable_interrupts
	lda #$37
	sta $01
	lda #0
	tax
	tay
	taz
	map
	eom
	+enable_interrupts

	lda #>$0400 		; Make sure screen memory set to sensible location
	sta $0288		; before we call screen init $FF5B
	jsr $ff5b ; more init
}

;!ifndef TARGET_MEGA65 {
	+disable_interrupts
	cld
!ifdef TARGET_C128 {
	lda COLS_40_80
	sta first_unavailable_save_slot_charcode
	lda #0
	sta c128_mmu_cfg
}
	jsr $ff8a ; restor (Fill vector table at $0314-$0333 with default values)
	jsr $ff84 ; ioinit (Initialize CIA's, SID, memory config, interrupt timer)
	jsr $ff81 ; scinit (Initialize VIC; set nput/output to keyboard/screen)
!ifdef TARGET_C128 {
	lda COLS_40_80
	cmp first_unavailable_save_slot_charcode
	beq +
	jsr kernal_jswapper
+
}

	+enable_interrupts
!ifdef TARGET_C128 {
	sta c128_mmu_load_pcra
}
;}

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
	sta keyboard_buff,x
	inx
	bne - ; Always branch
+	stx keyboard_buff_len
	lda #147
	jsr kernal_printchar
	lda #z_exe_mode_exit
	jsr set_z_exe_mode
	rts
.restart_keys
;	!pet "lO",34,":*",34,",08:",131,0
!ifdef TARGET_C128 {
	; must select memory under $4000 (basic)
	!pet "sY4e3",13,0
.restart_code_address = 4000
} else {
	!pet "sY3e4",13,0
.restart_code_address = 30000 ; $7530
}

.restart_code_begin
.restart_code_string_final_pos = .restart_code_string - .restart_code_begin + .restart_code_address
	ldx #0
-	lda .restart_code_string_final_pos,x
	beq +
	jsr $ffd2
	inx
	bne - ; Always branch
+	; Setup	key sequence
	ldx #0
-	lda .restart_code_keys,x
	beq +
	sta keyboard_buff,x
	inx
	bne - ; Always branch
+	stx keyboard_buff_len
	rts

.restart_code_string
	!pet 147,"lO",34,":"
!source "file-name.asm"
    !pet 34,","
.device_no
	!pet "08",17,17,17,17,13,"rU",13,13,0
.restart_code_keys
	!byte 19,13,13,0
.restart_code_end

}

z_ins_restore
!ifndef Z4PLUS {
	jsr restore_game
	beq +
	ldx #0
	jsr split_window
	jmp make_branch_true
+
	ldx #0
	jsr split_window
	jmp make_branch_false
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
!ifndef Z4PLUS {
	jsr save_game
	beq +
	jmp make_branch_true
+	jmp make_branch_false
}
!ifdef Z4PLUS {
	jsr save_game
	jmp z_store_result
}

!zone save_restore {
.inputlen !byte 0
.filename !pet "!0" ; 0 is changed to slot number
.inputstring !fill 19 ; filename max 20 chars (fileprefix + 14 + ",s,w")
.input_alphanum
	; read a string with only alphanumeric characters into .inputstring
	; return: x = number of characters read
	;         .inputstring: null terminated string read (max 20 characters)
	; modifies a,x,y
!ifdef SMOOTHSCROLL {
	jsr wait_smoothscroll
}
	jsr turn_on_cursor
	lda #0
	sta .inputlen
	cli
	jsr kernal_clrchn
-	jsr kernal_getchar
	beq -
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

disk_error
	; accumulator contains BASIC error code
	; most likely errors:
	; A = $05 (DEVICE NOT PRESENT)
	pha ; Store error code for printing
	jsr close_io    ; even if OPEN failed, the file has to be closed
	jsr printchar_flush
	lda #>.disk_error_msg
	ldx #<.disk_error_msg
	jsr printstring_raw
	; Add code to print error code!
	pla
	tax
	lda #0
	jsr printinteger
	jsr printchar_flush

	lda #$25
	jsr s_printchar
	lda #0
	ldx $d68b
	jsr printinteger
	jsr printchar_flush
	lda #$25
	jsr s_printchar
	lda #0
	ldx $d6a1
	jsr printinteger
	jsr printchar_flush

	lda #$0d
	jsr s_printchar
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

!ifdef SMOOTHSCROLL {
	jsr wait_smoothscroll
}
	; open the channel file
!ifdef TARGET_C128 {
	lda #$00
	tax
	jsr kernal_setbnk
}
	lda #directory_name_len
	ldx #<directory_name
	ldy #>directory_name
	jsr kernal_setnam ; call SETNAM

	lda #2      ; file number 2
	ldx disk_info + 4 ; Device# for save disk
+   ldy #0      ; secondary address 2
	jsr kernal_setlfs ; call SETLFS
	jsr kernal_open     ; call OPEN
	bcc +
	jmp disk_error    ; if carry set, the file could not be opened
+
	ldx #2      ; filenumber 2
	jsr kernal_chkin ; call CHKIN (file 2 now used as input)

	; Skip load address and disk title
	ldy #32
-	jsr kernal_readchar
	dey
	bne -

.read_next_line	
!ifdef SMOOTHSCROLL {
	jsr wait_smoothscroll
}
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

!ifdef TARGET_C128 {
	bit COLS_40_80
	bmi +++
}
; Set the first 40 chars of each row to the current text colour	
	lda s_colour
!ifdef TARGET_PLUS4 {
	tay
	lda plus4_vic_colours,y 
}
	ldy #39
-	sta (zp_colourline),y
	dey
	bpl -
+++
	
	txa
	sta .occupied_slots - $30,x
	jsr s_printchar
	lda #58
	jsr s_printchar
	lda #32
	jsr s_printchar
	dec zp_temp + 1
	
-	jsr kernal_readchar
.not_a_save_file	
	cmp #$22 ; Charcode for "
	beq .end_of_name
	bit zp_temp + 1
	bpl - ; Skip printing if not a save file
	jsr s_printchar
	jmp -
.end_of_name
-	jsr kernal_readchar
	cmp #0 ; EOL
	bne -
	bit zp_temp + 1
	bpl .read_next_line ; Skip printing if not a save file
	lda #13
	jsr s_printchar
	jmp .read_next_line
	
.end_of_dir
	jsr close_io

	; Fill in blanks
	ldx #0
-	lda .occupied_slots,x
	bne +

!ifdef TARGET_C128 {
	bit COLS_40_80
	bmi +++
}
; Set the first 40 chars of each row to the current text colour	
	lda s_colour
!ifdef TARGET_PLUS4 {
	tay
	lda plus4_vic_colours,y 
}
	ldy #39
---	sta (zp_colourline),y
	dey
	bpl ---
+++

	txa
	ora #$30
	jsr s_printchar
	lda #58
	jsr s_printchar
	lda #13
	jsr s_printchar
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
!ifdef TARGET_C128 {
    bit COLS_40_80
    bmi vdc_insertion_sort
}
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
!ifdef TARGET_C128 {
vdc_insertion_sort
	jsr .calc_screen_address
	stx zp_temp + 2 ; convert from $0400 (VIC-II) to $0000 (VDC)
	sec
	sbc #$04
	sta zp_temp + 3
	ldx .current_item
	dex
	jsr .calc_screen_address
	stx zp_temp ; convert from $0400 (VIC-II) to $0000 (VDC)
	sec
	sbc #$04
	sta zp_temp + 1
	; read  both rows from VCD into temp buffers
	lda zp_temp
	ldy zp_temp + 1
	jsr VDCSetAddress
	ldy #0
-	jsr VDCReadByte
	sta $0400,y
	iny
	cpy #17
	bne -
	lda zp_temp + 2
	ldy zp_temp + 3
	jsr VDCSetAddress
	ldy #0
-	jsr VDCReadByte
	sta $0428,y
	iny
	cpy #17
	bne -
	; sort in the buffer
	ldy #0
	lda $0428,y ; (zp_temp + 2),y
	cmp $0400,y ; (zp_temp),y
	bcs .done_sort
	; Swap items
	ldy #17
-	lda $0400,y ; (zp_temp),y
	pha
	lda $0428,y ; (zp_temp + 2),y
	sta $0400,y ; (zp_temp),y
	pla
	sta $0428,y ; (zp_temp + 2),y
	dey
	bpl -
	; copy back from the buffers into VDC
	lda zp_temp
	ldy zp_temp + 1
	jsr VDCSetAddress
	ldy #0
-	lda $0400,y
	jsr VDCWriteByte
	iny
	cpy #17
	bne -
	lda zp_temp + 2
	ldy zp_temp + 3
	jsr VDCSetAddress
	ldy #0
-	lda $0428,y
	jsr VDCWriteByte
	iny
	cpy #17
	bne -
	; check next line
	dec .current_item
	ldx .current_item
	beq +
	jmp vdc_insertion_sort
+	rts
}
.calc_screen_address
	lda .base_screen_pos
	ldy .base_screen_pos + 1
	stx .counter
	clc
-	dec .counter
	bmi +
	adc s_screen_width
	tax
	tya
	adc #0
	tay
	txa
	bcc - ; Always branch
+	tax
	tya
	rts
directory_name
	!pet "$"
directory_name_len = * - directory_name
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
	ldy #0
	jsr print_insert_disk_msg
	ldx disk_info + 4 ; Device# for save disk
	lda #0
	sta current_disks - 8,x
	beq .insert_done ; Always branch
.dont_print_insert_save_disk
	jsr wait_a_sec
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
	beq .ok_dont_ask
.ask_again
	lda #>.save_device_msg ; high
	ldx #<.save_device_msg ; low
	jsr printstring_raw
	jsr .input_alphanum
	cpx #0
	beq .ok_dont_ask
	cpx #3
	bcs .incorrect_device
	; One or two digits
	cpx #1
	bne .two_digits
	lda .inputstring
	cmp #$38
	bcc .incorrect_device
	cmp #$3a
	bcs .incorrect_device
	and #$0f
	bne .store_device ; Always jump
.two_digits
	lda .inputstring
	cmp #$31
	bne .incorrect_device
	lda .inputstring + 1
	cmp #$30
	bcc .incorrect_device
	cmp #$36
	bcs .incorrect_device
	and #$0f
	adc #10 ; Carry already clear
.store_device
	sta disk_info + 4
.ok_dont_ask
	lda #0
	sta ask_for_save_device
	clc ; All OK
	rts
.incorrect_device
	sec
	rts
	
restore_game

!ifdef TARGET_C128 {
	lda #0
	sta allow_2mhz_in_40_col
	sta reg_2mhz	;CPU = 1MHz
}

	jsr maybe_ask_for_save_device
	bcs .restore_failed

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

!ifdef TARGET_C128 {
	jsr restore_2mhz
	; Copy stack and pointers from bank 1 to bank 0
	jsr .copy_stack_and_pointers_to_bank_0
}
	; Swap in z_pc and stack_ptr
	jsr .swap_pointers_for_save
!if SUPPORT_REU = 1 {
 	lda use_reu
	bmi .restore_success_dont_insert_story_disk
}
	jsr .insert_story_disk
.restore_success_dont_insert_story_disk	
;	inc zp_pc_l ; Make sure read_byte_at_z_address
!ifdef Z4PLUS {
!ifdef TARGET_C128 {
	jsr update_screen_width_in_header
}
}
	jsr get_page_at_z_pc
	lda #0
	ldx #1
	rts
.restore_failed
!ifndef TARGET_MEGA65 {
	!if SUPPORT_REU = 1 {
		lda use_reu
		bmi .restore_fail_dont_insert_story_disk
	}
}
	jsr .insert_story_disk
	; Return failed status
.restore_fail_dont_insert_story_disk
!ifdef TARGET_C128 {
	jsr restore_2mhz
}
	lda #0
	tax
	rts

save_game

!ifdef TARGET_C128 {
	lda #0
	sta allow_2mhz_in_40_col
	sta reg_2mhz	;CPU = 1MHz
}

	jsr maybe_ask_for_save_device
	bcs .restore_failed

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
!ifdef SMOOTHSCROLL {
	jsr wait_smoothscroll
}

	; Erase old file, if any
!ifdef TARGET_C128 {
	lda #$00
	tax
	jsr kernal_setbnk
}
	lda #5
	ldx #<.erase_cmd
	ldy #>.erase_cmd
	jsr kernal_setnam
	lda #$0f      ; file number 15
	ldx disk_info + 4 ; Device# for save disk
	tay           ; secondary address 15
	jsr kernal_setlfs
	jsr kernal_open ; open command channel and send delete command)
	bcs .restore_failed  ; if carry set, the file could not be opened
	lda #$0f      ; filenumber 15
	jsr kernal_close
	
	; Swap in z_pc and stack_ptr
	jsr .swap_pointers_for_save
!ifdef TARGET_C128 {
	jsr .copy_stack_and_pointers_to_bank_1
}
	
	; Perform save
	jsr do_save
	bcc +
	jmp .restore_failed    ; if carry set, a save error has happened
+
!ifdef TARGET_C128 {
	jsr restore_2mhz
}
	; Swap out z_pc and stack_ptr
	jsr .swap_pointers_for_save

!if SUPPORT_REU = 1 {
 	lda use_reu
	bmi .dont_insert_story_disk
}
	jsr .insert_story_disk
.dont_insert_story_disk
	lda #0
	ldx #1
	rts

.m65_save_start = z_temp + 4 ; 4 bytes	
.m65_save_count = 	z_temp + 8 ; 2 bytes

do_restore
!ifdef SMOOTHSCROLL {
	jsr wait_smoothscroll
}
!ifdef TARGET_MEGA65 {
	jsr close_io

	lda #3
	ldx #<.restore_filename
	ldy #>.restore_filename
	jsr kernal_setnam

	lda #2      ; file# 2
	ldx disk_info + 4 ; Device# for save disk
	tay         ; secondary address: 3
	jsr kernal_setlfs

	jsr kernal_open     ; call OPEN
	bcc +
	; TODO: No fatal error
	lda #ERROR_FLOPPY_READ_ERROR
	jsr fatalerror
+
	ldx #2      ; filenumber 2
	jsr kernal_chkin ; (file 2 now used for output)
	
	lda #>(stack_start - zp_bytes_to_save)
	ldx #<(stack_start - zp_bytes_to_save)
	sta .m65_save_start + 1
	stx .m65_save_start
	lda #0
	sta .m65_save_start + 2
	sta .m65_save_start + 3
	lda #>(stack_size + zp_bytes_to_save)
	ldx #<(stack_size + zp_bytes_to_save)
	jsr .m65_restore_read_from_file
	bcs .end_do_restore
	
	lda #0
	sta .m65_save_start
	sta .m65_save_start + 1
	sta .m65_save_start + 2
	lda #$08
	sta .m65_save_start + 3
	ldy #header_static_mem
	jsr read_header_word
	jsr .m65_restore_read_from_file
	
.end_do_restore
	php ; store c flag so error can be checked by calling routine
	jsr close_io
	plp ; restore c flag
	rts

.m65_restore_read_from_file
	; In: a,x: number of bytes to read from file
	; Returns: Carry set if failed
	; File should already be open and be default channel for input
	sta .m65_save_count + 1
	stx .m65_save_count
	
	
	ldz #0
-	
	; jsr kernal_readst
	; bne .file_reading_broken

	jsr kernal_readchar
	sta [.m65_save_start],z

	jsr kernal_readst
	bne .file_reading_done

	inc .m65_save_start
	bne +
	inc .m65_save_start + 1

+	dec .m65_save_count
	lda .m65_save_count
	cmp #255
	bne +
	dec .m65_save_count + 1
+	ora .m65_save_count + 1
	bne -

.file_reading_done
	clc
	rts
.file_reading_broken
	clc ; Should do SEC, but this leads to horrible terp behaviour, for unknown reasons
	rts


} else {
!ifdef TARGET_C128 {
	lda #$01
	ldx #$00
	jsr kernal_setbnk
}
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
} ; Not TARGET_MEGA65

do_save
!ifdef SMOOTHSCROLL {
	jsr wait_smoothscroll
}
!ifdef TARGET_MEGA65 {
	jsr close_io

	ldx .inputlen
	lda #$2c
	sta .filename + 2,x
	sta .filename + 4,x
	lda #$53
	sta .filename + 3,x
	lda #$57
	sta .filename + 5,x


	lda .inputlen
	clc
	adc #6 ; add 2 bytes for prefix
	ldx #<.filename
	ldy #>.filename
	jsr kernal_setnam

	lda #2      ; file# 2
	ldx disk_info + 4 ; Device# for save disk
	tay         ; secondary address: 3
	jsr kernal_setlfs

	jsr kernal_open     ; call OPEN
	bcc +
	; TODO: No fatal error
	lda #ERROR_FLOPPY_READ_ERROR
	jsr fatalerror
+
	ldx #2      ; filenumber 2
	jsr kernal_chkout ; (file 2 now used for output)
	
	lda #>(stack_start - zp_bytes_to_save)
	ldx #<(stack_start - zp_bytes_to_save)
	sta .m65_save_start + 1
	stx .m65_save_start
	lda #0
	sta .m65_save_start + 2
	sta .m65_save_start + 3
	lda #>(stack_size + zp_bytes_to_save)
	ldx #<(stack_size + zp_bytes_to_save)
	jsr .m65_save_write_to_file
	
	lda #0
	sta .m65_save_start
	sta .m65_save_start + 1
	sta .m65_save_start + 2
	lda #$08
	sta .m65_save_start + 3
	ldy #header_static_mem
	jsr read_header_word
	; Increase by one, since the last byte is skipped (ROM bug?)
	inx
	bne +
	clc
	adc #1
+	jsr .m65_save_write_to_file
	
	php ; store c flag so error can be checked by calling routine
	jsr close_io
	plp ; restore c flag
	rts

.m65_save_write_to_file
	; In: a,x: number of bytes to write to file
	; Returns: Carry set if failed
	; File should already be open and be default channel for output
	tay
	ldz #0

-	cpx #0
	bne +
	cpy #0
	beq .file_copying_done

+	lda [.m65_save_start],z
	jsr kernal_printchar

	inc .m65_save_start
	bne +
	inc .m65_save_start + 1

+	dex
	cpx #255
	bne -
	dey
	
	jmp -

.file_copying_done
	clc
	rts


} else {
!ifdef TARGET_C128 {
	lda #$01
	ldx #$00
	jsr kernal_setbnk
}
	lda .inputlen
	clc
	adc #2 ; add 2 bytes for prefix
	ldx #<.filename
	ldy #>.filename
	jsr kernal_setnam
	lda #1      ; file# 1
	ldx disk_info + 4 ; Device# for save disk
	tay         ; secondary address: 1
	jsr kernal_setlfs
!ifdef TARGET_C128 {
	lda #<(story_start_far_ram - stack_size - zp_bytes_to_save)
	ldx #>(story_start_far_ram - stack_size - zp_bytes_to_save)
} else {
	lda #<(stack_start - zp_bytes_to_save)
	ldx #>(stack_start - zp_bytes_to_save)
}
	sta savefile_zp_pointer
	stx savefile_zp_pointer + 1
	ldx dynmem_size
	lda dynmem_size + 1
;	ldy #header_static_mem
;	jsr read_header_word
	clc
!ifdef TARGET_C128 {
	adc #>story_start_far_ram
} else {
 	adc #>story_start
}	
	tay
	lda #savefile_zp_pointer ; start address located in zero page
	jsr kernal_save
	php ; store c flag so error can be checked by calling routine
	lda #1 
	jsr kernal_close
	plp ; restore c flag
	rts
} ; End of not TARGET_MEGA65
	
.last_disk	!byte 0
.saveslot !byte 0
.saveslot_msg_save	!pet 13,"Save to",0
.saveslot_msg_restore	!pet 13,"Restore from",0
.saveslot_msg	!pet " slot (0-9, RETURN=cancel): ",0 ; Will be modified to say highest available slot #
.savename_msg	!pet "Comment (RETURN=cancel): ",0
.save_msg	!pet 13,"Saving...",13,0
.restore_msg	!pet 13,"Restoring...",13,0
.save_device_msg !pet 13,"Device# (8-15, RETURN=default): ",0
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
	
!ifdef TARGET_C128 {
.copy_stack_and_pointers_to_bank_1
	; Pick a cache page to use, one that the z_pc_mempointer isn't pointing to
	ldy #>vmem_cache_start
	ldx #0
	txa
	cpy z_pc_mempointer + 1
	bne +
	inx
+	sta vmem_cache_page_index,x ; Mark as unused
	txa
	clc
	adc #>vmem_cache_start
	sta z_temp ; vmem_cache page for copying
	lda #(>stack_start) - 1
	sta z_temp + 1 ; Source page
	lda #(>story_start_far_ram) - (>stack_size) - 1
	sta z_temp + 2 ; Destination page
	lda #(>stack_size) + 1
	sta z_temp + 3 ; # of pages to copy
-	lda z_temp + 1
	ldy z_temp
	ldx #0
	jsr copy_page_c128 ; Copy a page to vmem_cache
	lda z_temp
	ldy z_temp + 2
	ldx #1
	jsr copy_page_c128
	inc z_temp + 1
	inc z_temp + 2
	dec z_temp + 3
	bne -
	rts

.copy_stack_and_pointers_to_bank_0
	; ; Pick a cache page to use, one that the z_pc_mempointer isn't pointing to
	ldy #>vmem_cache_start
	ldx #0
	txa
	cpy z_pc_mempointer + 1
	bne +
	inx
+	
	sta vmem_cache_page_index,x ; Mark as unused
	txa
	clc
	adc #>vmem_cache_start
	sta z_temp + 4 ; vmem_cache page for copying
	tay
	lda #(>story_start_far_ram) - 1
	sta z_temp + 1 ; Source page
	lda #(>story_start) - 1
	sta z_temp + 2 ; Destination page
	lda #(>stack_size) + 1
	sta z_temp + 3 ; # of pages to copy
-	lda z_temp + 1
	ldy z_temp + 4
	ldx #1
	jsr copy_page_c128 ; Copy a page to vmem_cache
	dec z_temp + 3
	beq + ; Stop after copying the last page to vmem_cache
	lda z_temp + 4
	ldy z_temp + 2
	ldx #0
	jsr copy_page_c128
	dec z_temp + 1
	dec z_temp + 2
	bne - ; Always branch
+	
	; z_temp + 4 now holds the page# where the zp registers are stored in vmem_cache
	lda #(>stack_start) - 1
	sta z_temp + 2
	lda #($100 - zp_bytes_to_save)
	sta z_temp + 1
	sta z_temp + 3
	ldy #zp_bytes_to_save - 1
-	lda (z_temp + 3),y
	sta (z_temp + 1),y
	dey
	bpl -
	rts

}	

interval_length = 30 ; Unit: ms


!ifdef TARGET_C128 {
wait_an_interval
; Delay a little for scrolling
	ldx #interval_length*6/100
	bne .wait_any_jiffies ; Always branch

wait_a_sec
; Delay ~1.2 s so player can read the last text before screen is cleared
	ldx #60
.wait_any_jiffies
	+disable_interrupts
	stx $0a1d ; Timer
	ldx #0
	stx $0a1e
	stx $0a1f
	+enable_interrupts
-	bit $0a1f
	bpl -
	; ldx #40 ; How many frames to wait
; --	ldy #1
; -	bit $d011
	; bmi --
	; cpy #0
	; beq -
	; ; This is the beginning of a new frame
	; dey
	; dex
	; bne -
	rts
} else {
wait_a_sec
; Delay ~1.2 s so player can read the last text before screen is cleared
	ldx #0
!ifdef TARGET_MEGA65 {
	ldy #40*5
} else {
	ldy #5
}
; -	jsr kernal_delay_1ms
	; dex
	; bne -
	; dey
	; bne -
	; rts

wait_yx_ms
-	jsr kernal_delay_1ms
	dex
	bne -
	dey
	bne -
	rts

wait_an_interval
;	inc reg_bordercolour
	; Used for scrolling
!ifdef TARGET_MEGA65 {
	ldx #(<(40 * interval_length + 256))
	ldy #(>(40 * interval_length + 256))
} else {
	ldx #(<(interval_length + 256))
	ldy #(>(interval_length + 256))
}
	jmp wait_yx_ms
}

	

!ifndef UNDO {
z_ins_save_undo
z_ins_restore_undo
    ; Return -1 to indicate that this is not supported
    ldx #$ff
    txa
    jmp z_store_result
} else {

undo_state_available !byte 0

!ifdef Z5PLUS {
    ; the "undo" assembler instruction is only available in Z5+
z_ins_save_undo
	lda reu_bank_for_undo ; This is $ff if not available
	tax
	bmi ++
+	jsr do_save_undo
	; Return 2 if just restored, -1 if not supported, 1 if saved, 0 if fail
	lda #0
++	jmp z_store_result

z_ins_restore_undo
	ldx undo_state_available
	beq .undo_failed
    jsr do_restore_undo
    ; Return 0 if failed
    ldx #2
-   lda #0
    jmp z_store_result
.undo_failed
	ldx #0
    beq - ; Always branch
}

reu_bank_for_undo
!ifdef TARGET_MEGA65 {
	!byte $00 ; $00 means it's supported by default. May be changed to $ff at boot.
} else {
	!byte $ff 	; $ff means no undo. May be changed at boot. Meaning:
				; Bit 7: Undo disabled?
				; Bit 6: Undo (if enabled) uses a RAM buffer?
				; Bit 0-5: REU bank for undo, if enabled and doesn't use a RAM buffer
}

; we provide basic undo support for z3 as well through a hot key
; so the basic undo routines need to be available for all versions

!ifdef TARGET_MEGA65 {

do_save_undo
    ; prepare saving of zp variables
	jsr .swap_pointers_for_save

	; save zp variables + stack
    ; source address
    lda #>(stack_start - zp_bytes_to_save)
    ldx #<(stack_start - zp_bytes_to_save)
    stx dma_source_address
    sta dma_source_address + 1
    lda #0
    sta dma_source_bank_and_flags
    sta dma_source_address_top
    ; number of bytes
    lda #>(stack_size + zp_bytes_to_save)
    ldx #<(stack_size + zp_bytes_to_save)
    stx dma_count
    sta dma_count + 1
    ; destination address ($50000)
    lda #0
    sta dma_dest_address
    sta dma_dest_address + 1
    sta dma_dest_address_top
    lda #$05
    sta dma_dest_bank_and_flags
    jsr m65_run_dma
	jsr .swap_pointers_for_save

    ; save dynmem
    ; source address ($80000 - attic RAM)
    lda #0
    sta dma_source_address
    sta dma_source_address + 1
    sta dma_source_bank_and_flags
    lda #$80
    sta dma_source_address_top
    ; number of bytes
    ldy #header_static_mem
    jsr read_header_word
    stx dma_count
    sta dma_count + 1
    ; destination address
    lda #0
    sta dma_dest_address
    sta dma_dest_address_top
    lda #(>(stack_size + zp_bytes_to_save)) + 1
    sta dma_dest_address + 1
    lda #$05
    sta dma_dest_bank_and_flags
    jsr m65_run_dma
    ldx #1
	stx undo_state_available
	rts

do_restore_undo
	; restore zp variables + stack
    ; source address ($50000)
	jsr .swap_pointers_for_save
    lda #0
    sta dma_source_address
    sta dma_source_address + 1
    sta dma_source_address_top
    lda #$05
    sta dma_source_bank_and_flags
    ; number of bytes
    lda #>(stack_size + zp_bytes_to_save)
    ldx #<(stack_size + zp_bytes_to_save)
    stx dma_count
    sta dma_count + 1
    ; destination address
    lda #>(stack_start - zp_bytes_to_save)
    ldx #<(stack_start - zp_bytes_to_save)
    stx dma_dest_address
    sta dma_dest_address + 1
    lda #0
    sta dma_dest_bank_and_flags
    sta dma_dest_address_top
    jsr m65_run_dma

	jsr .swap_pointers_for_save
	jsr get_page_at_z_pc

    ; restore dynmem
    ; source address
    lda #0
    sta dma_source_address
    sta dma_source_address_top
    lda #(>(stack_size + zp_bytes_to_save)) + 1
    sta dma_source_address + 1
    lda #$05
    sta dma_source_bank_and_flags
    ; number of bytes
    ldy #header_static_mem
    jsr read_header_word
    stx dma_count
    sta dma_count + 1
    ; dest address
    lda #0
    sta dma_dest_address
    sta dma_dest_address + 1
    sta dma_dest_bank_and_flags
    lda #$80
    sta dma_dest_address_top
    jsr m65_run_dma
    ldx #0
	stx undo_state_available
	rts
	
} else {
	; Not MEGA65, so this is for C64/C128

!ifdef UNDO_RAM {
ram_undo_page !byte $ff ; Set during init, if RAM undo is to be used
vmap_entries_reserved !byte 0 ; Changed during init, if RAM undo is to be used
}

do_save_undo
	bit reu_bank_for_undo
	bmi .save_undo_done
!ifdef UNDO_RAM {
	bvs save_undo_in_ram
}
    ; prepare saving of zp variables
	jsr .swap_pointers_for_save

	jsr .setup_transfer_stack
!ifdef TARGET_C128 {
	lda #0
	sta allow_2mhz_in_40_col
	sta reg_2mhz	;CPU = 1MHz
}
	lda #%10110000;  C64 -> REU with immediate execution
	sta reu_command
	
	jsr .swap_pointers_for_save

!ifdef TARGET_C128 {
    ; ; save dynmem

	jsr .setup_transfer_dynmem
	lda #%10110000;  c128 -> REU with immediate execution
	sta reu_command
	jsr restore_2mhz

	; Restore REU to see RAM bank 0
	lda $d506
	and #%00111111 ; Bit 6: 0 means bank 0, bit 7 is unused
	sta $d506

!ifdef CUSTOM_FONT {
	lda #$17 ; 0001 011X = $0400 $1800
	sta $d018
}
}
    ldx #1
	stx undo_state_available
.save_undo_done
	rts

!ifdef UNDO_RAM {
	; This is a C128 only option, so code is C128 specific
save_undo_in_ram
	jsr .swap_pointers_for_save

	; Copy zp + stack to bank 1
	jsr .copy_stack_and_pointers_to_bank_1

	; Copy zp + stack + dynmem to undo RAM
	lda #(>story_start_far_ram) - (>stack_size) - 1
	sta z_temp + 1 ; Source page
	lda ram_undo_page
	sta z_temp + 2 ; Destination page
	lda #(>stack_size) + 1
	clc
	adc nonstored_pages
	sta z_temp + 3 ; # of pages to copy
-	lda z_temp + 1
	ldy z_temp + 2
	ldx #1 ; Copy within bank 1
	jsr copy_page_c128 ; Copy a page
	inc z_temp + 1
	inc z_temp + 2
	dec z_temp + 3
	bne -
	
	jsr .swap_pointers_for_save
    ldx #1
	stx undo_state_available
	rts

restore_undo_from_ram
	jsr .swap_pointers_for_save

	; Copy zp + stack + dynmem from undo RAM
	lda ram_undo_page
	sta z_temp + 1 ; Source page
	lda #(>story_start_far_ram) - (>stack_size) - 1
	sta z_temp + 2 ; Destination page
	lda #(>stack_size) + 1
	clc
	adc nonstored_pages
	sta z_temp + 3 ; # of pages to copy
-	lda z_temp + 1
	ldy z_temp + 2
	ldx #1 ; Copy within bank 1
	jsr copy_page_c128 ; Copy a page
	inc z_temp + 1
	inc z_temp + 2
	dec z_temp + 3
	bne -

	; Copy zp + stack to bank 0
	jsr .copy_stack_and_pointers_to_bank_0

	jmp .finalize_restore_undo
	; jsr .swap_pointers_for_save
	; jsr get_page_at_z_pc
    ; ldx #0
	; stx undo_state_available
	; rts
}

do_restore_undo
!ifdef UNDO_RAM {
	bit reu_bank_for_undo
	bvs restore_undo_from_ram ; Bit 7 is always clear if we get here, so just need to check bit 6 
}
	; restore zp variables + stack
    ; source address ($50000)
	jsr .swap_pointers_for_save

	jsr .setup_transfer_stack
!ifdef TARGET_C128 {
	lda #0
	sta allow_2mhz_in_40_col
	sta reg_2mhz	;CPU = 1MHz
}
	lda #%10110001;  REU -> c64 with immediate execution
	sta reu_command

!ifdef TARGET_C128 {
    ; ; restore dynmem

	jsr .setup_transfer_dynmem
	
	lda #%10110001;  REU -> c128 with immediate execution
	sta reu_command
	jsr restore_2mhz

	; Restore REU to see RAM bank 0
	lda $d506
	and #%00111111 ; Bit 6: 0 means bank 0, bit 7 is unused
	sta $d506

!ifdef CUSTOM_FONT {
	lda #$17 ; 0001 011X = $0400 $1800
	sta $d018
}
}

.finalize_restore_undo
	jsr .swap_pointers_for_save
	jsr get_page_at_z_pc

    ldx #0
	stx undo_state_available
	rts

.setup_transfer_stack
	; ; save zp variables + stack
    ; source address in C64 RAM
    ldy #>(stack_start - zp_bytes_to_save)
	; Target address in REU
	lda reu_bank_for_undo
	ldx #0
	; clc ; Doesn't matter, since we set exact transfer size after call
	jsr store_reu_transfer_params
	; Set C64 address lowbyte
    ldx #<(stack_start - zp_bytes_to_save)
	stx reu_c64base
	; Set transfer size
!ifdef TARGET_C64 {
	lda story_start + header_static_mem + 1
	clc
	adc #<(stack_size + zp_bytes_to_save)
	sta reu_translen
	lda story_start + header_static_mem
	adc #>(stack_size + zp_bytes_to_save)
	sta reu_translen + 1
} else {
	; C128
	ldx #<(stack_size + zp_bytes_to_save)
	stx reu_translen
	ldx #>(stack_size + zp_bytes_to_save)
	stx reu_translen + 1
}
	rts

!ifdef TARGET_C128 {
.setup_copy_screen
	ldy #>SCREEN_ADDRESS
	lda reu_bank_for_undo
	ldx #$fc
	clc
	jsr store_reu_transfer_params
	lda #4
    sta reu_translen + 1
	rts
	
.setup_transfer_dynmem
	bit COLS_40_80
	bmi .no_screen_copying_to_reu
	; Copy screen memory to REU (and later to bank 1, to avoid ugly flicker of garbage)
	jsr .setup_copy_screen
	
	lda #%10110000;  C64 -> REU with immediate execution
	sta reu_command

	; Wait until raster is in border
-	bit $d011
	bpl -
.no_screen_copying_to_reu

	; Make REU see RAM bank 1
	lda $d506
	ora #%01000000 ; Bit 6: 0 means bank 0, bit 7 is unused
	sta $d506

	bit COLS_40_80
	bmi .no_screen_copying_from_reu
!ifdef CUSTOM_FONT {
	lda #$12 ; 0001 001X = $0400 $0800
	sta $d018
}
	; Copy screen memory contents from REU to bank 1 to avoid ugly flicker of garbage
	jsr .setup_copy_screen
	lda #%10110001;  REU -> c64 with immediate execution
	sta reu_command
.no_screen_copying_from_reu

    ; source address in C128 RAM
    ldy #>story_start_far_ram
	; Target address in REU
	lda reu_bank_for_undo
	ldx #(>stack_size) + 1
	clc
	jsr store_reu_transfer_params

	; Set transfer size
    ldy #header_static_mem
    jsr read_header_word
	stx reu_translen
    sta reu_translen + 1

	rts
}


}

}

} ; end zone save_restore

} ; end zone disk
	
