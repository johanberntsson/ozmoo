#!/usr/bin/env python3
"""Decode a Neo6502 emulator screenshot into the 53x30 console text grid.

The decoder samples the centre of each 5x7 glyph cell and matches it against
the firmware's font_5x7.h table. It is used by test-neo6502-smoke.sh so the
smoke test checks rendered pixels rather than trusting OCR.
"""

import argparse
import os
import re
import sys
from functools import lru_cache
from pathlib import Path

try:
    from PIL import Image
except ImportError:  # pragma: no cover - environment setup error
    print("ERROR: Pillow is required (python3 -m pip install pillow).", file=sys.stderr)
    sys.exit(1)


SCREEN_COLS = 53
SCREEN_ROWS = 30
FOREGROUND = (255, 241, 232)
BACKGROUND = (29, 43, 83)
MAX_DISTANCE = 4

FONT_ITEMS = []


def parse_rgb(text):
    parts = [int(part, 0) for part in text.split(",")]
    if len(parts) != 3 or any(part < 0 or part > 255 for part in parts):
        raise argparse.ArgumentTypeError(f"expected three comma-separated RGB bytes, got {text!r}")
    return tuple(parts)


def parse_args():
    parser = argparse.ArgumentParser(
        description="Decode a Neo6502 emulator console screenshot."
    )
    parser.add_argument("screenshot", type=Path, help="PNG screenshot to decode")
    parser.add_argument("font_header", type=Path, help="Path to font_5x7.h")
    parser.add_argument("--cols", type=int, default=int(os.environ.get("NEO_SMOKE_COLS", SCREEN_COLS)))
    parser.add_argument("--rows", type=int, default=int(os.environ.get("NEO_SMOKE_ROWS", SCREEN_ROWS)))
    parser.add_argument("--x0", type=int, default=int(os.environ.get("NEO_SMOKE_X0", 27)))
    parser.add_argument("--y0", type=int, default=int(os.environ.get("NEO_SMOKE_Y0", 60)))
    parser.add_argument("--cw", type=int, default=int(os.environ.get("NEO_SMOKE_CW", 18)))
    parser.add_argument("--ch", type=int, default=int(os.environ.get("NEO_SMOKE_CH", 24)))
    parser.add_argument("--tol", type=int, default=int(os.environ.get("NEO_SMOKE_TOL", 40)))
    parser.add_argument(
        "--fg-rgb",
        type=parse_rgb,
        default=parse_rgb(os.environ.get("NEO_SMOKE_FG_RGB", ",".join(map(str, FOREGROUND)))),
        help="expected foreground RGB (default: 255,241,232 or NEO_SMOKE_FG_RGB)",
    )
    parser.add_argument(
        "--bg-rgb",
        type=parse_rgb,
        default=parse_rgb(os.environ.get("NEO_SMOKE_BG_RGB", ",".join(map(str, BACKGROUND)))),
        help="expected background RGB (default: 29,43,83 or NEO_SMOKE_BG_RGB)",
    )
    parser.add_argument(
        "--report-inverted",
        action="store_true",
        help="write the inverted console row numbers to stderr as INVERTED_ROWS=...",
    )
    return parser.parse_args()


def load_font(path):
    source = path.read_text()
    body = source.split("{", 1)[1].rsplit("}", 1)[0]
    values = [int(value, 16) for value in re.findall(r"0x([0-9a-fA-F]{2})", body)]
    if len(values) < 96 * 8:
        raise ValueError(f"{path} contains {len(values)} font bytes, expected at least {96 * 8}")

    font = {}
    for index, codepoint in enumerate(range(32, 128)):
        glyph = tuple(
            tuple((values[index * 8 + row] >> (7 - column)) & 1 for column in range(6))
            for row in range(7)
        )
        font[chr(codepoint)] = glyph
    return font


def build_lookup(font):
    global FONT_ITEMS
    FONT_ITEMS = list(font.items())
    exact = {}
    for character, glyph in FONT_ITEMS:
        exact.setdefault(glyph, character)
    return exact


def normalise_pattern(pattern):
    """Ignore the font's unused sixth column and mark the solid caret as blank.

    Neo draws the input caret as a solid 5x7 block which can spill into the
    unused sixth column of the preceding cell. The HD44780-derived font uses
    only the first five columns, so clearing column six is always safe.
    """
    rows = [tuple(row[:5]) + (0,) for row in pattern]
    if all(all(value for value in row[:5]) for row in rows):
        return CURSOR_PATTERN
    return tuple(rows)


CURSOR_PATTERN = tuple((1, 1, 1, 1, 1, 0) for _ in range(7))


@lru_cache(maxsize=None)
def nearest_glyph(pattern):
    best_character = "?"
    best_distance = 999
    for character, glyph in FONT_ITEMS:
        distance = sum(
            pattern[row][column] != glyph[row][column]
            for row in range(7)
            for column in range(6)
        )
        if distance < best_distance:
            best_character = character
            best_distance = distance
            if distance == 0:
                break
    return best_character, best_distance


def is_foreground(colour, tolerance):
    return all(abs(a - b) <= tolerance for a, b in zip(colour, FOREGROUND))


def row_is_inverted(pixels, x0, y0, cw, ch, row, cols, tolerance):
    """A console row is inverse video when foreground pixels dominate it."""
    foreground = 0
    total = 0
    for column in range(cols):
        for glyph_row in range(7):
            for glyph_column in range(6):
                x = x0 + column * cw + glyph_column * 3 + 1
                y = y0 + row * ch + glyph_row * 3 + 1
                total += 1
                if is_foreground(pixels[x, y], tolerance):
                    foreground += 1
    return foreground * 2 > total


def cell_pattern(pixels, x0, y0, cw, ch, column, row, tolerance, inverted):
    pattern = []
    for glyph_row in range(7):
        bits = []
        for glyph_column in range(6):
            x = x0 + column * cw + glyph_column * 3 + 1
            y = y0 + row * ch + glyph_row * 3 + 1
            bits.append(1 if is_foreground(pixels[x, y], tolerance) != inverted else 0)
        pattern.append(tuple(bits))
    return tuple(pattern)


def main():
    global FOREGROUND, BACKGROUND
    args = parse_args()
    FOREGROUND = args.fg_rgb
    BACKGROUND = args.bg_rgb
    font = load_font(args.font_header)
    exact = build_lookup(font)

    image = Image.open(args.screenshot).convert("RGB")
    pixels = image.load()

    inverted_rows = []
    for row in range(args.rows):
        inverted = row_is_inverted(
            pixels, args.x0, args.y0, args.cw, args.ch,
            row, args.cols, args.tol
        )
        if inverted:
            inverted_rows.append(row)
        characters = []
        for column in range(args.cols):
            pattern = normalise_pattern(cell_pattern(
                pixels, args.x0, args.y0, args.cw, args.ch,
                column, row, args.tol, inverted
            ))
            if pattern == CURSOR_PATTERN:
                character = ""
            else:
                character = exact.get(pattern)
            if character is None:
                character, distance = nearest_glyph(pattern)
                if distance > MAX_DISTANCE:
                    character = "?"
            characters.append(character)
        print(f"{row:02}: {''.join(characters)}")

    if args.report_inverted:
        print(
            "INVERTED_ROWS=" + ",".join(str(row) for row in inverted_rows),
            file=sys.stderr,
        )


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print(f"ERROR: {error}", file=sys.stderr)
        sys.exit(1)
