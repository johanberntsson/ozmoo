;TRACE_FLOPPY = 1
;TRACE_FLOPPY_VERBOSE = 1

readblocks_numblocks     !byte 0 
readblocks_currentblock  !byte 0,0 ; 257 = ff 1
readblocks_mempos        !byte 0,0 ; $2000 = 00 20

; story_blocks_per_disk_h	!byte 0,0,0
; story_blocks_per_disk_l !byte 0,0,0

disk_info
!ifdef Z3 {
	!fill 54
}
!ifdef Z4 {
	!fill 92
}
!ifdef Z5 {
	!fill 92
}
!ifdef Z8 {
	!fill 118
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
	lda readblocks_currentblock
	jsr print_byte_as_hex
	lda readblocks_currentblock + 1
	jsr print_byte_as_hex
}

    ; convert block to track/sector
    lda readblocks_currentblock
	sta .blocks_to_go
    lda readblocks_currentblock + 1
	sta .blocks_to_go + 1
	
	lda disk_info
	sta .disks ; # of disks
	ldx #0 ; Memory index
	ldy #0 ; Disk id
.check_next_disk	
	txa
	clc
	adc disk_info + 1,x
	sta .next_disk_index ; x-value where next disk starts
	; Check if the block we are looking for is on this disk
	lda readblocks_currentblock
	sec
	sbc disk_info + 4,x
	sta .blocks_to_go_tmp + 1
	lda readblocks_currentblock + 1
	sbc disk_info + 3,x
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
	lda disk_info + 2,x
	sta .device
	lda disk_info + 5,x
	sta .disk_tracks ; # of tracks which have entries
	lda #1
	sta .track
	; lda #0
	; sta zp_temp + 3 ; # highbyte of # of story blocks on disk
	; lda #0
	; sta story_blocks_per_disk_l - 1,y
.check_track
	lda disk_info + 6,x
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
	lda .blocks_to_go_tmp
	sta .blocks_to_go
	lda .blocks_to_go_tmp + 1
	sta .blocks_to_go + 1
	jmp .next_track
.track_map 		!fill 21
.sector_count 	!byte 0
.skip_sectors 	!byte 0
.temp_y 		!byte 0
SECTOR_INTERLEAVE = 4

.right_track_found
	; Add sectors not used at beginning of track
	; .blocks_to_go + 1: logical sector#
	; disk_info + 6,x: # of sectors skipped (3 bits), # of sectors used (5 bits)
	sty .temp_y
!ifdef TRACE_FLOPPY {
	jsr arrow
	lda .track
	jsr print_byte_as_hex
	jsr comma
	lda .blocks_to_go + 1
	jsr print_byte_as_hex
}
	lda disk_info + 6,x
	lsr
	lsr
	lsr
	lsr
	lsr ; a now holds # of sectors at start of track not in use
	sta .skip_sectors
; Initialize track map. Write 0 for sectors not yet used, $ff for sectors used 
	lda disk_info + 6,x
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
	adc #SECTOR_INTERLEAVE
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
	
	; lda .blocks_to_go + 1
	; sta .sector
	; lda disk_info + 6,x
	; cmp #$20
	; bcc .have_set_device_track_sector
; ;	and #%11100000
; ;	beq .have_set_device_track_sector
	; lsr
	; lsr
	; lsr
	; lsr
	; lsr ; a now holds # of sectors at start of track not in use
	; clc
	; adc .blocks_to_go + 1
	; sta .sector
	jmp .have_set_device_track_sector
.next_track
	inx
	inc .track
	dec .disk_tracks
	beq .next_disk
	jmp .check_track
.next_disk
	ldx .next_disk_index
	iny
	cpy .disks
	bcs +
	jmp .check_next_disk
+	lda #ERROR_OUT_OF_MEMORY ; Meaning request for Z-machine memory > EOF. Bad message? 
	jmp fatalerror

    ; ; (assuming each tracks has 16 sectors, skipping track18)
    ; lda readblocks_currentblock
    ; and #$0f
    ; sta .sector
    ; lda readblocks_currentblock
    ; sta .track
    ; lda readblocks_currentblock + 1
    ; ldx #4
; -   lsr
    ; ror .track
    ; dex
    ; bne -
    ; inc .track ; tracks are 1..
    ; lda .track
	; ldy #8
    ; cmp #18
    ; bcc +
    ; inc .track ; skip track 18
	; bne + ; Always branch

    ; convert track/sector to ascii and update drive command
read_track_sector
	; input: a: track, x: sector, y: device#, Word at readblocks_mempos holds storage address
	sta .track
	stx .sector
+   sty .device
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
	; TODO: Handle device# smarter!
;    ldx $BA       ; last used device number
;    bne +
    ldx .device
+   ldy #$02      ; secondary address 2
    jsr kernel_setlfs ; call SETLFS

    jsr kernel_open     ; call OPEN
    bcs .error    ; if carry set, the file could not be opened

    ; open the command channel

    lda #uname_len
    ldx #<.uname
    ldy #>.uname
    jsr kernel_setnam ; call SETNAM
    lda #$0F      ; file number 15
;    ldx $BA       ; last used device number
    ldx .device
    ldy #$0F      ; secondary address 15
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
.close
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
    jsr .close    ; even if OPEN failed, the file has to be closed
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
.disks	!byte 0
.next_disk_index	!byte 0
.disk_tracks	!byte 0

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

save_game
	lda #0
	tax
	rts


	