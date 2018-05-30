# Ozmoo

*Ozmoo (spell): survive unnatural death*

A Z-machine interpreter for the Commodore 64 

Written by Johan Berntsson and Fredrik Ramsberg in 2018

## Motivation

We were looking for a redistrubutable interpreter of Infocom and Inform games that could be used for new interactive fiction works on the C64.

While the old Infocom interpreters are still available, the license situation is not clear so it is risky to use in new work, especially commercial. Furthermore, some of the newer newer Inform-based games use features which the old Infocom interpreters on the C64 can't handle.

There are some other implementations, but they have some limitations:
* [Infocom64](https://github.com/christopherkobayashi/infocom64) is based on assembly code of the original Infocom interpreter so it has the same license issues. Also, it only works with certain setups of hardware or emulation.
* [Zeugma](https://www.linusakesson.net/software/zeugma/index.php) requires an REU (Ram Expansion Unit) and doesn't support save and restore.

## Building and running

You need to install the Acme cross-assembler and the Vice C64 emulator. You also need to prepare a C64 floppy with the ZMachine story on. Either use the supplied d64-files in the examples folder, or create your own with the create_d64.rb utility program (requires that Ruby is installed on your computer, and that you have access to a Z-machine story file).

### Linux

Acme can be downloaded from [SourceForge](https://sourceforge.net/projects/acme-crossass/)

Vice is available on Debian/Ubuntu with:
> sudo apt-get install vice

The Makefile includes various targets that will compile the
z-code interpreter and create a new floppy image containing both
a story file (Dejavu, if the command is "make dejavu") and the
interpreter. If there are no errors make will also start vice
with the new d64 image preloaded for testing.

### Windows

Use the build.ps1 script to build and test the interpreter. Example:

.\build.ps1 -Type z5 -Run
