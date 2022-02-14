<!-- pandoc manual.md -o manual.pdf -->

# Overview

Ozmoo is a a redistributable interpreter of Z-code games - Infocom games and games written in Inform, ZIL or Dialog. Ozmoo can be used for new interactive fiction works on the Commodore 64 and similar computers.  While the old Infocom interpreters are still available, the license situation is not clear so it is risky to use in new work, especially commercial. Furthermore, some of the newer Inform-based games use features which the old Infocom interpreters on the C64 can't handle. Ozmoo is written to provide a free alternative that doesn't have these risks and limitations.

Ozmoo was originally only developed for the Commodore 64, but it is structured so that it is fairly easy to retarget Ozmoo to computers with similar architecture. Apart from Commodore 64, Ozmoo can currently target the Commodore 128, the Commodore Plus/4 and the MEGA65 computers. There is also a fork of Ozmoo for the Acorn computers (BBC Micro and other variants).

## Features

Ozmoo for the Commodore 64 supports:

- Z-code version 1, 2, 3, 4, 5, 7 and 8. Essentially this covers all games except for the Infocom games with graphics.
- Fitting a lot more text on screen than Infocom's interpreters - This is done by using all 40 columns, smart wordwrap and a MORE prompt which uses a single character.
- Embedding a custom font. Currently two fonts are included in the distribution, plus some versions for Swedish, Danish, German, Italian, Spanish and French. And you can supply your own font.
- Custom alphabets in Z-machine version 5, 7 and 8.
- Custom character mappings, allowing for games using accented characters. Comes with predefined mappings for Swedish, Danish, German, Italian, Spanish and French.
- Custom colour schemes.
- A fully configurable secondary colour scheme (darkmode) which the player can toggle by pressing the F1 key.
- A configurable splash screen which is shown just before the game starts.
- Up to ten save slots on a save disk (and most games will get the full ten slots).
- Writing a name for each saves position.
- Building a Z-code game without virtual memory. This means the whole game must fit in RAM at once, imposing a size restriction of about 50-52 KB. A game built this way can then be played on a C64 without a diskdrive. This far, save/restore does require a diskdrive, but there may be a version with save/restore to tape in the future. Also, a game built in this mode doesn't support RESTART.
- Building a game as a d81 disk image. This means there is room for any size of game on a single disk. A d81 disk image can be used to create a disk for a 1581 drive or it can be used with an SD2IEC device or, of course, an emulator. Ozmoo uses the 1581 disk format's partitioning mechanism to protect the game data from being overwritten, which means you can safely use the game disk for game saves as well, thus eliminating the need for disk swapping when saving/restoring.
- Using an REU (Ram Expansion Unit) for caching. The REU can also be used to play a game built for a dual disk drive system with just one drive.
- Adding a loader which shows an image while the game loads.

## Limitations

Ozmoo should be able to run most Z-code games, regardless of size (A Z-code game can be up to 512 KB in size). However, there are some limitations:

- A Z-code file always starts with a section called dynamic memory. Ozmoo on the Commodore 64 can't handle games with more than roughly 35 KB of dynamic memory.
- If you want to run Ozmoo on a system with a single 1541 drive (or an emulation of one), the part of the game file that is not dynamic memory can be no larger than 170 KB. This typically means the game file can be about 190 KB in size.
- Some Inform 6 games and pretty much all Inform 7 games are too slow to be much fun on a Commodore 64. In general Infocom games, PunyInform games and modern-day ZIL games work the best. Inform 5 games and early Inform 6 games (typically using library 6/1 or 6/2) often work well too.

# Quickstart

The simplest option is to use Ozmoo Online, a web page where you can build games with Ozmoo without installing anything on your computer. It supports most of the options Ozmoo has. Ozmoo online is located at: http://microheaven.com/ozmooonline/

The other option is to install Ozmoo on your computer. This can be done on Windows, Linux and Mac OS X. To build a game, you run something like "ruby make.rb game.z5" Add -s to make the game start in Vice when it has been built. 

## Dependencies

You need to install:

- Acme cross-assembler
- Exomizer file compression program (tested with 3.0.0, 3.0.1 and 3.0.2)
- Ruby (Tested with 2.4.2, but any 2.4 version should work fine)
- The Vice emulator to test C64, C128 and Plus/4 builds on virtual hardware
- The xemu-xmega65 emulator if you want to test MEGA65 builds on virtual hardware

#### Windows

Acme can be downloaded from SourceForge: https://sourceforge.net/projects/acme-crossass/

Exomizer can be downloaded from Bitbucket. The download includes binaries for Windows: https://bitbucket.org/magli143/exomizer/wiki/browse/downloads

Get WinVice from SourceForge: http://vice-emu.sourceforge.net/windows.html

You can get Ruby from RubyInstaller: https://rubyinstaller.org/

####  Linux

Acme is available on Debian/Ubuntu with:

    > sudo apt install acme

Exomizer can be downloaded from Bitbucket and compiled:

    > cd src
    > make

Vice is available on Debian/Ubuntu with:

    > sudo apt install vice

Note that you have to supply the ROM images (kernal, basic, chargen, dos1541) under /usr/lib/vice to make x64 (the C64 emulator) run. See VICE instructions for more details.

Ruby is available on Debian/Ubuntu with:

    > sudo apt install ruby

## Customizing the make script

Edit the file make.rb. At the top of the file, you need to specify paths to the Acme assembler, Exomizer, the Vice C64 emulator, and the program "c1541" which is also included in the Vice distribution.  If you are using Windows, you can ignore the section on Linux and vice versa.

## View all commandline options for make.rb

At a command prompt, type "ruby make.rb"

## The basic way to build a game

At a command prompt, type "ruby make.rb mygame.z5"

## Build a game which will only consist of a single file

At a command prompt, type "ruby make.rb -P mygame.z5" to build a game which will only consist of a single file. A game created in this way does not require a disk drive to play.

## Build a game with optimized preloaded virtual memory data

Ozmoo has the option of optimizing which virtual memory blocks are loaded when the game starts. This is done to make the game as fast as possible in the beginning.

Typically, this is a step you want to do when you have the release version of the game. If you do this optimization and then change the story file, adding or removing more than a few bytes, you should redo the optimization.

Use these steps:

1. At a command prompt, type `ruby make.rb -o -s mygame.z5`. If you plan to release the game for the Commodore 128, add -t:c128 to this command. The text file produced in step 4 can then be used for all other Ozmoo platforms as well in step 5.

2. Play the game, performing the actions you think the player is likely to do first. Keep playing until the game halts, printing a report with lots of numbers. If you have done a reasonable amount of moves (let's say 10-20 moves) and you don't feel like spending more time on this, type `xxx` to end the optimization session and print the results.

3. Vice should now show a lot of hexadecimal numbers (and maybe some game text) on screen. In Vice, select `Edit -> Copy` from the menu to copy all of the screen contents.

4. Create a new text file (let's say you call it `mygame_optimization.txt`), paste the complete text you just copied from Vice into the file and save it.

5. At a command prompt, type `ruby make.rb -c mygame_optimization.txt mygame.z5`. You can use `-cf` instead of `-c` to have Ozmoo fill up any free slots of RAM with more virtual memory blocks. This will pick the lowest blocks which haven't already been loaded. 

Repeat step 5 for all platforms you want to build the game for.


# Targets

Ozmoo was originally written for the Commodore 64, but has been adapted for some other computers as well. make.rb takes a -t:target argument to build for other computers, and currently supports these platforms:

| Target | Comment |
| -- | ---- |
| -t:c64 | Build Ozmoo for the Commodore 64 (default) |
| -t:c128 | Build Ozmoo for the Commodore 128 |
| -t:plus4 | Build Ozmoo for the Commodore Plus/4 |
| -t:mega65 | Build Ozmoo for the MEGA65 |

Note that not all build options are supported for every platform. If an option isn't supported, the make.rb script will stop with an appropriate error message, and no Ozmoo files will be produced.

## Commodore 64

The Commodore 64 version is the default build target, and supports all build options. A game can have about 35 KB of dynamic memory. Games will need to do more disk access the more dynamic memory they have, so more than  about 30 KB may not be advisable. An REU can be used for caching if present.

## Commodore 128

The Commodore 128 version automatically detects if it is started from 40 or 80 columns mode, and adjusts to the screen size. When run in 80 column mode, the CPU runs at 2 MHz, making for quite responsive games. It makes use of the additional ram available compared to the Commodore 64 version, and allows for games with up to 44 KB dynamic memory. An REU can be used for caching if present. 

The Commodore 128 version does not allow a loader image, and build mode -P is not supported. Commodore 128 is the only target which can use build mode -71.

## Commodore Plus/4

The Commodore Plus/4 version makes use of the simplified memory map compared to the Commodore 64 version, allowing for games with up to 46 KB dynamic memory. Games will need to do more disk access the more dynamic memory they have, so more than about 30 KB may still not be advisable.

## MEGA65

The MEGA65 version is very similar to the C64 version of Ozmoo. It runs in C64 mode on the MEGA65, but uses the 80 column screen mode, the higher clockspeed and extra RAM of the MEGA65. The maximum amount of dynamic memory is about 35 KB. The only supported build mode is -81. A loader image is currently not supported.

## Other targets

A fork of Ozmoo targeting the Acorn computers (BBC Micro and other variants) can be found at https://github.com/ZornsLemma/ozmoo/tree/acorn. Note that this fork is using a different build script called make-acorn.py.

# Build Modes

## Drives and devices

A game built using Ozmoo is placed on one or more disks. These disks can then be used in different disk drives attached to the C64. The device numbers which can be used are 8, 9, 10, 11. If the game has two story disks (meaning it was built using mode D2 or D3), the player will need a computer with at least two disk drives OR one disk drive and an REU to play it.

## File name

The story is started by loading and running a boot file which is called "STORY" by default. It is possible to change this file name by using -fn. For example, 
```
make.rb -fn temple temple.z5
```
Make sure that the -fn argument follows the naming for the drive you are creating disks for.

## List of build modes

Notes: 

* Preloading means some or all of memory is filled with suitable parts of the story file, by loading this content from a file as the game starts. Using preloading speeds up game start for many players since this initial loading sequence can use any fastloader the user may have enabled. It also means gameplay is as fast as it gets, right from the start.

* Less RAM available for virtual memory system: This means a smaller part of C64 memory can be used for virtual memory handling, which means the game will need to load sectors from disk more often. This will of course slow the game down.

### Modes not requiring a disk drive for play:

P: _Program file_

- Story file size < ~51 KB: Using full amount of RAM.

Disks used:

- Boot / Story disk. This contains a single file, which may be moved to any other medium, like another disk image or a tape image.

### Modes requiring a single 1541 drive for play:

S1: _Single 1541 drive, one disk_

- Story file size < ~150 KB: Full preloading. Full amount of RAM available for virtual memory system.
- Story file size < ~170 KB: Less preloading the larger the story file. Full amount of RAM available for virtual memory system.

Disks used:
- Boot / Story disk
	
S2: _Single 1541 drive, two disks_

- Story file size < ~190 KB: Full preloading. Full amount of RAM available for virtual memory system.
<!-- - Story file size < ~210 KB: Full preloading. Less RAM available for virtual memory system the larger the story file. -->

Disks used:

- Boot disk
- Story disk
	
### Modes requiring two 1541 drives for play:

D2: _Double 1541 drives, two disks_

- Story file size < ~330 KB: Full preloading. Full amount of RAM available for virtual memory system.
- Story file size < ~360 KB: Less preloading the larger the story file. Full amount of RAM available for virtual memory system.

Disks used:

- Boot disk / Story disk 1
- Story disk 2

D3: _Double 1541 drives, three disks_

- Story file size < ~370 KB: Full preloading. Full amount of RAM available for virtual memory system.
<!-- - Story file size < ~390 KB: Full preloading. Less RAM available for virtual memory system the larger the story file. -->

Disks used:

- Boot disk
- Story disk 1
- Story disk 2

### Modes requiring a 1571 drive for play:

71: _Single 1571 drive, one disk_

- Story file size < ~320 KB: Full preloading. Full amount of RAM available for virtual memory system.
- Story file size < ~340 KB: Less preloading the larger the story file. Full amount of RAM available for virtual memory system.

Disks used:

- Boot / Story disk

### Modes requiring a 1581 drive for play:

81: _Single 1581 drive, one disk_

Any story size: Full preloading. Full amount of RAM available for virtual memory system.
	
Thanks to the partitioning available on the 1581, the story data is protected even in the event of a validate command. Thus, the user can safely use the story disk as a save disk as well.

Disks used:

- Boot / Story disk

### Modes requiring an SD2IEC:

To be added at a later date. An SD2IEC mode could enable full 512 KB story sizes.

# Splash Screen

By default, Ozmoo will show a splash screen just before the game starts. At the bottom of the screen is a line of text stating the version of Ozmoo used and instructions to use F1 to toggle darkmode. After three seconds, or when the player presses a key, the game starts.

You can use the following commandline parameters add up to four lines of text to the splash screen:

    -ss1:"text"
    -ss2:"text"
    -ss3:"text"
    -ss4:"text"

    -sw:nnn
This sets the number of seconds that Ozmoo will pause on the splash screen. The default is three seconds if no text has been added, and ten seconds if text has been added. A value of 0 will remove the splashscreen completely.

Example:

```
ruby make.rb supermm.z5 -ss1:"Super Mario Murders" -ss2:"A coin-op mystery" \
    -ss3:"by" -ss4:"John \"Popeye\" Johnsson" -sw:8
```

# Colours


Ozmoo lets you pick two different colour schemes for your game. We refer to these two colour schemes as normal mode and darkmode. The idea is that you may want lighter text on a dark background when playing at night, while dark text on a light background has proven to be easier to read, in well-lit conditions. Ozmoo will always start in normal mode, and the player can switch between normal mode and darkmode using the F1 key. When switching modes, Ozmoo will change the colour of all onscreen text which has the default foreground colour *or* which has the same colour as the background colour in the mode it's switching to and thus would otherwise become invisible.


## Colour switches

make.rb has the following switches to control colours:

    -dd
Disables darkmode.

    -rc:(Z-code colour)=(C64 colour), ...
Replace colours: Replaces one or more colours in the Z-code palette with the specified colours in the C64 palette.

    -dc:(Default background colour):(Default foreground colour)
Default colours: This picks the Z-code colours to use as default background and foreground colours.

    -sc:(Statusline colour)
Statusline colour: This picks the Z-code colour to use as statusline colour. This is only possible with version 1, 2 and 3 story files (z1/z2/z3).

    -ic:(Input colour)
Input colour: This picks the Z-code colour to use for player input text. This is only possible with version 1, 2, 3 and 4 story files (z1/z2/z3/z4).

    -bc:(Border colour)
Border colour. This picks the Z-code colour to use as border colour. 
Special values: 0 = same as background colour (default), 1 = same as foreground colour. If the game itself changes the screen colours, as it may do in Z5+ games, values 0 and 1 mean the border changes too.

    -cc:(Cursor color)
Cursor colour: This picks the Z-code colour for the cursor shown when waiting for player input. 1 = same as foreground colour (default). If the game itself changes the screen colours, as it may do in Z5+ games, value 1 mean the cursor changes too.


    -dmdc: (same as -dc but for darkmode)

    -dmsc: (same as -sc but for darkmode)

    -dmic: (same as -ic but for darkmode)

    -dmbc: (same as -bc but for darkmode)

    -dmcc: (same as -dc but for darkmode)

## Cursor switches

The shape and the blinking of the cursor can also be customized:

    -cb:(delay)
Cursor blinking frequency. delay is 1 to 99, where 1 is fastest.

    -cs:(Cursor shape)
Cursor shape: either of b,u or l; where b=block (default) shape, u=underscore shape and l=line shape.

## Palette

Z-code has a palette of 8 colours, numbered 2-9:

    2 = black       
    3 = red         
    4 = green       
    5 = yellow      
    6 = blue        
    7 = magenta     
    8 = cyan        
    9 = white       

The Commodore 64 has 16 colours, numbered 0-15:

    0 = black
    1 = white
    2 = red
    3 = cyan
    4 = purple
    5 = green
    6 = blue
    7 = yellow
    8 = orange
    9 = brown
    10 = pink
    11 = dark grey
    12 = grey
    13 = light green
    14 = light blue
    15 = light grey

When building Ozmoo for the Plus/4, Ozmoo has a list of Plus/4 colours which are approximately equivalent to the 16 colours of the C64. Thus, you use the same colour numbers as for the C64 when referring to "native" (non Z-code) colours.

The 80-column mode of the C128 has a different and rather limited palette. Ozmoo tries to use colours which are approximately the same as the C64 colours.

## Examples

Use cyan text on black background with a yellow statusbar (Please note that specifying the colour of the statusbar only works for z2/z2/z3 games!):

```
make.rb -dc:2:8 -sc:5 game.z3
```

Change so Z-code color 7 is dark grey instead of magenta and Z-code color 8 is light grey instead of cyan, and use these as default colors:

```
make.rb -rc:7=11,8=15 -dc:7:8 game.z5
```

Setting up the default palette (even though this isn't useful) is equivalent to using:

```
make.rb -rc:2=0,3=2,4=5,5=7,6=6,7=4,8=3,9=1 game.z5
```

# Fonts

When building a game with make.rb, you can choose to embed a font (character set) with the game using the -f option. This will use up 2 KB of memory which would otherwise have been available for game data. The font file should be exactly 2048 bytes long and just hold the raw data for the font, without load address or other extra information.

The font files are organized into subfolders under the "font" folder, with one subfolder per language:

da: Danish
en: English
de: German 
es: Spanish
fr: French
it: Italian
sv: Swedish

Included with the Ozmoo distribution are these custom fonts:

* Clairsys, by Paul van der Laan.

* Clairsys Bold, by Paul van der Laan.

* PXLfont-rf, by Retrofan.

* System, the standard C64 system font, with accented characters added by the Ozmoo team.

You are free to use one of these fonts in a game you make and distribute, regardless of whether you make any money off of the game. You must however include credits for the font, stating the name of the font and the creator of the font. We strongly suggest you include these credits both in the docs / game distribution and somewhere within the game (Some games print "Type ABOUT for information about the game." or something to that effect as the game starts).

To see all the licensing details for each font, read the corresponding license file in the "fonts" folder. The full information in the license file must also be included with the game distribution if you embed a font with a game.

# Sound

While several Infocom games had high and low-pitched beeps, a few games had extended sound support using sample playback. Ozmoo supports the basic sound effects (beeps) on all platforms, and extended sounds on the MEGA65.

The extended sound support uses sample files stored in the WAV format. The WAV files need to be 8 bit, mono. Audacity can be used to export wav files in the correct format:

- Select "File/Export/Export as WAV" from the main menu
- Select "Other compressed files" as the file type
- Select "Unsigned 8-bit PCM" as the encoding
- Save the file

## Sound switches

    -as path
Add Sounds: Enable extended sound support and add all .wav files in path

If extended sound is to be used, then make.rb should be called with the `-as path` switch. If set, then all .wav files in the `path` will be added to the .d81 floppy created for the MEGA65, and the SOUND assembly flag will be set when building Ozmoo.

# Loader image

When building for the Commodore 64 or Plus/4, it is possible to add a loader which shows an image while the game is loading, using -i (show image) or -if (show image with a flicker effect in the border). The image file must be a Koala paint multicolour image (10003 bytes in size) when building a game for the C64, or a Multi Botticelli multicolour image (10050 bytes in size) when building a game for the Plus/4. Border flicker is not supported for the Plus/4. Example commands:

```
make.rb -if mountain.kla game.z5
make.rb -i spaceship.mb -t:plus4 game.z5
```

# Command line history

There is an optional command line history feature that can be activated by -ch. If activated, it uses the wasted space between the interpreter and the virtual memory buffers to store command lines, that can later be retrieved using the cursor up and down keys. The maximum space allowed for the history is 256 bytes, but the stored lines are saved compactly so if only short commands like directions, "i" and "open door" etc are used it will fit quite a lot.

Since memory is limited on old computers this feature is disabled by default. To
enable it use -ch. This will allocate a history buffer large enough to be useful. It is also possible to manually define the minimal size of the history buffer with -ch:n, where n is 20-255 bytes.

# Miscellaneous options

## Option -sp:n

-sp:n is used to set the size of the Z-machine stack, in pages (1 page = 256 bytes). The default value is 4. Many games, especially ones from Infocom, can be run with just two pages of stack. The main reason for reducing this to two pages would be to squeeze in a slightly bigger game in build mode P, or to build a game where dynamic memory is slightly too big with the standard settings.

## Option -u

-u is used to enable the "unsafe" mode, which remove some runtime checks, reducing code size and increasing speed. This is typically used when the game is in a good state, but you need to make it smaller to fit into the available memory.

## Option -cm:[xx]

Ozmoo has some support for using accented characters in games. This is documented in detail in the tech report, but assuming that suitable fonts and character maps have been prepared, the -cm option is used to enable this character map. By default, Ozmoo have support for these character maps: sv, da, de, it, es and fr, for Swedish, Danish, German, Italian, Spanish and French, respectivily.

## Option -in:[n]

-in sets the interpreter number.

The interpreter numbers, originally defined by Infocom, are as follows:

    1 = DECSystem-20
    2 = Apple IIe
    3 = Macintosh
    4 = Amiga
    5 = Atari ST
    6 = IBM PC
    7 = Commodore 128
    8 = Commodore 64
    9 = Apple IIc
    10 = Apple IIgs
    11 = Tandy Color

The interpreter number is used by a few games to modify the screen output format. In Ozmoo we set 2 for Beyond Zork, 7 for C128 builds,  and 8 for other games by default, but -in allows you to try other interpreter numbers.
