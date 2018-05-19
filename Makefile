#DEBUGFLAGS = -DDEBUG=1
#VMFLAGS = -DUSEVM=1
C1541 := /usr/bin/c1541
#X64 := /usr/bin/x64
X64 := /usr/bin/x64 -warp

all: dejavu
#all: dragon
#all: minform
#all: test

d64.test: 
	acme -DZ5=1 $(DEBUGFLAGS) $(VMFLAGS) --cpu 6510 --format cbm -l acme_labels.txt --outfile ozmoo ozmoo.asm
	cp test/test.d64 test.d64
	$(C1541) -attach test.d64 -write ozmoo ozmoo

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

test: d64.test
	$(X64) test.d64

clean:
	rm -f ozmoo *.d64

