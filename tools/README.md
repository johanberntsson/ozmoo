# tools

Support scripts for the v6 graphics work.

Only `pics2asm.py` is run by the build: `make.rb -pics` invokes it. The rest
are development and design tools that are not part of a normal build. The
exception is `make_blorb.py`, which is meant to be run by hand, to build a
Blorb of pictures and sounds for a new v6 game. make_blorb.py is documented 
in the Ozmoo manual.

## pics2asm.py

Converts a game's pictures — a Blorb, or a directory of numbered PNGs — into
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
"disk 1" — the manifest of files to copy into the game directory).

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
`contents.yaml` — the front end that feeds `-pics <blorb>`, and the way to get
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
colours at indices 1..15 — index 0 is Ozmoo's transparent one. A `.wav` sound
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

Costs the X16 tile store for placing pictures off the tile grid — baking
boundary tiles against generating the covered cells straight from the staged
picture — over a whole blorb. A design tool, not part of the build: it is what
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
