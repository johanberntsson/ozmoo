all: z6

# ---------------------------------------------------------------------------
# sound: sound test. Since we don't have any z6 with sound we'll use Sherlock.
# ---------------------------------------------------------------------------

sound-sherlock-mega65:
	ruby make.rb -v -ch -t:mega65 -asw soundgame/sherlock soundgame/sherlock.z5
	# SDL/xmega65 doesn't play nice with pipewire
	SDL_AUDIODRIVER=pulseaudio xemu-xmega65 -8 mega65_sherlock.d81

# The same on the X16, where the sample is streamed into VERA's PCM FIFO from
# banked RAM (sound-x16.asm). Sherlock again: no v6 game we have has sound.
sound-sherlock-x16:
	ruby make.rb -v -ch -t:x16 -asw soundgame/sherlock soundgame/sherlock.z5
	cd x16_sherlock && SDL_AUDIODRIVER=pulseaudio ../x16-emulator46/x16emu -prg SHERLOCK.PRG -run  -dump RV -debug -zeroram

# testsound: plays the effects on demand, in the orders that have gone wrong
# (repeats, stop, two queued, loop for ever), and reports the routine argument
# being called. Works on any target that has sound; compare the two.
testsound-x16:
	inform -v5 testsound.inf
	ruby make.rb -v -ch -t:x16 -asw soundgame/sherlock testsound.z5
	cd x16_testsound && SDL_AUDIODRIVER=pulseaudio ../x16-emulator46/x16emu -prg TESTSOUND.PRG -run  -dump RV -debug -zeroram

testsound-mega65:
	inform -v5 testsound.inf
	ruby make.rb -v -ch -t:mega65 -asw soundgame/sherlock testsound.z5
	SDL_AUDIODRIVER=pulseaudio xemu-xmega65 -8 mega65_testsound.d81

# ---------------------------------------------------------------------------
# testz6: the v6 test game (grown opcode by opcode, compared against frotz).
# These are the development targets; the real games are the grid further down.
# ---------------------------------------------------------------------------

z6:
	inform -v6 testz6.inf
	ruby make.rb -s testz6.z6

# Same as z6, but with Extended Color Mode, giving each window its own
# background colour (at the price of a 64 character charset)
ecm:
	inform -v6 testz6.inf
	ruby make.rb -s -ecm testz6.z6

# testz6 on the MEGA65: the 80-column text screen, and the full colour screen
# that -fcm selects. -fcm is 80 columns on a 640x200 (H640) canvas; it should
# match `dfrotz -h 25 -w 80` line for line. -fcm:40 keeps the old 320x200,
# 40-column full colour screen, which should match `make z6` line for line,
# since both are 40 columns - that is the C64-vs-MEGA65 regression check.
z6-mega65:
	inform -v6 testz6.inf
	ruby make.rb -s -t:mega65 testz6.z6

z6-fcm:
	inform -v6 testz6.inf
	ruby make.rb -s -t:mega65 -fcm testz6.z6

z6-fcm40:
	inform -v6 testz6.inf
	ruby make.rb -s -t:mega65 -fcm:40 testz6.z6

# The same, drawing the test pictures in tools/testpics rather than "pic:N"
# notes. Those pictures are ours; tools/gen_testpics.py regenerates them.
z6-pics:
	inform -v6 testz6.inf
	ruby make.rb -s -t:mega65 -fcm -pics tools/testpics testz6.z6

# testz6 on the X16: the z6 window model on the VERA screen (80x60, text only),
# and drawing the test pictures (text on VERA layer 1, pictures on a layer 0
# tile map behind it, loaded from SD on demand).
z6-x16:
	inform -v6 testz6.inf
	ruby make.rb -s -t:x16 testz6.z6

z6-pics-x16:
	inform -v6 testz6.inf
	ruby make.rb -s -t:x16 -pics tools/testpics testz6.z6

frotz:
	inform -v6 testz6.inf
	frotz testz6.z6

# The window-local scrolling test: a small window scrolls inside a screen full
# of '#', which must survive intact. Every target must draw it the same way.
scroll:
	inform -v6 testz6scroll.inf
	ruby make.rb -s testz6scroll.z6

scroll-x16:
	inform -v6 testz6scroll.inf
	ruby make.rb -s -t:x16 testz6scroll.z6

scroll-mega65:
	inform -v6 testz6scroll.inf
	ruby make.rb -s -t:mega65 -fcm testz6scroll.z6

# ---------------------------------------------------------------------------
# The real v6 games, and dejavu (the z3 non-z6 regression game).
#
# Every game builds for every platform as <game>-<platform>, and - on the
# MEGA65 and X16, which draw pictures - with its graphics as
# <game>-pics-<platform>. All autostart in the platform's emulator.
#
#   platforms:  c64  c128  plus4  mega65  x16
#   games:      arthur  shogun  journey  zorkzero   (+ dejavu, regression)
#
# On the MEGA65 <game>-<platform> is the full colour 80-column screen (-fcm),
# the same screen the -pics target draws on, so the two differ only by the
# pictures. The C64 and Plus/4 get a target for every game even where the
# story is really too big to play comfortably (Journey especially) - the build
# itself is the useful check. Those large stories need a 1581, and the
# emulator is launched by hand with the drive set to 1581, since autostart
# alone does not pick that up.
# ---------------------------------------------------------------------------

Z6GAMES = z6games

# $(1) = target game name, $(2) = story file basename in z6games/
define game_targets
$(1)-c64:
	ruby make.rb -81 $$(Z6GAMES)/$(2).z6
	x64 -drive8type 1581 c64_$(2).d81
$(1)-c128:
	ruby make.rb -s -t:c128 -71 $$(Z6GAMES)/$(2).z6
$(1)-plus4:
	ruby make.rb -t:plus4 -81 $$(Z6GAMES)/$(2).z6
	xplus4 -drive8type 1581 plus4_$(2).d81
$(1)-mega65:
	ruby make.rb -s -t:mega65 -fcm $$(Z6GAMES)/$(2).z6
$(1)-x16:
	ruby make.rb -s -t:x16 $$(Z6GAMES)/$(2).z6
$(1)-pics-mega65:
	ruby make.rb -s -t:mega65 -fcm -pics $$(Z6GAMES)/$(2).blb $$(Z6GAMES)/$(2).z6
$(1)-pics-x16:
	ruby make.rb -s -t:x16 -pics $$(Z6GAMES)/$(2).blb $$(Z6GAMES)/$(2).z6
endef

$(eval $(call game_targets,arthur,arthur-r74-s890714))
$(eval $(call game_targets,shogun,shogun-r322-s890706))
$(eval $(call game_targets,journey,journey-r83-s890706))
$(eval $(call game_targets,zorkzero,zork0-r393-s890714))

# dejavu is a small z3 game (examples/dejavu.z3): the non-z6 regression check,
# so it has no pictures and fits the default disk of every platform.
dejavu-c64:
	ruby make.rb -s examples/dejavu.z3
dejavu-c128:
	ruby make.rb -s -t:c128 examples/dejavu.z3
dejavu-c128-80:
	ruby make.rb -t:c128 examples/dejavu.z3
	x128 -silent -80col -8 c128_dejavu.d71
dejavu-plus4:
	ruby make.rb -s -t:plus4 examples/dejavu.z3
dejavu-mega65:
	ruby make.rb -s -t:mega65 examples/dejavu.z3
dejavu-x16:
	ruby make.rb -s -t:x16 examples/dejavu.z3
dejavu-apple2:
	ruby make.rb -s -t:apple2 examples/dejavu.z3
# The conformance test games; "make apple2-conformance"
# runs them headlessly and checks them against dfrotz.
czech-apple2:
	ruby make.rb -s -t:apple2 test/czech.z5
praxix-apple2:
	ruby make.rb -s -t:apple2 test/praxix.z5
etude-apple2:
	ruby make.rb -s -t:apple2 test/etude.z5
dejavu-apple2e:
	ruby make.rb -s -t:apple2e examples/dejavu.z3
dejavu-apple2gs:
	ruby make.rb -s -t:apple2gs examples/dejavu.z3

advent-mega65:
	ruby make.rb -s -t:mega65 examples/advent_punyinform.z5
# ---------------------------------------------------------------------------
# Extras that do not fit the grid.
# ---------------------------------------------------------------------------

# Arthur on the C64 split over two 1541 drives instead of one 1581: boot +
# story 1 in drive 8, story 2 in drive 9.
arthur-c64-d2:
	ruby make.rb -D2 $(Z6GAMES)/arthur-r74-s890714.z6
	x64 -drive8type 1541 -9 c64_arthur-r74-s890714_story_2.d64 c64_arthur-r74-s890714_boot_story_1.d64

# Arthur on the C128's 80 column (VDC) screen, where the VDC window code runs.
# VICE cannot autostart a disk with the 80 column screen selected (it waits for
# a READY prompt on the VIC-II screen that never comes), so the disk is only
# attached and the game is started by typing RUN"STORY" at the BASIC prompt, as
# the player manual says.
arthur-c128-80:
	ruby make.rb -t:c128 -71 $(Z6GAMES)/arthur-r74-s890714.z6
	x128 -80col -drive8type 1571 -8 c128_arthur-r74-s890714.d71

# AMFV is a large z4 game, built as a d81 just to verify large files + d81.
amfv:
	ruby make.rb -81 amfvUnprotected.z4
	x64 -drive8type 1581 c64_amfvUnprotected.d81

# ---------------------------------------------------------------------------
# Apple II: the spike -- a standalone boot sector
# This target is to prove that the toolchain, the boot chain, the
# interleaved text page and both video encodings exists.
# ---------------------------------------------------------------------------

# Boot it in a window (AppleWin's SDL front end, sa2).
apple2-spike:
	ruby tools/apple2-spike.rb --run

# The headless check: boot it in applen, type a key, dump the text page out of
# a save state and say whether the screen is what it should be.
apple2-spike-dump:
	ruby tools/apple2-spike.rb --dump --keys z

# The same check under MAME, which reads the text page out of the running
# machine rather than out of a save state.
apple2-spike-mame:
	ruby tools/apple2-spike.rb --mame

# Boot it in a window (AppleWin's SDL front end, sa2).
apple2-rwts:
	ruby tools/apple2-rwts-spike.rb --run

# The headless check: read the payload under MAME, time it, and say whether
# every byte of it is right.
apple2-rwts-mame:
	ruby tools/apple2-rwts-spike.rb --mame

# ...and under AppleWin, which is the check that the RWTS is not simply
# agreeing with one emulator's idea of a disk.
apple2-rwts-dump:
	ruby tools/apple2-rwts-spike.rb --applen

# Every interleave, measured: sectors a second and address fields per sector
# for each skew, which is how the story data's layout gets chosen at step 2.
apple2-rwts-sweep:
	ruby tools/apple2-rwts-spike.rb --sweep

IMAGE ?= apple2_dejavu.dsk
apple2-cat:
	ruby tools/apple2-cat.rb $(OPTS) $(IMAGE)

# Measure the software clock under MAME and say what A2_POLLS_PER_JIFFY should be
STORY ?= examples/dejavu.z3
apple2-clock:
	ruby tools/apple2-clock.rb --story $(STORY) $(OPTS)

# The conformance games under MAME, their transcripts taken out of the running
# machine and compared with dfrotz. Name one (czech, praxix) to run just it.
apple2-conformance:
	ruby tools/apple2-conformance.rb $(OPTS)

clean:
	rm -rf *d64 *d71 *d81 x16_* apple2_*.dsk
