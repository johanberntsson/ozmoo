all: 
	cp ../d64toinf/inftod64.dat .
	inform -v3 czech/czech.inf czech.z3
	inform -v5 czech/czech.inf czech.z5
	inform -v5 +etude etude/etude.inf etude.z5
	inform -v3 strictz/strictz.inf strictz.z3
	inform -v5 strictz/strictz.inf strictz.z5
	../d64toinf/inftod64 strictz.z3 strictz3.d64
	../d64toinf/inftod64 strictz.z5 strictz5.d64
	../d64toinf/inftod64 etude.z5 etude.d64
	../d64toinf/inftod64 czech.z5 czechz5.d64
	../d64toinf/inftod64 czech.z3 czechz3.d64

clean:
	rm -f *.z3 *.z5 inftod64.dat test.d64

