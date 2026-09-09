; ---------------------------------------------------------------------------
; Ozmoo Apple II: the SmartPort/ProDOS block driver, and the boot block
;
; The 3.5" (and SCSI, and CFFA3000, and Floppy Emu) counterpart of
; asm/apple2-rwts.asm. Like that file this is a second object of its own,
; assembled by make.rb rather than sourced by ozmoo.asm, and it is resident for
; the whole session: it is both the loader that brings the interpreter in and
; the block reader the interpreter calls afterwards.
;
; Defines from make.rb: TERP_BLOCK, TERP_BLOCKS, TERP_LOAD.
; ---------------------------------------------------------------------------

	!cpu 6502
	* = $0800

; --- the header, at fixed addresses the interpreter knows ------------------
; The offsets deliberately echo asm/apple2-rwts.asm's, so disk.asm's stores are
; the same three or four instructions either way; only the meaning of the two
; bytes at $0807 changes, from a track and a sector to a block number.
	!byte 1                 ; $0800  "this block is bootable" - the firmware
	                        ;        checks this before it jumps
	jmp boot                ; $0801  where it jumps
	jmp sp_read             ; $0804  read one block
sp_block
	!byte 0                 ; $0807  block number, low byte...
	!byte 0                 ; $0808  ...and high
sp_dest
	!byte 0                 ; $0809  destination page...
	!byte 0                 ; $080A  ...and its low byte
	jmp sp_write            ; $080B  write one block
sp_write_protect
	!byte 0                 ; $080E  nonzero if the last write was refused by
	                        ;        the device rather than failing
sp_last_error
	!byte 0                 ; $080F  the firmware's own error code from the
	                        ;        last call, for a read that has to explain
	                        ;        itself on a machine with no debugger
sp_unit
	!byte 0                 ; $0810  the unit byte: $DSSS0000, so drive 1 of
	                        ;        slot s is s * 16 - which is exactly what
	                        ;        the firmware leaves in X
sp_slot
	!byte 0                 ; $0811  slot * 16, latched at boot

; --- ProDOS block call parameters, in zero page where the firmware wants ---
PD_COMMAND  = $42
PD_UNIT     = $43
PD_BUFFER   = $44
PD_BLOCK    = $46
PD_READ     = 1
PD_WRITE    = 2

; The zero page a ProDOS block driver is entitled to: $40-$4F, parameters and
; scratch alike. Saved and restored around every call - see sp_read.
PD_ZP_FIRST = $40

; Where that copy of the zero page goes. The driver is one 512 byte block at
; $0800 and the interpreter starts at $1000, so the pages between are ours:
; $0A00 is the block buffer the interpreter reads through (disk.asm) and $0C00
; is this.
SP_ZP_SAVE  = $0c00

; The error the firmware returns when the medium is write protected. Kept apart
; from every other failure because "the drive refused" and "the bits did not
; land" are the same carry to the caller and very different things to be told.
PD_ERR_WPROT = $2b

; ---------------------------------------------------------------------------
; boot: load the interpreter and go.
; ---------------------------------------------------------------------------
boot
	stx sp_slot
	stx sp_unit             ; drive 1 of that slot

	; Find the slot's ProDOS entry point: the page is $Cs00 and the low byte
	; of the entry is at $CsFF.
	txa
	lsr
	lsr
	lsr
	lsr                     ; a = slot
	ora #$c0                ; a = $Cs
	sta .entry_hi
	sta .fetch + 2
	lda #$ff
	sta .fetch + 1
.fetch
	lda $ffff               ; patched to $CsFF
	sta .entry_lo

	; Read the interpreter in, one block at a time.
	lda #<TERP_BLOCK
	sta sp_block
	lda #>TERP_BLOCK
	sta sp_block + 1
	lda #0
	sta sp_dest + 1
	lda #>TERP_LOAD
	sta sp_dest

	; The count is in memory and not in a register, because the firmware call
	; preserves nothing at all: the first version of this kept it in x, and the
	; call came back with x holding something else, so the loop never ended.
	; It read blocks into $C000 and up - the soft switches - which is as
	; thorough a way of destroying a machine as this driver has available.
	lda #TERP_BLOCKS
	sta .to_go
.next
	jsr sp_read
	bcs .failed
	inc sp_block
	bne +
	inc sp_block + 1
+	inc sp_dest             ; a block is two pages
	inc sp_dest
	dec .to_go
	bne .next
	jmp TERP_LOAD
.to_go !byte 0

.failed
	; Nowhere to go but the screen: this is before the interpreter exists.
	bit $c051
	bit $c052
	bit $c054
	bit $c056
	ldy #0
-	lda .msg,y
	beq +
	ora #$80
	sta $0400,y
	iny
	bne -
+	jmp *
.msg !text "DISK ERROR",0

; ---------------------------------------------------------------------------
; sp_read / sp_write: one block, from the parameters above. Carry clear if it
; worked. a, x and y are all clobbered, as they are on the RWTS side.
; ---------------------------------------------------------------------------
sp_read
	lda #PD_READ
	!byte $2c               ; bit $xxxx - skip the next two bytes
sp_write
	lda #PD_WRITE
	sta .cmd

	; THE ZERO PAGE IS NOT OURS ACROSS THIS CALL, and that is not a detail: a
	; ProDOS block device driver owns $40-$4F - its parameters are the six
	; bytes at $42 and the rest is its scratch - and Ozmoo has live interpreter
	; state right there. Measured on MAME's apple2gs, by diffing the whole zero
	; page across a call: the firmware changes exactly **$45 and $46**, which
	; are z_local_vars_ptr, the pointer to the running routine's local
	; variables. The symptom was not a disk fault at all. The game booted, read
	; its story correctly, and then ran off into memory and recursed until the
	; stack wrapped to $0000.
	;
	; The whole page is saved rather than the documented sixteen bytes, because
	; the measurement is of one call on one emulator and the cost of being
	; wrong is this bug again on a machine nobody can debug. It is ~3000 cycles
	; against a block read of some milliseconds.
	ldx #0
-	lda $00,x
	sta SP_ZP_SAVE,x
	inx
	bne -

	lda .cmd
	sta PD_COMMAND
	lda sp_unit
	sta PD_UNIT
	lda sp_dest + 1
	sta PD_BUFFER
	lda sp_dest
	sta PD_BUFFER + 1
	lda sp_block
	sta PD_BLOCK
	lda sp_block + 1
	sta PD_BLOCK + 1
	lda #0
	sta sp_write_protect
.call
	jsr $ffff               ; patched at boot to the slot's ProDOS entry
	sta sp_last_error       ; 0 on success, and harmless to record either way
	php                     ; the carry is the answer; the restore clobbers it
	ldx #0
-	lda SP_ZP_SAVE,x
	sta $00,x
	inx
	bne -
	plp
	bcc .ok
	; The caller reads the carry, so the test below must not be what sets it:
	; cmp writes the carry, and a firmware error code below $2B would otherwise
	; be handed back as "this worked".
	lda sp_last_error
	cmp #PD_ERR_WPROT
	bne .bad
	inc sp_write_protect    ; the device refused it; the bits are not at fault
.bad
	sec
	rts
.ok
	clc
	rts
.cmd !byte 0

; The two bytes of .call's operand, named so boot can patch them.
.entry_lo = .call + 1
.entry_hi = .call + 2

image_end
	!if image_end - $0800 > 512 {
		!error "The SmartPort driver is ", image_end - $0800, " bytes; the ",
		       "firmware loads exactly one 512 byte block."
	}
