#!/usr/bin/env python3
"""Build a Blorb of Z-machine version 6 pictures from a folder of images.

usage: make_blorb.py <contents.yaml | folder>

The picture set is described by a YAML "contents" file, so the script itself
knows nothing about any particular game. Give it either the file by name, or a
folder (it reads <folder>/contents.yaml).

    # top-level settings
    blorb:   wyrmward.blb   # the Blorb to write            (required)
    outdir:  pics           # where to leave the converted PNGs (default: pics)
    srcdir:  images         # where the source images live  (default: the
                            # directory holding this YAML file)

    # per-picture size caps, used when a picture omits its own (optional)
    max_width:  320
    max_height: 200

    pictures:
      - id: 1               # picture number                (required)
        file: title.png     # source image, under srcdir    (required)
        # no width/height -> the full v6 screen (or the max_* defaults)

      - id: 3
        file: dragon.png
        name: dragon        # used in the converted PNG's filename
                            # (the source's stem by default)
        width: 320          # cap this picture's size, preserving aspect
        height: 128         # ratio; inline pics leave room for text/[More]
        location: Dragon Hall   # a note, only printed in the report

Unlike the old line-based "contents" format, the size caps are **per picture**:
a full-screen intro can be listed beside inline room pictures that must stay
short. A picture with no width/height falls back to the top-level max_width /
max_height, and those default to the whole 320x200 v6 screen.

The Blorb and the output directory are relative to the current directory, so a
Makefile can keep them beside the story file; srcdir is relative to the YAML
file.

Each picture is:
  * scaled to fit within its width x height box, preserving aspect ratio and
    snapped down to a multiple of 8 pixels (the Ozmoo z6 cell grid);
  * quantised to at most 15 colours placed at palette indices 1..15, leaving
    index 0 free -- Ozmoo z6 treats index 0 as transparent, and a picture may
    use only 1..15. See tools/pics2asm.py, which reads the Blorb this writes.
"""

import os
import struct
import sys
from io import BytesIO

import yaml
from PIL import Image

# The limits tools/pics2asm.py enforces, mirrored here so a bad picture set is
# rejected while it is still being built rather than deep in the asm pipeline.
# A picture may be at most 40x25 cells, which is the v6 320x200 screen; picture
# numbers and the number of pictures both stop at 999 (the P### filename is
# three digits, and the interpreter's picture index is a word).
Z6_MAX_WIDTH = 320
Z6_MAX_HEIGHT = 200
Z6_CELL = 8
MAX_PIC_NUMBER = 999
MAX_PICTURES = 999

CONTENTS_NAME = "contents.yaml"


class ContentsError(Exception):
    """A problem with the contents file, reported with context."""


def _die(msg):
    sys.exit(f"{sys.argv[0]}: {msg}")


def read_contents(path):
    """Parse a YAML contents file into (top-level settings, pictures list)."""
    with open(path, encoding="utf-8") as f:
        try:
            doc = yaml.safe_load(f)
        except yaml.YAMLError as e:
            raise ContentsError(f"{path}: not valid YAML: {e}")
    if not isinstance(doc, dict):
        raise ContentsError(f"{path}: expected a YAML mapping at the top level")
    pictures = doc.pop("pictures", None)
    if not isinstance(pictures, list) or not pictures:
        raise ContentsError(f"{path}: needs a non-empty 'pictures' list")
    for i, pic in enumerate(pictures):
        if not isinstance(pic, dict):
            raise ContentsError(f"{path}: picture #{i + 1} is not a mapping")
    return doc, pictures


def _int(where, key, value, lo, hi):
    """Coerce value to an int in [lo, hi] or raise a ContentsError."""
    try:
        n = int(value)
    except (TypeError, ValueError):
        raise ContentsError(f"{where}: {key} = {value!r} is not a number")
    if not lo <= n <= hi:
        raise ContentsError(f"{where}: {key} = {n}; must be {lo}..{hi}")
    return n


def check(settings, pictures, path, source_dir):
    """Validate the contents against the v6 limits. Returns (cfg, pics).

    Everything is checked before any picture is converted, so a bad set fails
    without leaving half an output directory behind. cfg holds the top-level
    settings; pics is a list of dicts with number/file/name/description and the
    picture's own width/height caps.
    """
    known = {"blorb", "outdir", "srcdir", "max_width", "max_height"}
    for key in sorted(set(settings) - known):
        raise ContentsError(f"{path}: unknown setting {key!r}; "
                            f"expected one of {', '.join(sorted(known))}")
    if "blorb" not in settings:
        raise ContentsError(f"{path}: no blorb setting")

    default_w = _int(path, "max_width", settings.get("max_width", Z6_MAX_WIDTH),
                     Z6_CELL, Z6_MAX_WIDTH)
    default_h = _int(path, "max_height", settings.get("max_height", Z6_MAX_HEIGHT),
                     Z6_CELL, Z6_MAX_HEIGHT)

    if len(pictures) > MAX_PICTURES:
        raise ContentsError(f"{path}: {len(pictures)} pictures; a build may hold "
                            f"at most {MAX_PICTURES}")

    seen, pics = {}, []
    for i, pic in enumerate(pictures):
        where = f"{path}: picture #{i + 1}"
        unknown = set(pic) - {"id", "file", "name", "location", "width", "height"}
        if unknown:
            raise ContentsError(f"{where}: unknown key(s) "
                                f"{', '.join(sorted(map(repr, unknown)))}")
        if "id" not in pic or "file" not in pic:
            raise ContentsError(f"{where}: needs both 'id' and 'file'")
        num = _int(where, "id", pic["id"], 1, MAX_PIC_NUMBER)
        filename = str(pic["file"])
        if num in seen:
            raise ContentsError(f"{path}: picture {num} listed twice "
                                f"({seen[num]} and {filename})")
        seen[num] = filename
        src = os.path.join(source_dir, filename)
        if not os.path.exists(src):
            raise ContentsError(f"{where}: {src}: no such file")
        name = str(pic.get("name") or os.path.splitext(filename)[0])
        width = _int(where, "width", pic.get("width", default_w),
                     Z6_CELL, Z6_MAX_WIDTH)
        height = _int(where, "height", pic.get("height", default_h),
                      Z6_CELL, Z6_MAX_HEIGHT)
        pics.append({
            "number": num, "file": filename, "name": name,
            "description": str(pic.get("location") or ""),
            "max_width": width, "max_height": height,
        })

    cfg = {
        "blorb": str(settings["blorb"]),
        "outdir": str(settings.get("outdir", "pics")),
        "srcdir": source_dir,
    }
    return cfg, pics


def floor8(v):
    return max(Z6_CELL, (v // Z6_CELL) * Z6_CELL)


def prepare(path, max_width, max_height):
    """Return an indexed PIL image: <=15 colours at 1..15, index 0 free."""
    im = Image.open(path).convert("RGB")
    w, h = im.size
    ratio = min(max_width / w, max_height / h, 1.0)      # never upscale
    nw, nh = floor8(round(w * ratio)), floor8(round(h * ratio))
    im = im.resize((nw, nh), Image.LANCZOS)
    q = im.quantize(colors=15, method=Image.MEDIANCUT)   # indices 0..14
    pal = q.getpalette()[:15 * 3]
    data = bytes(p + 1 for p in q.getdata())             # shift to 1..15
    out = Image.new("P", q.size)
    out.putdata(data)
    out.putpalette([0, 0, 0] + pal)                      # index 0 reserved
    out.info["transparency"] = 0
    return out


def png_bytes(im):
    b = BytesIO()
    im.save(b, format="PNG", optimize=True)
    return b.getvalue()


def build_blorb(entries, outpath):
    """entries: list of (number, png_bytes). Writes a FORM..IFRS Blorb."""
    num = len(entries)
    ridx_data = struct.pack(">I", num)
    # RIdx chunk = 8 header + (4 + 12*num) body; PNG chunks follow it.
    pos = 12 + 8 + (4 + 12 * num)             # first PNG chunk offset
    offsets = []
    for _, data in entries:
        offsets.append(pos)
        pos += 8 + len(data) + (len(data) & 1)
    for (n, _), off in zip(entries, offsets):
        ridx_data += b"Pict" + struct.pack(">II", n, off)
    body = b"IFRS"
    body += b"RIdx" + struct.pack(">I", len(ridx_data)) + ridx_data
    for _, data in entries:
        body += b"PNG " + struct.pack(">I", len(data)) + data
        if len(data) & 1:
            body += b"\x00"
    blob = b"FORM" + struct.pack(">I", len(body)) + body
    with open(outpath, "wb") as f:
        f.write(blob)
    return len(blob)


def main(argv):
    if len(argv) != 2:
        _die(f"usage: {argv[0]} <{CONTENTS_NAME} | folder>")
    target = argv[1]
    if os.path.isdir(target):
        contents = os.path.join(target, CONTENTS_NAME)
    else:
        contents = target
    if not os.path.exists(contents):
        _die(f"{contents}: no such file"
             + (f" (expected a {CONTENTS_NAME!r} file in {target})"
                if os.path.isdir(target) else ""))

    try:
        settings, pictures = read_contents(contents)
        # srcdir defaults to the directory holding the YAML file, and is
        # resolved relative to it so the recipe can move independently of CWD.
        yaml_dir = os.path.dirname(contents) or "."
        srcdir = settings.pop("srcdir", None)
        source_dir = os.path.join(yaml_dir, srcdir) if srcdir else yaml_dir
        cfg, pics = check(settings, pictures, contents, source_dir)
    except ContentsError as e:
        _die(str(e))

    os.makedirs(cfg["outdir"], exist_ok=True)
    entries = []
    print(f"{'#':>3}  {'file':16} {'orig':>9}  {'z6':>9}  cols  where")
    for pic in pics:
        num, filename, name = pic["number"], pic["file"], pic["name"]
        src = os.path.join(cfg["srcdir"], filename)
        ow, oh = Image.open(src).size
        im = prepare(src, pic["max_width"], pic["max_height"])
        im.save(os.path.join(cfg["outdir"], f"{num:03d}-{name}.png"))
        entries.append((num, png_bytes(im)))
        print(f"{num:>3}  {filename:16} {ow:>4}x{oh:<4}  "
              f"{im.size[0]:>4}x{im.size[1]:<4}  {len(im.getcolors()):>4}  "
              f"{pic['description']}")
    size = build_blorb(entries, cfg["blorb"])
    print(f"\nWrote {cfg['blorb']} ({size} bytes, {len(entries)} pictures) and "
          f"{len(entries)} PNGs in {cfg['outdir']}/")


if __name__ == "__main__":
    main(sys.argv)
