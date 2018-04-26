# Name of the D64 file (if target d64 is used)
D64NAME := $(notdir $(CURDIR))
# All files in the d64 data folder (if present) will be added to the image
D64FOLDER := d64data
# Command used to run the emulator.
# Default: depending on target platform.
# For default (c64) target: x64 -kernal kernal -VICIIdsize -autostart
#EMUCMD := x64 -kernal kernal -VICIIdsize -autostart
EMUCMD := x64 -warp -kernal kernal -VICIIdsize -autostart
# Optional commands used before and after the emulation process
# Default: none
PREEMUCMD :=
POSTEMUCMD :=

all: test

test: d64
	$(PREEMUCMD)
	$(EMUCMD) ${D64NAME}.d64
	$(POSTEMUCMD)

d64:
	mkdir -p obj
	xa -o obj/main main.s
	#c1541 -format ${D64NAME},00 d64 ${D64NAME}.d64
	cp d64toinf/dejavu.d64 ${D64NAME}.d64
	c1541 -attach ${D64NAME}.d64 -write obj/main ${D64NAME}
	c1541 -attach ${D64NAME}.d64 $(foreach dsc, $(wildcard ${D64FOLDER}/*), -write $(dsc))

clean:
	rm -rf obj ozmoo.d64
