all: z6

z6:
	inform -v6 testz6.inf
	ruby make.rb -s testz6.z6

# Same as z6, but with Extended Color Mode, giving each window its own
# background colour (at the price of a 64 character charset)
ecm:
	inform -v6 testz6.inf
	ruby make.rb -s -ecm testz6.z6

frotz:
	inform -v6 testz6.inf
	frotz testz6.z6

# Arthur is a real z6 game. It doesn't fit on one disk, so it's built for a
# two drive system: boot + story 1 in drive 8, story 2 in drive 9.
# It currently crashes on startup, most likely in the graphics opcodes (which
# are untested dummies) used by its intro screen.
ARTHUR = arthur-r74-s890714
arthur:
	ruby make.rb -D2 $(ARTHUR).z6
	x64 -drive9type 1541 -9 c64_$(ARTHUR)_story_2.d64 c64_$(ARTHUR)_boot_story_1.d64

c64:
	ruby make.rb -s examples/dejavu.z3

x16:
	ruby make.rb -s examples/dejavu.z3 -t:x16

mega65:
	ruby make.rb -s examples/dejavu.z3 -t:mega65

plus4:
	ruby make.rb -s examples/dejavu.z3 -t:plus4

clean:
	rm -rf *d64 *d71 *d81 x16_*
