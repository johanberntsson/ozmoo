# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Ozmoo is a Z-machine interpreter for the Commodore 64, C128, Plus/4 and MEGA65 (plus an X16 target), written in 6502 assembly (ACME cross-assembler syntax) and driven by a Ruby build script. It runs Infocom/Inform story files.

**This checkout is the `z6` branch**, whose purpose is adding Z-machine **version 6** support: the window model works, graphics do not. `master` tracks upstream Ozmoo and must keep working — every change here has to be checked against both. This is Johan's personal project: make local commits, but never push without explicit permission.

## Build and run

Required: `acme`, `exomizer` (expected at `exomizer/src/exomizer` on Linux — a local checkout, not in git), VICE (`x64`, `x64sc`, `x128`, `xplus4`, `c1541`), `ruby`, and `inform` + `frotz`/`dfrotz` for the v6 test game. Tool paths are hardcoded at the top of `make.rb` (separate Windows/Linux sections).

```sh
make z6        # compile testz6.inf with inform -v6, build a d64, autostart in VICE
make ecm       # same, with -ecm (per-window background colours)
make frotz     # compile testz6.inf and run it in frotz — the reference behaviour
make arthur    # build the real v6 game Arthur for two drives and run it (currently crashes)
make c64       # build examples/dejavu.z3 (a z3 game) — the non-z6 regression check
make mega65    # same, for MEGA65
make clean

ruby make.rb [options] <storyfile>   # run with no args for the full option list
```

`dfrotz -h 25 -w 40 testz6.z6` gives reference output with the same screen size as a C64, which makes line-for-line comparison possible.

There is no automated test suite. `test/` holds standard conformance games (czech, praxix, strictz, oztest, etude) that are built and played manually. `testz6.inf` is the v6 test game — grow it opcode by opcode and compare against frotz rather than debugging a commercial game blind.

Before committing anything that touches shared code, rebuild the matrix: `testz6.z6`, `-ecm testz6.z6`, `examples/dejavu.z3`, `test/praxix.z5`, and `-t:c128` / `-t:mega65` / `-t:plus4` / `-smooth:1` variants.

## Conditional assembly is the architecture

Everything is one assembly program (`asm/ozmoo.asm` `!source`s all other files) specialized at build time by ACME `-D` flags that `make.rb` derives from the story file and command line:

- **Z-version**: `make.rb` reads the story file's version byte and passes `-DZ6=1` etc. `ozmoo.asm` derives cumulative flags: `Z3PLUS`, `Z4PLUS`, `Z5PLUS`, `Z6PLUS`, `Z7PLUS`, plus `Z6_Z7` (those two versions use packed-address offsets).
- **Target**: `-DTARGET_C128=1`, `-DTARGET_MEGA65=1`, etc. (no define for C64, the default).
- **Feature/debug flags**: edit `$GENERALFLAGS` / `$DEBUGFLAGS` at the top of `make.rb` to enable e.g. `DEBUG`, `TRACE`, `VICE_TRACE`, `CHECK_ERRORS`. `TRACE_SCREEN` (in `screen-z6.asm`) traces the v6 opcodes.

So "does this code run?" always depends on which `!ifdef` blocks are active for the given version/target.

## Source layout (asm/)

- `ozmoo.asm` — entry point, init, main loop; sources everything else.
- `zmachine.asm` — opcode dispatch and most `z_ins_*` routines.
- `stack.asm` — Z-stack, `stack_call_routine`, and the opcodes that touch the stack.
- `vmem.asm`, `memory.asm` — virtual memory: the story beyond dynamic memory is demand-paged from disk in 512-byte blocks. `set_z_pc` / `get_page_at_z_pc` page in the code being executed.
- `screenkernal.asm` / `screen.asm` — the non-z6 screen layer. `screenkernal.asm` replaces the C64 kernal screen routines (`s_printchar` instead of `$ffd2`); `screen.asm` implements the Z-machine screen model on top.
- `screenkernal-z6.asm` / `screen-z6.asm` — the **z6-only** equivalents, sourced instead of the above under `!ifdef Z6`. Keep them as close to their non-z6 counterparts as possible; when master changes the originals, re-fork rather than hand-patch.
- `screenmodel-z6.asm` — dead code, not sourced anywhere. Superseded by `screen-z6.asm`.
- `streams.asm`, `text.asm`, `dictionary.asm` — I/O streams (must precede text.asm), zchar decoding, tokenizing, `read_text`.
- `disk.asm`, `reu.asm`, `constants*.asm` — disk access, REU, per-target memory maps.

## The z6 screen model

Eight windows, each with the property array the spec requires (`window_y`, `window_x`, `window_y_size`, …, `window_attributes`, `window_linecount`), laid out contiguously so `get_wind_prop`/`put_wind_prop` can index them as `window_y + 8 * property + window`.

- Coordinates are stored **0-based internally**; the opcodes convert to/from the z-machine's 1-based coordinates.
- Printing, wrapping, scrolling, the cursor, the MORE prompt and erasing are all **per window**: text wraps at the window's right edge, scrolls its own rectangle, and the MORE prompt appears at the current window's bottom-right cell. Each window keeps its own cursor and line count.
- Ozmoo always shows a MORE prompt when a game quits, so the last message can be read. A lone `*` in a corner after quit is that, not a bug.
- `-ecm` (`Z6_ECM_MODE`, C64 + v6 only) turns on VIC-II Extended Color Mode: the top two bits of each screen code pick one of four background registers (`$d021`-`$d024`), giving each window its own background. The cost is a 64-character charset, so screen codes are masked to 6 bits (uppercase renders as lowercase) and reverse video is unavailable.

## Watch out for

- **v6 changes opcode shapes.** `pull` is the classic trap: in v1-v5 it names the variable to store into; in v6 it takes an optional user-stack operand and *stores* its result. Getting this wrong desyncs the PC and produces garbage, not a clean error. Check the spec (`z-spec10.pdf`) before assuming an opcode behaves as in v5.
- Several v6 opcodes are still dummies (graphics, `scroll_window`); see `todo.txt` for what is and isn't safe about them.
- `make arthur` crashes before executing a single instruction — its main routine unpacks outside resident memory, so the first `set_z_pc` never returns from `get_page_at_z_pc`. See `todo.txt`.

## Debugging under VICE (headless)

Symbol addresses come from `temp/acme_labels.txt` after a build.

```sh
x64sc -default -warp +sound -limitcycles 60000000 -exitscreenshot shot.png c64_testz6.d64
```

- Drive commands from a `-moncommands` file. Use **tracepoints** (`trace exec $addr`), not breakpoints — breakpoints halt the emulator and wait for stdin.
- Attach an action with `command <n> "<cmd>"`. Several tracepoints may share an address, one command each.
- To type text: `command 1 "keybuf hello"`. `keybuf` does **not** interpret `\n`, so append Return by poking the kernal keyboard buffer: `command 2 "> 027c 0d"` and `command 3 "> 00c6 06"` (buffer, then length).
- `-exitscreenshot` can catch a mid-frame redraw and show a character that isn't really there. To see the truth, dump screen RAM: `command N "m 0400 07e7"` and decode the log (screen codes; in ECM the top two bits are the background register).
- VICE randomizes the autostart delay, so cycle counts are **not** reproducible between runs.

## References

- `z-spec10.pdf` — the Z-machine standard. Essential for v6 window and opcode semantics.
- `documentation/techreport_15.pdf` — Ozmoo's internal design.
- `v6-discussion.txt` — design notes behind the ECM approach.
- `todo.txt` — known bugs and remaining v6 work.
