all: z6

z6:
	inform -v6 testz6.inf
	ruby make.rb -s testz6.z6

frotz:
	inform -v6 testz6.inf
	frotz testz6.z6

c64:
	ruby make.rb -s examples/dejavu.z3

x16:
	ruby make.rb -s examples/dejavu.z3 -t:x16

mega65:
	ruby make.rb -s examples/dejavu.z3 -t:mega65

plus4:
	ruby make.rb -s examples/dejavu.z3 -t:plus4

clean:
	rm -rf *d64 *d71 *d81 x16_*
