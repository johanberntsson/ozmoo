all: xx16

xx16:
	ruby make.rb -df:0 -s games/lgop.z5 -t:x16 -v -dc:3:5 -cc:0 -cb:9
	#ruby make.rb games/infocom/sherlock.z5 -s -ch:100 -t:x16  -v
	#ruby make.rb -df:0 -ch:100 -s examples/dejavu.z3 -t:x16 -v
	#ruby make.rb -ch:100 -s games/temple.z5 -t:x16 -v
	#ruby make.rb -ch:100 -s examples/dragontroll.z5 -t:x16 -v

mega65:
	ruby make.rb -df:0 -s games/lgop.z5 -t:mega65 -v -dc:3:5 -cc:0 -cb:1
	#ruby make.rb -t:mega65 ./games/infocom/sherlock.z5 -u -s -ch:100 -sb:0 -dm:0  -v
	#ruby make.rb examples/Aventyr.z5 -ch -s -t:mega65 -smooth
	#ruby make.rb games/infocom/planetfall.z5 -s -t:mega65 -sw:0
	#ruby make.rb -debug -v -ch -s games/infocom/hollywood.z3 -t:mega65 -sw:0
	#ruby make.rb -s -v -ch -t:mega65 z6/shogun-r322-s890706.z6
	#ruby make.rb -s -v -ch -t:mega65 -asa . testsnd.z5
	#~/mega65/mega65_ftp -c "put testsnd.d81" -c "quit"
	#ruby make.rb -s -ch -t:mega65 -asw lurking games/infocom/lurkinghorror-r221-s870918.z3
	#mv mega65_lurkinghorror-r221-s870918.d81 lurking.d81
	#~/mega65/m65 -F
	#~/mega65/mega65_ftp -c "put lurking.d81" -c "mount lurking.d81" -c "quit"
	#ruby make.rb  -v -ch -t:mega65 -asw sherlock games/infocom/sherlock.z5
	#mv mega65_sherlock.d81 sherlock.d81
	#~/mega65/mega65_ftp -c "put sherlock.d81" -c "quit"
	#ruby make.rb  -s -v -ch -t:mega65 -asw sherlock testsound.z5
	#ruby make.rb  -s -v -t:mega65 -snd 003.aiff testbench.z5
	#ruby make.rb infocom/trinity-r15-s870628.z4 -t:mega65 -81 -s
	#ruby make.rb -debug -s infocom/zork1-invclues-r52-s871125.z5 -t:mega65
	#ruby make.rb -s infocom/zork1-invclues-r52-s871125.z5 -t:mega65
	#ruby make.rb -s ./games/infocom/amfvUnprotected.z4 -t:mega65
	#ruby make.rb -s infocom/beyondzork.z5 -81 -t:mega65
	#ruby make.rb -s -ch examples/dragontroll.z5 -t:mega65
	#ruby make.rb -s examples/dejavu.z3 -t:mega65
	#ruby make.rb games/eas.z5 -s -t:mega65
	#ruby make.rb -rc:7=11,8=15 -dc:7:8 infocom/planetfall.z5 -s -t:mega65
	#ruby make.rb -d71 -s infocom/planetfall.z5 -ss1:"Super Mario Murders" -ss2:"A coin-op mystery" -ss3:"by" -ss4:"John \"Popeye\" Johnsson" -sw:8 -t:mega65
	#ruby make.rb -s games/infocom/hollywood.z3 -f fonts/en/ClairsysOzmoo-Regular-US.fnt -t:mega65

c128:
	ruby make.rb -df:0 -s games/lgop.z5 -t:c128 -v -dc:3:5 -cc:0 -cb:1
	#ruby make.rb -s z6/shogun-r322-s890706.z6 -t:c128 -81
	#ruby make.rb infocom/trinity-r15-s870628.z4 -t:c128 -81 -s
	#ruby make.rb -s ./games/infocom/amfvUnprotected.z4 -t:c128
	#ruby make.rb -s infocom/zork1-invclues-r52-s871125.z5 -t:c128
	#ruby make.rb -s infocom/beyondzork.z5 -t:c128
	#ruby make.rb -s -ch examples/dragontroll.z5 -t:c128
	#ruby make.rb -s examples/dejavu.z3 -t:c128
	#ruby make.rb -s games/infocom/borderzone.z5 -t:c128 -u
	#ruby make.rb -cb:5 -s games/infocom/hollywood.z3 -t:c128
	#ruby make.rb -ch -s games/infocom/sherlock.z5 -t:c128 -u
	#ruby make.rb examples/minizork.z3 -t:c128 -u:r -s 
	#ruby make.rb -ch -s games/infocom/hollywood.z3 -t:c128 -sb:6 -u

c64:
	ruby make.rb -df:0 -s games/lgop.z5 -t:c64 -v -dc:3:5 -cc:0 -cb:1
	#ruby make.rb -s examples/dejavu.z3
	#ruby make.rb examples/Aventyr.z5 -f fonts/sv/ClairsysOzmoo-Bold-SV.fnt -cm:sv -ch -s -81
	#ruby make.rb -t:c64 games/infocom/hollywood.z3 -s -ch:100 -sb:0 -dm:0 -smooth
	#ruby make.rb custard.z7 -81 -s 
	#ruby make.rb green.z2 -ch:20 -u -s
	#ruby make.rb infocom/minizork.z3 -ch:20 -s -smooth
	#ruby make.rb infocom/minizork.z3 -v -i loaderpic.kla 
	#ruby make.rb examples/minizork.z3 -u -s 
	#ruby make.rb -v games/drakmagi.z5
	#ruby make.rb -ch -s infocom/zork1-invclues-r52-s871125.z5
	#ruby make.rb games/infocom/planetfall.z5 -s -sw:0
	#ruby make.rb -debug -ch -s games/infocom/hollywood.z3
	#ruby make.rb -b -p:0 -ch -s games/infocom/hollywood.z3
	#ruby make.rb -s ./test/strictz.z3
	#ruby make.rb -s ./test/strictz.z5 
	#ruby make.rb -s ./test/czech.z3 
	#ruby make.rb -s ./games/infocom/amfvUnprotected.z4 -81
	#ruby make.rb -s infocom/beyondzork.z5 -81
	#ruby make.rb  -s -P examples/dragontroll.z5
	#ruby make.rb -s games/infocom/borderzone.z5 -81 
	#ruby make.rb -s examples/dejavu.z3
	#ruby make.rb -cb:5 -s games/infocom/hollywood.z3 
	#ruby make.rb -S1 -s games/infocom/hollywood.z3 
	#ruby make.rb -s games/infocom/hollywood.z3 -f fonts/clairsys.fnt
	#ruby make.rb -s -p:0 infocom/zork2.z3 
	#ruby make.rb -s games/infocom/zork1.z3
	#ruby make.rb -s games/infocom/nord_and_bert.z4 -81
	#ruby make.rb -ch infocom/planetfall.z5 -s 

plus4:
	#ruby make.rb -ch -s infocom/zork1-invclues-r52-s871125.z5 -t:plus4
	#ruby make.rb infocom/trinity-r15-s870628.z4 -t:plus4 -81 -s
	#ruby make.rb -s ./games/infocom/amfvUnprotected.z4 -81 -t:plus4
	#ruby make.rb -s infocom/beyondzork.z5 -81 -t:plus4
	#ruby make.rb -s -P -r examples/dragontroll.z5 -t:plus4
	#ruby make.rb -s -P -r examples/dejavu.z3 -t:plus4
	ruby make.rb -s games/infocom/hollywood.z3 -t:plus4
	#ruby make.rb -s games/infocom/hollywood.z3 -f fonts/clairsys.fnt -t:plus4
	#ruby make.rb infocom/planetfall.z5 -s -t:plus4
	#ruby make.rb -s games/infocom/nord_and_bert.z4 -t:plus4 -81
	#ruby make.rb -s games/infocom/borderzone.z5 -t:plus4 -81

clean:
	rm -rf *d64 *d71 *d81 x16_*
