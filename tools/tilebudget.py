#!/usr/bin/python3
"""Cost the X16 tile store for placing pictures off the tile grid.

    python3 tools/tilebudget.py z6games/arthur-r74-s890714.blb [more.blb ...]

A VERA tile is one 8x8 art cell (16 physical pixels wide, doubled). A picture
whose left edge or top edge does not land on a tile boundary cannot use the
picture's own tiles as they are, and there are two ways to deal with that:

  bake      what the engine does today (.pic_bake_boundary_buf), horizontally
            only. Copy the picture's N deduplicated tiles into the store, then
            bake one fresh, un-deduplicated tile per spanned map cell from
            them:                    N + (cw+1)*ch, or N + (cw+1)*(ch+1) for
            both axes.
  generate  build the shifted tiles straight from the staged picture data, so
            the unshifted run is never copied at all:   (cw+1)*(ch+1).
            "dedup" is the same with the generated tiles deduplicated as they
            are made, which needs a hash table at runtime and is not currently
            planned -- it is measured here as headroom.

Fully transparent output cells are not counted: the engine leaves such a cell
alone so that whatever is behind shows through.

This is a design tool, not part of the build. It exists because the choice
between those two is a tile-budget question and nothing else -- see phase 0b of
the pixel-units refactor at the top of todo.txt for what it decided.
"""
import sys

sys.path.insert(0, __file__.rsplit("/", 1)[0])
import pics2asm

# The VERA tile map entry is a 10-bit index and tile 0 is reserved transparent,
# so this is a hard limit, not a tunable (PIC_MAX_TILES in pictures-x16.asm).
STORE = 1023


def shifted(im, dx, dy):
    """(raw, deduplicated) tiles a shift of (dx, dy) art pixels really needs."""
    w, h = im.size
    px = im.load()
    cw, ch = (w + 7) // 8, (h + 7) // 8
    mw, mh = cw + (1 if dx else 0), ch + (1 if dy else 0)
    seen, raw = set(), 0
    for my in range(mh):
        for mx in range(mw):
            tile = bytes(
                px[sx, sy] if 0 <= sx < w and 0 <= sy < h else 0
                for r in range(8) for c in range(8)
                for sx, sy in ((mx * 8 + c - dx, my * 8 + r - dy),))
            if any(tile):           # all-transparent cells are left alone
                raw += 1
                seen.add(tile)
    return raw, len(seen)


def measure(blorb):
    imgs, rects, adaptive, replacements = pics2asm.load_blorb(blorb)
    rows = []
    for num, im in imgs:
        # Skip what a real build skips: BPal replacements, anything past the
        # three-digit [Pnnn] filename, and anything not an indexed PNG.
        if num in replacements or num > pics2asm.MAX_PIC_NUMBER or im.mode != "P":
            continue
        p = pics2asm.convert((im, f"picture {num}"), False, True)
        cw, ch = p["blob"][0], p["blob"][1]
        n = p["blob"][2] | (p["blob"][3] << 8)
        h_raw, h_ded = shifted(im, 2, 0)        # horizontal only
        v_raw, v_ded = shifted(im, 2, 2)        # both axes
        rows.append(dict(num=num, cw=cw, ch=ch, n=n,
                         bake_h=n + h_raw, bake_hv=n + v_raw,
                         gen_h=h_raw, gen_hv=v_raw,
                         dedup_h=h_ded, dedup_hv=v_ded))
    return rows


def report(name, rows):
    print(f"=== {name}: {len(rows)} pictures")
    print(f"{'pic':>5} {'cells':>8} {'N':>5} | {'bake_h':>7} {'gen_h':>7} "
          f"{'dedup_h':>8} | {'bake_hv':>8} {'gen_hv':>7} {'dedup_hv':>9}")
    for r in sorted(rows, key=lambda r: -r["bake_hv"])[:8]:
        print(f"{r['num']:>5} {r['cw']:>3}x{r['ch']:<4} {r['n']:>5} | "
              f"{r['bake_h']:>7} {r['gen_h']:>7} {r['dedup_h']:>8} | "
              f"{r['bake_hv']:>8} {r['gen_hv']:>7} {r['dedup_hv']:>9}")
    for k in ("bake_h", "gen_h", "dedup_h", "bake_hv", "gen_hv", "dedup_hv"):
        over = [r["num"] for r in rows if r[k] > STORE]
        print(f"  {k:>8}: max {max(r[k] for r in rows):>5}, "
              f"{len(over)} of {len(rows)} over the {STORE}-tile store"
              + (f" ({', '.join(str(n) for n in over[:6])}"
                 + (", ..." if len(over) > 6 else "") + ")" if over else ""))
    print()


def main():
    if len(sys.argv) < 2:
        sys.exit(f"usage: {sys.argv[0]} <blorb> [<blorb> ...]")
    for blorb in sys.argv[1:]:
        report(blorb.rsplit("/", 1)[-1], measure(blorb))


if __name__ == "__main__":
    main()
