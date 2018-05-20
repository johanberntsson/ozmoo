all: new

new:
	inform DragonTroll.inf
	cc inftod64.c -o inftod64
	./inftod64 dejavu.z3 dejavu.d64
	./inftod64 DragonTroll.z5 dragontroll.d64

org:
	cc inftod64_org.c -o inftod64org
	./inftod64org dejavu.z3 dejavu_org.d64
	./inftod64org DragonTroll.z5 dragontrollorg.d64
