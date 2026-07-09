#!/usr/bin/python3
"""Convert one PNG into MEGA65 Full Colour Mode tiles, for the z6 prototype.

FCM cells are 8x8 pixels, one byte per pixel, 64 bytes per cell, and the 16-bit
screen code is the cell's pixel data address divided by 64.

Pixel value 0 is transparent in FCM (the background shows through) and 255 is
taken from colour RAM, so neither may be a real picture colour. The picture's
own palette therefore goes into entries BASE..BASE+15 and pixel indices are
offset by BASE. Padding added to reach a cell boundary stays 0, so it comes out
transparent.

Identical cells are emitted once and referenced by a cell map, which is what
the screen RAM of a picture looks like. The map holds tile indices; whoever
draws the picture adds the base screen code (tile store address / 64).

Emits, for <name>:
    <name>-tiles.bin   unique cells, 64 bytes each
    <name>-map.bin     one little-endian 16-bit tile index per cell, row-major
    <name>-pal.bin     16 red, then 16 green, then 16 blue, nybble-swapped
    <name>.inc         ACME equates
"""
import sys, os
from PIL import Image

BASE = 16          # first palette entry the picture may use

def nybswap(v):
    return ((v & 0x0F) << 4) | (v >> 4)

def main():
    if len(sys.argv) != 3:
        sys.exit(f"usage: {sys.argv[0]} <in.png> <outdir/name>")
    src, stem = sys.argv[1], sys.argv[2]

    im = Image.open(src)
    if im.mode != "P":
        sys.exit(f"{src}: not an indexed PNG")
    w, h = im.size
    pal = im.getpalette()
    used = sorted({i for _, i in im.getcolors()})
    if len(used) > 16:
        sys.exit(f"{src}: {len(used)} colours, more than the 16 a bank holds")

    remap = {old: BASE + n for n, old in enumerate(used)}
    colours = [tuple(pal[old*3:old*3+3]) for old in used]

    cells_w, cells_h = (w + 7) // 8, (h + 7) // 8
    px = im.load()

    tiles, index_of, cellmap = bytearray(), {}, bytearray()
    for cy in range(cells_h):
        for cx in range(cells_w):
            cell = bytes(
                remap[px[cx*8 + col, cy*8 + row]]
                if cx*8 + col < w and cy*8 + row < h else 0
                for row in range(8) for col in range(8))
            if cell not in index_of:
                index_of[cell] = len(index_of)
                tiles += cell
            i = index_of[cell]
            cellmap += bytes((i & 0xFF, i >> 8))

    pal_bin = bytearray(48)
    for chan in range(3):
        for n in range(16):
            v = colours[n][chan] if n < len(colours) else 0
            pal_bin[chan*16 + n] = nybswap(v)

    os.makedirs(os.path.dirname(stem) or ".", exist_ok=True)
    open(stem + "-tiles.bin", "wb").write(tiles)
    open(stem + "-map.bin", "wb").write(cellmap)
    open(stem + "-pal.bin", "wb").write(pal_bin)
    with open(stem + ".inc", "w") as f:
        f.write(f"; generated from {os.path.basename(src)} by png2fcm.py\n")
        f.write(f"PIC_WIDTH    = {w}\n")
        f.write(f"PIC_HEIGHT   = {h}\n")
        f.write(f"PIC_CELLS_W  = {cells_w}\n")
        f.write(f"PIC_CELLS_H  = {cells_h}\n")
        f.write(f"PIC_TILES    = {len(index_of)}\n")
        f.write(f"PIC_PAL_BASE = {BASE}\n")

    n = cells_w * cells_h
    print(f"{os.path.basename(src)}: {w}x{h} -> {cells_w}x{cells_h} cells")
    print(f"  {len(used)} colours -> palette entries {BASE}..{BASE+len(used)-1}")
    print(f"  {n} cells, {len(index_of)} unique tiles = {len(tiles)} bytes "
          f"({len(tiles)/1024:.1f} KB), map {len(cellmap)} bytes")

main()
