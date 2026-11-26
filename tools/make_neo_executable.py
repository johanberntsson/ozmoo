#!/usr/bin/env python3
"""Build a Neo6502 .neo executable from an Ozmoo PRG and its resident story image.

The .neo format has an 8-byte header followed by load blocks:

    magic "NEO" prefix, 2 reserved bytes, exec address lo/hi
    block: continuation byte, load address lo/hi, size lo/hi,
           NUL-terminated comment, data

The continuation bit (0x80) is set on every block except the last.
"""

import argparse
import struct
from pathlib import Path


def block(control: int, address: int, data: bytes, comment: str) -> bytes:
    if not 0 <= address <= 0xFFFF:
        raise ValueError(f"load address ${address:04x} is not 16-bit")
    if len(data) > 0xFFFF:
        raise ValueError(f"block is too large: {len(data)} bytes")
    return (
        bytes((control, address & 0xFF, address >> 8, len(data) & 0xFF, len(data) >> 8))
        + comment.encode("ascii") + b"\x00"
        + data
    )


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("main_prg", type=Path, help="interpreter PRG from temp/ozmoo")
    parser.add_argument("story_bin", type=Path, help="resident story image from temp/compmem.tmp")
    parser.add_argument("output", type=Path, help="output .neo file")
    parser.add_argument("--main-addr", type=lambda value: int(value, 0), default=0x1000)
    parser.add_argument("--story-addr", type=lambda value: int(value, 0), default=0x4600)
    parser.add_argument("--exec-addr", type=lambda value: int(value, 0), default=0x1000)
    args = parser.parse_args()

    main_data = args.main_prg.read_bytes()
    if len(main_data) < 2:
        raise ValueError(f"{args.main_prg} is too small to be a PRG")
    prg_addr = main_data[0] | (main_data[1] << 8)
    if prg_addr != args.main_addr:
        raise ValueError(
            f"{args.main_prg} has load address ${prg_addr:04x}, expected ${args.main_addr:04x}"
        )

    payload = main_data[2:]
    story = args.story_bin.read_bytes()

    header = b"\x03NEO" + b"\x00\x00" + struct.pack("<H", args.exec_addr)
    body = block(0x80, args.main_addr, payload, "Ozmoo Neo6502 interpreter")
    body += block(0x00, args.story_addr, story, "Ozmoo resident story data")
    args.output.write_bytes(header + body)
    print(
        f"Wrote {args.output} "
        f"({len(header + body)} bytes: {len(payload)} interpreter + {len(story)} story)"
    )


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        raise SystemExit(f"ERROR: {error}")
