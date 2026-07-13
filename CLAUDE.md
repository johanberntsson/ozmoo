# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Ozmoo is a Z-machine interpreter for the Commodore 64, C128, Plus/4 and MEGA65 (plus an X16 target), written in 6502 assembly (ACME cross-assembler syntax) and driven by a Ruby build script. It runs Infocom/Inform story files.

**This checkout is the `z6` branch**, whose purpose is adding Z-machine **version 6** support. The window model works on every target; graphics work on the MEGA65 full colour screen — **80 columns (H640) since July 2026, with the pictures pixel-doubled to keep their 320-wide scale** — where Arthur draws its first room like the reference interpreter, and the mouse works there too (Zork Zero's clickable controls, Arthur's click-to-dismiss-`[MORE]`). All four v6 games boot at 80 columns; Johan is play-testing them and collecting the current crop of glitches (see todo.txt for the ones already known). `master` tracks upstream Ozmoo and must keep working — every change here has to be checked against both. This is Johan's personal project: make local commits, but never push without explicit permission.

## Build and run

Required: `acme`, `exomizer` (expected at `exomizer/src/exomizer` on Linux — a local checkout, not in git), VICE (`x64`, `x64sc`, `x128`, `xplus4`, `c1541`), `ruby`, and `inform` + `frotz`/`dfrotz` for the v6 test game. Tool paths are hardcoded at the top of `make.rb` (separate Windows/Linux sections).

```sh
make z6        # compile testz6.inf with inform -v6, build a d64, autostart in VICE
make ecm       # same, with -ecm (per-window background colours)
make frotz     # compile testz6.inf and run it in frotz — the reference behaviour
make z6-mega65 # testz6 on the MEGA65, 80-column text
make z6-fcm    # testz6 on the MEGA65 full colour screen: 80 columns (H640);
               # compare against `dfrotz -h 25 -w 80`
make z6-fcm40  # the legacy 40-column full colour screen; should match `make z6`
               # line for line -- the C64-vs-MEGA65 regression check
make z6-pics   # z6-fcm, drawing the test pictures in tools/testpics
make arthur    # build the real v6 game Arthur as a d81 and run it
make arthur-d2 # same, but split over two 1541 drives
make arthur-mega65 # Arthur on the MEGA65, 80-column text
make arthur-fcm    # Arthur on the MEGA65 full colour screen
make arthur-pics   # ...and drawing its own pictures. The whole thing.
make zork0     # Zork Zero on the full colour screen, to try the mouse (no pictures)
make zork0-pics # ...with its 396 pictures, spread over two picture disks
make shogun-pics  # Shogun on the full colour screen with its pictures (one disk)
make journey-pics # Journey, the largest v6 game, with its pictures (two disks)
make amfv      # build the large z4 game AMFV as a d81 (checks large files + d81)
make c64       # build examples/dejavu.z3 (a z3 game) — the non-z6 regression check
make mega65    # same, for MEGA65
make clean

ruby make.rb [options] <storyfile>   # run with no args for the full option list
```

`make arthur-pics` needs `z6games/arthur-r74-s890714.blb`, the game's blorb,
which is not in git. `-pics <blorb-or-dir>` runs `tools/pics2asm.py`, which puts
one compressed file per PNG picture on the d81 and sets `Z6_PICTURES`; it needs
`-fcm`. Given a blorb it also reads the game's `Rect` placeholders and `APal`
adaptive-palette list (see the Pictures section); given a plain directory of
numbered PNGs (`tools/testpics`) it just tiles those.

`dfrotz -h 25 -w 40 testz6.z6` gives reference output with the same screen size as a C64, which makes line-for-line comparison possible.

There is no automated test suite. `test/` holds standard conformance games (czech, praxix, strictz, oztest, etude) that are built and played manually. `testz6.inf` is the v6 test game — grow it opcode by opcode and compare against frotz rather than debugging a commercial game blind.

Before committing anything that touches shared code, rebuild the matrix: `testz6.z6`, `-ecm testz6.z6`, `examples/dejavu.z3`, `test/praxix.z5`, and `-t:c128` / `-t:mega65` / `-t:mega65 -fcm` / `-t:mega65 -fcm:40` / `-t:plus4` / `-smooth:1` variants. Building is not enough for the screen layer: run `testz6` on the C64 and on `-t:mega65 -fcm:40` and compare — both are 40 columns and should agree line for line — and check `-t:mega65 -fcm` (80 columns) against `dfrotz -h 25 -w 80`.

## Conditional assembly is the architecture

Everything is one assembly program (`asm/ozmoo.asm` `!source`s all other files) specialized at build time by ACME `-D` flags that `make.rb` derives from the story file and command line:

- **Z-version**: `make.rb` reads the story file's version byte and passes `-DZ6=1` etc. `ozmoo.asm` derives cumulative flags: `Z3PLUS`, `Z4PLUS`, `Z5PLUS`, `Z6PLUS`, `Z7PLUS`, plus `Z6_Z7` (those two versions use packed-address offsets).
- **Target**: `-DTARGET_C128=1`, `-DTARGET_MEGA65=1`, etc. (no define for C64, the default).
- **Feature/debug flags**: edit `$GENERALFLAGS` / `$DEBUGFLAGS` at the top of `make.rb` to enable e.g. `DEBUG`, `TRACE`, `VICE_TRACE`, `CHECK_ERRORS`. `TRACE_SCREEN` (in `screen-z6.asm`) traces the v6 opcodes.
  - `DEBUG` + `TRACE` together are the fastest way to place a crash: `fatalerror` names the error and prints the **last ten opcodes with their `z_pc`**, which usually identifies the guilty instruction outright. Decode them against the story file, or better, against `txd`'s disassembly (below).
  - `CHECK_ERRORS` is forced on for `-t:mega65` (`make.rb`) and off elsewhere, so a MEGA65 build can stop dead on something every other target runs straight through. `-re:0` turns it off. Do not reach for that first: an error only the MEGA65 reports is usually a real bug the other targets are silently living with.
  - `ztools-master/txd -n <story>` disassembles a story file and `infodump` dumps its header, objects and dictionary. Between the `TRACE` opcode list and `txd`, a v6 crash usually resolves in a couple of minutes. Not in git; keep a checkout in the working directory.

So "does this code run?" always depends on which `!ifdef` blocks are active for the given version/target.

## Source layout (asm/)

- `ozmoo.asm` — entry point, init, main loop; sources everything else.
- `zmachine.asm` — opcode dispatch and most `z_ins_*` routines.
- `stack.asm` — Z-stack, `stack_call_routine`, and the opcodes that touch the stack.
- `vmem.asm`, `memory.asm` — virtual memory: the story beyond dynamic memory is demand-paged from disk in 512-byte blocks. `set_z_pc` / `get_page_at_z_pc` page in the code being executed.
- `screenkernal.asm` / `screen.asm` — the non-z6 screen layer. `screenkernal.asm` replaces the C64 kernal screen routines (`s_printchar` instead of `$ffd2`); `screen.asm` implements the Z-machine screen model on top.
- `screenkernal-z6.asm` / `screen-z6.asm` — the **z6-only** equivalents, sourced instead of the above under `!ifdef Z6`. Keep them as close to their non-z6 counterparts as possible; when master changes the originals, re-fork rather than hand-patch.
- `streams.asm`, `text.asm`, `dictionary.asm` — I/O streams (must precede text.asm), zchar decoding, tokenizing, `read_text`.
- `disk.asm`, `reu.asm`, `constants*.asm` — disk access, REU, per-target memory maps.

`tools/` holds the picture pipeline: `pics2asm.py` (PNGs → the files on the disk),
`gen_testpics.py` (the pictures `testz6` draws, ours, in `tools/testpics`),
`png2fcm.py` (the reference for the tile format) and `fcm-prototype.asm` (a
standalone prg, the only place the working VIC-IV register setup is written out).

## The z6 screen model

Eight windows, each with the property array the spec requires (`window_y`, `window_x`, `window_y_size`, …, `window_attributes`, `window_linecount`), laid out contiguously so `get_wind_prop`/`put_wind_prop` can index them as `window_y + 8 * property + window`.

- Coordinates are stored **0-based internally**; the opcodes convert to/from the z-machine's 1-based coordinates.
- Printing, wrapping, scrolling, the cursor, the MORE prompt and erasing are all **per window**: text wraps at the window's right edge, scrolls its own rectangle, and the MORE prompt appears at the current window's bottom-right cell. Each window keeps its own cursor and line count.
- Ozmoo always shows a MORE prompt when a game quits, so the last message can be read. A lone `*` in a corner after quit is that, not a bug.
- Property 13 (font size) is the only window property that is a real word (height in the high byte, width in the low). It cannot live in the byte-per-window arrays, so `get_wind_prop` answers it directly with 1,1. It must never be zero: Arthur divides by it. `window_font_size_slot` exists only to keep properties 14 and 15 where the spec puts them.
- `-ecm` (`Z6_ECM_MODE`, C64 + v6 only) turns on VIC-II Extended Color Mode: the top two bits of each screen code pick one of four background registers (`$d021`-`$d024`), giving each window its own background. The cost is a 64-character charset, so screen codes are masked to 6 bits (uppercase renders as lowercase) and reverse video is unavailable.
- `-fcm` (`Z6_FCM_MODE`, MEGA65 + v6 only) puts the VIC-IV into Full Colour Mode with 16-bit character codes on an **80x25, 640x200 (H640) screen** — v6 games assume 80 columns (Zork Zero's layout breaks and Journey is unplayable at 40), while their pictures stay at their 320-wide scale by pixel doubling (see Pictures). Text glyphs are the ROM font's 8-pixel ones, so a text cell is half the width of a doubled picture cell's 16 physical pixels; codes below 256 stay ordinary glyphs (`FCLRLO` clear), codes from 256 up are 64-byte tiles. `-fcm:40` (`Z6_FCM_40`) keeps the old 320x200, 40x25 screen and builds its disks with an `_fcm40` suffix; it renders text identically to the C64, which makes it the line-for-line regression target (`make z6-fcm40`), while the 80-column screen is compared against `dfrotz -h 25 -w 80`. The z6 kernal has no separate text path — `s_printchar` always writes two-byte FCM cells — so everything, including the **splash screen**, renders in FCM; the splash lines are centred for 40 columns and get the same +20 re-centring as the 80-column text build (only `-fcm:40` must skip it, where +20 would wrap into garbage). A custom font is refused with `-fcm` (CHARPTR is pinned to the ROM font). Per-window background colours are **not** implemented yet, which is the remaining half of the FCM work. On quit, `z_ins_quit` clears the FCM mode bits (`$d054` CHR16/FCLRHI) and the mouse sprite before the C64 reset, which never touches `$d054` — otherwise BASIC comes up in 16-bit-character full-colour mode, unreadable.
- **Colour RAM under FCM goes through 32-bit pointers, not `$d800`.** The 80-column screen needs 80x25x2 = 4000 colour bytes, which outgrow the CPU's 2 KB `$d800` window (`colour2k`), so under `Z6_FCM_MODE` every colour access uses `sta [zp],z` into colour RAM at `$ff80000` **plus `FCM_COLOUR_OFFSET` (`$0800`, set in `$d064/5`)**: `zp_colourline` is a 4-byte pointer at `$e5` (low word = offset + row offset + the usual +1 bias, high word always `$0ff8`), with scratch pointers at `$d9`/`$dd` (scroll row copies) and `$e1` (the [More] cell). **The high words must never live at `$f5/$f6`** — the kernal keyboard scan rewrites those two bytes with its decode-table pointer on every IRQ. `$d9-$f2` is the kernal screen editor's line-link table, which Ozmoo's own screen code replaces, so that region is interrupt-safe.
- **The screen's colour region must not start at colour offset 0.** The first 2 KB of colour RAM is also mapped at `$1f800-$1ffff` in bank 1, whose top is CBDOS workspace: every SD/disk access rewrites colour bytes around `$7f2-$7fb`. In FCM's 16-bit colour cells those land in *attribute* bytes, and `$f8` there is a GOTOX token that blanks the rest of the row — this was the white stripe over Arthur's intro pictures and the intermittently vanishing line tails. The 40-column screen's 2000 bytes stopped just short of the DOS bytes, which is why only 80 columns suffered. `FCM_COLOUR_OFFSET` keeps the screen clear; scrollback's temporary colour sits at `$1000`; `z_ins_quit` puts the offset back to 0 for BASIC. When dumping colour RAM in the xemu monitor, the screen's colour now starts at `$ff80800`, not `$ff80000`.

### The FCM cell is two bytes, and that keeps biting

Under `-fcm` a screen cell and a colour cell are two bytes each. Ozmoo writes the character into the **even** byte of a screen cell and the colour into the **odd** byte of a colour cell; the other two must be zero and stay zero.

- `zp_screencolumn` still holds a *column*. Only the sites that index the screen double it, which leaves the window edges, margins and every comparison alone.
- `zp_colourline` is biased by **+1**, so one doubled index writes both character and colour. A row offset's low byte is a multiple of 32, so the bias never carries.
- Every character store must also zero the cell's high byte — the `clear_cell_high_byte` macro. Miss one and text printed over a picture leaves the cell pointing at a tile.
- **Most text does not go through `s_printchar`.** It goes through `print_line_from_buffer` in `screen-z6.asm`, which writes the screen directly. Four separate bugs have come from forgetting one of these sites; audit them all with `grep -n 'sta (zp_screenline),y'`.

### Pictures (MEGA65, `-fcm -pics`)

`tools/pics2asm.py` reads the blorb (or a PNG directory) and writes one compressed file per picture; `make.rb` puts them on **separate picture disks** (`mega65_<game>_pics_1.d81`, `_pics_2.d81`, …), one d81 per disk, packed to fill each before the next; `pic_load_all` decompresses them into attic RAM at `$08300000` at boot, next to where `sound.asm` preloads the WAVs, under a "loading graphics" label with a `/`-per-few-pictures progress bar (scaled to stay ~30 wide) like the story preloader's. Only an index is assembled in: picture numbers, the `Rect` placeholder sizes, the `pic_adaptive` flags, and the disk each picture is on.

- **Pictures live on their own disks, not the boot disk.** Arthur's story alone (~1061 blocks) plus the interpreter and sound nearly fills a d81, so the boot disk holds only those and the pictures go on `_pics_N.d81`. `pics2asm.py` packs the picture files across as many disks as they need (`picdisks.txt` records the assignment; `pic_disk` is the assembled-in table) and `make.rb`'s `build_picture_disks` builds one d81 per disk.
- **Two drives, then swap.** `pic_load_all` groups its load by picture disk; for each it tries the second drive (`boot_device + 1`, e.g. 9) then the boot drive, and only if neither holds the disk does it print `insert picture disk N` and wait for a key. So with `xemu -8 boot.d81 -9 pics_1.d81` a one-disk set loads with no prompt; `make.rb` auto-mounts `-9` with the first picture disk when it launches the emulator. Presence is checked by reading the **drive error channel** (`.pic_probe`): a missing file OPENs "successfully" but leaves error 62 and reads back a stale buffer page, so the status byte alone can't be trusted.
- **Picture numbers run to 999** (`pic_number_lo`/`_hi`, `rect_number_lo`/`_hi`; the `P###` filename is three digits) and the per-build **count is 16-bit** too: `.pic_index` is a word, the parallel `pic_*` tables are indexed through `.pic_addr` (base + word index → `.pi_ptr`), and `pic_win_number` is a word per window. So a build can hold up to 999 pictures — Zork Zero's 396 (numbered to 504) build and load. A picture disk's directory holds ~296 files, so 396 needs two disks; only the first is auto-mounted in drive 9, so the rest still prompt for a swap.

- **On the 80-column screen a logical picture cell is two tiles.** The games' art is 320-wide, so each 8x8-pixel cell of a picture becomes two screen cells (left half, right half) whose pixels are doubled — the picture keeps its visual size while text stays 8 pixels wide. `pics2asm.py` emits two cell-map entries per logical cell and stores the halves **undoubled** on disk and in attic (16 bytes a tile: 4 source pixels a row); `.pic_copy_tiles` writes each pixel twice as it bakes the 64-byte store tile (`.pic_emit_pixel`). Deduplication happens on the halves, so the doubling costs nothing on disk — the picture sets are the same size as the 40-column ones (Arthur and Shogun one picture disk, Zork Zero and Journey two). Arthur's worst live set (frame + scene + status) measures 1894 of the 2048-tile store; `--stats` in pics2asm prints the numbers without writing anything.
- The tile store is `$40000-$5ffff` — 2048 tiles — because Arthur keeps a border, a scene and a status panel on screen at once. Sound moves down to bank 1 and undo out to attic to make room; see the memory map in the techreport. Without `-pics` the store stays in bank 1. A cell's screen code is its tile's address / 64, so `FCM_TILE_CODE_HI + tile index`.
- **Each drawn picture gets its own tile run and its own palette bank**, bumped together and reused together (`pic_win_base`/`pic_win_number`/`pic_win_bank`, keyed by window; only the *same* picture redrawn into a window reuses its run). This is because a window holds several pictures at once — Arthur composites a scene inside a frame — so a per-window bank (the old `16 + 16 * window`) had them fighting over one palette. Banks are `16 * bank`, `bank` running 1..14; bank 15 is skipped because its top colour would be pixel value 255, which FCM takes from colour RAM. When a fresh tile run won't fit, `.pic_alloc` **compacts the store instead of wrapping** (`.pic_gc`): every tile still shown by a cell outside the incoming picture's rectangle is moved to the bottom of the store (ascending order, safe in place) and its cells repointed, so Arthur's Merlin scene can be drawn centred over the sword picture with the sword's frame kept intact, as the reference shows it. Only if survivors + new picture still exceed 2048 does the old wrap-to-zero happen. The *palette* allocator still wraps, spoiling at most a picture no longer the newest; a fully opaque cell composited over another picture reuses its own tile rather than baking a copy (`.pcf_make_tile` counts transparent pixels while loading its buffer).
- **A picture keeps its PNG palette indices; they are not compacted.** A pixel is its own index (0 transparent, 1..15 straight into the bank), and the bank is loaded in index order. This is what lets an **adaptive** picture line up with the palette it borrows (below). Four bits a pixel on disk and in attic, one byte in the store; 255 comes from colour RAM, so a picture has at most 15 colours. Arthur's pictures put transparency at index 0 and never colour index 0.
- **Compositing works two ways.** `pics2asm.py` writes `$ffff` for a cell that is transparent through and through, and `pic_fill_cells` leaves such a cell untouched — so a frame with a hole (like Arthur's) drawn over a scene shows the scene through the hole. A *partly* transparent cell (some opaque, some transparent pixels) is composited **per pixel**: before writing an opaque cell, `pic_fill_cells` reads what is already there, and if a full colour tile is underneath it bakes a fresh tile taking the overlay's pixel where opaque and the underlying tile's pixel where transparent (`.pcf_make_tile`). This works because the tile store holds *absolute* palette indices with every bank loaded at once, so one tile can legitimately mix the overlay's colours and the scene's. Cells with only text or blank underneath keep the old behaviour (a transparent pixel shows the screen background), so pictures drawn over an empty screen are unchanged. The composite tiles are taken from `pic_next_tile`, bumped and wrapped like the normal allocator — cheap for Arthur (~9 a room), but a game that redraws a full-screen picture straight over another without clearing would churn the store, so if Zork Zero or Journey corrupt tiles the fix is to skip compositing for fully-opaque overlays.
- **Adaptive-palette pictures (blorb `APal`, `pic_adaptive`)** — Arthur's frame and side bars — ignore their own (placeholder) palette and are drawn in the palette of the last *direct* picture (`pic_direct_base`), so the UI recolours to match the scene. `pic_read_palette` is skipped for them and their tiles are baked into the current direct bank.
- Drawing is clipped to the screen: `pic_fill_cells` and `pic_erase` stop at the last row/column, so a picture placed partly (or, from a bad coordinate, wholly) off screen cannot scribble past screen RAM into the interpreter.
- `make.rb` upper-cases the names it puts in the disk directory, so the interpreter asks for `P004`. A wrong name fails **silently**: OPEN reports success and one page of the copy buffer lands in attic.

### Mouse (MEGA65, `-fcm`)

`asm/mouse.asm` (sourced under `Z6`, gated on `Z6_FCM_MODE`) implements the z-spec 10.3 mouse. It is FCM-only: text-only z6 has no pointer.

- The 1351/Amiga mouse on **control port 2** is read from the MEGA65's direct pot registers `$d620`/`$d621` (no SID/CIA multiplexing) and its button from `$dc00` bit 4. The pot is a wrapping 6-bit counter, so `mouse_poll` tracks the signed change between reads and accumulates a pixel position, clamped to 640x200 (320x200 under `-fcm:40`). **Port 2 is where xemu puts the mouse**, and it is the right choice anyway: port 1's lines are shared with the keyboard matrix, so `$dc01` bit 4 reads keyboard row 4 (SPACE, etc.) and can't distinguish a click from a keypress. A real MEGA65 mouse in port 1 would need `$d622`/`$d623` and `$dc01`, with the keyboard caveat.
- The pointer is **sprite 0**, addressed through the VIC-IV 16-bit sprite pointer (`$d06c`-`$d06e`, SPRPTR16), because the classic pointer slot (screen + `$3f8`) lands inside the FCM screen RAM. `mouse_poll` moves it; there is no hardware "sprite follows mouse", the MEGA65 KERNAL just does the same in an interrupt. **Sprite X coordinates stay in the 320-wide space under H640** (one sprite unit = two physical pixels), so `.mouse_place_sprite` halves the 0..639 position; the pointer therefore moves in 2-pixel steps on the 80-column screen.
- `mouse_poll` runs from `getchar_and_maybe_toggle_darkmode` on every input wait (so the pointer follows the mouse through `read`, `read_char` and the `[MORE]` prompt). A press becomes input code **254**; the click cell goes into the header extension table (`mouse_write_header_coords`), and `read_mouse`/`z_ins_mouse_window` report the live pointer and confine it to a window.
- `z_init` keeps Flags 2 bit 5 and calls `mouse_enable` (which sets `mouse_active` and shows the sprite) **only if the game asked for the mouse** — Arthur, Zork Zero and `testz6` (whose `@read_mouse` test asks) all get a pointer. Clicks are ignored unless `mouse_active`.
- The pointer is a red arrow (sprite 0 colour, `mouse.asm`), chosen so it stays visible over the white status line. The click is confirmed working: in xemu, Zork Zero's compass rose responds to a click on the full colour screen. Automated headless testing still can't drive it (xemu can't move or press a mouse without a window), but the sprite, `mouse_active`, and the terminator table can all be read back.

## Watch out for

- **v6 changes opcode shapes.** `pull` is the classic trap: in v1-v5 it names the variable to store into; in v6 it takes an optional user-stack operand and *stores* its result. Getting this wrong desyncs the PC and produces garbage, not a clean error. Check the Z-machine standard (see References) before assuming an opcode behaves as in v5.
- `draw_picture`, `erase_picture` and `picture_data` are all implemented under `-fcm -pics`, including `Rect` placeholders, adaptive palettes and transparent-cell compositing (see the Pictures section); elsewhere `draw_picture` writes a `pic:N` note and `picture_data` reports no picture. Arthur's first room — a scene composited inside a recolouring frame — now renders like the reference interpreter. `z_init` still clears the "pictures available" bit in `header_flags_2` even under `-fcm -pics`, which disagrees with `picture_data`; Arthur tolerates it (it draws pictures regardless), but the bit ought to be set when `Z6_PICTURES`. `print_form` and `scroll_window` turned out to be text opcodes and are done. See `todo.txt`.
- **The z-machine writes "the current window" as `-3`** (z-spec 8.8.3), and Arthur does so 27 times. Every opcode taking a window number must go through `window_from_operand`; taking the operand's low byte raw indexes the property arrays at `$fd`. This produced coordinates like y=244 and hung `.pic_draw`'s row loop, whose counter is one byte.
- **`.pic_find` clobbers `x`.** The 16-bit rewrite uses `x` as a table-address high byte (for `.pic_addr`); the old one-byte version kept the picture number in `x` for its whole loop. Any code that calls `.pic_find` and then `.rect_find` (which wants the number in `x`) must reload `x` first — `draw_picture`'s `.dp_not_image` does, `picture_data`'s `.pd_try_rect` didn't, and Arthur drew the churchyard scene off-screen for it (a bad rect size fed the game's layout). A ring buffer logging each `draw_picture`'s index and computed y found it. When a v6 opcode misbehaves, suspect the *game* got bad data from one of our query opcodes (`picture_data`, `get_wind_prop`) before suspecting the blit.
- **v6 is a "large" version, like v7/v8, not like v4/v5.** Story files run to 512 KB, the header file length is divided by 8, and block addresses need two high bits. `make.rb` has always known this (`$zcode_version > 5`); the assembly used to express it as `Z7PLUS`, which excludes v6. Use `Z6PLUS` for anything size-related, and be suspicious of any new `Z4PLUS`/`Z7PLUS` split. See `todo.txt` for the three bugs this caused.
- No v6 interpreter ever ran on a C64, so v6 code paths have never been exercised against a real game. Expect more latent assumptions — minimum screen size, stack depth, story size — that no other version happens to violate.
- **An error only the MEGA65 reports is usually a real bug everyone else lives with.** `CHECK_ERRORS` is compiled into MEGA65 builds and out of the others. Arthur's `FATAL ERROR: 17` turned out to be a modulo by zero the C64 executed too, caused by `get_wind_prop` returning 0 for the font size. Reaching for `-re:0` would have hidden a genuine defect.
- **The C64, Plus/4 and MEGA65 work. The C128 and X16 are still deliberately untouched.** The z6 window model is only wired into the scroll path the first three share; the C128 80-column (VDC) and X16 (VERA) scroll routines still scroll the whole screen, and ECM is C64-only. Those two remain known and accepted, not oversights — don't "fix" them yet.
- The C64 and Plus/4 will never draw pictures. The `pic:N` notes have to stay for them.
- **Terminating characters were a general bug** (all targets, not just mouse). z-spec 10.5.2.1: the table (`$2e`) holds function key codes 129-154 and 252-254, and 255 means "any of them". Ozmoo rejected everything above 140 and its 255 wildcard omitted the mouse clicks, so a click never ended a line. `parse_terminating_characters` now accepts the whole valid range, and the pre-filled default set the wildcard activates includes 252-254 on the full colour screen. If you touch that array, keep it in step with `NUM_DEFAULT_TERMINATORS`.
- **A big picture set spans several disks.** The `-pics` pipeline packs the numbered files across as many `_pics_N.d81` disks as they need (see the Pictures section) and `pic_load_all` sweeps the disks at boot, trying the second drive before asking for a swap. Picture numbers and the build count are both 16-bit, so Zork Zero's 396 pictures build and load (`make zork0-pics`, two disks). What headless testing can't reach: **loading past the first picture disk** (a real swap, which xemu can't do — verified only up to the disk-2 prompt). All four v6 games have `-pics` targets at 80 columns: Arthur and Shogun fit one picture disk (Arthur's first room and Shogun's title art verified against references), Zork Zero and Journey take two, so their pictures load only up to the swap prompt headlessly. Text-only at 80 columns, Zork Zero is playable and Journey boots into its command-menu layout; Journey's box-drawing divider glyphs are the known follow-up (see todo.txt). The squished right-aligned headers turned out to be the stream-3/live-cursor pair fixed with Shogun's menu screen (below).
- **The v6 games measure text by printing it to output stream 3** and reading the width back from header word `$30` (z-spec 7.1.2.1.1) — Shogun sizes its whole menu screen that way, Arthur its right-aligned status line. Three things had to hold: the stream-3 close writes the widest buffered line into `$30` (streams.asm counts units per line, newline starts a new one); `print_table` goes through `streams_print_output` even for a single row, since Shogun measures its menu items with print_table into stream 3 (printing them straight to the screen both left the width at 0 and leaked text onto the screen); and `get_wind_prop` answers the **live** cursor (`zp_screenrow`/`zp_screencolumn`) for the current window, because the per-window arrays only sync on window switches and games read the cursor back after every centred line.
- **`set_cursor` interacts with the print buffer**: pending buffered text belongs where the cursor *was*, so set_cursor flushes first, and restarts the buffer at the new position after the move (`start_buffering` inside the flush captures the pre-move column, so the restart must come after `restore_cursor`). `set_cursor -1/-2` is cursor visibility (z-spec 8.7.2.3): `cursor_hidden` suppresses both drawing and deleting the input cursor — the delete writes a space, which ate the first letter of Shogun's selected menu item where the game parks the (hidden) cursor.
- **80-column pictures builds report interpreter number 6 (IBM)** (make.rb defaults `-in:` when `-fcm` is 80 wide and `-pics` is given). Infocom's v6 games reserve their full layout for the IBM interpreter — Shogun only draws its right-hand border picture (a separate image, picture 59) when the header says IBM, and hardcodes its margins otherwise. Text and 40-column builds stay a C64 (8).
- **`DEBUG_SCREENLOG`** (add to `$DEBUGFLAGS` in make.rb) assembles a 128-entry ring buffer (`screenlog_buf`, 8 bytes an entry: id, current window, operands, and a result word for `get_wind_prop`/stream-3 close) recording every v6 screen opcode. Reading it out through the xemu monitor gives the exact sequence and arguments a game used to lay out a broken screen — this is how Shogun's menu page was diagnosed; far better than TRACE_SCREEN, which scrolls the screen it is tracing.
- **Fixed (verify in play):** the `-fcm` bug where games dropped or changed the odd stretch of body text, differently on each run — Arthur's intro lost a line's tail, Zork Zero's banquet paragraph likewise — was CBDOS scribbling colour-RAM attribute bytes (the colour-offset bullet above), the same root cause as the white stripe over Arthur's intro pictures. Fixed July 2026 by `FCM_COLOUR_OFFSET`; if a stretch of text still vanishes mid-row, re-open `todo.txt`.

## Debugging under VICE (headless)

Symbol addresses come from `temp/acme_labels.txt` after a build.

```sh
x64sc -default -warp +sound -limitcycles 60000000 -exitscreenshot shot.png c64_testz6.d64
```

- Drive commands from a `-moncommands` file. Use **tracepoints** (`trace exec $addr`), not breakpoints — breakpoints halt the emulator and wait for stdin.
- Tracepoint *hits* are not printed to stdout; only the confirmation of the tracepoint's creation is. Start the moncommands file with `logname "<file>"` and `log on` to capture the hits.
- Loading a d81 under true drive emulation takes over 100 million cycles before the first Ozmoo instruction runs, so `-limitcycles` needs to be generous (200000000+) or the trace will be empty and look like a crash.
- Attach an action with `command <n> "<cmd>"`. Several tracepoints may share an address, one command each.
- To type text: `command 1 "keybuf hello"`. `keybuf` does **not** interpret `\n`, so append Return by poking the kernal keyboard buffer: `command 2 "> 027c 0d"` and `command 3 "> 00c6 06"` (buffer, then length).
- `-exitscreenshot` can catch a mid-frame redraw and show a character that isn't really there. To see the truth, dump screen RAM: `command N "m 0400 07e7"` and decode the log (screen codes; in ECM the top two bits are the background register).
- VICE randomizes the autostart delay, so cycle counts are **not** reproducible between runs.
- A headless run stops at the first **MORE prompt** and at `read`, so it never reaches the end of a test game. Put a tracepoint on `show_more_prompt` with `command <n> "keybuf n"` to answer them.
- Don't hang a memory dump on `read_char`: it is a polling loop, so the dump repeats for as long as the game waits (44 million lines in one run here). `read_text` is hit once. Either way, take the *first* dump from the log.

## Debugging the MEGA65 under xemu (headless)

`xemu-xmega65` is better instrumented for this than VICE: it dumps the screen as plain **ASCII**, so there is nothing to decode and no mid-redraw artifact.

```sh
xemu-xmega65 -headless -sleepless -besure -skipunhandledmem \
    -8 mega65_testz6.d81 -autoload -dumpscreen screen.txt -screenshot shot.png
```

- It never exits by itself — there is no cycle limit. Wrap it in `timeout`; the dumps are still written on the way out.
- Like VICE, a headless run halts at the first **MORE prompt**. There are no tracepoints, but `-uartmon <socket>` gives a monitor that can do it: poll screen RAM (`$0800`; 80x25 one byte a cell on the text screen, or **two** bytes a cell under `-fcm` — 80x25 of them, 40x25 with `-fcm:40`) for the MORE character `$aa` (reverse `*`) **in a cell whose high byte is zero** — a picture tile's code can have `$aa` as its low byte, and treating those as MORE prompts stuffs the keyboard forever — and when it appears poke Return into the kernal keyboard buffer with `s0277 0d` then `s00c6 01`. That reaches `read`, where the game waits harmlessly, so stop there and dump rather than answering the read — the quit path shows a final MORE prompt and then resets, wiping the screen.
- Monitor commands over the socket: `m<addr>` reads 16 bytes, `M<addr>` reads a block, `s<addr> <bytes>` writes. Addresses are bare hex in the full 28-bit space, so colour RAM is `Mff80000`, not `Md800`.
- `-dumpscreen` only fires on exit, so it cannot capture an intermediate state; read `$0800` over the monitor instead. Screen codes there, not ASCII. Under `-fcm` take every second byte for the characters; a non-zero odd byte means the cell is a picture tile, not text.
- **`-dumpscreen` decodes screen codes in software, so it cannot see a bug in the character-rendering path.** It reports the code in the cell, never the glyph the VIC-IV fetched for it: a wrong `CHARPTR` is invisible in the dump and obvious in `-screenshot`. `FCM_CHARSET` pointed at the wrong 2 KB half of the C64 font for months because of this. `testz6` hid it too — its text is all lowercase, which under the uppercase/graphics charset renders as plausible-looking capitals. Anything touching the charset needs a screenshot, of text with a capital letter in it.
- `$e0` in screen RAM is the **cursor** (`CURSORCHAR` in `ozmoo.asm`), not a corrupt cell. It overwrites the character under it, so a dump taken while the cursor is up shows `$e0` where the text character belongs.
- Monitor addresses are the **linear** 28-bit map, so `$d000` there is RAM, not I/O. Reading `md054` returns zeros; the VIC-IV registers are at `$ffd3xxx` (`mffd3050`). Colour RAM is `$ff80000`.
- To try something without dragging Ozmoo along, build a bare prg and load it directly: `xemu-xmega65 -headless ... -prg foo.prg -prgmode 64 -screenshot shot.png`. Combined with `-screenshot`, a picture can be compared against its source PNG pixel by pixel. xemu renders the red channel one LSB low (`$bb` shows as 186), so compare within a tolerance of 1, not exactly.
- `-dumpmem` writes memory, and `-uartmon <socket>` opens a monitor, if the screen isn't enough.
- Non-printable screen codes come out as `{$xx}` in the dump.
- The uartmon socket takes **one client**: a second connect appears to succeed but its commands time out, and the first client goes with it. One driver process must own the socket for the whole run.
- Reading the monitor is slow (~16 bytes per round trip), so a full `-fcm` screen takes ~25 s — too slow to catch Arthur's **timed** intro screens. Sample one row (160 bytes, ~1.5 s) and dump more only on a change.
- `-screenshot` writes the frame xemu is showing **when it finishes shutting down**, not when it is signalled. Under `-sleepless` the game races seconds ahead between SIGTERM and teardown, so a timed screen is gone from the shot; drop `-sleepless` (real-time) when the screenshot must catch a moment, and accept the slower boot.
- The keyboard-buffer poke (`s0277 <petscii>` then `s00c6 01`) answers game prompts fine (Arthur's Y/N, MORE), one key per poke.

## References

- The Z-machine standard, version 1.0/1.1 — essential for v6 window and opcode semantics, and worth checking rather than trusting memory. Not in the repo; it is easy to find online (`z-spec10.pdf`). Keep a copy in the working directory when doing v6 work: `pdftotext z-spec10.pdf -` makes it greppable.
- `documentation/techreport_15.pdf` — Ozmoo's internal design.
- `todo.txt` — known bugs and remaining v6 work.
