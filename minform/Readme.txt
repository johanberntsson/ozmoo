mInform 1.1
-----------------------------------------------------------------------

The mInform library is a replacement library for Inform. I've managed to
squeeze them down to 19K (one room, one object). 

Things that were cut: Multiple object handling (take all, take three
coins, etc), Plurals, darkness, reduced lookmodes, reduced inventory
list management, clock support, oops/undo processing, compound commands
(open chest and take all from it), some lesser used verbs (but not
many), he/she/it processing and a huge reduction of library responses
(mostly by combining similar ones). Timers are limited to 4 and text
input to 64 characters. Amazingly enough, what's left does retain a very
Inform-like feel. 

The library works with Inform 6.30 and 6.21 but not for v3 files (that
is still a compiler issue). Currently the "describe" property must be a
routine.

With the 6.15 compiler (the last to support v3 files) mInform will
produce the smallest Z code files and can produce the full range of
v3-v8 files. This will be the recommended target compiler as it is still
available for most machines in the IF archive.

I compiled a 3 room 5 object and 1 NPC game and it was only 21K - and
converted it for use on the C64 and it ran rather well (much faster as
the processing and memory usage within the library has been greatly
reduced). This 3 room game is included as a sample with the library
(MINFORM.INF). I've compiled games like CIA.INF (30 sparse rooms
and an additional 60 objects) and it works out to only 30K. 

This library is, essentially, still the property of those caretakers of
Inform. Nothing more was done than to pair it down. I thank the Inform
team for their hard work and ongoing efforts!

Dave Bernazzani
November 2004

Release History
-------------------------
1.0 - Initial Release
1.1 - Added back in SCRIPT ON and SCRIPT OFF. Fixed spelling mistake on "possession".




