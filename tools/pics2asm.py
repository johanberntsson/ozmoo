#!/usr/bin/python3
"""Convert a directory of numbered PNGs into MEGA65 picture files.

    python3 tools/pics2asm.py temp tools/testpics

Writes, into <outdir>:
    pictures.asm    the index Ozmoo assembles in: how many pictures there are,
                    what they are numbered, and which picture disk each is on.
    p<nnn>.bin      one file per picture, which make.rb puts on a picture disk
                    and Ozmoo preloads into attic RAM at boot, the way it
                    already preloads the sound effects.
    picdisks.txt    which picture disk (1-based) each p<nnn>.bin belongs on, so
                    make.rb can build one d81 per disk. When more pictures are
                    given than fit one d81, they are spread over several.

With --fcm-width 80 (the default) the pictures are for the 80-column H640 full
colour screen: each logical 8x8-pixel cell of the source becomes two tiles
(its left half, then its right) and two cell-map entries, and the interpreter
pixel-doubles each tile as it bakes it into the store, so a picture keeps its
320-wide visual size next to 8-pixel-wide text. Such a tile is 16 bytes on
disk: 4 source pixels a row, two to a byte -- the doubling costs nothing on
disk or in attic RAM. --fcm-width 40 emits the old one-tile-per-cell format
(32-byte tiles) for the 40-column screen. --stats measures and prints but
writes nothing.

--x16 emits the Commander X16 format instead: the same 80-column geometry, but
one cell-map entry and one 32-byte tile per logical cell (a VERA tile is 16x8
pixels, a whole doubled cell), a 32-byte palette in VERA order (GGGGBBBB,
0000RRRR per entry, ready for $1fa00), and no compression -- the files sit
loose in the game directory and are LOADed from SD on demand, so there are no
picture disks and no decompressor. pictures.asm then carries pic_width and
pic_height (in text cells) instead of the disk and attic-page tables, because
picture_data must answer for pictures that are not loaded.

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
    then    the tiles: two pixels a byte, high nybble first; 32 bytes each on
            the 40-column screen (8x8 pixels), 16 bytes each on the 80-column
            screen (4x8 source pixels, doubled to 8x8 when baked)

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
import os, sys, glob, struct, subprocess, tempfile
from PIL import Image

BASE = 16
PAGE = 256

# A picture disk's pictures are concatenated (each page-padded so every picture
# starts on an attic page boundary) and crunched into one archive with exomizer.
# The interpreter's decruncher in pictures-mega65.asm is a port of exomizer's
# reference decoder (exodec.c), which reads the stream FORWARD, so the archive
# is crunched forward too (no -b). raw format, exomizer-2 layout (-P0, the
# table format the port builds), compatibility mode (-c, no literal sequences).
# -m is the maximum sequence offset (the furthest back a match reaches); 4096
# costs almost nothing here because page-padded, tile-deduplicated pictures
# match locally, and it bounds the back-reference distance the decruncher walks.
STREAM_WINDOW = 4096
STREAM_FLAGS  = ["raw", "-q", "-C", "-P0", "-c", "-m", str(STREAM_WINDOW)]

def nybswap(v):
    return ((v & 0x0F) << 4) | (v >> 4)

def crunch(exomizer, data):
    """Exomizer-crunch a blob with the stream-decruncher flags; return the bytes."""
    with tempfile.TemporaryDirectory() as d:
        i, o = os.path.join(d, "in"), os.path.join(d, "out")
        open(i, "wb").write(data)
        r = subprocess.run([exomizer] + STREAM_FLAGS + [i, "-o", o],
                           stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
        if r.returncode != 0:
            sys.exit(f"exomizer failed: {r.stderr.decode()[:400]}")
        return open(o, "rb").read()

def build_archive(exomizer, blobs):
    """Concatenate the raw blobs, each padded up to a page so every picture lands
    on an attic page boundary, and crunch the lot into one archive. Returns the
    crunched bytes; the per-picture page counts are ceil(len/256), assembled in
    as pic_pages so the interpreter can place each picture without the padding
    ever needing to be measured at runtime."""
    stream = bytearray()
    for b in blobs:
        stream += b
        stream += b"\x00" * (-len(b) % PAGE)
    return crunch(exomizer, bytes(stream))

def convert(path, double=False, x16=False):
    if not isinstance(path, str):     # (image, name) tuple from a blorb
        im, path = path
    else:
        im = Image.open(path)
    if im.mode != "P":
        sys.exit(f"{path}: not an indexed PNG")
    w, h = im.size
    pal = im.getpalette()
    pal = pal + [0] * (48 - len(pal))    # a short palette still fills 16 entries
    # Keep the PNG's own palette indices rather than compacting them. Pixel
    # value 0 is transparent -- it shows whatever is already on screen, which is
    # how a frame with a hole lets the picture behind show -- and Arthur's
    # pictures put their transparent colour at index 0, or leave 0 unused.
    # Indices 1..15 point straight into a 16-entry palette bank. Not compacting
    # is what lets an adaptive picture line up with the palette it borrows: its
    # index 5 then means the same colour as the direct picture's index 5.
    trns = im.info.get("transparency")
    if isinstance(trns, (bytes, bytearray)):
        transparent = {i for i, a in enumerate(trns) if a == 0}
    elif isinstance(trns, int):
        transparent = {trns}
    else:
        transparent = set()
    if transparent and transparent != {0}:
        sys.exit(f"{path}: transparent at index {sorted(transparent)}, not 0")
    opaque = {i for _, i in im.getcolors()} - transparent
    if opaque and (min(opaque) < 1 or max(opaque) > 15):
        sys.exit(f"{path}: colours at indices {sorted(opaque)}; a bank holds "
                 f"1..15, with 0 transparent")

    cw, ch = (w + 7) // 8, (h + 7) // 8
    if cw > 40 or ch > 25:
        sys.exit(f"{path}: {cw}x{ch} cells, larger than the 40x25 screen")
    px = im.load()
    empty = bytes(64)             # a cell that is transparent through and through
    tiles, index_of, cellmap = bytearray(), {}, []
    logical = set()               # unique source cells, for the stats
    for cy in range(ch):
        for cx in range(cw):
            cell = bytes(px[cx*8+c, cy*8+r]
                         if cx*8+c < w and cy*8+r < h else 0
                         for r in range(8) for c in range(8))
            if cell != empty:
                logical.add(cell)
            # On the 80-column screen a logical cell becomes two tiles, its
            # left half then its right. They are stored undoubled -- 4 source
            # pixels a row -- and the interpreter doubles each pixel as it
            # bakes them, so the doubling costs nothing on disk. On the
            # 40-column screen the cell is itself the tile.
            if double:
                halves = [bytes(cell[r*8 + half*4 + c]
                                for r in range(8) for c in range(4))
                          for half in (0, 1)]
                empty_tile = empty[:32]
            else:
                halves = [cell]
                empty_tile = empty
            for t in halves:
                if t == empty_tile:
                    # nothing to draw: $ffff tells the interpreter to leave the
                    # cell alone, so a picture drawn over another shows through
                    cellmap.append(0xffff)
                    continue
                if t not in index_of:
                    index_of[t] = len(index_of)
                    tiles += t
                cellmap.append(index_of[t])

    ntiles = len(index_of)
    max_tiles = 1023 if x16 else (2048 if double else 1024)
    if ntiles > max_tiles:
        sys.exit(f"{path}: {ntiles} unique tiles; the store holds {max_tiles}")

    if x16:
        # VERA palette RAM order: two bytes an entry, GGGGBBBB then 0000RRRR,
        # ready to stream straight to $1fa00 + bank * 32.
        palette = bytearray(32)
        for n in range(16):
            r, g, b = pal[n*3], pal[n*3+1], pal[n*3+2]
            palette[n*2] = (g & 0xf0) | (b >> 4)
            palette[n*2 + 1] = r >> 4
    else:
        # The bank in the picture file's own index order: entry n is palette
        # index n, in the nybble-swapped order the VIC-IV registers want.
        palette = bytearray(48)
        for chan in range(3):
            for n in range(16):
                palette[chan*16 + n] = nybswap(pal[n*3 + chan])

    packed = bytearray()          # two pixels a byte, high nybble first
    for i in range(0, len(tiles), 2):
        packed.append((tiles[i] << 4) | tiles[i+1])

    blob = bytearray()
    blob += bytes((cw * 2 if double else cw, ch))
    blob += struct.pack("<H", ntiles)
    blob += palette
    for i in cellmap:
        blob += struct.pack("<H", i)
    blob += packed
    if len(blob) > 0xffff:
        sys.exit(f"{path}: {len(blob)} bytes uncompressed; more than 64 KB")
    # convert() always returns the raw, uncompressed blob now. The X16 stores
    # it as-is (FAT32 has no block pressure, and it is LOADed from SD on demand).
    # The MEGA65 concatenates a picture disk's raw blobs, page-padded, and
    # exomizer-crunches the whole lot into one archive per disk (build_archives
    # below); the interpreter streams that back into attic through a ported
    # exomizer decruncher. One archive per disk compresses far better than the
    # old per-picture RLE (cross-picture redundancy) and collapses Zork Zero and
    # Journey onto a single picture disk.
    return dict(w=w, h=h, cw=cw * 2 if double else cw, ch=ch, ntiles=ntiles,
                logical=len(logical), colours=len(opaque),
                blob=bytes(blob), raw=len(blob))

def load_blorb(filepath):
    """Return (images, rects, adaptive) from a Blorb: images is a list of
    (num, PIL Image) for the PNG resources; rects is a list of (num, w_px, h_px)
    for the Rect placeholders (which carry only a size a game reads with
    picture_data, to lay real pictures out); adaptive is the set of picture
    numbers in the APal chunk, which are drawn using the last direct picture's
    palette instead of their own."""
    blorb = open(filepath, "rb").read()
    if blorb[:4] != b"FORM" or blorb[8:12] != b"IFRS":
        sys.exit(f"{filepath}: not a Blorb (FORM..IFRS) file")
    chunks, ridx, apal, pos = {}, None, b"", 12
    while pos < len(blorb):
        ctype = blorb[pos:pos+4]
        clen = struct.unpack(">I", blorb[pos+4:pos+8])[0]
        data = blorb[pos+8:pos+8+clen]
        chunks[pos] = (ctype, data)
        if ctype == b"RIdx":
            ridx = data
        elif ctype == b"APal":
            apal = data
        pos += 8 + clen + (clen & 1)
    if ridx is None:
        sys.exit(f"{filepath}: no resource index (RIdx) chunk")
    adaptive = {struct.unpack(">I", apal[i:i+4])[0] for i in range(0, len(apal), 4)}
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
    return images, rects, adaptive

# A picture may be numbered up to 999 (three digits, the P### filename width).
# The interpreter's picture index is 16-bit, so the count is bounded only by the
# numbering: at most 999 distinct pictures, and in practice by attic RAM.
MAX_PIC_NUMBER = 999
MAX_PICTURES   = 999


def pack_disks(sizes, disk_blocks, disk_files):
    """Assign each picture (given its compressed size, in pic_number order) to a
    picture disk, filling one before starting the next. A disk is capped by both
    its data blocks and its directory's file count. Returns (disks, count)."""
    disks, cur_disk, cur_blocks, cur_files = [], 1, 0, 0
    for s in sizes:
        blocks = (s + 253) // 254
        if cur_files and (cur_files >= disk_files or cur_blocks + blocks > disk_blocks):
            cur_disk += 1
            cur_blocks = cur_files = 0
        if blocks > disk_blocks:
            sys.exit(f"a single picture needs {blocks} blocks, more than a "
                     f"picture disk holds ({disk_blocks})")
        disks.append(cur_disk)
        cur_blocks += blocks
        cur_files += 1
    return disks, cur_disk


def main():
    fcm_width, stats, x16, exomizer, args = 80, False, False, None, []
    argv, i = sys.argv[1:], 0
    while i < len(argv):
        a = argv[i]
        if a == "--stats":
            stats = True
        elif a == "--x16":
            x16 = True
        elif a == "--fcm-width" and i + 1 < len(argv):
            i += 1
            fcm_width = int(argv[i])
        elif a.startswith("--fcm-width="):
            fcm_width = int(a.split("=", 1)[1])
        elif a == "--exomizer" and i + 1 < len(argv):
            i += 1
            exomizer = argv[i]
        elif a.startswith("--exomizer="):
            exomizer = a.split("=", 1)[1]
        else:
            args.append(a)
        i += 1
    if fcm_width not in (40, 80):
        sys.exit("--fcm-width must be 40 or 80")
    if not 2 <= len(args) <= 4:
        sys.exit(f"usage: {sys.argv[0]} [--fcm-width 40|80] [--x16] "
                 f"[--exomizer PATH] [--stats] "
                 f"<outdir> <png-dir-or-blorb> [disk-blocks disk-files]")
    # The MEGA65 crunches its picture disks; the X16 and stats-only runs do not.
    if not x16 and not stats and exomizer is None:
        exomizer = os.path.join(os.path.dirname(__file__), "..",
                                "exomizer", "src", "exomizer")
        if not os.path.exists(exomizer):
            sys.exit("MEGA65 picture disks need exomizer; pass --exomizer PATH")
    outdir, source = args[0], args[1]
    # The X16's screen has the MEGA65 80-column geometry -- text cells 8 pixels,
    # picture cells 16 -- but its L0 tile map holds one 16x8 tile per logical
    # cell, so the cell map is one entry per cell like the 40-column format,
    # while the game-facing sizes (pic_width, rects) are in doubled text cells.
    double = fcm_width == 80 and not x16
    # make.rb passes the picture-disk budget; without it everything goes on one
    # disk (the standalone / directory-of-PNGs case).
    disk_blocks = int(args[2]) if len(args) > 2 else 1 << 30
    disk_files  = int(args[3]) if len(args) > 3 else 1 << 30

    rects, adaptive = [], set()
    if os.path.isdir(source):
        images = [(int(os.path.basename(p)[:-4]), p)
                  for p in sorted(glob.glob(os.path.join(source, "*.png")),
                                  key=lambda s: int(os.path.basename(s)[:-4]))]
        images = [(n, p) for n, p in images]  # (num, path)
        if not images:
            sys.exit(f"no numbered PNGs in {source}")
    else:
        imgs, rects, adaptive = load_blorb(source)
        # convert() takes either a path or an (image, name) tuple
        images = [(num, (im, f"picture {num}")) for num, im in imgs]

    if len(images) > MAX_PICTURES:
        sys.exit(f"{len(images)} pictures: a build may hold at most "
                 f"{MAX_PICTURES} for now (the interpreter's picture index is "
                 f"still 8-bit; see todo.txt).")

    if not stats:
        os.makedirs(outdir, exist_ok=True)
    nums, sizes, pics, total, raw_total = [], [], [], 0, 0
    for num, src in images:
        if not 0 < num <= MAX_PIC_NUMBER:
            sys.exit(f"picture {num}: numbers must be 1..{MAX_PIC_NUMBER}")
        p = convert(src, double, x16)
        if x16 and len(p['blob']) > 0x8000:
            sys.exit(f"picture {num}: {len(p['blob'])} bytes; more than the "
                     f"X16's 32 KB (4 bank) staging area")
        # pic_pages holds ceil(raw / 256) in a single byte, so a picture is at
        # most 255 pages (65280 bytes) of attic.
        if (p['raw'] + PAGE - 1) // PAGE > 255:
            sys.exit(f"picture {num}: {p['raw']} bytes; more than 255 attic pages")
        if x16 and not stats:      # the X16 stores one uncompressed file per pic
            open(os.path.join(outdir, f"p{num:03d}.bin"), "wb").write(p['blob'])
        nums.append(num)
        pics.append((num, p))
        raw_total += p['raw']
        if double:
            # logical unique cells -> doubled pre-dedup -> tiles actually stored
            print(f"  picture {num:3d}: {p['w']}x{p['h']} px, {p['cw']}x{p['ch']} cells, "
                  f"{p['logical']} -> {2*p['logical']} -> {p['ntiles']} tiles, "
                  f"{p['colours']} colours, {p['raw']} bytes")
        else:
            print(f"  picture {num:3d}: {p['w']}x{p['h']} px, {p['cw']}x{p['ch']} cells, "
                  f"{p['ntiles']} tiles, {p['colours']} colours, {p['raw']} bytes")

    # Assign pictures to picture disks and build one crunched archive per disk.
    # The X16 keeps its loose uncompressed files, one per picture, and no disks.
    def dblocks(n): return (n + 253) // 254
    archives = {}                       # disk number -> crunched archive bytes
    if x16:
        disk_of, disk_count = [1] * len(nums), 1
    else:
        # Try the whole set as one archive first: every shipped game fits one
        # picture disk this way, so the common path crunches exactly once. Only
        # if it overflows do we fall back to packing by each picture's own
        # crunched size (an upper bound on its cost inside a shared archive, so
        # a disk that fits the sum always fits the combined archive) and build
        # one archive per disk.
        blobs = [p['blob'] for _, p in pics]
        one = build_archive(exomizer, blobs)
        if dblocks(len(one)) <= disk_blocks:
            disk_of, disk_count, archives = [1] * len(nums), 1, {1: one}
        else:
            sizes = [len(crunch(exomizer, b)) for b in blobs]
            disk_of, disk_count = pack_disks(sizes, disk_blocks, 1 << 30)
            for d in range(1, disk_count + 1):
                archives[d] = build_archive(
                    exomizer, [b for b, dd in zip(blobs, disk_of) if dd == d])
    if not stats:
        for d, blob in archives.items():
            open(os.path.join(outdir, f"pics{d}.bin"), "wb").write(blob)
        with open(os.path.join(outdir, "picdisks.txt"), "w") as f:
            if x16:
                for num, d in zip(nums, disk_of):
                    f.write(f"p{num:03d}.bin {d}\n")
            else:
                for d in range(1, disk_count + 1):
                    f.write(f"pics{d}.bin {d}\n")

    # A Rect is an invisible placeholder: no image, just a size in cells that
    # picture_data reports. Cells are ceil(pixels / 8), as for a real picture,
    # so on the 80-column screen a rect is twice as many cells wide.
    rw = 1 if fcm_width == 40 else 2
    rects = sorted((n, rw * ((w + 7) // 8), (h + 7) // 8) for n, w, h in rects)

    def lo(v): return v & 0xff
    def hi(v): return (v >> 8) & 0xff

    if not stats:
        with open(os.path.join(outdir, "pictures.asm"), "w") as f:
            f.write("; Generated by tools/pics2asm.py - do not edit\n")
            f.write(f"; from {source}\n;\n")
            if x16:
                f.write("; Only the index is assembled in. Each picture is a file in\n")
                f.write("; the game directory, loaded from SD on demand when it is\n")
                f.write("; drawn. Rect pictures carry no image, only a size\n")
                f.write("; picture_data reports.\n\n")
            else:
                f.write("; Only the index is assembled in. Each picture disk holds one\n")
                f.write("; exomizer archive (picsN.bin) of that disk's pictures, page-\n")
                f.write("; padded and concatenated; pic_load_all decrunches it into attic\n")
                f.write("; RAM at boot. pic_pages gives each picture's attic size, so the\n")
                f.write("; interpreter computes pic_page_lo/hi at boot rather than reading\n")
                f.write("; sizes off disk. Rect pictures carry no image, only a size.\n\n")
            f.write(f"picture_count = {len(nums)}\n")
            # How many picture disks the interpreter must sweep at boot; >1 makes
            # pic_load_all prompt for each in turn.
            f.write(f"picture_disk_count = {disk_count}\n\n")
            # Picture numbers run up to 999, so they are two byte-per-entry tables,
            # like pic_page_lo/hi, rather than one word table.
            f.write("pic_number_lo\t!byte " + ",".join(str(lo(n)) for n in nums) + "\n")
            f.write("pic_number_hi\t!byte " + ",".join(str(hi(n)) for n in nums) + "\n")
            if x16:
                # The X16 answers picture_data from the index -- the picture may
                # not be loaded -- so each picture's size is assembled in, in
                # game units: text cells, so twice the file's 16-pixel cells wide.
                f.write("pic_width\t!byte " +
                        ",".join(str(2 * p['cw']) for _, p in pics) + "\n")
                f.write("pic_height\t!byte " +
                        ",".join(str(p['ch']) for _, p in pics) + "\n")
            else:
                # Total crunched size across all disks, in 256-byte pages, so the
                # interpreter can scale its "loading graphics" progress bar to a
                # fixed width however big the picture set is.
                arch_pages = sum((len(b) + 255) // 256 for b in archives.values())
                f.write(f"picture_crunched_pages = {arch_pages}\n")
                # Which picture disk (1-based) each picture's archive lives on.
                f.write("pic_disk\t!byte " + ",".join(str(d) for d in disk_of) + "\n")
                # ceil(raw / 256): the picture's attic size in pages. Each picture
                # is page-padded in its archive, so this is exactly where the next
                # one begins. pic_load_all sums these from PIC_ATTIC_PAGE to fill
                # pic_page_lo/hi at boot -- no sizes are ever read off disk.
                f.write("pic_pages\t!byte " +
                        ",".join(str((p['raw'] + 255) // 256) for _, p in pics) + "\n")
                f.write("pic_page_lo\t!fill picture_count, 0\n")
                f.write("pic_page_hi\t!fill picture_count, 0\n")
            # 1 where a picture is adaptive (Blorb APal): it is drawn in the last
            # direct picture's palette, not its own, so a game's UI can recolour to
            # match the scene. Parallel to pic_number.
            f.write("pic_adaptive\t!byte " +
                    ",".join("1" if n in adaptive else "0" for n in nums) + "\n\n")
            # Always define the arrays, even with no rects, so the interpreter's
            # rect lookup assembles; rect_count gates whether it is ever scanned.
            f.write(f"rect_count = {len(rects)}\n")
            rr = rects or [(0, 0, 0)]
            f.write("rect_number_lo\t!byte " + ",".join(str(lo(n)) for n, _, _ in rr) + "\n")
            f.write("rect_number_hi\t!byte " + ",".join(str(hi(n)) for n, _, _ in rr) + "\n")
            f.write("rect_width\t!byte " + ",".join(str(w) for _, w, _ in rr) + "\n")
            f.write("rect_height\t!byte " + ",".join(str(h) for _, _, h in rr) + "\n")

    if x16:
        x16_total = sum(p['raw'] for _, p in pics)
        print(f"{len(nums)} pictures, {x16_total} bytes in {len(nums)} uncompressed "
              f"files in the game directory"
              + (f"; {len(rects)} rect placeholders" if rects else ""))
    elif not stats:
        arch_total = sum(len(b) for b in archives.values())
        disk_note = (f" over {disk_count} picture disks" if disk_count > 1
                     else " on one picture disk")
        print(f"{len(nums)} pictures, {raw_total} bytes crunched to {arch_total} on disk "
              f"({100*arch_total/raw_total:.0f}%){disk_note}, {raw_total} bytes in attic RAM"
              + (f"; {len(rects)} rect placeholders" if rects else ""))

    if stats:
        # Measurement only, nothing written: how close the set comes to the
        # interpreter's caps. Attic is page-aligned per picture; the tile
        # store holds PIC_MAX_TILES live tiles across all windows -- 2048 on
        # the MEGA65, 1023 in the X16's VERA tile store (tile 0 is reserved).
        store_cap = 1023 if x16 else 2048
        top = sorted(pics, key=lambda t: -t[1]['ntiles'])[:5]
        if x16:
            print("stats only, nothing written")
        else:
            attic = sum((p['raw'] + 255) // 256 * 256 for _, p in pics)
            print(f"stats only, nothing written; {attic} bytes of attic, page-aligned")
        print(f"  largest by tiles (store cap {store_cap} live): "
              + ", ".join(f"#{n}={p['ntiles']}" for n, p in top))
        print(f"  largest picture: {max(p['raw'] for _, p in pics)} bytes raw "
              f"(cap 65280, 255 attic pages)")

main()
