all: make_praxix
#all: make_czech
#all: make_oztest

make_oztest:
	inform -v3 oztest/oztest.inf oztest.z3
	inform -v5 oztest/oztest.inf oztest.z5
	../create_d64.rb oztest.z5 oztest.d64
	../create_d64.rb oztest.z3 oztest.d64

make_czech:
	inform -v3 czech/czech.inf czech.z3
	inform -v5 czech/czech.inf czech.z5
	../create_d64.rb czech.z5 czechz5.d64
	../create_d64.rb czech.z3 czechz3.d64

make_strictz:
	inform -v3 strictz/strictz.inf strictz.z3
	inform -v5 strictz/strictz.inf strictz.z5
	../create_d64.rb strictz.z3 strictz3.d64
	../create_d64.rb strictz.z5 strictz5.d64

make_etude:
	inform -v5 +etude etude/etude.inf etude.z5
	../create_d64.rb etude.z5 etude.d64

make_praxix:
	inform -v5 +etude praxix/praxix.inf praxix.z5
	../create_d64.rb praxix.z5 praxix.d64

clean:
	rm -f *.z3 *.z5 *.d64

