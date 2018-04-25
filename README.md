TERP
=======
Johan Berntsson, 2018

A Z-machine interpreter for the Commodore 64 

Building and running
-----

You need to install the xa65 assembler and the vice C64 emulator.

On Debian/Ubuntu:
> sudo apt-get install xa65 vice

First enter d64toinf and type "make" to create an floppy containing a
Z-machine story file in the old Infocom floppy format (dejavu.d64).

Once dejavu.d64 exists, then use the main Makefile (type "make") to
compile the z-code interpreter and create a new floppy image containing
both the story file and the interpreter (c64-zterp.d64 image). If there
are no errors "make" will also start vice with the new d64 image preloaded
for testing.

