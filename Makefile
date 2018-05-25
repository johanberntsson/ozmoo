DEBUGFLAGS = -DDEBUG=1
#VMFLAGS = -DUSEVM=1
C1541 := /usr/bin/c1541
#X64 := /usr/bin/x64
X64 := /usr/bin/x64 -warp -autostart-delay-random

#all: dejavu
#all: dragon
all: minform
#all: testz3
#all: testz5

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

d64.dejavu: 
	acme -DZ3=1 $(DEBUGFLAGS) $(VMFLAGS) --cpu 6510 --format cbm -l acme_labels.txt --outfile ozmoo ozmoo.asm
	cp d64toinf/dejavu.d64 dejavu.d64
	$(C1541) -attach dejavu.d64 -write ozmoo ozmoo

d64.dragon:
	acme -DZ5=1 $(DEBUGFLAGS)  $(VMFLAGS) --cpu 6510 --format cbm -l acme_labels.txt --outfile ozmoo ozmoo.asm
	cp d64toinf/dragontroll.d64 dragontroll.d64
	$(C1541) -attach dragontroll.d64 -write ozmoo ozmoo

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

