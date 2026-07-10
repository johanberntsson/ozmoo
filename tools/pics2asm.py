#!/usr/bin/python3
"""Convert a directory of numbered PNGs into MEGA65 picture files.

    python3 tools/pics2asm.py temp tools/testpics

Writes, into <outdir>:
    pictures.asm    the index Ozmoo assembles in: how many pictures there are
                    and what they are numbered. Nothing else is embedded.
    p<nnn>.bin      one file per picture, which make.rb puts on the d81 and
                    Ozmoo preloads into attic RAM at boot, the way it already
                    preloads the sound effects.

The file is RLE compressed, PackBits style, and decompressed into attic RAM as
it is read. Uncompressed it is:

    0       cells wide
    1       cells high
    2..3    number of unique tiles, little endian
    4..51   palette: 16 red, then 16 green, then 16 blue, nybble swapped as the
            VIC-IV palette registers want. Entry 0 of the 16 is the transparent
            one and is never shown.
    52..    the cell map: two bytes a cell, row major, a little endian index
            into the tiles below
    then    the tiles: 32 bytes each, two pixels a byte, high nybble first

A tile is 8x8 pixels and holds a colour index of 0..15, where 0 is transparent.
draw_picture expands each nybble to a byte as it copies the tiles into the store,
adding 16 + 16 * window, because a window holds at most one picture and so owns
a bank of 16 palette entries above the 16 text colours. Storing four bits a
pixel halves the picture set before it is compressed; Arthur's does not fit on a
d81 otherwise.

FCM cells are 8x8 pixels and a cell's screen code is its data address divided by
64. In the store a pixel of 0 is transparent and 255 comes from colour RAM, so
neither may be a real colour: hence 15 colours a picture, not 16.
"""
import os, sys, glob, struct
from PIL import Image

BASE = 16

def nybswap(v):
    return ((v & 0x0F) << 4) | (v >> 4)

def rle(data):
    """PackBits: n in 0..127 means n+1 literal bytes follow; n in 129..255 means
    the next byte repeats 257-n times; 128 is unused. Decoding needs no
    lookahead, which is what makes the 6502 side short."""
    out, i, n = bytearray(), 0, len(data)
    while i < n:
        run = 1
        while i + run < n and data[i + run] == data[i] and run < 128:
            run += 1
        if run >= 2:
            out.append(257 - run)
            out.append(data[i])
            i += run
        else:
            lit = bytearray()
            while i < n and len(lit) < 128:
                run = 1
                while i + run < n and data[i + run] == data[i] and run < 3:
                    run += 1
                if run >= 3:
                    break
                lit.append(data[i])
                i += 1
            out.append(len(lit) - 1)
            out += lit
    return bytes(out)

def convert(path):
    if not isinstance(path, str):     # (image, name) tuple from a blorb
        im, path = path
    else:
        im = Image.open(path)
    if im.mode != "P":
        sys.exit(f"{path}: not an indexed PNG")
    w, h = im.size
    pal = im.getpalette()
    used = sorted({i for _, i in im.getcolors()})
    if len(used) > 15:
        sys.exit(f"{path}: {len(used)} colours. A bank holds 16 and index 0 is "
                 f"transparent, so a picture may have 15.")
    # index 0 is transparent, so the picture's colours start at 1
    remap = {old: 1 + n for n, old in enumerate(used)}
    colours = [tuple(pal[o*3:o*3+3]) for o in used]

    cw, ch = (w + 7) // 8, (h + 7) // 8
    if cw > 40 or ch > 25:
        sys.exit(f"{path}: {cw}x{ch} cells, larger than the 40x25 screen")
    px = im.load()
    tiles, index_of, cellmap = bytearray(), {}, []
    for cy in range(ch):
        for cx in range(cw):
            cell = bytes(remap[px[cx*8+c, cy*8+r]]
                         if cx*8+c < w and cy*8+r < h else 0
                         for r in range(8) for c in range(8))
            if cell not in index_of:
                index_of[cell] = len(index_of)
                tiles += cell
            cellmap.append(index_of[cell])

    ntiles = len(index_of)
    if ntiles > 1024:
        sys.exit(f"{path}: {ntiles} unique tiles; the store in bank 1 holds 1024")

    palette = bytearray(48)
    for chan in range(3):
        for n in range(16):
            # entry 0 of the bank is the transparent one
            v = colours[n - 1][chan] if 0 < n <= len(colours) else 0
            palette[chan*16 + n] = nybswap(v)

    packed = bytearray()          # two pixels a byte, high nybble first
    for i in range(0, len(tiles), 2):
        packed.append((tiles[i] << 4) | tiles[i+1])

    blob = bytearray()
    blob += bytes((cw, ch))
    blob += struct.pack("<H", ntiles)
    blob += palette
    for i in cellmap:
        blob += struct.pack("<H", i)
    blob += packed
    if len(blob) > 0xffff:
        sys.exit(f"{path}: {len(blob)} bytes uncompressed; more than 64 KB")
    return dict(w=w, h=h, cw=cw, ch=ch, ntiles=ntiles,
                colours=len(used), blob=rle(bytes(blob)), raw=len(blob))

def load_blorb(filepath):
    """Return (images, rects) from a Blorb: images is a list of (num, PIL Image)
    for the PNG resources; rects is a list of (num, w_px, h_px) for the Rect
    placeholders. Rects carry no pixels, only a size a game reads with
    picture_data; Arthur uses them to lay real pictures out."""
    blorb = open(filepath, "rb").read()
    if blorb[:4] != b"FORM" or blorb[8:12] != b"IFRS":
        sys.exit(f"{filepath}: not a Blorb (FORM..IFRS) file")
    chunks, ridx, pos = {}, None, 12
    while pos < len(blorb):
        ctype = blorb[pos:pos+4]
        clen = struct.unpack(">I", blorb[pos+4:pos+8])[0]
        data = blorb[pos+8:pos+8+clen]
        chunks[pos] = (ctype, data)
        if ctype == b"RIdx":
            ridx = data
        pos += 8 + clen + (clen & 1)
    if ridx is None:
        sys.exit(f"{filepath}: no resource index (RIdx) chunk")
    from PIL import Image
    import io
    images, rects = [], []
    for i in range(struct.unpack(">I", ridx[:4])[0]):
        off = 4 + i*12
        if ridx[off:off+4] != b"Pict":
            continue
        num = struct.unpack(">I", ridx[off+4:off+8])[0]
        start = struct.unpack(">I", ridx[off+8:off+12])[0]
        ctype, data = chunks[start]
        if ctype == b"PNG ":
            images.append((num, Image.open(io.BytesIO(data))))
        elif ctype == b"Rect":
            w, h = struct.unpack(">II", data[:8])
            rects.append((num, w, h))
    return images, rects

def main():
    if len(sys.argv) != 3:
        sys.exit(f"usage: {sys.argv[0]} <outdir> <png-dir-or-blorb>")
    outdir, source = sys.argv[1], sys.argv[2]

    rects = []
    if os.path.isdir(source):
        images = [(int(os.path.basename(p)[:-4]), p)
                  for p in sorted(glob.glob(os.path.join(source, "*.png")),
                                  key=lambda s: int(os.path.basename(s)[:-4]))]
        images = [(n, p) for n, p in images]  # (num, path)
        if not images:
            sys.exit(f"no numbered PNGs in {source}")
    else:
        imgs, rects = load_blorb(source)
        # convert() takes either a path or an (image, name) tuple
        images = [(num, (im, f"picture {num}")) for num, im in imgs]

    os.makedirs(outdir, exist_ok=True)
    nums, total, raw_total = [], 0, 0
    for num, src in images:
        if not 0 < num < 256:
            sys.exit(f"picture {num}: numbers must be 1..255")
        p = convert(src)
        if len(p['blob']) > 255 * 256:
            sys.exit(f"picture {num}: {len(p['blob'])} bytes compressed; a picture "
                     f"file may be at most 255 pages")
        open(os.path.join(outdir, f"p{num:03d}.bin"), "wb").write(p['blob'])
        nums.append(num)
        total += len(p['blob'])
        raw_total += p['raw']
        print(f"  picture {num:3d}: {p['w']}x{p['h']} px, {p['cw']}x{p['ch']} cells, "
              f"{p['ntiles']} tiles, {p['colours']} colours, "
              f"{p['raw']} -> {len(p['blob'])} bytes")

    # A Rect is an invisible placeholder: no image, just a size in cells that
    # picture_data reports. Cells are ceil(pixels / 8), as for a real picture.
    rects = sorted((n, (w + 7) // 8, (h + 7) // 8) for n, w, h in rects)

    with open(os.path.join(outdir, "pictures.asm"), "w") as f:
        f.write("; Generated by tools/pics2asm.py - do not edit\n")
        f.write(f"; from {source}\n;\n")
        f.write("; Only the index is assembled in. Each picture is a file on the\n")
        f.write("; disk, preloaded into attic RAM at boot. Rect pictures carry no\n")
        f.write("; image, only a size picture_data reports.\n\n")
        f.write(f"picture_count = {len(nums)}\n\n")
        f.write("pic_number\t!byte " + ",".join(str(n) for n in nums) + "\n")
        f.write("pic_page_lo\t!fill picture_count, 0\n")
        f.write("pic_page_hi\t!fill picture_count, 0\n\n")
        # Always define the arrays, even with no rects, so the interpreter's
        # rect lookup assembles; rect_count gates whether it is ever scanned.
        f.write(f"rect_count = {len(rects)}\n")
        f.write("rect_number\t!byte " + ",".join(str(n) for n, _, _ in rects or [(0, 0, 0)]) + "\n")
        f.write("rect_width\t!byte " + ",".join(str(w) for _, w, _ in rects or [(0, 0, 0)]) + "\n")
        f.write("rect_height\t!byte " + ",".join(str(h) for _, _, h in rects or [(0, 0, 0)]) + "\n")

    print(f"{len(nums)} pictures, {raw_total} bytes packed to {total} on disk "
          f"({100*total/raw_total:.0f}%), {raw_total} bytes in attic RAM"
          + (f"; {len(rects)} rect placeholders" if rects else ""))

main()
