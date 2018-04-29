C1541 := /usr/bin/c1541
X64 := /usr/bin/x64 -warp

all: z5

d64.z3: 
	acme -DZ3=1 --cpu 6510 --format cbm --outfile ozmoo ozmoo.asm
	cp d64toinf/dejavu.d64 dejavu.d64
	$(C1541) -attach dejavu.d64 -write ozmoo ozmoo

d64.z5:
	acme -DZ5=1 --cpu 6510 --format cbm --outfile ozmoo ozmoo.asm
	cp d64toinf/dragontroll.d64 dragontroll.d64
	$(C1541) -attach dragontroll.d64 -write ozmoo ozmoo

z3: d64.z3
	$(X64) dejavu.d64

z5: d64.z5
	$(X64) dragontroll.d64

clean:
	rm -f ozmoo *.d64

