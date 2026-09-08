#!/usr/bin/env python3
"""Apple IIgs phase 3, step 0: the font legibility mockup.

Renders the same text three ways and writes PNGs to look at:

  320-1bit   80 columns of the 320-pixel SHR screen, 4 pixels per cell, drawn
             with the hand-made 3x8 font: 3 pixels of glyph and one of gap.
  320-aa     the same 4 pixels per cell, but each pixel takes one of 16 colours,
             so the 6x8 master font is area-averaged two columns at a time into
             3 samples of grey.  This is the thing 320 mode can do that no other
             Ozmoo target can.
  640        the 640-pixel screen, 8 pixels per cell, the 6x8 master font drawn
             1-bit.  The reference for what the per-scanline-640-band fallback
             would buy.

  320-thresh (extra, not in the plan) the 6x8 master downsampled to 4 samples
             and thresholded back to 1 bit.  It separates "antialiasing helps"
             from "the hand-drawn 3-wide design helps", which the three panels
             the plan asks for cannot tell apart on their own.

The trap the plan warns about is viewing this at 1:1 on a modern display, where
a perfectly good font looks cramped and gets rejected.  So nothing is written at
1:1.  A IIgs fills a 4:3 screen with either mode, which makes a 320-mode pixel
0.83 as wide as it is tall and a 640-mode pixel 0.42; the defaults below (4 host
pixels across a 320-mode pixel, 5 down a scanline) give 0.8, which is honest to
within 4%.  --hscale/--vscale move it, and --scale 1 --vscale 1 reproduces the
trap deliberately if you want to see it.
"""

import argparse, os, sys
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))

# ---------------------------------------------------------------- fonts

# Shade characters, paper to ink.  The 1-bit fonts use only the two ends.
SHADES = {".": 0.0, "-": 1.0 / 3.0, "+": 2.0 / 3.0, "#": 1.0}

def load_font(path):
    """Read a '@<hex>' + rows-of-#-and-. font file.  Returns {code: [rows]}."""
    # A row is a line made only of '#' and '.', so a comment starting with '#'
    # cannot be mistaken for one (and '#####.' cannot be mistaken for a comment,
    # which is how the first version of this got it wrong).
    glyphs, code, rows = {}, None, []
    for line in open(path):
        line = line.rstrip("\n").rstrip()
        if line.startswith("@"):
            if code is not None:
                glyphs[code] = rows
            code, rows = int(line[1:].strip(), 16), []
        elif line and set(line) <= set(SHADES) and code is not None:
            rows.append(line)
    if code is not None:
        glyphs[code] = rows
    for c, r in glyphs.items():
        if len(r) != 8:
            sys.exit("%s: glyph $%02X has %d rows, want 8" % (path, c, len(r)))
        w = len(r[0])
        if any(len(x) != w for x in r):
            sys.exit("%s: glyph $%02X has ragged rows" % (path, c))
    return glyphs

def coverage_direct(glyph, cell_w):
    """Glyph rows -> 8 rows of cell_w coverages, straight off the shade chars."""
    return [[SHADES[x] for x in (row + "." * cell_w)[:cell_w]] for row in glyph]

def coverage_downsampled(glyph, cell_w):
    """The 8-wide master area-averaged into cell_w samples (cell_w must be 4)."""
    n = 8 // cell_w
    out = []
    for row in glyph:
        row = (row + "." * 8)[:8]
        out.append([sum(1.0 for x in row[i * n:(i + 1) * n] if x == "#") / n
                    for i in range(cell_w)])
    return out

def coverage_thresholded(glyph, cell_w):
    return [[1.0 if v >= 0.5 else 0.0 for v in row]
            for row in coverage_downsampled(glyph, cell_w)]

def coverage_hinted(narrow_glyph, master_glyph, cell_w):
    """The crisp 3-wide glyph, with a grey wherever the 6x8 master has ink that
    the crisp one had to drop.  Solid stems from the hand-drawn font, greys only
    where they buy something - a diagonal, a curve - which is the only place
    antialiasing can help when the whole glyph is three samples wide."""
    crisp = coverage_direct(narrow_glyph, cell_w)
    soft = coverage_downsampled(master_glyph, cell_w)
    return [[max(crisp[y][x], 0.5 if soft[y][x] > 0.0 else 0.0)
             for x in range(cell_w)] for y in range(8)]

# ---------------------------------------------------------------- the screen

def nybble(n):
    """A IIgs palette component (0-15) as an 8-bit sRGB value."""
    return round(n * 255 / 15)

class Renderer:
    """One of the four ways of drawing text, and the palette it needs."""

    def __init__(self, name, glyphs, cell_w, coverage, gamma, second=None):
        self.name, self.glyphs, self.cell_w = name, glyphs, cell_w
        self.coverage, self.second = coverage, second
        # Coverage -> a IIgs palette nybble.  Half coverage is not half the
        # number: a display's gamma means half the *light* is 15*0.5**(1/2.2),
        # i.e. $B.  The whole palette cost is one entry per distinct shade, and
        # the set is closed under the inverse-video swap because 1-x maps it
        # onto itself.
        self.gamma = gamma
        self.cache = {}

    def cell(self, code):
        if code not in self.cache:
            g = self.glyphs.get(code) or self.glyphs[0x20]
            if self.second is None:
                self.cache[code] = self.coverage(g, self.cell_w)
            else:
                g2 = self.second.get(code) or self.second[0x20]
                self.cache[code] = self.coverage(g, g2, self.cell_w)
        return self.cache[code]

    def shade(self, v):
        n = round(15 * (v ** (1.0 / self.gamma)))
        return (nybble(n), nybble(n), nybble(n))

    def palette_entries(self, text):
        used = set()
        for ch in text:
            for row in self.cell(ord(ch)):
                for v in row:
                    used.add(round(v, 3))
                    used.add(round(1.0 - v, 3))   # the inverse-video swap
        return sorted(used)

    def render(self, lines, cols, rows):
        """lines is a list of (text, inverse) -> an RGB image, one host pixel
        per screen pixel."""
        w, h = cols * self.cell_w, rows * 8
        img = Image.new("RGB", (w, h), (0, 0, 0))
        px = img.load()
        for r in range(rows):
            text, inverse = lines[r] if r < len(lines) else ("", False)
            text = (text + " " * cols)[:cols]
            for c, ch in enumerate(text):
                cov = self.cell(ord(ch))
                for y in range(8):
                    for x in range(self.cell_w):
                        v = cov[y][x]
                        if inverse:
                            v = 1.0 - v
                        px[c * self.cell_w + x, r * 8 + y] = self.shade(v)
        return img

def scale(img, cell_w, hscale, vscale):
    """Blow up so a 320-mode pixel is twice as wide as a 640-mode one and both
    are taller than wide, which is what the hardware does on a 4:3 screen."""
    hx = hscale * (8 // cell_w)       # 320-mode cells get twice the width
    return img.resize((img.width * hx, img.height * vscale), Image.NEAREST)

# ---------------------------------------------------------------- the text

# Our own prose, in the register the games use.  Deliberately not a quotation:
# the clean-room rule covers Infocom's interpreter, and their prose is theirs.
PARAGRAPH_80 = [
    ("  Ozmoo v16                 The Long Gallery                Score: 40  Moves: 112 ", True),
    ("", False),
    ("The Long Gallery", False),
    ("A corridor of tall windows runs the length of the west wall, and the low sun", False),
    ("throws the shadow of every mullion across the boards at your feet. Portraits", False),
    ("hang opposite, four of them, each in a frame heavier than the last. The one", False),
    ("nearest the door has been taken down and turned to face the wall; a paler", False),
    ("rectangle of panelling marks where it hung. A staircase descends to the east,", False),
    ("and a draught comes up it that smells of the river.", False),
    ("", False),
    ("You can see a brass key (which is glowing faintly) and Lord Ashgrove's diary", False),
    ("here.", False),
    ("", False),
    (">turn the fourth portrait around", False),
    ("", False),
    ("You lift it away from the wall. Behind the canvas, wedged into the stretcher,", False),
    ("is a folded sheet of paper, and it has been there a long time.", False),
    ("", False),
    ("  [Press SPACE to continue, or Q to quit.]  --MORE--", False),
    ("", False),
    ("abcdefghijklmnopqrstuvwxyz  ABCDEFGHIJKLMNOPQRSTUVWXYZ  0123456789  Il1 O0 rn m", False),
    ("!\"#$%&'()*+,-./:;<=>?@[\\]^_`{|}~   \"Quoted,\" he said; 3.5\" x 800K = 1,600 blocks.", False),
    ("", False),
    ("The quick brown fox jumps over the lazy dog. Pack my box with five dozen jugs.", False),
    (">", False),
]

PARAGRAPH_40 = [
    (" The Long Gallery      Score: 40  Moves: 112", True),
    ("", False),
    ("The Long Gallery", False),
    ("A corridor of tall windows runs the", False),
    ("length of the west wall, and the low", False),
    ("sun throws the shadow of every mullion", False),
    ("across the boards at your feet.", False),
    ("Portraits hang opposite, four of them,", False),
    ("each in a frame heavier than the last.", False),
    ("", False),
    ("You can see a brass key here.", False),
    ("", False),
    (">turn the fourth portrait around", False),
    ("", False),
    ("abcdefghijklmnopqrstuvwxyz  Il1 O0 rn", False),
    ("ABCDEFGHIJKLMNOPQRSTUVWXYZ  m w 3.5\"", False),
    ("0123456789  !\"#$%&'()*+,-./:;<=>?@[\\]", False),
    ("", False),
    ("  [Press SPACE to continue.] --MORE--", False),
    (">", False),
]

# ---------------------------------------------------------------- output

def label_font(size):
    try:
        return ImageFont.load_default(size=size)
    except TypeError:                    # very old Pillow
        return ImageFont.load_default()

def compare_sheet(renders, path, title, gap=24, margin=16, labelsize=20):
    f = label_font(labelsize)
    lh = labelsize + 10
    th = labelsize + 14
    w = margin * 2 + sum(i.width for _, i in renders) + gap * (len(renders) - 1)
    h = margin * 2 + th + lh + max(i.height for _, i in renders)
    sheet = Image.new("RGB", (w, h), (32, 32, 32))
    d = ImageDraw.Draw(sheet)
    d.text((margin, margin), title, font=f, fill=(255, 255, 255))
    x = margin
    for name, img in renders:
        d.text((x, margin + th), name, font=f, fill=(200, 200, 200))
        sheet.paste(img, (x, margin + th + lh))
        d.rectangle([x - 1, margin + th + lh - 1,
                     x + img.width, margin + th + lh + img.height],
                    outline=(90, 90, 90))
        x += img.width + gap
    sheet.save(path)
    return sheet

def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--out", default="temp/gsfont", help="output directory")
    ap.add_argument("--hscale", type=int, default=2,
                    help="host pixels across one 640-mode pixel (default 2, so "
                         "a 320-mode pixel is 4)")
    ap.add_argument("--vscale", type=int, default=5,
                    help="host pixels down one scanline (default 5)")
    ap.add_argument("--gamma", type=float, default=2.2,
                    help="display gamma used to turn a coverage into a palette "
                         "nybble (default 2.2, which puts half coverage at $B, "
                         "not at $8 - half the light, not half the number)")
    args = ap.parse_args()

    master = load_font(os.path.join(HERE, "fonts", "gs-6x8.txt"))
    narrow = load_font(os.path.join(HERE, "fonts", "gs-3x8.txt"))
    grey = load_font(os.path.join(HERE, "fonts", "gs-3x8-grey.txt"))
    g = args.gamma

    # The three the plan asks for come first, then the controls that say which
    # half of a difference is doing the work.
    renderers = [
        Renderer("320, 1-bit hand-drawn 3x8", narrow, 4, coverage_direct, g),
        Renderer("320, greyscale hand-drawn 3x8", grey, 4, coverage_direct, g),
        Renderer("640, 1-bit 6x8 (the fallback)", master, 8, coverage_direct, g),
        Renderer("320, 6x8 master area-averaged", master, 4, coverage_downsampled, g),
        Renderer("320, 6x8 master thresholded", master, 4, coverage_thresholded, g),
        Renderer("320, 3x8 plus grey hints from the master", narrow, 4,
                 coverage_hinted, g, second=master),
    ]

    os.makedirs(args.out, exist_ok=True)
    slugs = ["320-1bit", "320-grey", "640", "320-avg", "320-thresh", "320-hinted"]

    # Full 80x25 screens, one file each.
    full = []
    for r, slug in zip(renderers, slugs):
        img = scale(r.render(PARAGRAPH_80, 80, 25), r.cell_w, args.hscale, args.vscale)
        p = os.path.join(args.out, "gs-font-screen-%s.png" % slug)
        img.save(p)
        full.append((r.name, img, p))

    # The three-panel comparison the plan asks for, plus the threshold control.
    panels = []
    for r in renderers:
        panels.append((r.name,
                       scale(r.render(PARAGRAPH_40, 40, 20), r.cell_w,
                             args.hscale, args.vscale)))
    cmp_path = os.path.join(args.out, "gs-font-compare.png")
    compare_sheet(panels[:3], cmp_path,
                  "Apple IIgs step 0: 80-column text, same 40-column block three ways "
                  "(320-mode pixel drawn %dx%d, 640-mode %dx%d)"
                  % (args.hscale * 2, args.vscale, args.hscale, args.vscale))
    cmp4_path = os.path.join(args.out, "gs-font-compare-all.png")
    compare_sheet(panels, cmp4_path,
                  "...and the controls: the 6x8 master area-averaged into 4 samples, "
                  "the same thresholded back to 1 bit (which separates the antialiasing "
                  "from the drawing), and the crisp 3x8 with a grey wherever the master "
                  "has ink it had to drop")

    # The plan's literal request - "each pixel two screen pixels wide" - which
    # is also the trap it warns about: at 1:1 vertically a perfectly readable
    # font looks cramped, because a real scanline is not one host pixel tall.
    trap = [(n, scale(r.render(PARAGRAPH_40, 40, 20), r.cell_w, 1, 1))
            for (n, _), r in zip(panels[:3], renderers[:3])]
    trap_path = os.path.join(args.out, "gs-font-compare-1to1.png")
    compare_sheet(trap, trap_path,
                  "The same three at 1:1 - what the plan warns not to judge by. A "
                  "scanline is not one host pixel tall on any real monitor.",
                  gap=12)

    # A strip of just the hard pairs, magnified, for looking at glyph shapes.
    hard = [("Il1 O0 rn m", False), ("wm nn hb", False), ("E8 S5 G6 Q0", False)]
    strip = []
    for r in [renderers[0], renderers[1], renderers[3], renderers[2]]:
        strip.append((r.name, scale(r.render(hard, 13, 3), r.cell_w,
                                    args.hscale * 3, args.vscale * 3)))
    strip_path = os.path.join(args.out, "gs-font-hardpairs.png")
    compare_sheet(strip, strip_path,
                  "The pairs a narrow font loses first, at 3x the honest scale")

    # ------------------------------------------------------------ report
    text = "".join(l for l, _ in PARAGRAPH_80 + PARAGRAPH_40)
    print("Apple IIgs font mockup - phase 3 step 0")
    print("  master 6x8 : %d glyphs, $%02X-$%02X" %
          (len(master), min(master), max(master)))
    print("  narrow 3x8 : %d glyphs, $%02X-$%02X" %
          (len(narrow), min(narrow), max(narrow)))
    print("  honest scale: a 320-mode pixel is %dx%d host pixels, a 640-mode one %dx%d"
          % (args.hscale * 2, args.vscale, args.hscale, args.vscale))
    print("  pixel aspect drawn %.3f wide per tall; the hardware's is 0.833 (320) "
          "and 0.417 (640)" % (args.hscale * 2 / args.vscale))
    print()
    for r in renderers:
        lv = r.palette_entries(text)
        n = len(r.glyphs)
        bits = max(1, (len(lv) - 1).bit_length())
        store = n * ((r.cell_w * bits + 7) // 8) * 8
        print("  %-40s cell %d px, %2d palette entr%s, %d bits a sample, "
              "%d bytes of font"
              % (r.name, r.cell_w, len(lv), "y" if len(lv) == 1 else "ies",
                 bits, store))
    print()
    # How crowded is each font?  For every pair of letters and digits, the sum
    # of |difference| over the cell - a pair one pixel apart is a pair a reader
    # has only one pixel to tell apart.  The worst few name the trouble; the
    # counts say how much of it there is, which is the number that matters.
    alnum = [c for c in range(0x30, 0x7B) if chr(c).isalnum()]
    print()
    print("  Glyph crowding, over the %d letter and digit pairs: how many are "
          "within N pixels" % (len(alnum) * (len(alnum) - 1) // 2))
    print("    %-40s %5s %5s %5s %5s   %s"
          % ("", "<=1", "<=2", "<=3", "min", "the closest pairs"))
    for r in renderers:
        pairs = []
        for i, a in enumerate(alnum):
            for b in alnum[i + 1:]:
                ca, cb = r.cell(a), r.cell(b)
                d = sum(abs(ca[y][x] - cb[y][x])
                        for y in range(8) for x in range(r.cell_w))
                pairs.append((d, chr(a), chr(b)))
        pairs.sort()
        n1 = sum(1 for d, _, _ in pairs if d <= 1.0)
        n2 = sum(1 for d, _, _ in pairs if d <= 2.0)
        n3 = sum(1 for d, _, _ in pairs if d <= 3.0)
        print("    %-40s %5d %5d %5d %5.2f   %s"
              % (r.name, n1, n2, n3, pairs[0][0],
                 " ".join("%s%s" % (a, b) for _, a, b in pairs[:8])))
    print()
    for name, img, p in full:
        print("  wrote %s  (%dx%d)  %s" % (p, img.width, img.height, name))
    print("  wrote %s" % cmp_path)
    print("  wrote %s" % cmp4_path)
    print("  wrote %s" % strip_path)
    print("  wrote %s  (the trap, deliberately)" % trap_path)

if __name__ == "__main__":
    main()
