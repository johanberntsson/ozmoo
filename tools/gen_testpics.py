#!/usr/bin/python3
"""Generate the small test pictures testz6 draws.

These are ours, unlike Arthur's, so they can live in the repository and be
compared against. Numbers match the draw_picture calls in testz6.inf.

    python3 tools/gen_testpics.py tools/testpics
"""
import os, sys
from PIL import Image

def put(im, x, y, c):
    if 0 <= x < im.size[0] and 0 <= y < im.size[1]:
        im.putpixel((x, y), c)

def make(num, w, h, draw):
    im = Image.new("P", (w, h), 0)
    # index 0 is left unused by the converter's transparency rule anyway, but
    # keep a real palette so the PNG is indexed.
    pal = [0,0,0, 255,255,255, 255,0,0, 0,255,0, 0,0,255, 255,255,0,
           255,0,255, 0,255,255, 128,128,128]
    im.putpalette(pal + [0] * (768 - len(pal)))
    draw(im)
    return im

def picture_4(im):
    """16x16: a bordered box with diagonals, four colours."""
    w, h = im.size
    for x in range(w):
        for y in range(h):
            if x in (0, w-1) or y in (0, h-1): c = 1     # white border
            elif x == y:                        c = 2     # red diagonal
            elif x + y == w - 1:                c = 3     # green anti-diagonal
            else:                               c = 4     # blue fill
            put(im, x, y, c)

def picture_9(im):
    """24x8: three solid colour blocks, so a wrong tile order is obvious."""
    w, h = im.size
    for x in range(w):
        for y in range(h):
            put(im, x, y, 5 + x // 8)   # yellow, magenta, cyan

def picture_12(im):
    """8x8: a single checkerboard cell."""
    for x in range(8):
        for y in range(8):
            put(im, x, y, 1 if (x + y) % 2 == 0 else 2)

PICS = {4: (16, 16, picture_4), 9: (24, 8, picture_9), 12: (8, 8, picture_12)}

def main():
    outdir = sys.argv[1] if len(sys.argv) > 1 else "tools/testpics"
    os.makedirs(outdir, exist_ok=True)
    for num, (w, h, draw) in PICS.items():
        im = make(num, w, h, draw)
        path = os.path.join(outdir, f"{num}.png")
        im.save(path)
        print(f"{path}: {w}x{h}, {len(im.getcolors())} colours")

main()
