# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Ozmoo is a Z-machine interpreter for the Commodore 64, C128, Plus/4 and MEGA65 (plus an X16 target), written in 6502 assembly (ACME cross-assembler syntax) and driven by a Ruby build script. It runs Infocom/Inform story files.

**This checkout is the `z6` branch**, whose purpose is adding Z-machine **version 6** support. The window model works on every target; graphics work on the MEGA65, where Arthur now draws its pictures. `master` tracks upstream Ozmoo and must keep working — every change here has to be checked against both. This is Johan's personal project: make local commits, but never push without explicit permission.

## Build and run

Required: `acme`, `exomizer` (expected at `exomizer/src/exomizer` on Linux — a local checkout, not in git), VICE (`x64`, `x64sc`, `x128`, `xplus4`, `c1541`), `ruby`, and `inform` + `frotz`/`dfrotz` for the v6 test game. Tool paths are hardcoded at the top of `make.rb` (separate Windows/Linux sections).

```sh
make z6        # compile testz6.inf with inform -v6, build a d64, autostart in VICE
make ecm       # same, with -ecm (per-window background colours)
make frotz     # compile testz6.inf and run it in frotz — the reference behaviour
make z6-mega65 # testz6 on the MEGA65, 80-column text
make z6-fcm    # testz6 on the MEGA65 full colour screen; should match `make z6`
make z6-pics   # same, drawing the test pictures in tools/testpics
make arthur    # build the real v6 game Arthur as a d81 and run it
make arthur-d2 # same, but split over two 1541 drives
make arthur-mega65 # Arthur on the MEGA65, 80-column text
make arthur-fcm    # Arthur on the MEGA65 full colour screen
make arthur-pics   # ...and drawing its own pictures. The whole thing.
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

Before committing anything that touches shared code, rebuild the matrix: `testz6.z6`, `-ecm testz6.z6`, `examples/dejavu.z3`, `test/praxix.z5`, and `-t:c128` / `-t:mega65` / `-t:mega65 -fcm` / `-t:plus4` / `-smooth:1` variants. Building is not enough for the screen layer: run `testz6` on the C64 and on `-t:mega65 -fcm` and compare, since both are 40 columns and should agree line for line.

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
- `-fcm` (`Z6_FCM_MODE`, MEGA65 + v6 only) puts the VIC-IV into Full Colour Mode with 16-bit character codes: 320x200, 40x25 cells. Codes below 256 stay ordinary glyphs (`FCLRLO` clear), codes from 256 up are 64-byte tiles. It should render text identically to the C64. Per-window background colours are **not** implemented yet, which is the remaining half of the FCM work.

### The FCM cell is two bytes, and that keeps biting

Under `-fcm` a screen cell and a colour cell are two bytes each. Ozmoo writes the character into the **even** byte of a screen cell and the colour into the **odd** byte of a colour cell; the other two must be zero and stay zero.

- `zp_screencolumn` still holds a *column*. Only the sites that index the screen double it, which leaves the window edges, margins and every comparison alone.
- `zp_colourline` is biased by **+1**, so one doubled index writes both character and colour. A row starts at a multiple of 80, so the bias never carries.
- Every character store must also zero the cell's high byte — the `clear_cell_high_byte` macro. Miss one and text printed over a picture leaves the cell pointing at a tile.
- **Most text does not go through `s_printchar`.** It goes through `print_line_from_buffer` in `screen-z6.asm`, which writes the screen directly. Four separate bugs have come from forgetting one of these sites; audit them all with `grep -n 'sta (zp_screenline),y'`.

### Pictures (MEGA65, `-fcm -pics`)

`tools/pics2asm.py` reads the blorb (or a PNG directory) and writes one compressed file per picture; `make.rb` puts them on the d81; `pic_load_all` decompresses them into attic RAM at `$08300000` at boot, next to where `sound.asm` preloads the WAVs. Only an index is assembled in: picture numbers, the `Rect` placeholder sizes, and the `pic_adaptive` flags.

- The tile store is `$40000-$5ffff` — 2048 tiles — because Arthur keeps a border, a scene and a status panel on screen at once. Sound moves down to bank 1 and undo out to attic to make room; see the memory map in the techreport. Without `-pics` the store stays in bank 1. A cell's screen code is its tile's address / 64, so `FCM_TILE_CODE_HI + tile index`.
- **Each drawn picture gets its own tile run and its own palette bank**, bumped together and reused together (`pic_win_base`/`pic_win_number`/`pic_win_bank`, keyed by window; only the *same* picture redrawn into a window reuses its run). This is because a window holds several pictures at once — Arthur composites a scene inside a frame — so a per-window bank (the old `16 + 16 * window`) had them fighting over one palette. Banks are `16 * bank`, `bank` running 1..14; bank 15 is skipped because its top colour would be pixel value 255, which FCM takes from colour RAM. When either allocator wraps it can only spoil a picture that is no longer the newest on screen.
- **A picture keeps its PNG palette indices; they are not compacted.** A pixel is its own index (0 transparent, 1..15 straight into the bank), and the bank is loaded in index order. This is what lets an **adaptive** picture line up with the palette it borrows (below). Four bits a pixel on disk and in attic, one byte in the store; 255 comes from colour RAM, so a picture has at most 15 colours. Arthur's pictures put transparency at index 0 and never colour index 0.
- **Compositing works through transparent cells.** `pics2asm.py` writes `$ffff` for a cell that is transparent through and through, and `pic_fill_cells` leaves such a cell untouched — so a frame with a hole (like Arthur's) drawn over a scene shows the scene through the hole. A partly transparent cell is still one opaque tile; its transparent pixels show the screen background, not the picture behind.
- **Adaptive-palette pictures (blorb `APal`, `pic_adaptive`)** — Arthur's frame and side bars — ignore their own (placeholder) palette and are drawn in the palette of the last *direct* picture (`pic_direct_base`), so the UI recolours to match the scene. `pic_read_palette` is skipped for them and their tiles are baked into the current direct bank.
- Drawing is clipped to the screen: `pic_fill_cells` and `pic_erase` stop at the last row/column, so a picture placed partly (or, from a bad coordinate, wholly) off screen cannot scribble past screen RAM into the interpreter.
- `make.rb` upper-cases the names it puts in the disk directory, so the interpreter asks for `P004`. A wrong name fails **silently**: OPEN reports success and one page of the copy buffer lands in attic.

## Watch out for

- **v6 changes opcode shapes.** `pull` is the classic trap: in v1-v5 it names the variable to store into; in v6 it takes an optional user-stack operand and *stores* its result. Getting this wrong desyncs the PC and produces garbage, not a clean error. Check the Z-machine standard (see References) before assuming an opcode behaves as in v5.
- `draw_picture`, `erase_picture` and `picture_data` are all implemented under `-fcm -pics`, including `Rect` placeholders, adaptive palettes and transparent-cell compositing (see the Pictures section); elsewhere `draw_picture` writes a `pic:N` note and `picture_data` reports no picture. Arthur's first room — a scene composited inside a recolouring frame — now renders like the reference interpreter. `z_init` still clears the "pictures available" bit in `header_flags_2` even under `-fcm -pics`, which disagrees with `picture_data`; Arthur tolerates it (it draws pictures regardless), but the bit ought to be set when `Z6_PICTURES`. `print_form` and `scroll_window` turned out to be text opcodes and are done. See `todo.txt`.
- **The z-machine writes "the current window" as `-3`** (z-spec 8.8.3), and Arthur does so 27 times. Every opcode taking a window number must go through `window_from_operand`; taking the operand's low byte raw indexes the property arrays at `$fd`. This produced coordinates like y=244 and hung `.pic_draw`'s row loop, whose counter is one byte.
- **v6 is a "large" version, like v7/v8, not like v4/v5.** Story files run to 512 KB, the header file length is divided by 8, and block addresses need two high bits. `make.rb` has always known this (`$zcode_version > 5`); the assembly used to express it as `Z7PLUS`, which excludes v6. Use `Z6PLUS` for anything size-related, and be suspicious of any new `Z4PLUS`/`Z7PLUS` split. See `todo.txt` for the three bugs this caused.
- No v6 interpreter ever ran on a C64, so v6 code paths have never been exercised against a real game. Expect more latent assumptions — minimum screen size, stack depth, story size — that no other version happens to violate.
- **An error only the MEGA65 reports is usually a real bug everyone else lives with.** `CHECK_ERRORS` is compiled into MEGA65 builds and out of the others. Arthur's `FATAL ERROR: 17` turned out to be a modulo by zero the C64 executed too, caused by `get_wind_prop` returning 0 for the font size. Reaching for `-re:0` would have hidden a genuine defect.
- **The C64, Plus/4 and MEGA65 work. The C128 and X16 are still deliberately untouched.** The z6 window model is only wired into the scroll path the first three share; the C128 80-column (VDC) and X16 (VERA) scroll routines still scroll the whole screen, and ECM is C64-only. Those two remain known and accepted, not oversights — don't "fix" them yet.
- The C64 and Plus/4 will never draw pictures. The `pic:N` notes have to stay for them.
- **Open bug:** under `-fcm`, Arthur drops or changes the odd character in body text, differently on each run. It happens with and without `-pics`, never with `testz6`, and the 80-column build is clean. Something timed — the cursor, or the MORE prompt saving and restoring the character under it. See `todo.txt`.

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
- Like VICE, a headless run halts at the first **MORE prompt**. There are no tracepoints, but `-uartmon <socket>` gives a monitor that can do it: poll screen RAM (`$0800`; 80x25 one byte a cell, or 40x25 **two** bytes a cell under `-fcm`) for the MORE character `$aa` (reverse `*`), and when it appears poke Return into the kernal keyboard buffer with `s0277 0d` then `s00c6 01`. That reaches `read`, where the game waits harmlessly, so stop there and dump rather than answering the read — the quit path shows a final MORE prompt and then resets, wiping the screen.
- Monitor commands over the socket: `m<addr>` reads 16 bytes, `M<addr>` reads a block, `s<addr> <bytes>` writes. Addresses are bare hex in the full 28-bit space, so colour RAM is `Mff80000`, not `Md800`.
- `-dumpscreen` only fires on exit, so it cannot capture an intermediate state; read `$0800` over the monitor instead. Screen codes there, not ASCII. Under `-fcm` take every second byte for the characters; a non-zero odd byte means the cell is a picture tile, not text.
- **`-dumpscreen` decodes screen codes in software, so it cannot see a bug in the character-rendering path.** It reports the code in the cell, never the glyph the VIC-IV fetched for it: a wrong `CHARPTR` is invisible in the dump and obvious in `-screenshot`. `FCM_CHARSET` pointed at the wrong 2 KB half of the C64 font for months because of this. `testz6` hid it too — its text is all lowercase, which under the uppercase/graphics charset renders as plausible-looking capitals. Anything touching the charset needs a screenshot, of text with a capital letter in it.
- `$e0` in screen RAM is the **cursor** (`CURSORCHAR` in `ozmoo.asm`), not a corrupt cell. It overwrites the character under it, so a dump taken while the cursor is up shows `$e0` where the text character belongs.
- Monitor addresses are the **linear** 28-bit map, so `$d000` there is RAM, not I/O. Reading `md054` returns zeros; the VIC-IV registers are at `$ffd3xxx` (`mffd3050`). Colour RAM is `$ff80000`.
- To try something without dragging Ozmoo along, build a bare prg and load it directly: `xemu-xmega65 -headless ... -prg foo.prg -prgmode 64 -screenshot shot.png`. Combined with `-screenshot`, a picture can be compared against its source PNG pixel by pixel. xemu renders the red channel one LSB low (`$bb` shows as 186), so compare within a tolerance of 1, not exactly.
- `-dumpmem` writes memory, and `-uartmon <socket>` opens a monitor, if the screen isn't enough.
- Non-printable screen codes come out as `{$xx}` in the dump.

## References

- The Z-machine standard, version 1.0/1.1 — essential for v6 window and opcode semantics, and worth checking rather than trusting memory. Not in the repo; it is easy to find online (`z-spec10.pdf`). Keep a copy in the working directory when doing v6 work: `pdftotext z-spec10.pdf -` makes it greppable.
- `documentation/techreport_15.pdf` — Ozmoo's internal design.
- `todo.txt` — known bugs and remaining v6 work.
