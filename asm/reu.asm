reu_status   = $DF00
reu_command  = $DF01
reu_c64base  = $DF02
reu_reubase  = $DF04
reu_translen = $DF07
reu_irqmask  = $DF09
reu_control  = $DF0A

reu_needs_loading !byte 0 ; Should be 0 from the start

!zone reu {

reu_error
	lda #0
	sta use_reu
	lda #>.reu_error_msg
	ldx #<.reu_error_msg
	jsr printstring_raw
-	jsr kernal_getchar
	beq -
	rts

.reu_error_msg
	!pet 13,"REU error, disabled. [SPACE]",0


!ifdef TARGET_MEGA65 {

m65_reu_load_page_limit = z_temp + 10
m65_reu_enable_load_page_limit !byte 0
.m65_reu_load_address = object_temp
.m65_reu_memory_buffer = zp_temp + 2
.m65_reu_page_count = z_temp + 11

m65_load_file_to_reu
	; In: a,x: REU load page (0 means first address of Attic RAM)
	; Returns: a: Number of pages loaded.
	; Call SETNAM before calling this
	; Opens file as #2. Closes file at end.

	; Prepare for copying data to REU
	stx .m65_reu_load_address ; Lowbyte of current page in REU memory
	sta .m65_reu_load_address + 1 ; Highbyte of current page in REU memory

	lda #0
	sta .m65_reu_page_count
	; Prepare a page where we can store data
;	jsr get_free_vmem_buffer
	lda #>reu_copy_buffer
	sta .m65_reu_memory_buffer + 1
	lda #<reu_copy_buffer
	sta .m65_reu_memory_buffer
	
	lda #2      ; file number 2
	tay
	ldx boot_device
	jsr kernal_setlfs ; call SETLFS

	jsr kernal_open     ; call OPEN
	bcc +
	lda #ERROR_FLOPPY_READ_ERROR
	jsr fatalerror
+
	ldx #2      ; filenumber 2
	jsr kernal_chkin ; call CHKIN (file 2 now used as input)
	
.initial_copy_loop

	jsr kernal_readst
	bne .file_copying_done
	
	ldy #0
-	jsr kernal_readchar
	sta(.m65_reu_memory_buffer),y
	iny
	bne -

	lda .m65_reu_load_address + 1
	ldx .m65_reu_load_address
	ldy .m65_reu_memory_buffer + 1 ; Current C64 memory page
	jsr copy_page_to_reu
	bcs reu_error

	inc .m65_reu_page_count

	lda m65_reu_enable_load_page_limit
	beq +
	dec m65_reu_load_page_limit
	beq .file_copying_done

+
	; Inc REU page
	inc .m65_reu_load_address
	bne .initial_copy_loop
	inc .m65_reu_load_address + 1
	jmp .initial_copy_loop ; Always branch
	
	
.file_copying_done
	lda #$00     
	sta m65_reu_enable_load_page_limit
	jsr kernal_chkin  ; restore input to keyboard
	lda #$02      ; filenumber 2
	jsr kernal_close ; call CLOSE
	lda .m65_reu_page_count
	rts

;reu_copy_buffer !fill 256
reu_copy_buffer = $cf00

} ; End TARGET_MEGA65


copy_page_to_reu
	; a,x = REU page
	; y = C64 page

!ifdef TARGET_MEGA65 {
	stx dma_dest_address + 1
	pha
	and #$0f
	sta dma_dest_bank_and_flags
	sty dma_source_address + 1

	ldx #1
	stx dma_count + 1
	dex ; Set x = 0
	stx dma_count
	stx dma_dest_address
	stx dma_source_address
	stx dma_source_bank_and_flags
	stx dma_source_address_top
	pla
	lsr
	lsr
	lsr
	lsr
	ora #$80 ; Base of HyperRAM
	sta dma_dest_address_top

	jsr m65_run_dma

} else {
; Not MEGA65
	clc
	jsr store_reu_transfer_params

!ifdef SMOOTHSCROLL {
	jsr wait_smoothscroll
}
-	lda #%10110000;  c64 -> REU with immediate execution
	sta reu_command

	; Verify
	
	lda #%10110011;  compare c64 to REU with immediate execution
	sta reu_command
	lda reu_status
	and #%00100000
	beq .update_progress_bar

	; Signal REU error and return
	sec
	rts
}

.update_progress_bar
	; Update progress bar
	lda reu_progress_bar_updates
	beq +
	dec progress_reu
	bne +
	lda reu_progress_base
	sta progress_reu
	lda #20
	jsr s_printchar
+	clc
	rts

reu_progress_bar_updates	!byte 0

copy_page_from_reu
	; a,x = REU page
	; y = C64 page
!ifdef TARGET_MEGA65 {
	stx dma_source_address + 1
	pha
	and #$0f
	sta dma_source_bank_and_flags
	sty dma_dest_address + 1

	ldx #1
	stx dma_count + 1
	dex ; Set x = 0
	stx dma_count
	stx dma_source_address
	stx dma_dest_address
	stx dma_dest_address_top
	stx dma_dest_bank_and_flags
	pla
	lsr
	lsr
	lsr
	lsr
	ora #$80 ; Base of HyperRAM
	sta dma_source_address_top

	jmp m65_run_dma

} else { 
; Not MEGA65

!ifdef TARGET_C128 {
	pha
	lda #0
	sta allow_2mhz_in_40_col
	sta reg_2mhz	;CPU = 1MHz
	pla
}

	clc
	jsr store_reu_transfer_params

!ifdef SMOOTHSCROLL {
	jsr wait_smoothscroll
}
	lda #%10110001;  REU -> c64 with immediate execution
	sta reu_command

!ifdef TARGET_C128 {
restore_2mhz
	lda #1
	sta allow_2mhz_in_40_col
	bit COLS_40_80
	bpl +
	lda use_2mhz_in_80_col
	sta reg_2mhz	;CPU = 2MHz
+
}
	rts
} ; else (not MEGA65)


!ifndef TARGET_MEGA65 {
store_reu_transfer_params

	; a,x = REU page
	; y = C64 page
	; Transfer size: $01 if C is set, $100 if C is clear
	sta reu_reubase + 2
	stx reu_reubase + 1
	sty reu_c64base + 1
	ldx #0
	stx reu_irqmask
	stx reu_control ; to make sure both addresses are counted up
	stx reu_c64base
	stx reu_reubase
	; Transfer size: $01 if C is set, $100 if C is clear
	lda #>$0100 ; Transfer one page
	bcc +
	; Set transfer size to $01
	txa
	inx
+	stx reu_translen
	sta reu_translen + 1
	rts
}

.size = object_temp
.old = object_temp + 1
.temp = vmem_cache_start + 2


.reu_banks_to_check = 16 ; Can be up to 128, but make sure .reu_tmp has room 
.reu_tmp = streams_stack; 60 bytes, we use less (see line just before this)

reu_banks !byte 0

check_reu_size

!ifdef TARGET_MEGA65 {
	; Start checking at address $08 00 00 00
	ldz #0
	ldy #0
	sty stack_tmp
	sty stack_tmp + 1
	sty stack_tmp + 2
	lda #$08
	sta stack_tmp + 3
.check_next_bank
	lda [stack_tmp],z
	sta .reu_tmp,y		; Store the old value for the first byte of bank

	iny
	tya
	sta [stack_tmp],z	; Save the bank number + 1 in the first byte of bank
	lda [stack_tmp],z
	sta stack_tmp + 4
	cpy stack_tmp + 4	; Check if the new value stuck
	beq +
	dey
	jmp .found_end_of_reu
	
+	dey
	tya
	sta [stack_tmp],z	; Save the bank number in the first byte of bank
	lda [stack_tmp],z
	sta stack_tmp + 4
	cpy stack_tmp + 4	; Check if the new value stuck
	bne .found_end_of_reu
	
	lda #0
	sta stack_tmp + 2
	lda [stack_tmp],z
	bne .found_end_of_reu ; Should be the bank number for bank #0 ( i.e. 0)
	
	iny
	sty stack_tmp + 2	; Set the next bank to test 
	cpy #.reu_banks_to_check
	bcc .check_next_bank
.found_end_of_reu
	; y is now 0 - .reu_banks_to_check, meaning the first unavailable bank number
	sty stack_tmp + 4
-	dey
	bmi +
	lda .reu_tmp,y
	sty stack_tmp + 2
	sta [stack_tmp],z ; Write the original value back
	jmp -

+	lda stack_tmp + 4
	rts
} else {
	; Target not MEGA65

	ldx #0
	stx object_temp ; Bank currently being checked

	; Backup the first value in this 64 KB bank in REU, to C64 memory
-	lda object_temp
	jsr .reu_check_read
	ldx object_temp
	sta .reu_tmp,x

	; Write the number of the 64KB bank to the first byte in the bank
	lda object_temp
	sta $100
	jsr .reu_check_write

	; Check if the first byte of this and all previous 64 KB banks are correct
	lda object_temp
	sta object_temp + 1
--	lda object_temp + 1
	jsr .reu_check_read
	cmp object_temp + 1
	bne +
	dec object_temp + 1
	bpl --
	
	inc object_temp
	lda object_temp
	cmp #.reu_banks_to_check
	bcc -
+
	; Restore the original contents in all banks, in reverse order
	ldx object_temp ; This now holds the # of 64 KB banks available in REU
	dex
	stx object_temp + 1
-	ldx object_temp + 1
	lda .reu_tmp,x
	sta $100
	txa
	jsr .reu_check_write
	dec object_temp + 1
	bpl -

	; Round the # of 64 KB banks down to 2^n
	lda #$80
-	bit object_temp
	bne .done
	lsr
	bcc -
.done
	rts

.reu_check_store	
	ldx #0
	ldy #1
	sec
	jmp store_reu_transfer_params

.reu_check_read
	jsr .reu_check_store
	lda #%10110001;  REU -> c64 with immediate execution
	sta reu_command
	lda $100
	rts

.reu_check_write
	jsr .reu_check_store
	lda #%10110000;  c64 -> REU with immediate execution
	sta reu_command
	rts
	
}
}

; progress_reu = parse_array
; reu_progress_ticks = parse_array + 1
; reu_last_disk_end_block = string_array ; 2 bytes

reu_progress_base
!ifndef Z4PLUS {
	!byte 16 ; blocks read to REU per tick of progress bar for games < 128 KB
} else {
	!ifdef Z7PLUS {
		!byte 64 ; blocks read to REU per tick of progress bar for games < 512 KB
	} else {
		!byte 32 ; blocks read to REU per tick of progress bar for games < 256 KB
	}
}


print_reu_progress_bar
	lda z_temp + 4
	sec
	sbc reu_last_disk_end_block
	sta reu_progress_ticks
	lda z_temp + 5
	sbc reu_last_disk_end_block + 1
!ifdef Z4PLUS {
	!ifdef Z7PLUS {
		ldx #6 ; One tick is 2^6 = 64 blocks
	} else {
		ldx #5 ; One tick is 2^5 = 32 blocks
	}
} else {
	ldx #4 ; One tick is 2^4 = 16 blocks
}
-	lsr 
	ror reu_progress_ticks
	dex
	bne -

	lda reu_progress_base
	sta progress_reu

; Print progress bar
	lda #13
	jsr s_printchar
	ldx reu_progress_ticks
	beq +
-	lda #47
	jsr s_printchar
	dex
	bne -
+
	; Signal that REU copy routine should update progress bar
	lda #$ff
	sta reu_progress_bar_updates

	rts
