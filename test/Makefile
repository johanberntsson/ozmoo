all: d64

bin:
	inform -v3 czech/czech.inf czech.z3
	inform -v5 czech/czech.inf czech.z5
	inform -v5 +etude etude/etude.inf etude.z5
	inform -v3 strictz/strictz.inf strictz.z3
	inform -v5 strictz/strictz.inf strictz.z5

d64:
	../create_d64.rb strictz.z3 strictz3.d64
	../create_d64.rb strictz.z5 strictz5.d64
	../create_d64.rb etude.z5 etude.d64
	../create_d64.rb czech.z5 czechz5.d64
	../create_d64.rb czech.z3 czechz3.d64
	../create_d64.rb praxix.z5 praxix.d64

clean:
	rm -f *.z3 *.z5 test.d64

