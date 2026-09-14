# Fast loader for C64 disk reads — handover

Work in progress, **uncommitted**. Adds an optional fast loader (DreamLoad) to
Ozmoo's block reads on the C64, behind the new `-fl` build flag.

## Result

| scenario | without `-fl` | with `-fl` | |
|---|---|---|---|
| one 256-byte block, standalone benchmark | 455 ms | 213 ms | **2.1x faster** |
| in-game, no REU, `advent_punyinform.z5` 80 KB | 36 turns / 300 s | **78 turns / 300 s** | **2.2x faster** |
| in-game, with REU, same game | 102 turns / 300 s | **137 turns / 300 s** | the REU load saved |
| REU bulk cache load, `Aventyr.z5` 133 KB | 239 s | 40 s | **6x faster** |

The in-game figure is the `-bm` walkthrough (`benchmarks.json`, key
`r7-s251205`), same disk, same script, one screen read at the end of a fixed
300 s window. It lands almost exactly on the raw per-block ratio, which is the
point: the RAM cache costs only the 2 blocks the loader physically occupies, so
the whole transfer speedup reaches the game.

Getting there took three attempts at reserving the loader's KB — see bug 3. The
middle one built, ran, and was **~30 % slower than no fast loader at all**; if
this is ever re-worked, measure the game, not the block.

The 6x REU figure was measured in the previous session. The REU path caches the
whole game up front and then does no disk I/O, so the RAM cache does not come
into it.

## What it needs, what it gives, how it fails

**To use it:** build with `-fl`. Off by default.

**Requirements**, all of which are checked:

| | |
|---|---|
| target | C64 only — `make.rb` errors out on any other target |
| drive | a real **1541**, identified by ROM signature (`$fea0` = `$0d`, `$e5c6` = `$34 $b1`). A 1541-II, 1571, 1581, sd2iec, Pi1541 or similar is rejected |
| device | 8–11, and only the drive the game booted from |
| RAM | 1 KB at `$cc00-$cfff` (2 vmem blocks) plus ~1.3 KB of program image |

`make.rb` prints the cache cost and the preload limit when `-fl` is used, so the
trade is visible at build time and not only here.

**Does it fall back?** Yes, on every failure it can detect — `read_track_sector`
falls straight through to the existing kernal path, so the game keeps working:

| what goes wrong | detected by | result |
|---|---|---|
| not a C64 build | `make.rb` | build error, explicit |
| device not 8–11 | `fastloader_init` | never installs, kernal path, **says so at boot** |
| drive does not answer `M-R` | `ST` bit 7 | never installs, kernal path, **says so at boot** |
| not a 1541 (ROM signature) | `.fl_is_1541` | never installs, kernal path, **says so at boot** |
| drive code upload fails | `ST` bit 7 after `M-E` | disabled for the rest of the session, **says so at boot** |
| read for a different device | `fastloader_readblock` | kernal path for that read, silent |
| loader suspended and a file is open (`$98`) | `fastloader_readblock` | kernal path for that read, silent |
| bad sector / media error | drive gives up after 5 tries, returns carry set | kernal path retries it and reports errors as usual |

Anything that stops the loader installing at boot now prints

```
Fast loader off: no 1541 found.
```

and holds for ~1.2 s (`wait_a_sec`, the same pause Ozmoo uses elsewhere "so
player can read the last text before screen is cleared" — the game clears the
screen immediately afterwards, so without the pause the line is invisible).
Verified on hardware by forcing the detection to fail. A successful install
prints nothing.

**Will it fail without a clear reason why?** Two ways remain:

1. **`LoadTS` has no timeout.** Its handshake loops (`bvc`/`bmi` in
   `ldserial.src` and `ld41.src`) spin forever. If the drive stops answering
   mid-transfer — door opened, cable pulled, a drive that passed the ROM check
   but cannot actually run the code — the machine **hangs**, and no fallback can
   help because nothing regains control. The kernal path has device-not-present
   timeouts; this does not. Inherent to DreamLoad, but a real behaviour change.
2. **Under VICE it fails by giving wrong answers.** `LoadTS` returns garbage
   with carry *clear* — a silent wrong answer, not an error. Anyone testing an
   `-fl` build in an emulator will see corruption that looks like a bug in
   Ozmoo. See the traps section.

## Status

The two gaps the previous handover listed are closed, and **two further bugs it
did not know about were found and fixed** — one of them was silently corrupting
memory in any game big enough to fill the cache, which is why this could look
finished when it was not. See *Four bugs*.

Verified on hardware (Ultimate 64, `examples/advent_punyinform.z5`, 80 KB):

- `tools/fastloader/test/flverify.asm` — 200 sectors spread across the disk,
  each checked against the d64 itself: **200 ok, 0 bad**.
- `tools/fastloader/test/fltest.asm` — install → read → suspend → an ordinary
  DOS command channel answers → re-install → read: **PASS**, and the checksum
  matches the sector's true content in the d64.
- The game plays with `-fl` and prints a transcript **identical, line for line,
  to the same build without `-fl`** — both with the one-segment and the
  two-segment cache, so the banked half of the map is exercised.
- 2.2x faster in game without an REU, and correct with one (see Result).
- In-game **save** works: the save-slot directory lists (the exact operation
  that used to hang the machine), the file is written, "Ok." is printed, and the
  game resumes normally — so the loader re-installed itself after the drive had
  been handed back to DOS.
- The "no 1541" boot message appears, by forcing detection to fail.
- A build **without** `-fl` still plays correctly after the `vmem.asm` change;
  every edit there is behind `!ifdef FASTLOADER`, so it assembles identically.

Build matrix: **28/28** — `testz6.z6`, `examples/dejavu.z3`, `test/praxix.z5`
across default/`-t:c128`/`-t:plus4`/`-t:mega65`/`-t:x16`/`-smooth:1`,
`-t:mega65 -fcm` and `-fcm:40` for the v6 game, `-ecm`, and `-fl`, `-fl:0`,
`-il:8`, `-fl -sb:1`, `-fl -re:1`.

### Not verified

- **Restore.** In-game restore reports "Failed restore." on the Ultimate 64 —
  but it does so **identically with and without `-fl`**, so it is not a fast
  loader regression. It is either the U64's read-write d64 mount or the test
  harness; it was not chased down. Save is verified, restore is not.
- CLAUDE.md's line-for-line screen check of `testz6` C64 vs `-t:mega65 -fcm:40`
  — `xemu-xmega65` is not installed on this machine. The change does not touch
  the screen layer, but that is reasoning, not a result.

## Four bugs

### 1 — DOS coexistence (was Gap 1) — fixed

DreamLoad is a **captive** loader: once installed, the drive stops speaking the
normal DOS protocol, so save, restore, the save-file directory and disk swaps
would hang the machine. `tools/fastloader/test/coexist.asm` still demonstrates
the hang.

Fixed with a suspend/resume pair, hooked in **one** place rather than at every
call site. `constants.asm` points `kernal_open`, `kernal_load`, `kernal_save`
and `kernal_reset` at shims in `fastloader.asm`; each shim hands the drive back
(`SwitchOff`, `$cd0f`) before calling the real kernal routine, and
`fastloader_readblock` re-installs the loader on the next block read. Every
kernal file operation in Ozmoo therefore steps aside automatically. The shim
only fires for the drive the loader actually holds — a printer or the screen is
none of its business.

Two things had to be right for this to work; both cost a hardware session:

- **`SwitchOff` is not a handshake, it is a drive reset.** The drive answers it
  with `jmp ($fffc)`. A 1541 holds DATA low from reset until its DOS is ready —
  measured at ~1 s on the U64 — and a kernal `OPEN` inside that window does not
  fail, it **hangs**: the drive is pulling DATA, so the kernal believes a device
  answered its LISTEN and waits forever for a handshake. `.fl_wait_for_dos`
  waits for `$dd00` bit 7 to come back and stay back, and gives up after ~4 s
  rather than hang.
- **Re-installing needs a delay after the `M-E`.** The drive turns its motor off
  and then waits for *both* bus lines to be released before it will take a
  command. A `LoadTS` issued inside that window pulls DATA while the drive is
  still waiting for DATA to go free: the drive holds CLK, the host waits for
  CLK, deadlock. DreamLoad's own installer has the same delay in the same place
  (`dload.src`, the `Sys7` loop). `.fl_settle` is ~50 ms, once per install.

The install also stopped using `OPEN`/`CHKOUT` and now drives the bus directly
(`LISTEN`/`SECOND`/`CIOUT`, `TALK`/`TKSA`/`ACPTR`). That leaves no entry in the
kernal's file table, so there is nothing to close once the drive has gone
captive — closing a logical file at that point is itself a hang — and no logical
file number to collide with the ones `read_track_sector` and the save code use.
The old code left file 15 open forever, which would have broken the kernal
fallback path.

Cost: about 1 s to suspend plus ~1.5 s to re-install, once per save or restore.
Rare enough not to matter.

### 2 — drive detection (was Gap 2) — fixed

`fastloader_init` now identifies a 1541 the way DreamLoad's own installer does,
by reading ROM signatures with `M-R`: `$fea0` = `$0d`, `$e5c6` = `$34 $b1`.
Anything else — a 1581, an sd2iec — leaves `fastloader_enabled = 0` and every
read falls back to the kernal path. Confirmed on hardware: the signature reads
back `$34 $b1` and the loader enables itself.

### 3 — reserving the loader's KB, wrong twice before right

**First attempt (inherited): `first_banked_memory_page = $cc`.** That reserves
nothing. It only says where banking starts; `$cc00` stays in the vmem pool.
Ozmoo's RAM cache is a linear run of pages from `story_start` upwards, so
`$cc00` was handed out as an ordinary cache block and written straight over the
resident loader a few thousand words into any game big enough to fill the cache.
It survived the previous session's testing because nothing there ever filled the
cache: `czech.z5` is small, and the Aventyr measurement ran from the REU.

**Second attempt: `VMEM_END_PAGE = $cc`,** putting the loader above the end of
vmem. Correct, simple — and it threw away the banked RAM at `$d000-$ffff` with
it, taking the cache from 62 blocks to 36. That measured **~30 % slower than no
fast loader at all** (25 turns/300 s against 36), because the extra cache misses
cost more than the 2.1x reads saved. A fix that builds, runs and passes every
correctness test can still be the wrong fix.

**What is there now: a two-segment map.** The cache is
`story_start`..`$cbff` plus `$d000`..`$ffff`, with the loader's KB in the hole
between them, so only the 2 blocks it physically occupies are lost (62 → 60).
`vmem_page_for_index` in `vmem.asm` converts a block index to a page:

```
	cmp vmap_unbanked_blocks
	bcs +
	asl                      ; segment 0
	adc vmap_first_ram_page
	rts
+	sbc vmap_unbanked_blocks ; segment 1
	asl
	adc #vmem_banked_start_page
	rts
```

This is not a new idea in Ozmoo — it is exactly the shape of the C128's two-bank
map (`first_vmap_entry_in_bank_1` / `vmap_first_ram_page_in_bank_1`), which sits
a few lines above each of the five call sites. Everything is behind
`!ifdef FASTLOADER`, so a build without `-fl` assembles byte-identically.

Three things have to agree, and all three are in the code with comments saying
so:

- `vmem_page_for_index` — the runtime split
- `vmap_max_entries` in `ozmoo.asm` — segment 0's count (`vmap_unbanked_blocks`)
  plus segment 1's, rather than one subtraction across the whole range
- `make.rb` — `$vmem_blocks_in_ram` the same way, and
  `$dynmem_and_vmem_size_bank_0_max` capped at `$cc00` so the **preload** stops
  at the hole. The boot file decrunches as one contiguous run from
  `$storystart`, so it cannot jump the gap; blocks above the loader are read in
  during play. This is the same limit the C128 already uses for its bank 0.

One site is deliberately left alone: the `opt_temp + 1` conversion in
`OPTIMIZE_VMEM` only ever sees indices below `vmap_unbanked_blocks` (its search
loop counts down from there), so it is always in segment 0.

REU Boost is untouched. It has its own page-granular map
(`reu_boost_area_start_page`, one page per vmap entry, confined below
`reu_boost_hash_table`) and its path returns via `jmp .return_result` without
ever reaching any of the five sites. `first_banked_memory_page` stays `$cc`
precisely because `reu_boost_hash_table` is derived from it, which is what keeps
that hash table below the loader instead of on top of it.

### 4 — the loader works in Ozmoo's zero page

This was the one actually corrupting the game, and it is invisible from the
source: DreamLoad's resident loader keeps its working variables in zero page.
From `user_cfg/dload.cfg` in its source, and confirmed by scanning the 512-byte
binary we ship:

| DreamLoad | address | what Ozmoo keeps there (C64) |
|---|---|---|
| `LdLAE` | `$ae`, `$af` | kernal load/save end address |
| `LdGZp` | `$fc` | **`zp_temp + 1`** |
| `LdChk` | `$fd` | **`zp_temp + 2`** |

A block read happens in the middle of running Z-code, so `zp_temp` is very often
live across it. The sectors arrive perfectly — 200/200 verified against the disk
image — and the interpreter still wanders off and executes `QUIT` a few hundred
reads later. `fastloader_readblock` and `fastloader_suspend` now stash and
restore those four bytes around every call into the resident (`LoadTS` and
`SwitchOff`; `lda`/`sta` only, so `LoadTS`'s carry survives).

**If the resident blob is ever rebuilt from DreamLoad source with a different
`dload.cfg`, re-check this table.** The addresses are baked into the binary.

## How it works

Ozmoo does **not** ship DreamLoad's 4.2 KB installer. It carries the
post-install state directly (~1.3 KB):

- `asm/fastloader-drivecode.bin` — 786 bytes, the 1541 drive code, loaded into
  drive RAM at `$0300` with `M-W` in 32-byte chunks, entry `$0311`
- `asm/fastloader-resident.bin` — 512 bytes, the resident C64 loader already
  patched for the 1541, copied to `$cd00`

Resident jump table (the full one, from `ldcommon.src`):

| address | |
|---|---|
| `$cd00` | `LoadFile` — by name |
| `$cd03` | `LoadTS` — **X = track, Y = sector**, sector lands at `$cf00`, carry set on error |
| `$cd06` | `ShutUp` |
| `$cd09` | `WakeUp` |
| `$cd0c` | `LedOff` |
| `$cd0f` | `SwitchOff` — resets the drive back to normal DOS |

`$cc00-$cfff` (1 KB, 2 vmem blocks) is reserved by `VMEM_END_PAGE = $cc` — see
bug 3. **`make.rb` must agree**: it computes the preload from its own copy of the
memory map, so `$memory_end_address` moves with it. Changing only one side
silently corrupts the preload.

The loader re-installs itself lazily, from `fastloader_readblock`, but never
while a logical file is open (`$98` != 0) — re-installing talks to the bus and
would cut across whatever that file is doing. In that case the read simply falls
back to the kernal path.

## Files

Changed:

- `asm/constants.asm` — `first_banked_memory_page = $cc` under `FASTLOADER`;
  `kernal_open`/`load`/`save`/`reset` routed to the shims, with the raw `$ffxx`
  addresses kept as `kernal_*_raw`
- `asm/ozmoo.asm` — `!source "fastloader.asm"`; `jsr fastloader_init` before
  `prepare_static_high_memory`; `vmap_max_entries` counts both vmem segments
- `asm/vmem.asm` — `vmem_page_for_index` and its five call sites, all behind
  `!ifdef FASTLOADER`
- `asm/disk.asm` — branch at `.have_set_device_track_sector`, falling through to
  the kernal path when carry is set; `jsr fastloader_shutdown` in `z_ins_restart`
- `asm/zmachine.asm` — `jsr fastloader_shutdown` in `z_ins_quit`
- `make.rb` — `-fl` flag (C64 only), `-il:<n>` interleave override, memory
  reservation
- `.gitignore` — the generated `asm/flverify-table.asm`

Added:

- `asm/fastloader.asm`, `asm/fastloader-drivecode.bin`,
  `asm/fastloader-resident.bin`
- `tools/fastloader/` — test harness, see below

**`asm/zmachine.asm` is CRLF in git.** An earlier pass converted it to LF and
turned a 3-line change into a 4481-line diff. If `git diff --stat` on that file
shows thousands of lines, run `perl -pi -e 's/\r?\n/\r\n/'` on it.

## Interleave: leave it at 9

Ozmoo **already** has a sector interleave mechanism (`asm/disk.asm`, the
`.track_map` walk with `adc disk_info ; #SECTOR_INTERLEAVE`), and `make.rb`
sets `@interleave = 9` for D64. Measured REU load against it:

| interleave | Aventyr REU load |
|---|---|
| 8 | 36 s — but **one of two runs timed out** (>260 s) |
| **9 (current default)** | **40 s, reproduced twice** |
| 10 | >260 s |
| 11 | >260 s |

8 is nominally 11 % faster but sits right at the edge of the timing window; 10
and 11 fall off a cliff (miss the sector, eat a full revolution). **No change
warranted** — the whole 6x comes from the loader. `-il:<n>` remains for tuning
and defaults to 9.

Note a standalone benchmark showed no cliff at 10 (111.9 ms) while Ozmoo does.
Ozmoo does REU DMA per block, which shifts and sharpens the curve — which is
why this had to be measured inside Ozmoo, not extrapolated.

## Traps — do not re-learn these

- **VICE cannot run this.** `x64sc` returns garbage from `LoadTS` with carry
  *clear* — a silent wrong answer, not an error — and the game dies in a way
  that looks exactly like a real bug. Hours went into chasing a phantom here.
  Neither `-drive8type 1541` nor `-drive8idle 0` nor `+virtualdev8` helps.
  **Test the fast loader on hardware only.** VICE is still useful for the
  *rest* of Ozmoo: stubbing `fastloader_init` to an `rts` in the monitor is a
  clean way to check that an `-fl` build's memory layout is sound, because then
  every read takes the kernal path.
- **Never poll `machine:readmem` while the drive is working.** Each read is a
  DMA that steals C64 cycles and disturbs cycle-exact IEC timing: 5 of 11
  polled runs returned corrupt data, 0 of 5 unpolled. Drive blind and read the
  screen once, at an input prompt, when the drive is idle. `tools/fastloader/
  runprg.rb` does exactly this. A crash caused by your own polling is
  indistinguishable from a crash in the loader — both reset to BASIC.
- **A test that reads one sector twice proves nothing.** It shows the loader is
  deterministic, not that it fetched the sector that was asked for, and not that
  the bytes are right. Check against the d64 (`flverify.asm`), and check the
  *checksum of the sector's true content*, not just that two reads agree.
- **`M-E` is not equivalent to DreamLoad's bootstrap entry.** `i41.src` does
  `sei` and `sta $1800` (releasing both IEC lines) before `jmp $0311`. Entering
  via a plain `M-E` hangs. A 9-byte stub fixes it (see `.fl_entrystub`).
- **The drive blob contains one `$0d` byte at offset 765 (`$05fd`)**, which
  terminates the `M-W` command early. It is shipped as `$0c` and repaired in
  the drive by a second stub containing no `$0d`.
- **ACME**: `sec` is an opcode and cannot be used as a label. Anonymous labels
  `-` and `--` are *different* labels, not "the previous one" and "the one
  before that" — `bne --` fails unless a `--` exists.
- **Ozmoo local labels** (`.track`, `.sector`, `.device`) are zone-scoped and
  invisible from another file — pass them in registers.
- **U64 REST keyboard**: a single `"transition":"tap"` after any idle period is
  silently dropped. Use press → hold ≥60 ms → release (`hold` in `u64.rb`).
- **U64 boot**: a reset lands in BASIC; nothing autostarts as VICE does. DMA
  the PRG in with `runners:run_prg` (see `d64.rb` for pulling it out of a d64)
  — typing `LOAD"*",8,1` races the reset banner's own `ready.` and loses the
  trailing CR.
- **A bare reset to BASIC with no "fatal error" message is not a Z-machine
  error.** It means the interpreter reached `kernal_reset` through `z_ins_quit`
  — i.e. it executed a `quit` opcode out of corrupted memory. `fatalerror`
  would have printed and waited for a key first, so if you are feeding
  keystrokes you will erase the evidence: stop sending keys and read the screen.

## Licensing

DreamLoad is by **The Dreams** (the-dreams.de), **WTFPL** — no restrictions,
GPL-2 compatible (Ozmoo is GPL-2). Source:
`svn co https://svn.code.sf.net/p/rrtools/code/dload/`. The assembler
`dreamass` is in the same repo (`.../code/dreamass/trunk`, plain `make`).

`tools/fastloader/test/t41only.src` rebuilds the drive blob standalone:
`dreamass t41only.src` → `t41.bin`, 786 bytes at `$0300`. It matches the copy
inside DreamLoad's own installer byte-for-byte (found at offset 2150 of
`dload.prg`), so the blob is verifiably the real thing.

The source is worth checking out when anything is unclear — `ldcommon.src`
(jump table), `ldserial.src` (`SwitchOff`, `SendByte`), `ld41.src` (`GByte`),
`t41.src` (the drive side), `dload.src` (the installer, including the delay
after `M-E`) and `user_cfg/dload.cfg` (the zero page map) all answered questions
here that guessing did not.

## Test harness — `tools/fastloader/`

- `u64.rb` — drives an Ultimate 64 over its REST API (`U64` env var or the
  hardcoded address): mount (read-only or read-write), reset, `run_prg`,
  `readmem`/`writemem`, keyboard, `screen`
- `runprg.rb` — mount, reset, run a PRG, read the screen **once**. The
  deliberate absence of polling is the point; see the traps above.
- `gen_verify.rb` — emits `asm/flverify-table.asm`, the expected checksums for
  200 sectors spread across a given d64. Generated, not committed.
- `screens.rb` — decodes C64 screen RAM to text; parses VICE monitor dumps.
  **Take exactly 16 bytes per dump line and place by address** — VICE appends
  an ASCII gutter whose first token can look like a hex byte, and its `(C:$xxxx)`
  prompt prefixes the first line of every dump. `test_screens.rb` covers this
  (5 assertions, `ruby test_screens.rb`).
- `d64.rb` — d64 directory/sector-chain reader; extracts the boot PRG
- `measure.rb` — reset, run a benchmark PRG, parse its result line
- `test/*.asm` — standalone tests. The two that matter now are built against
  the **shipped** `asm/fastloader.asm` rather than a copy of it, so they cannot
  drift from the code:
  - `flverify.asm` — 200 sectors across the disk, each checked against the d64.
    The read-correctness test. **200 ok, 0 bad.**
  - `fltest.asm` — install → read → suspend → ordinary DOS command channel →
    re-install → read. The coexistence test. **PASS.**
  - `bench.asm` — Ozmoo's current kernal path, 40 blocks
  - `bench2.asm` — same with channels kept open (**measured identical**; the
    OPEN/CLOSE churn costs nothing, the transfer is everything)
  - `dlbench.asm` — same 40 blocks via DreamLoad's own installer
  - `blobtest.asm` — installer-free install, the design now in `fastloader.asm`
  - `coexist.asm` — demonstrates the original DOS hang
  - `k_diag.asm` — kernal read path diagnostic (per-block checksums, `ST`,
    drive error channel)
  - `linetest.asm` / `linetest2.asm` — empirically map the IEC lines both ways

Both live tests are built from `asm/` so `!source` and `!binary` resolve:

```sh
cd asm
ruby ../tools/fastloader/gen_verify.rb ../c64_game.d64 flverify-table.asm 200
acme --cpu 6510 --format cbm -DTARGET_C64=1 -DFASTLOADER=1 \
     -o /tmp/flverify.prg ../tools/fastloader/test/flverify.asm
cd .. && ruby tools/fastloader/runprg.rb /tmp/flverify.prg c64_game.d64 90
```

Verified IEC mapping (measured, not assumed):

| direction | sender | receiver sees |
|---|---|---|
| drive→C64 DATA | `$1800` bit 1 | `$dd00` bit 7 → 0 |
| drive→C64 CLK | `$1800` bit 3 | `$dd00` bit 6 → 0 |
| C64→drive CLK | `$dd00` bit 4 | `$1800` bit 2 → **1** |
| C64→drive DATA | `$dd00` bit 5 | `$1800` bit 0 → **1** |

Drive inputs read inverted (pulled low = 1); idle reads `$00`.

## Dead ends worth not repeating

- A hand-rolled transfer protocol. IEC has three wired-OR lines, so a line
  carrying data cannot also carry the handshake — the sender reads back its own
  pull. 2 bits per handshake therefore needs ATN as the third line, which is
  exactly what DreamLoad does. Use the prior art.
- "Keep the channels open instead of OPEN/CLOSE per block" — measured 452 vs
  455 ms/block. No gain. The cost is ~1.76 ms **per byte** in the transfer.
- Interleave without a fast loader — measured across gaps 1/4/8/10/16 on the
  kernal path: 431–446 ms/block, i.e. noise. Interleave only pays once the
  transfer is short enough for head position to matter.
- Reserving the loader's RAM with `first_banked_memory_page` — see bug 3. It
  looks right, it builds, it runs, and it corrupts memory once the cache fills.
- Reserving it with `VMEM_END_PAGE` instead — also see bug 3. Correct, simple,
  passes every correctness test, and ~30 % **slower than no fast loader at all**
  because it costs 26 of 62 cache blocks. Benchmark the game, not the block: the
  standalone per-block figure said 2.1x faster the whole time it was losing.
- Debugging this under VICE — see the traps. The emulator's answers were
  confidently wrong in both directions.
