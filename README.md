# Ozmoo

*Ozmoo (spell): survive unnatural death*

A Z-machine interpreter for the Commodore 64 

Written by Johan Berntsson and Fredrik Ramsberg in 2018

![Minizork running on Ozmoo](https://github.com/johanberntsson/ozmoo/blob/master/screenshots/minizork.png)


## Motivation

We were looking for a redistributable interpreter of Infocom and Inform games that could be used for new interactive fiction works on the C64.

While the old Infocom interpreters are still available, the license situation is not clear so it is risky to use in new work, especially commercial. Furthermore, some of the newer Inform-based games use features which the old Infocom interpreters on the C64 can't handle.

There are some other implementations, but they have their limitations:
* [Infocom64](https://github.com/christopherkobayashi/infocom64) is based on assembly code of the original Infocom interpreter so it has the same license issues. Also, it only works with certain setups of hardware or emulation.
* [Zeugma](https://www.linusakesson.net/software/zeugma/index.php) requires an REU (Ram Expansion Unit) and doesn't support save and restore.

## Building and running

You need to install:
* Acme cross-assembler
* Exomizer file compression program
* Vice C64 emulator
* Ruby (Tested with 2.4.2, but most 2.x versions should work fine)

Edit the file make.rb. At the top of the file, you need to specify paths to the Acme assembler, the Vice C64 emulator, and the program "1541" which is also included in the Vice distribution.

To build a game, you run something like "ruby make.rb game.z5" Add -p to make the game start in Vice when it has been built. Run make.rb without arguments to view all options.

### Linux

Acme can be downloaded from [Github](https://github.com/meonwax/acme) and compiled.

Exomizer can be downloaded from [Bitbucket](https://bitbucket.org/magli143/exomizer/wiki/Home) and compiled.

Vice is available on Debian/Ubuntu with:
> sudo apt-get install vice

Ruby is available on Debian/Ubuntu with:
> sudo apt-get install ruby

### Windows

Acme can be downloaded from [SourceForge](https://sourceforge.net/projects/acme-crossass/)

Exomizer can be downloaded from [Bitbucket](https://bitbucket.org/magli143/exomizer/wiki/Home). The download includes binaries for Windows.

Get WinVice from [SourceForge](http://vice-emu.sourceforge.net/)

You can get Ruby from [RubyInstaller](https://rubyinstaller.org/)

