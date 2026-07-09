splashline0 
	!pet "", 0
splashline1
	!pet "", 0
splashline2
	!pet "", 0
splashline3
	!pet "", 0
splashline4
	!pet "               Ozmoo 12.6",0

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
	!pet "   Ctrl: D=Reset device# K=Key repeat",0
splashline7
!ifdef SMOOTHSCROLL {
	!pet "  0-8=Scroll slowness, 9=Smooth scroll",0
!ifdef TARGET_C128 {
splashline7alt
	!pet "           0-8=Scroll slowness",0
}
} else {
	!pet "           0-8=Scroll slowness",0
}


splash_index_col
	!byte 0, 0, 0, 0, 0, 0, 0, 0

