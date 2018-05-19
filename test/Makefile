all: 
	cp ../d64toinf/inftod64.dat .
	inform -v5 czech/czech.inf czech.z5
	inform -v5 +etude etude/etude.inf etude.z5
	inform -v3 strictz/strictz.inf strictz.z3
	inform -v3 strictz/strictz.inf strictz.z5
	#../d64toinf/inftod64 strictz.z3 test.d64
	#../d64toinf/inftod64 strictz.z5 test.d64
	#../d64toinf/inftod64 etude.z5 test.d64
	../d64toinf/inftod64 czech.z5 test.d64

clean:
	rm -f *.z3 *.z5 inftod64.dat test.d64

