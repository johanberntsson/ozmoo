#Ozmoo

*Ozmoo (spell): survive unnatural death*

A Z-machine interpreter for the Commodore 64 

Written by Johan Berntsson and Fredrik Ramsberg, 2018

## Building and running

You need to install the Acme cross-assembler and the Vice C64 emulator. You also need to prepare a C64 floppy with the ZMachine story on. Either use the supplied d64toinf/dragontroll.d64 or prepare a new file using the utilities in d64toinf. Typing "make" on Linux will build inftod64 and prepare dejavu.d64.

### Linux

Acme can be downloaded from [SourceForge](https://sourceforge.net/projects/acme-crossass/)

Vice is available on Debian/Ubuntu with:
> sudo apt-get install vice

The default target of the Makefile (type "make") will compile the
z-code interpreter and create a new floppy image containing both
a sample story file (DragonTroll) and the interpreter. If there
are no errors "make" will also start vice with the new d64 image
preloaded for testing.

### Windows

Use the build.ps1 script to build and test the interpreter.

