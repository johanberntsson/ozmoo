splashline0 
	!pet "@0s@", 0
splashline1
	!pet "@1s@", 0
splashline2
	!pet "@2s@", 0
splashline3
	!pet "@3s@", 0
splashline4
!ifdef UNDO {
	!pet "          Ozmoo @vs@ with Undo",0
} else {
	!pet "               Ozmoo @vs@",0
}

; The key lines below are the CBM ones, and on an Apple every one of them is
; wrong: there are no function keys, the save device and key repeat are not
; ours to set (both are compiled out of getchar_and_maybe_toggle_darkmode) and
; the scroll slowness keys wait on a raster this machine has not got - so
; leaving them would advertise three things that do nothing. A IIgs keeps
; darkmode, on Ctrl-D; its two colourless siblings are built NODARKMODE.
splashline5
!ifdef TARGET_APPLE2_FAMILY {
	!ifndef NODARKMODE {
		!pet "             Ctrl-D=Darkmode",0
	} else {
		!pet " ",0
	}
} else ifndef NODARKMODE {
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
!ifdef UNDO {
!ifndef Z5PLUS {
SHOWUNDO=1
}
}

splashline6
!ifdef TARGET_APPLE2_FAMILY {
	!pet " ",0
} else ifdef TARGET_X16 {
	!pet "       Ctrl: 0-8=Scroll slowness",0
} else ifdef SHOWUNDO {
	!pet " Ctrl: D=Reset device# K=Key rpt U=Undo",0
} else {
	!pet "   Ctrl: D=Reset device# K=Key repeat",0
}

splashline7
!ifdef TARGET_APPLE2_FAMILY {
	!pet " ",0
} else ifdef SMOOTHSCROLL {
	!pet "  0-8=Scroll slowness, 9=Smooth scroll",0
!ifdef TARGET_C128 {
splashline7alt
	!pet "           0-8=Scroll slowness",0
}
} else ifdef TARGET_X16 {
	!pet "",0
} else {
	!pet "           0-8=Scroll slowness",0
}


splash_index_col
	!byte @0c@, @1c@, @2c@, @3c@, 0, 0, 0, 0

