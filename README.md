# Ozmoo

*Ozmoo (spell): survive unnatural death*

A Z-machine interpreter for the Commodore 64 

Written by Johan Berntsson and Fredrik Ramsberg, 2018

## Motivation

We were looking for a redistrubutable interpreter of Infocom and Inform games that could be used for new interactive fiction works on the C64.

While the old Infocom interpreters are still available, the license situation is not clear so it is risky to use in new work, especially commercial. Furthermore, newer Inform-based games are unlikely to run on this interpreter.

There are some alternate implementations, but they have some limitations:
* [Infocom64](https://github.com/christopherkobayashi/infocom64) is based on assembly code of the original Infocom interpreter so it has the same license issues
* [Zeugma](https://www.linusakesson.net/software/zeugma/index.php) doesn't support save and restore

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

