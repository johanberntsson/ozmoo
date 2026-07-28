#!/usr/bin/env python3
"""Build a Blorb of Z-machine version 6 pictures and sounds from a folder.

usage: make_blorb.py <contents.yaml | folder>

The resource set is described by a YAML "contents" file, so the script itself
knows nothing about any particular game. Give it either the file by name, or a
folder (it reads <folder>/contents.yaml).

    # top-level settings
    blorb:   wyrmward.blb   # the Blorb to write            (required)
    outdir:  pics           # where to leave the converted files (default: pics)
    srcdir:  images         # where the source files live   (default: the
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

    sounds:                 # optional
      - id: 3               # @sound_effect number; 1 and 2 are the bleeps,
        file: 003.wav       # so game sounds start at 3
        name: intro
        location: played by Initialise   # a note, only printed in the report

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

Sounds are for the interpreters that read them out of the Blorb -- sfrotz plays
them, which is what makes it a usable reference for a game with sound. Ozmoo's
own MEGA65 build does NOT read them from here: it takes the wavs straight off
the source folder with make.rb's -asw, which is why the same 8-bit mono wav can
feed both. A .wav listed here is converted to AIFF, because **Blorb has no WAV
chunk type**: the spec's sound chunks are AIFF ('FORM'), 'OGGV', 'MP3 ', 'MOD '
and 'SONG', and 'WAV ' exists only in ADRIFT-specific Blorbs, which a Z-machine
interpreter will not play. An .aiff/.aif source is embedded verbatim instead.
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

# Sound effect numbers. The Z-machine's sounds 1 and 2 are the interpreter's own
# bleeps, so a game's own effects start at 3 (Blorb spec, "Sound Resources"), and
# Ozmoo's -asw stops at 255 -- it looks for 003.wav .. 255.wav and its sound
# table is indexed by (number - 3).
MIN_SND_NUMBER = 3
MAX_SND_NUMBER = 255

CONTENTS_NAME = "contents.yaml"


class ContentsError(Exception):
    """A problem with the contents file, reported with context."""


def _die(msg):
    sys.exit(f"{sys.argv[0]}: {msg}")


def read_contents(path):
    """Parse a YAML contents file into (settings, pictures, sounds)."""
    with open(path, encoding="utf-8") as f:
        try:
            doc = yaml.safe_load(f)
        except yaml.YAMLError as e:
            raise ContentsError(f"{path}: not valid YAML: {e}")
    if not isinstance(doc, dict):
        raise ContentsError(f"{path}: expected a YAML mapping at the top level")
    pictures = doc.pop("pictures", None) or []
    sounds = doc.pop("sounds", None) or []
    for what, items in (("pictures", pictures), ("sounds", sounds)):
        if not isinstance(items, list):
            raise ContentsError(f"{path}: '{what}' must be a list")
        for i, item in enumerate(items):
            if not isinstance(item, dict):
                raise ContentsError(f"{path}: {what[:-1]} #{i + 1} is not a mapping")
    if not pictures and not sounds:
        raise ContentsError(f"{path}: needs a 'pictures' or a 'sounds' list")
    return doc, pictures, sounds


def _int(where, key, value, lo, hi):
    """Coerce value to an int in [lo, hi] or raise a ContentsError."""
    try:
        n = int(value)
    except (TypeError, ValueError):
        raise ContentsError(f"{where}: {key} = {value!r} is not a number")
    if not lo <= n <= hi:
        raise ContentsError(f"{where}: {key} = {n}; must be {lo}..{hi}")
    return n


def check(settings, pictures, sounds, path, source_dir):
    """Validate the contents against the v6 limits. Returns (cfg, pics, snds).

    Everything is checked before any picture is converted, so a bad set fails
    without leaving half an output directory behind. cfg holds the top-level
    settings; pics is a list of dicts with number/file/name/description and the
    picture's own width/height caps; snds the same for the sound effects.
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

    seen, snds = {}, []
    for i, snd in enumerate(sounds):
        where = f"{path}: sound #{i + 1}"
        unknown = set(snd) - {"id", "file", "name", "location"}
        if unknown:
            raise ContentsError(f"{where}: unknown key(s) "
                                f"{', '.join(sorted(map(repr, unknown)))}")
        if "id" not in snd or "file" not in snd:
            raise ContentsError(f"{where}: needs both 'id' and 'file'")
        num = _int(where, "id", snd["id"], MIN_SND_NUMBER, MAX_SND_NUMBER)
        filename = str(snd["file"])
        if num in seen:
            raise ContentsError(f"{path}: sound {num} listed twice "
                                f"({seen[num]} and {filename})")
        seen[num] = filename
        src = os.path.join(source_dir, filename)
        if not os.path.exists(src):
            raise ContentsError(f"{where}: {src}: no such file")
        ext = os.path.splitext(filename)[1].lower()
        if ext not in (".wav", ".aiff", ".aif"):
            raise ContentsError(f"{where}: {filename}: unsupported sound format "
                                f"{ext or '(none)'}; expected .wav (converted to "
                                f"AIFF) or .aiff/.aif (embedded as it is)")
        snds.append({
            "number": num, "file": filename,
            "name": str(snd.get("name") or os.path.splitext(filename)[0]),
            "description": str(snd.get("location") or ""),
        })

    cfg = {
        "blorb": str(settings["blorb"]),
        "outdir": str(settings.get("outdir", "pics")),
        "srcdir": source_dir,
    }
    return cfg, pics, snds


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


def _iff_chunks(blob, pos, end):
    """Walk RIFF/IFF chunks, yielding (id, data). Odd chunks are padded."""
    while pos + 8 <= end:
        cid = blob[pos:pos + 4]
        size = int.from_bytes(blob[pos + 4:pos + 8], "little"
                              if blob[:4] == b"RIFF" else "big")
        yield cid, blob[pos + 8:pos + 8 + size]
        pos += 8 + size + (size & 1)


def _extended80(rate):
    """An integer sample rate as an 80-bit IEEE 754 extended float (AIFF COMM).

    value = mantissa * 2**(exponent - 16383 - 63), with the mantissa's top bit
    explicit, so for an integer rate this is exact and needs no float maths:
    shift the rate up until bit 63 is set and count the shift.
    """
    if rate <= 0:
        return b"\x00" * 10
    bits = rate.bit_length()
    mantissa = rate << (64 - bits)
    exponent = 16382 + bits
    return struct.pack(">HQ", exponent, mantissa)


def wav_to_aiff(path):
    """Convert an 8- or 16-bit PCM wav to AIFF. Returns (aiff_bytes, info).

    Hand-rolled rather than through the stdlib: Python 3.13 removed both `aifc`
    and `audioop`, and sox would be a new build dependency for the one job.
    """
    blob = open(path, "rb").read()
    if blob[:4] != b"RIFF" or blob[8:12] != b"WAVE":
        raise ContentsError(f"{path}: not a RIFF/WAVE file")
    fmt = data = None
    for cid, chunk in _iff_chunks(blob, 12, len(blob)):
        if cid == b"fmt " and fmt is None:
            fmt = chunk
        elif cid == b"data" and data is None:
            data = chunk
    if fmt is None or data is None:
        raise ContentsError(f"{path}: no {'fmt ' if fmt is None else 'data'} chunk")
    tag, channels, rate, _byte_rate, _align, bits = struct.unpack("<HHIIHH", fmt[:16])
    if tag != 1:
        raise ContentsError(f"{path}: not uncompressed PCM (format tag {tag})")
    if channels < 1:
        raise ContentsError(f"{path}: {channels} channels")
    if bits == 8:
        # 8-bit wav samples are UNSIGNED, 8-bit AIFF samples are SIGNED.
        samples = bytes(b ^ 0x80 for b in data)
    elif bits == 16:
        # Both are signed; wav is little-endian and AIFF big-endian.
        samples = data[:len(data) & ~1]
        samples = b"".join(samples[i + 1:i + 2] + samples[i:i + 1]
                           for i in range(0, len(samples), 2))
    else:
        raise ContentsError(f"{path}: {bits}-bit samples; expected 8 or 16")
    frame = channels * (bits // 8)
    frames = len(samples) // frame
    comm = struct.pack(">hIh", channels, frames, bits) + _extended80(rate)
    ssnd = struct.pack(">II", 0, 0) + samples          # offset, blockSize
    body = b"AIFF"
    for cid, chunk in ((b"COMM", comm), (b"SSND", ssnd)):
        body += cid + struct.pack(">I", len(chunk)) + chunk
        if len(chunk) & 1:
            body += b"\x00"
    aiff = b"FORM" + struct.pack(">I", len(body)) + body
    return aiff, {"rate": rate, "bits": bits, "channels": channels,
                  "frames": frames}


def read_aiff(path):
    """Embed an existing AIFF verbatim. Returns (aiff_bytes, info)."""
    blob = open(path, "rb").read()
    if blob[:4] != b"FORM" or blob[8:12] not in (b"AIFF", b"AIFC"):
        raise ContentsError(f"{path}: not a FORM..AIFF file")
    info = {"rate": 0, "bits": 0, "channels": 0, "frames": 0}
    for cid, chunk in _iff_chunks(blob, 12, len(blob)):
        if cid == b"COMM" and len(chunk) >= 18:
            channels, frames, bits = struct.unpack(">hIh", chunk[:8])
            exponent, mantissa = struct.unpack(">HQ", chunk[8:18])
            rate = mantissa >> (16383 + 63 - exponent) if exponent else 0
            info = {"rate": rate, "bits": bits, "channels": channels,
                    "frames": frames}
    return blob, info


def build_blorb(resources, outpath):
    """resources: list of (usage, number, chunk_id, data). Writes a FORM..IFRS.

    The index entries are emitted in the same order as the chunks they point at,
    as the spec asks, and every chunk is padded to an even length (the padding
    byte is not counted in the chunk's own length).
    """
    ridx_data = struct.pack(">I", len(resources))
    # RIdx chunk = 8 header + (4 + 12*n) body; the resource chunks follow it.
    pos = 12 + 8 + (4 + 12 * len(resources))
    for usage, number, _cid, data in resources:
        ridx_data += usage + struct.pack(">II", number, pos)
        pos += 8 + len(data) + (len(data) & 1)
    body = b"IFRS"
    body += b"RIdx" + struct.pack(">I", len(ridx_data)) + ridx_data
    for _usage, _number, cid, data in resources:
        body += cid + struct.pack(">I", len(data)) + data
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
        settings, pictures, sounds = read_contents(contents)
        # srcdir defaults to the directory holding the YAML file, and is
        # resolved relative to it so the recipe can move independently of CWD.
        yaml_dir = os.path.dirname(contents) or "."
        srcdir = settings.pop("srcdir", None)
        source_dir = os.path.join(yaml_dir, srcdir) if srcdir else yaml_dir
        cfg, pics, snds = check(settings, pictures, sounds, contents, source_dir)
    except ContentsError as e:
        _die(str(e))

    os.makedirs(cfg["outdir"], exist_ok=True)
    resources = []
    if pics:
        print(f"{'#':>3}  {'file':16} {'orig':>9}  {'z6':>9}  cols  where")
    for pic in pics:
        num, filename, name = pic["number"], pic["file"], pic["name"]
        src = os.path.join(cfg["srcdir"], filename)
        ow, oh = Image.open(src).size
        im = prepare(src, pic["max_width"], pic["max_height"])
        im.save(os.path.join(cfg["outdir"], f"{num:03d}-{name}.png"))
        resources.append((b"Pict", num, b"PNG ", png_bytes(im)))
        print(f"{num:>3}  {filename:16} {ow:>4}x{oh:<4}  "
              f"{im.size[0]:>4}x{im.size[1]:<4}  {len(im.getcolors()):>4}  "
              f"{pic['description']}")

    if snds:
        print(f"\n{'#':>3}  {'file':16} {'format':>18}  {'length':>7}  where")
    try:
        for snd in snds:
            num, filename, name = snd["number"], snd["file"], snd["name"]
            src = os.path.join(cfg["srcdir"], filename)
            if filename.lower().endswith(".wav"):
                aiff, info = wav_to_aiff(src)
                # Leave the converted AIFF beside the converted PNGs, so what
                # went into the Blorb can be played and inspected on its own.
                with open(os.path.join(cfg["outdir"],
                                       f"{num:03d}-{name}.aiff"), "wb") as f:
                    f.write(aiff)
            else:
                aiff, info = read_aiff(src)
            # A Blorb sound resource IS the AIFF file: chunk type 'FORM', and
            # the chunk's data is everything after that file's own 8-byte header.
            resources.append((b"Snd ", num, aiff[:4], aiff[8:]))
            secs = info["frames"] / info["rate"] if info["rate"] else 0
            print(f"{num:>3}  {filename:16} "
                  f"{info['rate']:>6} Hz {info['bits']}-bit "
                  f"{'mono' if info['channels'] == 1 else str(info['channels']) + 'ch':<5}"
                  f"{secs:>6.1f}s  {snd['description']}")
    except ContentsError as e:
        _die(str(e))

    size = build_blorb(resources, cfg["blorb"])
    def count(n, thing):
        return f"{n} {thing}" + ("" if n == 1 else "s")
    made = count(len(pics), "picture") if pics else ""
    if snds:
        made += (" and " if made else "") + count(len(snds), "sound")
    print(f"\nWrote {cfg['blorb']} ({size} bytes, {made}); converted files "
          f"in {cfg['outdir']}/")


if __name__ == "__main__":
    main(sys.argv)
