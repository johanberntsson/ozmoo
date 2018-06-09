#DEBUGFLAGS = -DDEBUG=1
VMFLAGS = -DUSEVM=1
C1541 := /usr/bin/c1541
#X64 := /usr/bin/x64 -autostart-delay-random
X64 := /usr/bin/x64 -warp -autostart-delay-random

#all: minizork
#all: zork1
all: dejavu
#all: dragon
#all: minform
#all: czechz3
#all: czechz5
#all: strictz3
#all: strictz5
#all: etude
#all: praxix
#all: oztestz3

d64.czechz3: 
	acme -DZ3=1 $(DEBUGFLAGS) $(VMFLAGS) --cpu 6510 --format cbm -l acme_labels.txt --outfile ozmoo ozmoo.asm
	cp test/czechz3.d64 czechz3.d64
	$(C1541) -attach czechz3.d64 -write ozmoo ozmoo

d64.czechz5: 
	acme -DZ5=1 $(DEBUGFLAGS) $(VMFLAGS) --cpu 6510 --format cbm -l acme_labels.txt --outfile ozmoo ozmoo.asm
	cp test/czechz5.d64 czechz5.d64
	$(C1541) -attach czechz5.d64 -write ozmoo ozmoo

d64.etude: 
	acme -DZ5=1 $(DEBUGFLAGS) $(VMFLAGS) --cpu 6510 --format cbm -l acme_labels.txt --outfile ozmoo ozmoo.asm
	cp test/etude.d64 etude.d64
	$(C1541) -attach etude.d64 -write ozmoo ozmoo

d64.praxix: 
	acme -DZ5=1 $(DEBUGFLAGS) $(VMFLAGS) --cpu 6510 --format cbm -l acme_labels.txt --outfile ozmoo ozmoo.asm
	cp test/praxix.d64 praxix.d64
	$(C1541) -attach praxix.d64 -write ozmoo ozmoo

d64.oztestz5: 
	acme -DZ5=1 $(DEBUGFLAGS) $(VMFLAGS) --cpu 6510 --format cbm -l acme_labels.txt --outfile ozmoo ozmoo.asm
	cp test/oztestz5.d64 oztest.d64
	$(C1541) -attach oztest.d64 -write ozmoo ozmoo

d64.oztestz3: 
	acme -DZ3=1 $(DEBUGFLAGS) $(VMFLAGS) --cpu 6510 --format cbm -l acme_labels.txt --outfile ozmoo ozmoo.asm
	cp test/oztestz3.d64 oztest.d64
	$(C1541) -attach oztest.d64 -write ozmoo ozmoo

d64.strictz3: 
	acme -DZ3=1 $(DEBUGFLAGS) $(VMFLAGS) --cpu 6510 --format cbm -l acme_labels.txt --outfile ozmoo ozmoo.asm
	cp test/strictz3.d64 strictz3.d64
	$(C1541) -attach strictz3.d64 -write ozmoo ozmoo

d64.strictz5: 
	acme -DZ5=1 $(DEBUGFLAGS) $(VMFLAGS) --cpu 6510 --format cbm -l acme_labels.txt --outfile ozmoo ozmoo.asm
	cp test/strictz5.d64 strictz5.d64
	$(C1541) -attach strictz5.d64 -write ozmoo ozmoo

d64.minform: 
	acme -DZ5=1 $(DEBUGFLAGS) $(VMFLAGS) --cpu 6510 --format cbm -l acme_labels.txt --outfile ozmoo ozmoo.asm
	cp minform/minform.d64 minform.d64
	$(C1541) -attach minform.d64 -write ozmoo ozmoo

d64.minizork: 
	acme -DZ3=1 $(DEBUGFLAGS) $(VMFLAGS) --cpu 6510 --format cbm -l acme_labels.txt --outfile ozmoo ozmoo.asm
	cp infocom/minizork.d64 minizork.d64
	$(C1541) -attach minizork.d64 -write ozmoo ozmoo

d64.zork1: 
	acme -DZ3=1 $(DEBUGFLAGS) $(VMFLAGS) --cpu 6510 --format cbm -l acme_labels.txt --outfile ozmoo ozmoo.asm
	cp infocom/zork1.d64 zork1.d64
	$(C1541) -attach zork1.d64 -write ozmoo ozmoo

d64.dejavu: 
	acme -DZ3=1 $(DEBUGFLAGS) $(VMFLAGS) --cpu 6510 --format cbm -l acme_labels.txt --outfile ozmoo ozmoo.asm
	cp examples/dejavu.d64 dejavu.d64
	$(C1541) -attach dejavu.d64 -write ozmoo ozmoo

d64.dragon:
	acme -DZ5=1 $(DEBUGFLAGS)  $(VMFLAGS) --cpu 6510 --format cbm -l acme_labels.txt --outfile ozmoo ozmoo.asm
	cp examples/dragontroll.d64 dragontroll.d64
	$(C1541) -attach dragontroll.d64 -write ozmoo ozmoo

minizork: d64.minizork
	$(X64) minizork.d64

zork1: d64.zork1
	$(X64) zork1.d64

dejavu: d64.dejavu
	$(X64) dejavu.d64

dragon: d64.dragon
	$(X64) dragontroll.d64

minform: d64.minform
	$(X64) minform.d64

etude: d64.etude
	$(X64) etude.d64

praxix: d64.praxix
	$(X64) praxix.d64

oztestz3: d64.oztestz3
	$(X64) oztest.d64

oztestz5: d64.oztestz5
	$(X64) oztest.d64

strictz3: d64.strictz3
	$(X64) strictz3.d64

strictz5: d64.strictz5
	$(X64) strictz5.d64

czechz5: d64.czechz5
	$(X64) czechz5.d64

czechz3: d64.czechz3
	$(X64) czechz3.d64

clean:
	rm -f ozmoo *.d64

