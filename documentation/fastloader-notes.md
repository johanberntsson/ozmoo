# Fast loader for C64 disk reads — handover

Adds an optional fast loader (DreamLoad) to Ozmoo's block reads on the C64,
behind the new `-fl` build flag. Committed locally on `master`, not pushed -
this is Johan's repository.

## Result

Every figure below was **re-measured this session** on the same Ultimate 64,
because the original set did not hang together: a 6x and a 2.1x cannot both
describe the same loader. Two of the four survived unchanged, one was
optimistic, and one was measuring something other than what it claimed.

| scenario | without `-fl` | with `-fl` | |
|---|---|---|---|
| one 256-byte block, standalone benchmark | 445-452 ms | 218-224 ms | **2.0x faster** |
| in-game, **no REU**, `advent_punyinform.z5` 80 KB | 36 turns / 300 s | **78 turns / 300 s** | **2.2x faster** |
| in-game, **with REU**, same game | 150 turns / 300 s | 149 turns / 300 s | **no difference at all** |
| REU bulk cache load, `Aventyr.z5` 133 KB | 241 s | 48-58 s | **4.1-5.0x faster** |
| REU bulk cache load, `advent_punyinform.z5` 80 KB | 104 s | 46 s | **2.3x faster** |

**The with-REU row used to read "102 -> 137 turns / 300 s".** That was a
measurement artefact: the 300 s window started when the REU question was
answered, so most of it was spent watching the cache load rather than playing.
Once the story is in the REU there is no disk I/O left to speed up, and the two
builds play at **the same rate** - 150 against 149 turns, one turn apart. What
`-fl` actually buys an REU owner is the one-off load at the start, and that is
the row below it. (The old numbers reconstruct exactly under that reading:
300 s minus a 104 s load at ~0.5 turns/s is ~98 turns, against the 102 recorded;
minus a 46 s load, ~127 against the 137 recorded.)

The in-game figure is the `-bm` walkthrough (`benchmarks.json`, key
`r7-s251205`), same disk, same script, one screen read at the end of a fixed
300 s window that starts when the game does. It lands almost exactly on the raw
per-block ratio, which is the point: the RAM cache costs only the 2 blocks the
loader physically occupies, so the whole transfer speedup reaches the game.

It is also **exactly reproducible**, which is worth knowing before chasing a
difference: benchmark mode seeds the PRNG fixed, so two runs of the same build
end on the same move, in the same room, with the same score. 36 and 36 without
`-fl`, 78 and 78 with it. Any variation at all means something really changed.

The per-block figures are `tools/fastloader/test/bench.asm` (Ozmoo's kernal
path) and `blobtest.asm` (the loader), 3 runs each, 40 blocks per run.

Getting there took three attempts at reserving the loader's KB — see bug 3. The
middle one built, ran, and was **~30 % slower than no fast loader at all**; if
this is ever re-worked, measure the game, not the block.

Aventyr's bulk load, run to run:

| build | runs |
|---|---|
| without `-fl` | 241.1 s, 241.1 s - identical to the second |
| with `-fl` | 48.2 s, 58.3 s, 58.2 s |

So **4.1x on the median run, 5.0x on the best**. The previous session's 239 s
baseline reproduces exactly; its 40 s did not - 48 s was the best of three here,
so the recorded "6x" was the lucky run. Quote 4x.

The ~20 % spread between `-fl` runs is the same sensitivity the interleave table
below shows: the bulk REU path sits close to a timing cliff at interleave 9, so
where the head happens to be when the load starts is worth ten seconds. The
no-`-fl` runs do not vary at all, because the kernal path loses a whole
revolution per block either way and has nothing left to lose.

**Why the bulk path beats the per-block ratio**: the standalone ~450 ms -> ~220 ms
is one block in isolation. A bulk cache load reads *consecutive* sectors, where
the interleave earns its keep - the loader is back in time for the next sector,
the kernal path is not. That is also why interleave moves this measurement off a
cliff and moves a standalone block benchmark hardly at all. It is also why the
same measurement on the 80 KB game is only 2.3x: less of the load is the long
consecutive run where that pays, and more of it is fixed startup.

The REU path caches the whole game up front and then does no disk I/O, so the
RAM cache does not come into it.

## What it needs, what it gives, how it fails

**To use it:** build with `-fl`. Off by default.

**Requirements**, all of which are checked:

| | |
|---|---|
| target | C64 only — `make.rb` errors out on any other target |
| drive | a **1541 or 1541-II**, identified by ROM signature (`$fea0` = `$0d`, `$e5c6` = `$34 $b1`). A 1571, 1581, sd2iec, Pi1541 or similar is rejected |
| bus | that 1541 must be the **only** drive on the bus - see *Bug 5* |
| device | 8–11, and only the drive the game booted from |
| RAM | 1 KB at `$cc00-$cfff` (2 vmem blocks) plus 2 KB of program image; the dynmem ceiling drops 3 KB, and REU Boost may have to go - see *What `-fl` costs at build time* |

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
| a second drive answers on 8-11 | `.fl_alone_on_bus` | never installs, kernal path, **says so at boot** |
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

**Will it fail without a clear reason why?** One way remains:

1. **`LoadTS` has no timeout.** Its handshake loops (`bvc`/`bmi` in
   `ldserial.src` and `ld41.src`) spin forever. If the drive stops answering
   mid-transfer — door opened, cable pulled, a drive that passed the ROM check
   but cannot actually run the code — the machine **hangs**, and no fallback can
   help because nothing regains control. The kernal path has device-not-present
   timeouts; this does not. Inherent to DreamLoad, but a real behaviour change.
(A second one used to be listed here — "under VICE it returns wrong answers".
**Withdrawn**: VICE runs this correctly, see *VICE runs it after all*.)

## Status

Four bugs found and fixed along the way — one of them was silently corrupting
memory in any game big enough to fill the cache, which is why this could look
finished when it was not. See *Five bugs*. The three items the last handover
left as pull-request blockers are all closed; see *Cleared since the last
handover*.

Verified on hardware (Ultimate 64; `examples/advent_punyinform.z5`, 80 KB,
unless another game is named):

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
- Under **VICE** (3.8 r45032, stock settings): `flverify` 200 ok 0 bad,
  `fltest` PASS, and the game plays with 137 `LoadTS` calls on a tracepoint -
  the same answers as hardware, to the byte.
- A build **without** `-fl` still plays correctly after the `vmem.asm` change;
  every edit there is behind `!ifdef FASTLOADER`, so it assembles identically.
- A **v6** game (`testz6.z6`) with `-fl` prints the same screen as the same
  build without it.
- **Two-disk** games swap disks at boot with the loader installed:
  `Sherlock.z5` and `Bureaucr.z4` both cache disk 1, take the swap and play.
- With a **second drive** on the bus the loader declines and the game plays on
  the kernal path - `Sherlock.z5 -D2` across devices 8 and 9, and a single-disk
  game with an empty drive 9. Both **hung** before this was handled; see
  *Bug 5*.

Build matrix: **26 ok, 2 failures, neither a `-fl` regression** — `testz6.z6`,
`examples/dejavu.z3`, `test/praxix.z5` across
default/`-t:c128`/`-t:plus4`/`-t:mega65`/`-t:x16`/`-smooth:1`,
`-t:mega65 -fcm` and `-fcm:40` for the v6 game, `-ecm`, and `-fl`, `-fl:0`,
`-il:8`. `-fl -sb:1 testz6.z6` is refused because v6 has no scrollback buffer at
all, and `-fl -re:1 testz6.z6` overflows the init area by two bytes (`-sp:5`
fixes it; `-ecm -re:1` overflows it with no `-fl` anywhere). See *What `-fl`
costs at build time*.

### Tested against real Infocom games

Five games built both ways (`spellbreaker` 150 KB, `hitchhiker` 158 KB,
`ballyhoo` 150 KB, `lurkinghorror` 127 KB, `planetfall` 126 KB), on an
Ultimate 64:

- **No REU: 10/10.** Both builds of all five reach their opening room with
  identical text.
- **40-turn soak, `-fl`, no REU: 5/5.** Walking each game around for 40 moves
  so the RAM cache turns over many times - no corruption, no reset, every one
  still at a live prompt with sane text afterwards. Reaching the opening room
  is *not* a sufficient test: the zero-page bug (bug 4) did not show until the
  cache had cycled several times.
- **REU: `planetfall` passes both ways.**

### Two games hang caching to REU - NOT caused by this change

`spellbreaker` (150 KB) answering Y to "Use REU" stalls partway through the
cache load, at five progress marks, and never recovers. **It does this on the
stock build with no fast loader**, so it is pre-existing and not ours.
Confirmed properly: it stalls for 600 s with *zero* memory reads from the test
harness, so it is not the DMA hazard below, and poking a key does not move it -
genuinely hung, not waiting for input. The Ultimate's REU is enabled at 16 MB,
so it is not a size limit on the hardware side. `planetfall` at 126 KB caches
fine, so it looks size-related somewhere above that. Not investigated further.

`BeyondZo.z5` (276 KB, `-D2`) does the same on its **second** story disk, and
also does it with no fast loader: the stock build reaches the same prompt and
then resets to BASIC while caching disk 2. Two games now, both above 126 KB,
both pre-existing. Worth one line in the PR so a reviewer does not read it as
fallout from this change.

### Not verified

- **Restore.** In-game restore reports "Failed restore." on the Ultimate 64 —
  but it does so **identically with and without `-fl`**, so it is not a fast
  loader regression. It is either the U64's read-write d64 mount or the test
  harness; it was not chased down. Save is verified, restore is not.
- CLAUDE.md's line-for-line screen check of `testz6` C64 vs `-t:mega65 -fcm:40`
  — `xemu-xmega65` is not installed on this machine. The change does not touch
  the screen layer, but that is reasoning, not a result.

## What is left before this is a pull request

**Nothing blocking.** All three items the previous handover listed are closed;
what is left is the ordinary list of things nobody has got to, below.

### Also outstanding

- **Real hardware.** Everything here ran on an Ultimate 64's emulated 1541.
  Never a physical 1541 or 1541-II, never a real C64, never NTSC. The two
  delays in `fastloader.asm` (~1 s waiting out the drive reset, ~50 ms settling
  after `M-E`) were tuned against that one machine.
- **Restore.** Save is verified; restore reports "Failed restore." - but does so
  identically without `-fl`, so it is not a regression here. It should be made
  to work, or at least explained, before anyone claims save/restore is fine.
- **`LoadTS` has no timeout.** A drive that stops answering hangs the machine
  with no fallback. Inherent to DreamLoad; worth stating in the PR.
- CLAUDE.md's line-for-line `testz6` C64 vs `-t:mega65 -fcm:40` screen check -
  `xemu-xmega65` is not installed on this machine.

It is also Johan's repository: commit locally, never push without permission.

## Cleared since the last handover

### VICE runs it after all — was blocker 3

The previous handover said `LoadTS` under `x64sc` "returns carry clear with a
buffer of garbage" and that the fast loader could only be tested on hardware.
**That is wrong.** Measured this session on VICE 3.8 r45032 (`x64sc`), stock
settings, against `c64_advent_punyinform.d64` built with `-fl`:

| test | VICE | hardware (U64) |
|---|---|---|
| `flverify.prg`, 200 sectors checked against the d64 | **200 ok, 0 bad** | **200 ok, 0 bad** |
| `fltest.prg` install → read → suspend → DOS → resume → read | **PASS**, sig `$34b1`, cksum `$2b75` | **PASS**, sig `$34b1`, cksum `$2b75` |
| the real `-fl` game, 8 commands deep | plays correctly; **141 calls to `fastloader_readblock`, 137 to `LoadTS`** on a monitor tracepoint, so the loader really served the reads | plays correctly |

The two emulator answers match the two hardware answers byte for byte. So
`-fl` is testable the usual way, and the "hours chasing a phantom" were spent
on something else.

**What actually goes wrong under VICE**, and only for the standalone tests:

- **A VICE 1541 stepper bug.** `src/drive/iecieee/via2d.c`, `store_prb()` moves
  the head **twice** for one `$1c00` write — the normal path at :307-312 and
  again in the `#if 1` block at :338-351 (labelled as a fix for VICE bug #1083),
  which has no ±1 restriction. On a drive that has never seeked, DreamLoad's
  motor-on write lands the head on an **odd half track**, which is unformatted,
  so `rotation_sync_found()` never sees SYNC and the drive code spins in
  wait-for-SYNC for ever. Both sides hang; nothing returns a wrong answer.
  (Traced with a watchpoint on `current_half_track`; forcing
  `drive_set_half_track(38, …)` at the moment of the hang makes the same run
  finish 200 ok.)
- **Ozmoo never hits it**, because the kernal has loaded the boot file from the
  disk long before `fastloader_init` runs, so the head has seeked and the
  stepper phase agrees with it. That is why the game plays but the injected test
  hung.
- The standalone tests now do the same thing on purpose:
  `seek_the_head_first` in `flverify.asm` / `fltest.asm` reads the directory
  with a kernal `LOAD` before `fastloader_init`. **Both halves are load-bearing
  and were measured**: with the seek removed the injected test hangs after
  printing its title; without the `$ba` default it prints "no 1541", because an
  injected PRG never went through a kernal `LOAD` and `CURRENT_DEVICE` is still
  0.

Worth reporting upstream to VICE: one PRB write should produce at most one
stepper transition. The reproducer is the injected `flverify.prg` with the seek
taken out — it hangs with zero prior disk access.

**The old "carry clear with garbage" symptom was never reproduced here**, on
3.8 r45032 or on a 3.10 r46236 tree build. It may have been the zero-page
corruption later fixed as bug 4, or an older VICE. Unknown, and no longer worth
chasing.

How to run them:

```sh
cd asm
ruby ../tools/fastloader/gen_verify.rb ../c64_advent_punyinform.d64 flverify-table.asm 200
acme --cpu 6510 --format cbm -DTARGET_C64=1 -DFASTLOADER=1 \
     -o /tmp/flverify.prg ../tools/fastloader/test/flverify.asm
cd ..
x64sc -default -warp +sound -limitcycles 900000000 -autostartprgmode 1 \
      -8 c64_advent_punyinform.d64 -exitscreenshot /tmp/shot.png \
      -autostart /tmp/flverify.prg
```

`-autostartprgmode 1` is required: the default replaces the attached image with
the PRG's own disk, and the test then has no d64 to read. `-drive8truedrive` is
**already on by default**, so the previous handover's flag experiments were all
no-ops.

### z6 builds and runs - was blocker 1

The previous handover said "the z6 branch has never been built with this".
**In this repository there is no separate z6 branch**: `git branch -a` has only
`master` and `c128-vdc`, the remote has only `master`, and `master` already
carries `screen-z6.asm`, `screenkernal-z6.asm` and the rest of the v6 work. So
the shared-code check CLAUDE.md asks for is the ordinary build matrix, plus a
v6 game actually running the new path.

Both now done:

- `ruby make.rb -fl testz6.z6` builds, and **runs on hardware** (Ultimate 64,
  REU declined so every read goes through the loader). Its screen is
  **identical, line for line, to the same build without `-fl`**.
- Build matrix in a clean worktree, 26 ok / 2 fail: `testz6.z6`,
  `examples/dejavu.z3`, `test/praxix.z5` across default, `-t:c128`, `-t:plus4`,
  `-t:mega65`, `-t:x16`, `-smooth:1`; `-ecm`; `-t:mega65 -fcm` and `-fcm:40`;
  `-fl` on all three games; `-fl:0`; `-il:8 -fl`.
- The two failures are **not** `-fl` regressions: `-fl -sb:1 testz6.z6` is
  refused because the scrollback buffer is not supported in v6 at all, and
  `-fl -re:1 testz6.z6` overflows - see *What -fl costs at build time* below.

The kernal shims (`kernal_open`/`load`/`save`/`reset`) reach the v6 forks too,
since `constants.asm` is shared. Nothing in `screen-z6.asm` or
`screenkernal-z6.asm` calls them; on a C64 `-fl` build the only shim users are
`disk.asm`, `reu.asm`, `sound.asm`, `vmem.asm`, `utilities.asm` and
`zmachine.asm`. `pictures-mega65.asm`, `pictures-x16.asm` and `sound-x16.asm`
also call `kernal_open`, but `-fl` is C64-only so they never see a shim, and
`picloader.asm` is a standalone PRG with its own origin, built without
`FASTLOADER`.

### Multi-disk games, disk swapping and two drives - was blocker 2

The previous handover assumed a mid-game swap. There isn't one: the manual
(`documentation/manual/manual.md`, line 332) says a `D2`/`D3` game needs **two
drives, or one drive and an REU**. Story data is never swapped mid-game.
`print_insert_disk_msg` fires in exactly two places - `insert_disks_at_boot` in
`ozmoo.asm`, which asks for each further story disk while it bulk-loads it into
the REU, and `.insert_save_disk`/`.insert_story_disk` in `disk.asm` for saves.

So the swap that matters happens **at boot, while the loader holds the drive
captive**. Tested on hardware, one drive, REU accepted, disk 2 mounted at the
prompt:

| game | size | result |
|---|---|---|
| `Sherlock.z5` `-D2 -fl` | 188 KB | **pass** - disk 1 cached, swap, disk 2 cached, opening room correct, `look`/`inventory`/`south` all sane |
| `Bureaucr.z4` `-D2 -fl` | 243 KB | **pass** - same, and the licence-application form renders correctly |
| `BeyondZo.z5` `-D2 -fl -rb:0` | 276 KB | **fails caching disk 2** - one progress mark, then nothing for 300 s |

Beyond Zork is **not** a `-fl` regression: the same build **without** `-fl`
reaches the same prompt (disk 1 in 296 s against the fast loader's <140 s, the
expected 2.1x) and then dies caching disk 2 too - it reset to BASIC. Same family
as the Spellbreaker REU stall above, which is also pre-existing and also only
appears above ~126 KB.

Timing note: Beyond Zork's story disk 1 caches in **296 s without `-fl`, and in
under 140 s with it**. The 140 is a *bound*, not a measurement - it is a fixed
sleep at which the prompt had already appeared - so read it as "at least 2.1x",
not as 2.1x. The measured figure for this path is Aventyr's, above.

The **other** way the manual allows a multi-disk game - two drives - was run
too, and it found a hang that had nothing to do with disk swapping: any second
drive on the bus breaks the loader, whether or not it holds a story disk. The
loader now declines to install when it finds one. See *Bug 5*.

### What `-fl` costs at build time

This is the part that will surprise someone, and it was not written down
before. `-fl` raises `$storystart` by **2 KB** (the 1298 bytes of blob plus this
file's code, page-rounded) and takes **1 KB** more for the resident. So:

- **The dynmem ceiling drops by 3 KB**, 36864 -> 33792 bytes on the C64. A game
  whose dynamic memory lands in that window builds without `-fl` and fails with
  it.
- **REU Boost wants 3 KB of unbanked RAM, which is exactly what `-fl` takes.**
  `BeyondZo.z5` builds with `-D2` and fails with `-D2 -fl`; `-D2 -fl -rb:0`
  builds. `make.rb` now says so in both error messages rather than leaving the
  reader to work out that the fast loader is the reason.
- **The 1 KB of one-shot init that lives in the stack area is nearly full on a
  v6 build.** `-re:1 testz6.z6` ends at `$53fe` of a `$5400` limit - one byte
  spare - and `-fl` needs two more, so `-fl -re:1 testz6.z6` fails to assemble
  ("Produced too much code", `ozmoo.asm:3193`). `-sp:5` fixes it. This is a
  pre-existing tightness, not something `-fl` created: `-ecm -re:1 testz6.z6`
  overflows the same limit with no fast loader anywhere.

Games too big for the C64 either way, checked so they are not re-checked:
`Trinity.z4` and `Amfv.z4` both have 37888 bytes of dynamic memory, over the
36864 the C64 allows even without `-fl`.

## Five bugs

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
Anything else leaves `fastloader_enabled = 0` and every read falls back to the
kernal path.

What each drive actually does, measured under VICE with `-drive8type` (this
handout used to claim the 1541-II was rejected, which is **wrong** and mattered,
since that is most of the surviving drives):

| `-drive8type` | signature | result |
|---|---|---|
| 1541 | `$34b1` | installs; `flverify` **200 ok, 0 bad** |
| 1542 (**1541-II**) | `$34b1` | installs; `flverify` **200 ok, 0 bad** |
| 1571 | `$37b1` | rejected, "no 1541 found" |
| 1581 | `$ff00` | rejected, "no 1541 found" |

So the 1541-II is not merely tolerated, it reads every one of 200 test sectors
correctly - which stands to reason, as its DOS ROM is the 1541's. An sd2iec or
Pi1541 has not been tried and is presumed rejected on signature; nothing has
been measured either way.

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

### 5 — a second drive on the bus hangs the machine — fixed

Found by finally running the two-drive case the last handover listed as
untested. Two shapes, both a **hang**, both measured on an Ultimate 64 with its
drive B switched on:

- `Sherlock.z5 -D2 -fl` across devices 8 and 9. Ozmoo's `auto_disk_config` puts
  story disk 2 on device 9 when there is no REU, the kernal reads it over the
  same bus while our drive is captive, and the machine freezes on the game's
  title screen. The same build **without** `-fl` plays fine on the same two
  drives, so it is ours.
- A **single-disk** game with drive 9 switched on and holding no disk at all.
  Nothing ever addresses device 9, and it still hangs a few blocks in.

The cause is DreamLoad's protocol, not Ozmoo's disk handling: it clocks its
data by toggling ATN, and any other IEC drive answers an ATN low by pulling
DATA to acknowledge - the same line the loader is reading.

**The fix is to not install.** `.fl_alone_on_bus` LISTENs to each of devices
8-11 that is not ours; a drive that is not there sets `ST` bit 7 and an absent
bus costs one kernal timeout each, once, at boot. If anything answers, the
loader stays off and says

```
Fast loader off: another drive found.
```

Two things that look like details and are not:

- **`ST` is sticky.** It must be cleared before each probe, or the first absent
  drive's `$80` answers for all of them - and cleared again afterwards, or
  `.fl_install` reads that `$80`, decides the drive never took its code, and
  gives up on a perfectly good 1541. That failure prints "no 1541 found", which
  sends you looking in exactly the wrong place.
- **Checking Ozmoo's own disk table instead is not enough**, and that was the
  first fix tried. It catches the `-D2`-on-two-drives case and passes a machine
  whose second drive holds nothing - which is the second case above, and still
  hangs. Costing a few kernal timeouts at boot is the price of covering both.

Handing the drive back at the first foreign read was also tried and is worse:
`SwitchOff`'s own handshake has no timeout, and the other drive can hold the
line it waits for.

What still works, verified after the fix: `flverify` 200/200 and `fltest` PASS
on hardware and under VICE; the two-drive Sherlock declines and plays; a
single-disk game with drive 9 on plays; and one drive plus an REU - the other
way the manual allows a multi-disk game to be played - still installs the
loader and keeps the full speedup.

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

`$cc00-$cfff` (1 KB, 2 vmem blocks) is carved out of the RAM cache by
`$unbanked_ram_end_address = 0xcc00` in `make.rb` and by `vmem_page_for_index`
in `vmem.asm`, which maps the cache as two segments with the loader in the hole
between them — see bug 3, and do **not** reach for `VMEM_END_PAGE`, which is
the attempt that measured slower than no fast loader at all. **`make.rb` must
agree with the runtime**: it computes the preload from its own copy of the
memory map, so changing only one side silently corrupts the preload.

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
  reservation, and a hint on the two errors `-fl` can cause by itself (the
  dynmem ceiling and REU Boost's 3 KB)
- `.gitignore` — the generated `asm/flverify-table.asm`

Added:

- `asm/fastloader.asm` (`.fl_alone_on_bus`, bug 5),
  `asm/fastloader-drivecode.bin`,
  `asm/fastloader-resident.bin`
- `tools/fastloader/` — test harness, see below. `flverify.asm` and
  `fltest.asm` gained `wait_a_sec` and `seek_the_head_first`; without the first
  they no longer assembled at all against the shipped `asm/fastloader.asm`

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
warranted** — the whole speedup comes from the loader. `-il:<n>` remains for tuning
and defaults to 9.

Note a standalone benchmark showed no cliff at 10 (111.9 ms) while Ozmoo does.
Ozmoo does REU DMA per block, which shifts and sharpens the curve — which is
why this had to be measured inside Ozmoo, not extrapolated.

## Traps — do not re-learn these

- **VICE runs this fine — the older note here saying otherwise was wrong.**
  200/200 sectors, `fltest` PASS, and the game plays, all matching hardware.
  What does bite is a VICE 1541 stepper bug that hangs any program talking to
  the drive **before the drive has ever seeked**; Ozmoo is never such a program
  (the kernal loads its boot file first), and the standalone tests seek on
  purpose in `seek_the_head_first`. Details under *VICE runs it after all*.
  Two flag notes worth keeping: `-drive8truedrive` is on by **default**, so
  toggling it proves nothing, and injecting a PRG next to an attached d64 needs
  `-autostartprgmode 1` or VICE swaps the disk out from under the test.
- **After changing an Ultimate 64 drive setting, write any config value before
  measuring anything.** Enabling or disabling drive B leaves the U64's IEC
  subsystem in a state where the loader reads garbage - `flverify` drops from
  200/200 to "bad t/s 01/00", on *committed* code, and it survives
  `machine:reboot`. Writing any config key over the REST API clears it (a
  no-op write of `Printer Settings/Bus ID` to the value it already had is
  enough). Hours went into bisecting Ozmoo for this; the tell is that the last
  known-good commit fails the same way, so build the previous commit in a
  worktree and run it before believing a regression is yours.
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
    The read-correctness test. **200 ok, 0 bad**, on hardware *and* under VICE.
  - `fltest.asm` — install → read → suspend → ordinary DOS command channel →
    re-install → read. The coexistence test. **PASS**, on both.
  - Both start with `seek_the_head_first`: default `CURRENT_DEVICE` to 8 when it
    is not a drive (an injected PRG never went through a kernal `LOAD`, so `$ba`
    is 0), then read the directory so the drive has seeked. Without the first
    the test says "no 1541"; without the second it hangs under VICE. Ozmoo needs
    neither - it has loaded its boot file by then - so this is test setup, not a
    workaround in the shipped code.
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

Under VICE instead of hardware, same PRG (see *VICE runs it after all* for why
`-autostartprgmode 1` is not optional):

```sh
x64sc -default -warp +sound -limitcycles 900000000 -autostartprgmode 1 \
      -8 c64_game.d64 -exitscreenshot /tmp/shot.png -autostart /tmp/flverify.prg
```

Do **not** write the test PRG onto the d64 it is checking: the write lands in
sectors the table was generated from, and the test then reports them bad
(measured: 198 ok, 2 bad, both "want $0000", both sectors the PRG now occupies).

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
- Believing "VICE cannot run this". It can, and always could; the failure that
  was seen is a hang from a VICE head-stepping bug that only a program touching
  a never-seeked drive can trigger. A whole PR blocker rested on a symptom
  ("carry clear with garbage") that nobody could reproduce afterwards. When an
  emulator seems to be lying, re-measure before writing it down.
