all: z6

z6:
	inform -v6 testz6.inf
	ruby make.rb -s testz6.z6

# Same as z6, but with Extended Color Mode, giving each window its own
# background colour (at the price of a 64 character charset)
ecm:
	inform -v6 testz6.inf
	ruby make.rb -s -ecm testz6.z6

# testz6 on the MEGA65: the 80-column text screen, and the 320x200 full colour
# screen that -fcm selects. The FCM one should match `make z6` line for line,
# since both are 40 columns.
z6-mega65:
	inform -v6 testz6.inf
	ruby make.rb -s -t:mega65 testz6.z6

z6-fcm:
	inform -v6 testz6.inf
	ruby make.rb -s -t:mega65 -fcm testz6.z6

frotz:
	inform -v6 testz6.inf
	frotz testz6.z6

# AMFV is a large z4 game (just to verify d81)
AMFV = amfvUnprotected
amfv:
	ruby make.rb -81 $(AMFV).z4
	x64 -drive8type 1581 c64_$(AMFV).d81

# Arthur is a real z6 game. It boots and plays; the places where it would show
# a picture get a "pic:N" note instead. Its story file is too big for a 1541,
# so it is built either for a 1581, or for a two drive system with boot +
# story 1 in drive 8 and story 2 in drive 9.
Z6GAMES = z6games
ARTHUR = arthur-r74-s890714

arthur:
	ruby make.rb -81 $(Z6GAMES)/$(ARTHUR).z6
	x64 -drive8type 1581 c64_$(ARTHUR).d81

arthur-d2:
	ruby make.rb -D2 $(Z6GAMES)/$(ARTHUR).z6
	x64 -drive8type 1541 -9 c64_$(ARTHUR)_story_2.d64 c64_$(ARTHUR)_boot_story_1.d64

# Arthur on the MEGA65, as 80-column text and on the full colour screen.
# Neither draws pictures: draw_picture still writes its "pic:N" note.
#
# -re:0 turns off CHECK_ERRORS, which make.rb otherwise forces on for MEGA65.
# Arthur does a modulo by zero after picture_data tells it there are no
# pictures, so with the check on it stops with FATAL ERROR: 17. The C64 build
# runs the same instruction and does not notice. See todo.txt; step 4 removes
# the need for this.
arthur-mega65:
	ruby make.rb -s -t:mega65 -re:0 $(Z6GAMES)/$(ARTHUR).z6

arthur-fcm:
	ruby make.rb -s -t:mega65 -re:0 -fcm $(Z6GAMES)/$(ARTHUR).z6

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
