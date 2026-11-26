# tools

Support scripts for the v6 graphics work.

Only `pics2asm.py` is run by the build: `make.rb -pics` invokes it. The rest
are development and design tools that are not part of a normal build. The
exception is `make_blorb.py`, which is meant to be run by hand, to build a
Blorb of pictures and sounds for a new v6 game. make_blorb.py is documented 
in the Ozmoo manual.

## test-neo6502-smoke.sh

Rebuilds Minizork for Neo6502, boots the packaged `dist/minizork/MINIZORK.NEO`
with the emulator's `path:` pointing at that same flat release directory, types
`open mailbox` and `read leaflet`, captures the console, and asserts the
rendered text. In particular it guards against the paged-read corruption that
used to turn the leaflet's continuation into `BH!CJ...`, and checks the status
line and bottom prompt. The `puzzles, and descriptions` assertion also catches
resident VMEM reaching the C64-compatible I/O window: a story block mapped over
`$d020`/`$d021` was silently rewritten by `init_screen_colours` and rendered as
`puzzlesthe cof escriptions`. It also asserts that only the top status line uses
inverse video colours on Neo6502. It uses `decode_neo_console.py` to match
screenshot pixels against the firmware's `font_5x7.h`, so no OCR is involved.

Clone the upstream
[neo6502-firmware](https://github.com/paulscottrobson/neo6502-firmware) repo and
build its emulator, then point `NEO_FIRMWARE_ROOT` at that checkout:

```sh
git clone https://github.com/paulscottrobson/neo6502-firmware.git ../neo6502-firmware
make -C ../neo6502-firmware/emulator
export NEO_FIRMWARE_ROOT=/path/to/neo6502-firmware
tools/test-neo6502-smoke.sh
```

The scripts default to a sibling `../neo6502-firmware` checkout and expect
`emulator/neo` and `firmware/common/include/interface/font_5x7.h` under it.

The script writes its screenshot, decoded text grid, inverse-video report, and
emulator log under `/tmp/opencode/neo-smoke`. It needs `ruby`, `python3` with
Pillow, `xdotool`,
ImageMagick `import`, and an SDL display. Defaults can be overridden with
`NEO_FIRMWARE_ROOT`, `NEO_SMOKE_WORKDIR`,
`NEO_SMOKE_STORY`, `OZMOO_HOME`, `NEO_SMOKE_SKIP_BUILD`, and the timing and
screen-geometry variables named at the top of the script.

The emulator tests are also available through `tests/Makefile`:

```sh
make -C tests neo-smoke
make -C tests neo-save-restore
```

They are deliberately not part of `make -C tests all`, because they need a
Neo firmware checkout and X11 tools. The save/restore test uses an isolated
storage directory under `/tmp/opencode/neo-save-restore`; it copies the
generated `MINIZORK.STORY` and `MINIZORK.CFG` sidecars out of the flat release
package there and verifies the native `MINIZORK.S00` save file, including an
emulator restart. On `RESTORE`, the Neo path lists every slot and its saved
comment before asking which slot to restore, so occupied slots are visible at
the prompt. The screenshot script types the save comment in lowercase; the
assertion checks that the Neo prompt folds it to uppercase in the save header.

## decode_neo_console.py

Matches screenshot pixels against the firmware's `font_5x7.h` to recover the
console text used by the Neo smoke and save/restore assertions. Rows whose
samples are mostly foreground-coloured are decoded as inverse video, which lets
the Neo status line be checked without losing the surrounding text. With
`--report-inverted`, it also writes those row numbers to stderr as
`INVERTED_ROWS=...`. It is a test helper, not part of the interpreter or the
game.

The expected pixel colours default to the normal Neo console palette, white on
darkblue. To check a
build made with `-neo-fg`/`-neo-bg`, pass `--fg-rgb r,g,b` and `--bg-rgb r,g,b`
(or set `NEO_SMOKE_FG_RGB`/`NEO_SMOKE_BG_RGB`). `test-neo6502-smoke.sh` forwards
`-neo-fg`/`-neo-bg` from `NEO_SMOKE_FG`/`NEO_SMOKE_BG` and the RGB overrides from
those two environment variables. `test-neo6502-save-restore.sh` honours the same
RGB overrides.

One known artefact: Praxix's banner is decoded as `Type "help" ... "guit" to
exit`, although the interpreter prints `quit`. The decoder compares the first
seven rows of each glyph (the first seven bytes of each eight-byte font entry);
`g` and `q` differ only in the eighth row, so they are indistinguishable to it.
Treat decoded `guit` in Praxix captures as `quit` — it is a decoder limitation,
not a story-text or rendering bug.

## make_neo_executable.py

Wraps a Neo6502 Ozmoo build into a single `.neo` executable. It takes the
assembled interpreter PRG (`temp/ozmoo`) and the resident story image
(`temp/compmem.tmp`), checks the PRG load address, and writes the `.neo` header
plus load blocks. The header execute address defaults to `$1000`, so NeoBASIC's
`LOAD "MINIZORK.NEO"` starts the game without a separate `SYS`. `make.rb` passes
`--main-addr`, `--story-addr` (from the `story_start` label) and `--exec-addr`
explicitly, so the resident story always loads where this build expects it.

```sh
python3 tools/make_neo_executable.py temp/ozmoo temp/compmem.tmp MINIZORK.NEO \
    --story-addr 0x4600
```

The executable still needs the generated `<GAME>.STORY` and `<GAME>.CFG`
runtime sidecars in the Neo storage root for paged reads. `make.rb` names them
after the story file's 8.3 basename, so different games do not overwrite each
other's sidecars.

## Neo6502 release layout

A Neo6502 build (`ruby make.rb -t:neo6502 <game>.z3`) now writes a flat release
package instead of a `.d64`, a `storage/` directory, or an `autostart.bas`:

```
dist/<game>/<GAME>.NEO      interpreter + resident story
dist/<game>/<GAME>.STORY    byte-for-byte story file for paged VMEM reads
dist/<game>/<GAME>.CFG      VMEM map and save configuration
dist/<game>.zip             archive of the directory above
```

`<game>` is the story file's base name (`zork1`, `minizork`, ...); `<GAME>` is
its FAT-style 8.3 form (`ZORK1`, `MINIZORK`, ...). Copy or unzip the directory
onto the Neo's SD card and load `<GAME>.NEO` from there. Saves are created
alongside the sidecars as `<GAME>.S00`. In the emulator, point its storage path
at the same directory (for example `path:dist/minizork`) rather than expecting
a nested `storage/` folder. `-s` starts the packaged `.NEO` that way.

## pics2asm.py

Converts a game's pictures - a Blorb, or a directory of numbered PNGs - into
the files a `-pics` build needs, plus the `pictures.asm` index Ozmoo assembles
in. `make.rb` runs it; it is not normally run by hand.

```sh
ruby make.rb -t:mega65 -fcm -pics tools/testpics testz6.z6
ruby make.rb -t:x16 -pics z6games/arthur-r74-s890714.blb arthur.z6
```

What it writes depends on the target, because the two picture engines load
their pictures in completely different ways:

* **MEGA65** (`--fcm-width 80`, the default; `40` for the legacy 320x200
  screen). Each picture disk's pictures are page-padded, concatenated and
  crunched into one exomizer archive, `pics<n>.bin`. Every shipped game fits a
  single archive, and `make.rb` then puts it on the **boot disk** beside the
  story, so a game is one d81 with no picture disk and no swap; a set that
  overflows falls back to one `_pics_N.d81` per archive. `pic_load_all`
  decrunches the archive into attic RAM at boot. Needs exomizer
  (`--exomizer PATH`, defaulting to `exomizer/src/exomizer`).
* **X16** (`--x16`). One uncompressed `p<nnn>.bin` per picture, which
  `build_zip` copies into the game directory as `[P###]`; there is no preload
  and no picture disk, each picture being LOADed from SD the first time it is
  drawn. `pictures.asm` then also carries `pic_width`/`pic_height`, because
  `picture_data` must answer for a picture that is not loaded.

`picdisks.txt` names the files to put on each picture disk (for the X16, all
"disk 1" - the manifest of files to copy into the game directory).

Other options: `--pixel-units` adds the native-art-pixel size tables
`Z6_PIXEL_UNITS` builds report from `picture_data`; `--stats` measures and
prints but writes nothing; `--all-pictures` keeps the pictures normally
dropped (Snavig BPal palette replacements, and anything numbered above 999).
Blorb `Rect` placeholders and the `APal` adaptive list are read and passed
through to the index.

The file format is documented at the top of the script (note its own header is
written from the MEGA65's point of view and predates the archives);
`png2fcm.py` remains the reference for the tile format itself.

## make_blorb.py

Builds a v6 Blorb of pictures and sounds from a folder, described by a YAML
`contents.yaml` - the front end that feeds `-pics <blorb>`, and the way to get
a new game's resources into a form both Ozmoo and sfrotz can read.

```sh
python3 tools/make_blorb.py mygame            # reads mygame/contents.yaml
python3 tools/make_blorb.py mygame/contents.yaml
```

The YAML gives top-level `blorb` / `outdir` / `srcdir` and optional
`max_width` / `max_height`, then a `pictures:` list (`id`, `file`, optional
`name` / `location` / per-picture `width` / `height`) and an optional
`sounds:` list (`id` 3..255, since the Z-machine's sounds 1 and 2 are the
interpreter's bleeps). Each picture is scaled to fit its box preserving aspect
ratio, snapped down to a multiple of 8 pixels, and quantised to at most 15
colours at indices 1..15 - index 0 is Ozmoo's transparent one. A `.wav` sound
is converted to AIFF on the way in, because **Blorb has no WAV chunk type**;
an `.aiff` source is embedded verbatim. The sounds are for the *other*
interpreter: Ozmoo's own build reads the wavs off the source folder with
`-asw`, so one folder feeds both. The full format is documented at the top of
the script.

## gen_testpics.py

Writes the small pictures in `tools/testpics` that testz6 draws. They are ours,
so they live in the repository; the numbers match the `draw_picture` calls in
`testz6.inf`.

```sh
python3 tools/gen_testpics.py tools/testpics
```

## tilebudget.py

Costs the X16 tile store for placing pictures off the tile grid - baking
boundary tiles against generating the covered cells straight from the staged
picture - over a whole blorb. A design tool, not part of the build: it is what
decided phase 0b of the pixel-units refactor in favour of generating.

```sh
python3 tools/tilebudget.py z6games/arthur-r74-s890714.blb
```

## png2fcm.py

Converts one indexed PNG into MEGA65 Full Colour Mode tiles. Superseded by
`pics2asm.py` for building a game, but kept as the readable reference for the
tile format, and it is what feeds `fcm-prototype.asm`.

```sh
python3 tools/png2fcm.py z6games/arthur-graphics/1.png /tmp/pic
```

Writes `pic-tiles.bin` (unique 8x8 cells, 64 bytes each), `pic-map.bin` (one
little-endian 16-bit tile index per cell, row-major), `pic-pal.bin` (16 red,
then 16 green, then 16 blue, nybble-swapped as the VIC-IV palette registers
want) and `pic.inc` (ACME equates).

The picture's colours land in palette entries 16..31, and pixel indices are
offset to match, because in FCM pixel value 0 is transparent and 255 comes from
colour RAM. Entries 0..15 are left to the text colours. Padding to the cell
boundary stays 0, so it is transparent.

Requires Pillow. Rejects a PNG with more than 16 colours; none of Arthur's have
more than 14.

## fcm-prototype.asm

The throwaway prototype from step 2 of the MEGA65 plan in `todo.txt`. It sets
up a 320x200 FCM screen with 16-bit character codes, DMAs a picture's tiles
into bank 1 at `$10000`, and draws it with a line of ordinary text beneath.

```sh
python3 tools/png2fcm.py z6games/arthur-graphics/40.png /tmp/p/pic
cp tools/fcm-prototype.asm /tmp/p/ && cd /tmp/p
acme -f cbm -o fcmtest.prg fcm-prototype.asm
xemu-xmega65 -headless -sleepless -besure -skipunhandledmem \
    -prg fcmtest.prg -prgmode 64 -screenshot shot.png
```

It is kept because it is the only place the working VIC-IV register setup is
written down. It is not part of Ozmoo and nothing sources it.
