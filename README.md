# Ozmoo

*Ozmoo (spell): survive unnatural death*

A Z-machine interpreter for the Commodore 64 and similar computers

Written by Johan Berntsson and Fredrik Ramsberg in 2018-2021

![Mini-Zork I running on Ozmoo](https://github.com/johanberntsson/ozmoo/blob/master/screenshots/minizork.png)


## Status

Update 2021-Oct-03: Release 8 with MEGA65 speedups, plus optimizations and bugfixes for all platforms.

Update 2021-May-04: Release 7 with new MEGA65 target, improved z3 statusline on 80 column displays.

Update 2021-Mar-19: Release 6 with input history, input colours, a new font and bug fixes.

Update 2021-Mar-02: There is now an official port of [Ozmoo for Acorn computers](https://zornslemma.github.io/ozmoo.html).

Update 2020-Dec-20: Release 5 with new C128 and Plus/4 targets, Beyond Zork mode, preload updates and bug fixes.

Update 2020-Sep-20: Release 4. Bugfixes, new cursor customization options, and a loader showing an image of your choice while the game loads.

Update 2020-Mar-04: Release 3 is here. Many bugfixes. Darkmode and splash screen added. Support for four new languages.

Update 2019-Jun-04: We have created release 2, with several new features, many bugfixes, better docs and other improvements.

Update 2018-Dec-27: We now consider Ozmoo ready for production use. A few minor features are missing, like output to printer and the ability to save and restore arbitrary parts of memory, and chances are they won't be added. 

There are probably still some bugs, and we will work to fix them as soon as we hear of them or notice them. We expect almost all games to run just fine.

Known bugs: See todo.txt.

If you want to follow what's happening with Ozmoo, we recommend you to star the project.

![Hibernated 2 with a loader image](https://github.com/johanberntsson/ozmoo/blob/master/screenshots/hibernated2_loading.gif)


## Motivation

We were looking for a redistributable interpreter of Infocom and Inform games that could be used for new interactive fiction works on the C64.

While the old Infocom interpreters are still available, the license situation is not clear so it is risky to use in new work, especially commercial. Furthermore, some of the newer Inform-based games use features which the old Infocom interpreters on the C64 can't handle.

There are some other implementations, but they have their limitations:
* [Infocom64](https://github.com/christopherkobayashi/infocom64) is based on assembly code of the original Infocom interpreter so it has the same license issues. Also, it only works with certain setups of hardware or emulation.
* [Zeugma](https://www.linusakesson.net/software/zeugma/index.php) requires an REU (Ram Expansion Unit) and doesn't support save and restore.
* [Z](http://petsd.net/petfood.php?lang=en) is an interpreter for Z-code version 3 only.

## What games can Ozmoo run?

The simple answer: Ozmoo should be able to run most Z-code games, regardless of size (A Z-code game can be up to 512 KB in size).

The longer answer:
* Ozmoo only supports version 3, 4, 5 and 8 of Z-code. This means you can't run the very first versions of Zork I and II, or the Infocom games with graphics.
* A Z-code file always starts with a section called dynamic memory. Ozmoo will not be able to handle games with more than roughly 35 KB of dynamic memory.
* If you want to run Ozmoo on a system with a single 1541 drive (or an emulation of one), the part of the game file that is not dynamic memory can be no larger than 170 KB. This typically means the game file can be about 190 KB in size.
* Most Inform 6 games and all Inform 7 games are too slow to be any fun on Ozmoo. The games that perform well are typically PunyInform games, ZIL games, Infocom games and Inform 5 games. Early Inform 6 games (using library 6/1 or 6/2) may also be fast enough.

## Nice-to-have features

![Ozmoo running a German game using a custom font with accented characters](https://github.com/johanberntsson/ozmoo/blob/master/screenshots/germangame.png)

Ozmoo supports:

* Fitting a lot more text on screen than Infocom's interpreters - This is done by using all 40 columns, smart wordwrap and a MORE prompt which uses a single character.
* Embedding a custom font. Currently two fonts are included in the distribution, plus some versions for Swedish, Danish, German, Italian, Spanish and French. And you can supply your own font.
* Custom alphabets in Z-machine version 5 and 8.
* Custom character mappings, allowing for games using accented characters. Comes with predefined mappings for Swedish, Danish, German, Italian, Spanish and French.
* Custom colour schemes.
* A fully configurable secondary colour scheme (darkmode) which the player can toggle by pressing the F1 key.
* A configurable splash screen which is shown just before the game starts.
* Up to ten save slots on a save disk (and most games will get the full ten slots).
* Writing a name for each saves position.
* Building a Z-code game without virtual memory. This means the whole game must fit in RAM at once, imposing a size restriction of about 50-52 KB. A game built this way can then be played on a C64 without a diskdrive. This far, save/restore does require a diskdrive, but there may be a version with save/restore to tape in the future. Also, a game built in this mode doesn't support RESTART.
* Building a game as a d81 disk image. This means there is room for any size of game on a single disk. A d81 disk image can be used to create a disk for a 1581 drive or it can be used with an SD2IEC device or, of course, an emulator. Ozmoo uses the 1581 disk format's partitioning mechanism to protect the game data from being overwritten, which means you can safely use the game disk for game saves as well, thus eliminating the need for disk swapping when saving/restoring.
* Using an REU (Ram Expansion Unit) for caching. The REU can also be used to play a game built for a dual disk drive system with just one drive.

![Ozmoo running Hollywood Hijinx vs Infocom's interpreter running Hollywood Hijinx](https://github.com/johanberntsson/ozmoo/blob/master/screenshots/hollywood.png)

The differences in screen handling are evident in this comparison between Infocom's interpreter (left) and Ozmoo, both showing the first screenful of text in Hollywood Hijinx. Ozmoo manages to squeeze in 872 characters of text, which is 34% more than Infocom's interpreter (650 characters). Both interpreters have reserved the top line for the statusline, but Ozmoo doesn't actually print the statusline until the first prompt.

## Other versions

There is a port of [Ozmoo for Acorn computers](https://zornslemma.github.io/ozmoo.html).

## Building and running

The simplest but also somewhat limited option, is to use [Ozmoo Online](http://microheaven.com/ozmooonline/), a web page we have setup where you can build games with Ozmoo without installing anything on your computer.

The other option is to install Ozmoo on your computer. This can be done on Windows, Linux and Mac OS X.

You need to install:
* Acme cross-assembler
* Exomizer file compression program (tested with 3.0.0, 3.0.1 and 3.0.2)
* Vice C64 emulator
* Ruby (Tested with 2.4.2, but any 2.4 version should work fine)

Edit the file make.rb. At the top of the file, you need to specify paths to the Acme assembler, Exomizer, the Vice C64 emulator, and the program "c1541" which is also included in the Vice distribution.

To build a game, you run something like "ruby make.rb game.z5" Add -s to make the game start in Vice when it has been built. Run make.rb without arguments to view all options.

### Windows

Acme can be downloaded from [SourceForge](https://sourceforge.net/projects/acme-crossass/)

Exomizer can be downloaded from [Bitbucket](https://bitbucket.org/magli143/exomizer/wiki/browse/downloads). The download includes binaries for Windows.

Get WinVice from [SourceForge](http://vice-emu.sourceforge.net/windows.html)

You can get Ruby from [RubyInstaller](https://rubyinstaller.org/)

### Linux

Acme is available on Debian/Ubuntu with:

    > sudo apt install acme

If this doesn't work, then acme can also be downloaded from [Github](https://github.com/meonwax/acme) and compiled:

    > cd src
    > make

Exomizer can be downloaded from [Bitbucket](https://bitbucket.org/magli143/exomizer/wiki/Home) and compiled:

    > cd src
    > make

Vice is available on Debian/Ubuntu with:

    > sudo apt install vice

Note that you have to supply the ROM images (kernal, basic, chargen, dos1541) under /usr/lib/vice to make x64 (the C64 emulator) run. See VICE instructions for more details.

Ruby is available on Debian/Ubuntu with:

    > sudo apt install ruby

### Thanks

Special thanks to:
* howtophil, for Linux-related make.rb suggestions
* Retrofan and Paul van der Laan for font support
* lft for good advice and support
* Jason Compton, for great help in testing
* Alessandro Morgantini for adding support for Italian
* Thomas Bøvith for adding support for Danish
* Eric Sherman for adding cursor customization support
* Paul Gardner-Stephen for porting Ozmoo to the MEGA65
* Steve Flintham for bug fixes and porting Ozmoo to Acorn computers
* Bart van Leeuwen for testing Ozmoo on the C128
* Karol Stasiak for several configuration and vmem patches
