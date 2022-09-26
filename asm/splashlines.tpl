splashline0 
	!pet "@0s@", 0
splashline1
	!pet "@1s@", 0
splashline2
	!pet "@2s@", 0
splashline3
	!pet "@3s@", 0
splashline4

!ifndef NODARKMODE {
	!ifdef SCROLLBACK {
		!pet " Ozmoo @vs@  F1=Darkmode F5=Scrollback"
	} else {
		!pet "        Ozmoo @vs@   F1=Darkmode"
	}
} else {
	!ifdef SCROLLBACK {
		!pet "       Ozmoo @vs@   F5=Scrollback"
	} else {
		!pet "               Ozmoo @vs@"
	}
}
!byte 0


splash_index_col
	!byte @0c@, @1c@, @2c@, @3c@, 0

