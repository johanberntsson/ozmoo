# tools

Support scripts for the v6 graphics work. Nothing here is built by `make.rb`.

## png2fcm.py

Converts one indexed PNG into MEGA65 Full Colour Mode tiles.

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
