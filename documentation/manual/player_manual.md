<!-- pandoc manual.md -o manual.pdf -->

# Introduction

This manual explains how to play Ozmoo games, and how to use special features such as RAM expansions and darkmode. Since Ozmoo is using direct access to floppy discs or floppy images, there are also some differences to be aware of when it comes to copying games, saving and restoring saves, and handling large games. 

# Starting a game

To start the game, just insert the floppy in the floppy drive and type `load "story",8` and `run`. On Plus/4 and C128, you can also use `dload "story"` and then `run`.

# Playing a game

Type commands in plain English each time you see the prompt (\>). Most of the sentences that games will understand are imperative sentences, as if you are commanding the computer to do things. When you have finished typing your input, press the RETURN (or ENTER) key, and the game will then respond, telling you whether your request is possible at this point in the story, and what happened as a result.

You can include several inputs on one line if you separate them by the word "then" or by a period. Each input will be handled in order, as though you had typed them individually at separate prompts. If the game doesn't understand one of the sentences on your input line, or if an unusual event occurs, it will ignore the rest of your input line. 

To move around, just type the direction you want to go. In addition to the compass directions, "up", "down", "in" and "out" can also work in some places. Aboard a ship, you may be able to use "fore", "aft", "starboard" and "port". There are many different kinds of sentences used in interactive fiction games. Here are some examples:

\>north

\>w

\>down 

\>take the sword

\>examine the dirty towel

\>put the shiny key in the wooden box

You can use multiple objects with certain verbs (usually "take", "drop", "put" and "insert") if you separate them by the word "and" or by a comma. Some examples: 

\>take the book and the ladder

\>drop the pink book, the torch and the key


The word "it" and other pronouns can be handy. For example:

\>examine the apple. take it. eat it

The word "all" refers to every visible object except those inside something else. If there were an apple on the ground and an orange inside a cabinet, "take all" would take the apple but not the orange. "take all from the cabinet" on the other hand, would of course take the orange.

When you meet intelligent creatures, you can talk to them by typing their name, then a comma, then whatever you want to say to them or ask them to do. For example:

\>Lisa, hello

\>John, open the box

# Darkmode
Ozmoo games can toggle between normal colours and a dark mode. This is done by pushing the F1 key whenever the game is waiting for input. The colours used by normal and dark mode are decided by the game author.

# Saving
The "save" commands creates a snapshot of your current position. You can return to a saved position in the future by using the "restore" command. When you use "save" or "restore" you will be asked to insert a save disk. If your game disk is a 1581 floppy disk (or a .d81 floppy image) then you can safely use it as a save disk as well, otherwise you will need to prepare an empty floppy disk or a disk image (d64, d71 or d81) to use as a save disk. Do not store other files on this disk, and do not use the same disk as a save disk for several games!

# Large games
Ozmoo has several build modes to allow even large game files to be played, which may require more than one floppy disk. Small games fit on one floppy (called the Boot / Story disk), while large games have one Boot disk and one Story disk. You start the game from the Boot disk, and then change to the Story disk when prompted.

However, really large games may use two Story disks. Such games can only be played if you have either two floppy drives, or a ram expansion unit (REU).

# Copying
An Ozmoo game stores data directly onto the floppy disk in addition to files. Because of this, it is not possible to copy a game to a new floppy by just copying files. If you want to make a copy you need to use a copy program that copies the whole disk, sectors by sector.

# RAM expansion
Ozmoo can use a RAM expansion unit (REU) to cache story data. If Ozmoo detects an REU at startup, it will ask if you want to use the REU or not. If the REU is 512 KB or more, any game will fit. If it is smaller then it depends on the game size. If the REU is too small to fit the whole game Ozmoo will typically crash - just restart and don't use the REU in that case.

A REU can be used instead of a second floppy drive when playing very large games, as described in the "Large games" section above.

# Patched games

## Beyond Zork
Ozmoo has support for Beyond Zork, which was never released on the Commodore 64. Beyond Zork was designed for 80 column screens, and to make it playable Ozmoo makes minor modifications to fit all information on a 40 column screen. The map and screen decorations are using simplified ASCII characters, and Darkmode is disabled since Beyond Zork requires control over the colours. The title screen hasn't been modified, so it shows text that doesn't quite fit on a 40 column screen.


