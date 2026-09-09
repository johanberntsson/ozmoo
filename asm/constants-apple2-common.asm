; Constants shared by every Apple II target (TARGET_APPLE2_FAMILY)

; --- hardware ---------------------------------------------------------------
KEYBOARD              = $C000   ; bit 7 = a key is waiting, bits 0-6 = ASCII
KEYBOARD_STROBE       = $C010   ; any access clears the strobe
SPEAKER               = $C030   ; a click per access
TXTCLR                = $C050   ; these four put the screen in 40 column text,
TXTSET                = $C051   ; page 1, no mixed graphics
MIXCLR                = $C052
LOWSCR                = $C054
HIRESOFF              = $C056

!ifdef A2_SMARTPORT {
; --- the SmartPort block driver ---------------------------------------------
; asm/apple2-smartport.asm rather than asm/apple2-rwts.asm: block 0 of the disk,
; which the firmware loads and jumps into, and which then stays resident as the
; block reader. The offsets echo the RWTS's so disk.asm's stores are the same
; few instructions either way; what changes is that the two bytes at $0807 are
; a block number rather than a track and a sector, and that a block is 512
; bytes where a sector is 256 - so one of Ozmoo's pages is half a block. See
; a2_sp_read_page in disk.asm for what that costs (one buffer and one copy).
A2_READ_BLOCK         = $0804
A2_BLOCK              = $0807   ; block number, low byte then high
A2_DEST               = $0809   ; destination page...
A2_DEST_LO            = $080A   ; ...and its low byte
A2_WRITE_BLOCK        = $080B
A2_WRITE_PROTECT      = $080E   ; the device refused the write
A2_LAST_ERROR         = $080F   ; the firmware's own error code
A2_UNIT               = $0810   ; $DSSS0000: drive and slot
A2_SLOT               = $0811   ; slot * 16, latched at boot

; The driver is 512 bytes at most, so everything from $0A00 up to the
; interpreter is free where the RWTS needed it for nibble buffers. The first
; page and a half of that is the block buffer a half-block read needs.
A2_BLOCK_BUFFER       = $0A00   ; 512 bytes

; Where make.rb puts things. Block 0 is the boot block the firmware loads, and
; block 1 the config; everything else the interpreter is told at boot, out of
; the config block itself. Keep in step with A2_SP_CONFIG_BLOCK in make.rb.
A2_SP_CONFIG_BLOCK    = 1
} else {
; The boot chain at $0800, which stays resident. Ozmoo reaches a sector through
; the jump at A2_READ_SECTOR (or A2_WRITE_SECTOR) after filling in the track,
; sector and address below it; see the header of asm/apple2-rwts.asm, which owns
; these addresses.
A2_READ_SECTOR        = $0804
A2_TRACK              = $0807
A2_SECTOR             = $0808
A2_DEST               = $0809   ; high byte of the buffer address...
A2_DEST_LO            = $080A   ; ...and its low byte
A2_WRITE_SECTOR       = $080B   ; write one sector, same three parameters
A2_WRITE_PROTECT      = $080E   ; nonzero if the last write was refused by the
                                ; drive rather than failing to verify
A2_LAST_TRACK         = $080F   ; the track and sector of the last address
A2_LAST_SECTOR        = $0810   ; field the drive decoded. After a read that
                                ; failed, these two against the ones asked for
                                ; say whether the head was in the wrong place
                                ; or the bits under it would not decode
A2_DRIVE              = $0811   ; which drive on the controller, 1 or 2. Set
                                ; once and it stays; the driver keeps a head
                                ; position for each and swaps them over
A2_SLOT               = $0812   ; slot * 16, latched by the driver from the
                                ; PROM's own $2B at boot
A2_MOTOR_OFF          = $c088   ; + slot * 16: stop the drive. The RWTS never
                                ; does (it pages constantly), but quitting to
                                ; BASIC should not leave it spinning
A2_BOOTSLOT_ZP        = $2b     ; ...and where the PROM left it, which the
                                ; driver still reads on the way through boot.
                                ; It is mem_temp + 1 to us, so a restart has to
                                ; put A2_SLOT back there before jumping to $0801
}

; --- getting back to BASIC --------------------------------------------------
; The autostart ROM's RESET routine decides between a warm start and a cold one
; by a "power-up byte": if $3F4 holds $3F3 EOR $A5 it believes the vector at
; $3F2/$3F3 and jumps through it, and otherwise it cold starts, which on a
; machine with a disk controller means booting the disk. Ozmoo's quit sets the
; three bytes and then goes through the reset vector, so the ROM does its own
; screen and I/O hook initialisation - which we need, having trashed the zero
; page - and lands in Applesoft instead of booting the game again.
A2_SOFTEV             = $03f2   ; where a warm reset goes (a word)
A2_PWREDUP            = $03f4   ; ...believed only if it holds $3F3 EOR $A5
A2_BASIC_COLD         = $e000   ; Applesoft cold start

; --- the language card ------------------------------------------------------
; $D000-$FFFF is ROM on a bare machine and 16K of RAM on any IIe (and on a II+
; with a language card). The switches are $C080-$C08F: bit 3 picks the bank
; that answers at $D000-$DFFF, bit 0 write-enables the RAM - and a write enable
; only takes if the address is READ twice in a row, which is why the pairs
; below are always written out twice. $E000-$FFFF is shared by both banks, so
; bank 1 gives one contiguous 12K window from $D000 up.
;
; Ozmoo uses bank 1 and never switches again after boot: A2_LC_RAM leaves the
; RAM readable AND writable for the rest of the session, because the code that
; lives there self-modifies like any other Ozmoo code. Only the reset stub
; (apple2-kernal.asm) ever puts the ROM back.
A2_LC_ROM_WR          = $C089   ; read ROM, write RAM  (bank 1) - copy state
A2_LC_ROM             = $C08A   ; read ROM, RAM write protected - the ROM back
A2_LC_RAM             = $C08B   ; read RAM, write RAM  (bank 1) - resting state

; The 4K at $D000-$DFFF that bank 1 answers with is split in two. The bottom
; 2K is where COLOUR_ADDRESS points: this machine has no colour memory, and the
; shared screen code writes a colour beside every character it prints, so those
; writes are given a real 2K of scratch to land in rather than being wrapped in
; an ifdef at 133 sites. The clear in .change_colours walks (screen size >> 8)
; + 1 whole pages from COLOUR_ADDRESS, which is the 8 pages a 80x24 screen
; needs - hence the check, since one page more would reach the code above it.
; Everything from A2_LC_CODE_START up is interpreter code, moved off the disk
; by a2_lc_init at boot.
A2_LC_CODE_START      = $D800
A2_LC_CODE_END        = $FFFA   ; the last six bytes are the CPU's vectors
!if SCREEN_WIDTH * SCREEN_HEIGHT >= (A2_LC_CODE_START - COLOUR_ADDRESS) {
	!error "The colour scratch below A2_LC_CODE_START is too small for this screen."
}

; --- zero page --------------------------------------------------------------
; Laid out like the X16's, which is the most recent map written from scratch
; rather than inherited from the C64's KERNAL gaps.
z_trace_index		  = $22
z_exe_mode	  		  = $23
z_opcode              = $24
z_extended_opcode	  = $25
z_opcode_number       = $26
z_operand_count		  = $27
zp_pc_h               = $28
zp_pc_l               = $29
mem_temp              = $2a ; 2 bytes
mempointer_y          = $2c ; 1 byte
zword				  = $2d ; 6 bytes
zp_mempos             = $33 ; 2 bytes

z_operand_value_high_arr = $35 ; 8 bytes
z_operand_value_low_arr = $3d ;  8 bytes

;
; NOTE: This entire block of variables, except last byte of z_pc_mempointer
; and z_pc_mempointer_is_unsafe is included in the save/restore files
; and _have_ to be stored in a contiguous block of zero page addresses
;
	z_local_vars_ptr		= $45 ; 2 bytes
	z_local_var_count		= $47
	stack_pushed_bytes		= $48 ; 2 bytes
	stack_ptr				= $4a ; 2 bytes
	stack_top_value			= $4c ; 2 bytes
	stack_has_top_value		= $4e ;
	z_pc					= $4f ; 3 bytes (last byte shared with z_pc_mempointer)
	z_pc_mempointer			= $51 ; 2 bytes (first byte shared with z_pc)
	zp_save_start			= z_local_vars_ptr
	zp_bytes_to_save		= z_pc + 3 - z_local_vars_ptr

;
; End of contiguous zero page block
;

zchar_triplet_cnt	  = $55
packed_text			  = $56 ; 2 bytes
alphabet_offset		  = $58
escape_char			  = $59
escape_char_counter	  = $5a
abbreviation_command  = $5b

parse_array           = $5c ; 2 bytes
string_array          = $5e ; 2 bytes

z_address			  = $60 ; 3 bytes
z_address_temp		  = $63

object_tree_ptr       = $64 ; 2 bytes
object_num			  = $66 ; 2 bytes
object_temp			  = $68 ; 2 bytes

z_low_global_vars_ptr	  = $6a ; 2 bytes
z_high_global_vars_ptr	  = $6c ; 2 bytes

stack_tmp			  = $6e; ! 5 bytes
default_properties_ptr = $73 ; 2 bytes
zchars				  = $75 ; 3 bytes

s_colour 			  = $78 ; the byte is kept, but nothing renders it

mempointer            = $7c ; 2 bytes
vmem_temp			  = $7e ; 2 bytes

vmap_max_entries	  = $80
vmap_used_entries	  = $81
vmap_quick_index_match= $82
vmap_next_quick_index = $83
vmap_quick_index	  = $84 ; Must follow vmap_next_quick_index!
vmap_quick_index_length = 6 ; Says how many bytes vmap_quick_index uses

z_temp				  = $8a ; 12 bytes

num_rows 			  = $96
; Screen kernal stuff. Must be kept together or update s_init in screenkernal.
!ifndef Z6 {
s_ignore_next_linebreak = $97 ; 3 bytes
}
s_reverse 			  = $9a

savefile_zp_pointer   = $9b ; 2 bytes
current_window		  = $9d
is_buffered_window	  = $9e

s_stored_x			  = $9f
s_stored_y			  = $a0
s_current_screenpos_row = $a1

max_chars_on_line	  = $a2
buffer_index		  = $a3
last_break_char_buffer_pos = $a4

zp_cursorswitch       = $a5
zp_screenline         = $a6 ; 2 bytes current line (pointer to screen memory)
zp_screencolumn       = $a8 ; current cursor column
zp_screenrow          = $a9 ; current cursor row
zp_colourline         = $aa ; 2 bytes. There is no colour memory on this
                            ; machine, so it points into the scratch below
                            ; A2_LC_CODE_START - which is real RAM on a IIe and
                            ; ROM, and so a no-op, on a II+
cursor_row			  = $ac ; 2 bytes

window_start_row	  = $ae ; 4 bytes

zp_temp               = $b2 ; 5 bytes

; The software clock and the entropy counter the keyboard shim keeps
; (asm/apple2-kernal.asm). There is no timer and no readable vertical blank on
; a II+ or a IIe, so the jiffy count is made by the input loop counting its own
; passes; a2_entropy is free running and sampled when a key is pressed.
a2_jiffy              = $b7 ; 3 bytes, as RDTIM's a/x/y
a2_jiffy_sub          = $ba ; 2 bytes: polls left until the next jiffy, which
                            ; is more than 256, so this is a word
a2_entropy            = $bc ; 2 bytes

; A IIgs does have a readable vertical blank, so it counts frames instead and
; has no use for the poll counter - the two bytes are the same two, under the
; names the edge detector wants.
a2_vbl_last           = a2_jiffy_sub      ; bit 7 of $C019 as it was last seen
a2_vbl_now            = a2_jiffy_sub + 1  ; ...and as it is now

; --- buffers ----------------------------------------------------------------
; $0100-$01ff is the 6502 stack, which print_buffer shares with it exactly as
; it does on the C64; $0300-$03ff is the vmem page table.
print_buffer		  = $0100 ; SCREEN_WIDTH + 1 bytes
print_buffer2         = $0200 ; SCREEN_WIDTH + 1 bytes
memory_buffer         = $02a7
memory_buffer_length  = 89

vmap_buffer_start     = $0300
vmap_buffer_end       = $0400 ; Last byte + 1

; --- what the Apple II does not have ----------------------------------------
; Nothing is banked on a 48K II+, so no page ever needs banking in or out.
first_banked_memory_page = $c0
