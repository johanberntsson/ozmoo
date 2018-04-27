Ozmoo
=======
*Ozmoo (spell): survive unnatural death*

A Z-machine interpreter for the Commodore 64 

Written by Johan Berntsson and Fredrik Ramsberg, 2018

Building and running
-----

You need to install the Acme cross-assembler and the Vice C64 emulator.

Acme can be downloaded from [SourceForge](https://sourceforge.net/projects/acme-crossass/)

Vice is available on Debian/Ubuntu with:
> sudo apt-get install vice

First enter d64toinf and type "make" to create an floppy containing a
Z-machine story file in the old Infocom floppy format (dejavu.d64).

Once dejavu.d64 exists, then use the main Makefile (type "make") to
compile the z-code interpreter and create a new floppy image containing
both the story file and the interpreter (ozmoo.d64 image). If there
are no errors "make" will also start vice with the new d64 image preloaded
for testing.

