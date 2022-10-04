splashline0 
	!pet "@0s@", 0
splashline1
	!pet "@1s@", 0
splashline2
	!pet "@2s@", 0
splashline3
	!pet "@3s@", 0
splashline4
	!pet "               Ozmoo @vs@",0

splashline5
!ifndef NODARKMODE {
	!ifdef SCROLLBACK {
		!pet "        F1=Darkmode F5=Scrollback",0
	} else {
		!pet "               F1=Darkmode",0
	}
} else {
	!ifdef SCROLLBACK {
		!pet "              F5=Scrollback",0
	} else {
		!pet " ",0
	}
}
splashline6
	!pet "   Ctrl: D=Reset device# R=Repeat keys",0
splashline7
	!pet "            0-3=Scroll delay",0


splash_index_col
	!byte @0c@, @1c@, @2c@, @3c@, 0, 0, 0, 0

