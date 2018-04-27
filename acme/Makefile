C1541 := /usr/bin/c1541
X64 := /usr/bin/x64 -warp

all: test

d64: 
	mkdir -p obj
	acme --cpu 6510 --format cbm --outfile obj/ozmoo ozmoo.asm
	cp ../d64toinf/dejavu.d64 ozmoo.d64
	$(C1541) -attach ozmoo.d64 -write obj/ozmoo ozmoo

test: d64
	$(X64) ozmoo.d64

clean:
	rm -f obj ozmoo.d64

