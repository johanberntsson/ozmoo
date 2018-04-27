TARGETS := ozmoo
C1541 := /usr/bin/c1541
X64 := /usr/bin/x64

.PRECIOUS: %.d64

all: $(TARGETS)

%.prg: %.asm
	acme --cpu 6510 --format cbm --outfile $@ $<

%.d64: %.prg
	cp ../d64toinf/dejavu.d64 $@
	$(C1541) -attach $@ -write $< $(TARGETS)

%: %.d64
	$(X64) $<

clean:
	rm -f $(TARGETS) *.prg *.d64

