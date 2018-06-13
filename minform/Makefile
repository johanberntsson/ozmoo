all:
	inform -v5 minform.inf
	../ztools-master/txd -d -n minform.z5 > minform.zasm
	../create_d64.rb minform.z5 minform.d64 minform.dynmem
clean:
	rm -f minform.z5 minform.d64

