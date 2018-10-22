# Ozmoo

*Ozmoo (spell): survive unnatural death*

A Z-machine interpreter for the Commodore 64 

Written by Johan Berntsson and Fredrik Ramsberg in 2018

![Minizork running on Ozmoo](https://github.com/johanberntsson/ozmoo/blob/master/screenshots/minizork.png)


## Status

Ozmoo is not ready for release or production use. Some features are missing, most notably save and restore functionality. There are also numerous bugs.

If you want to start using Ozmoo once it's more mature, we recommend you to star the project, or just return every once in a while to see what's happening.

## Motivation

We were looking for a redistributable interpreter of Infocom and Inform games that could be used for new interactive fiction works on the C64.

While the old Infocom interpreters are still available, the license situation is not clear so it is risky to use in new work, especially commercial. Furthermore, some of the newer Inform-based games use features which the old Infocom interpreters on the C64 can't handle.

There are some other implementations, but they have their limitations:
* [Infocom64](https://github.com/christopherkobayashi/infocom64) is based on assembly code of the original Infocom interpreter so it has the same license issues. Also, it only works with certain setups of hardware or emulation.
* [Zeugma](https://www.linusakesson.net/software/zeugma/index.php) requires an REU (Ram Expansion Unit) and doesn't support save and restore.

## What games can Ozmoo run?

The simple answer: Ozmoo should be able to run most Z-code games, regardless of size (A Z-code game can be up to 512 KB in size).

The longer answer:
* Ozmoo only supports version 3, 4, 5 and 8 of Z-code. This means you can't run the very first versions of Zork I and II, or the Infocom games with graphics.
* A Z-code file always starts with a section called dynamic memory. Ozmoo will not be able to handle games with more than roughly 35 KB of dynamic memory.
* If you want to run Ozmoo on a system with a single 1541 drive (or an emulation of one), the part of the game file that is not dynamic memory can be no larger than 191.5 KB. This typically means the game file can be about 210 KB in size.
* Some Inform 6 games and pretty much all Inform 7 games will never be fast enough to be any fun on Ozmoo. In general, Infocom games are faster than Inform games.

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

