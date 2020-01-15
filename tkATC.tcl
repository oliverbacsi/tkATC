#!/usr/bin/wish
##################################################
# tkATC - Air Traffic Controller, Tcl/Tk version #
#                                                #
# Based on the ncurses game ATC from BSDGames    #
#                                                #
# DickBird Software, 2019-JUN-24                 #
##################################################


#################### INIT PART ####################


package require Tk
package require img::jpeg
package require img::xpm

foreach t {P J} {
	image create photo i_pl_$t -format xpm -file "images/$t.xpm"
	for {set j 0} {$j < 7} {incr j} {
		for {set i 0} {$i < 8} {incr i} {
			set im "pl_${t}_${j}_[expr $i*45]"
			image create photo $im -width 46 -height 46
			$im copy i_pl_$t -from [expr $i*46] [expr $j*46] [expr $i*46+45] [expr $j*46+45] -to 0 0
		}
	}
}
image create photo i_a -format xpm -file "images/A.xpm"
for {set i 0} {$i < 8} {incr i} {
	set im "ai_[expr $i*45]"
	image create photo $im -width 55 -height 55
	$im copy i_a -from [expr $i*55] 0 [expr $i*55+54] 54 -to 0 0
}
image create photo i_e -format xpm -file "images/E.xpm"
for {set i 0} {$i < 8} {incr i} {
	set im "ex_[expr $i*45]"
	image create photo $im -width 46 -height 46
	$im copy i_e -from [expr $i*46] 0 [expr $i*46+45] 45 -to 0 0
}
image create photo be_0 -format xpm -file "images/B.xpm"
image create photo i_expl -format xpm -file "images/X.xpm"

array set DB {
	GameName ""
	W 0 H 0
	Delay 1
	MaxPlanes 0
	Airports {}
	Exits {}
	Beacons {}
	Planes {}
	Command ""
	CRASHED 0
	CrashLog ""
	TotalTime 0
	SafePlanes 0
	PlaneTimer 1
	PlaneRandom 30
	NextID 0
}
array set Delta {
	X,0  0 X,45  1 X,90 1 X,135 1 X,180 0 X,225 -1 X,270 -1 X,315 -1
	Y,0 -1 Y,45 -1 Y,90 0 Y,135 1 Y,180 1 Y,225  1 Y,270  0 Y,315 -1
}
global DB Delta
set DB(MapFont) [font actual "Arial 10 bold"]
set PAUSED 0 ; global PAUSED


#################### PROC PART ####################


proc showDetails {_name} {
global DB

	.ls config -text ""
	if {[lsearch -exact $DB(Beacons) $_name] > -1} {
		.ls config -text "Beacon $DB(B,$_name,Full) \[$_name\]:  X=$DB(B,$_name,X) Y=$DB(B,$_name,Y)"
	}
	if {[lsearch -exact $DB(Exits) $_name] > -1} {
		.ls config -text "Exit $DB(E,$_name,Full) \[$_name\]:  X=$DB(E,$_name,X) Y=$DB(E,$_name,Y) Direction=$DB(E,$_name,D)"
	}
	if {[lsearch -exact $DB(Airports) $_name] > -1} {
		.ls config -text "Airport $DB(A,$_name,Full) \[$_name\]:  X=$DB(A,$_name,X) Y=$DB(A,$_name,Y) Direction=$DB(A,$_name,D)"
	}
}


proc getDirChange {_fr _to} {
	if {$_to>$_fr} {
		if {[expr $_to-$_fr] > 180} {return -45} else {return 45}
	} elseif {$_to<$_fr} {
		if {[expr $_fr-$_to] < 180} {return -45} else {return 45}
	} else {
		return 0
	}
}


proc checkNextStep {XC YC Alt Dir tAlt tDir} {
global Delta
variable NextX -1
variable NextY -1
variable NextA -1
variable NextD -1

	if {$tAlt > $Alt} {
		set NextA [expr $Alt+1]
	} elseif {$tAlt < $Alt} {
		set NextA [expr $Alt-1]
	} else {
		set NextA $Alt
	}
	if {[expr $Alt+$NextA]} {
		set NextD [expr ($Dir+[getDirChange $Dir $tDir])%360]
		set NextX [expr $XC+$Delta(X,$NextD)]
		set NextY [expr $YC+$Delta(Y,$NextD)]
	} else {
		set NextX $XC
		set NextY $YC
		set NextD $Dir
	}
	return [list $NextX $NextY $NextA $NextD]
}


proc checkTargetReached {XC YC Alt Dir Target} {
global DB

	set TargetType [string index $Target 0]
	set TargetName [string range $Target 2 4]
	set TargetX   $DB($Target,X)
	set TargetY   $DB($Target,Y)
	set TargetDir $DB($Target,D)
	if {"$TargetType" eq "A"} {set TargetAlt 0} else {set TargetAlt 9}
	if {($XC == $TargetX) && ($YC == $TargetY) && ($Alt == $TargetAlt) && ($Dir == $TargetDir)} {return 1}
	return 0
}


proc removePlane {p} {
global DB

	.c delete $DB(P,$p,TxtID)
	.c delete $DB(P,$p,PicID)
	set idx [lsearch -exact $DB(Planes) $p]
	set DB(Planes) [concat [lrange $DB(Planes) 0 [expr $idx-1]] [lrange $DB(Planes) [expr $idx+1] end]]
	array unset DB P,$p,*
}


proc checkCrashConditions {Name Alt Target Fuel nX nY nAlt nDir} {
global DB
variable CR 0
variable CL {}

	if {($nX >= [expr $DB(W)/46]) || ($nX < 0)} {set CR 1 ; append CL "Plane \"$Name\" has left the playfield incorrectly.\n"}
	if {($nY >= [expr $DB(H)/46]) || ($nY < 0)} {set CR 1 ; append CL "Plane \"$Name\" has left the playfield incorrectly.\n"}
	if {($nAlt == 0) && ($Alt > 0)} {
		set POI [getMapFeature $nX $nY]
		if {![string match A,* $POI]} {
			set CR 1 ; append CL "Plane \"$Name\" has crashed into the ground.\n"
		} elseif {$nDir != $DB($POI,D)} {
			set CR 1 ; append CL "Plane \"$Name\" tried to land in wrong direction.\n"
		} elseif {"$Target" ne "$POI"} {
			set CR 1 ; append CL "Plane \"$Name\" has landed at the wrong airport.\n"
		}
	}
	if {[expr $Alt + $nAlt] > 0} {
		foreach q $DB(Planes) {
			if {$Name ne $q} {
				if {[expr $DB(P,$q,CurrA) + $DB(P,$q,NextA)] > 0} {
					if {([expr abs($nX-$DB(P,$q,NextX))] < 2) && ([expr abs($nY-$DB(P,$q,NextY))] < 2) && ([expr abs($nAlt-$DB(P,$q,NextA))] < 2)} {
						set CR 1
						append CL "Planes \"$Name\" and \"$q\" in dangerous proximity.\n"
					}
				}
			}
		}
	}
	if {$Fuel < 0} {
		set CR 1 ; append DB(CrashLog) "Plane \"$Name\" fuel tanks are dry.\n"
	}
	return [list $CR $CL]
}


proc getMapFeature {MX MY} {
global DB

	foreach i $DB(Airports) {
		if {($DB(A,$i,X) == $MX) && ($DB(A,$i,Y) == $MY)} {return "A,$i"}
	}
	foreach i $DB(Exits) {
		if {($DB(E,$i,X) == $MX) && ($DB(E,$i,Y) == $MY)} {return "E,$i"}
	}
	foreach i $DB(Beacons) {
		if {($DB(B,$i,X) == $MX) && ($DB(B,$i,Y) == $MY)} {return "B,$i"}
	}
	return ""
}


proc performNextStep {p} {
global DB

	foreach parm {X Y A D} {
		set DB(P,$p,Curr$parm) $DB(P,$p,Next$parm)
	}
	set id1 $DB(P,$p,PicID)
	set id2 $DB(P,$p,TxtID)
	set ty $DB(P,$p,Type)
	set cl $DB(P,$p,Color)
	set di $DB(P,$p,CurrD)
	.c itemconfig $id1 -image pl_${ty}_${cl}_$di
	.c coords $id1 [expr $DB(P,$p,CurrX)*46] [expr $DB(P,$p,CurrY)*46]
	.c coords $id2 [expr $DB(P,$p,CurrX)*46+1] [expr $DB(P,$p,CurrY)*46-1]
	incr DB(P,$p,Fuel) -1
}


proc initNewPlane {} {
global DB

	if {[llength $DB(Planes)] < $DB(MaxPlanes)} {
		set p [string index "ABCDEFGHIJKLMNOPQRSTUVWXYZ" $DB(NextID)]
		set DB(NextID) [expr ($DB(NextID)+1)%26]
		while {[info exists DB(P,$p,Type)]} {
			set p [string index "ABCDEFGHIJKLMNOPQRSTUVWXYZ" $DB(NextID)]
			set DB(NextID) [expr ($DB(NextID)+1)%26]
		}
		set AllFeatures {}
		foreach i $DB(Airports) {lappend AllFeatures "A,$i"}
		foreach i $DB(Exits)    {lappend AllFeatures "E,$i"}
		set Type [lindex {J P} [expr int(2.0*rand())]]
		set Col [expr int(7.0*rand())]
		set Source [lindex $AllFeatures [expr int(rand()*[llength $AllFeatures])]]
		set Target $Source
		while {"$Target" eq "$Source"} {
			set Target [lindex $AllFeatures [expr int(rand()*[llength $AllFeatures])]]
		}
		lappend DB(Planes) $p
		set DB(P,$p,Type) $Type
		set DB(P,$p,Color) $Col
		set DB(P,$p,CurrX) $DB($Source,X)
		set DB(P,$p,CurrY) $DB($Source,Y)
		set DB(P,$p,Target) $Target
		set DB(P,$p,Source) $Source
		if {"[string index $Source 0]" eq "A"} {
			set DB(P,$p,CurrA) 0
			set DB(P,$p,CurrD) $DB($Source,D)
			set DB(P,$p,TargA) 0
			set DB(P,$p,TargD) $DB($Source,D)
		} else {
			set DB(P,$p,CurrA) 7
			set DB(P,$p,CurrD) [expr ($DB($Source,D)+180)%360]
			set DB(P,$p,TargA) 7
			set DB(P,$p,TargD) $DB(P,$p,CurrD)
		}
		set DB(P,$p,Itiner) {}
		set diffX [expr abs($DB($Target,X)-$DB($Source,X))]
		set diffY [expr abs($DB($Target,Y)-$DB($Source,Y))]
		if {$diffX>$diffY} {set DB(P,$p,Fuel) [expr round(1.8*$diffX)+5]} else {set DB(P,$p,Fuel) [expr round(1.8*$diffY)+5]}
		foreach parm {A D X Y} {set DB(P,$p,Next$parm) $DB(P,$p,Curr$parm)}
		set DB(P,$p,PicID) [.c create image [expr 46*$DB(P,$p,CurrX)] [expr 46*$DB(P,$p,CurrY)] -image pl_${Type}_${Col}_$DB(P,$p,CurrD) -anchor nw]
		set DB(P,$p,TxtID) [.c create text  [expr 46*$DB(P,$p,CurrX)+1] [expr 46*$DB(P,$p,CurrY)-1] -font $DB(MapFont) -text $p -anchor nw -fill [lindex {"#FF8080" "#FFB880" "#FFFF80" "#80FF80" "#80FFFF" "#8080FF" "#FF80FF"} $Col]]
		.c bind $DB(P,$p,PicID) <1> "updatePlaneDetails $p"
		.c bind $DB(P,$p,TxtID) <1> "updatePlaneDetails $p"
		.c bind $DB(P,$p,PicID) <3> "showPlaneRoute $p"
		.c bind $DB(P,$p,TxtID) <3> "showPlaneRoute $p"
	}
	set DB(PlaneTimer) [expr round(rand()*$DB(PlaneRandom))+1]
}


proc interpItiner {XC YC Alt Dir tAlt tDir Itin} {

	set i1 [lindex $Itin 0]
	if {![string length $i1]} {return [list $tAlt $tDir $Itin]}
	set i1D [string map {, " " : " "} $i1]
	if {("[string index $i1 0]" eq "@") && ("[string range [getMapFeature $XC $YC] end-2 end]" ne "[string range $i1 1 3]")} {return [list $tAlt $tDir $Itin]}
	if {"[string index $i1 0]" eq "+"} {
		foreach {NX NY NA ND} [checkNextStep $XC $YC $Alt $Dir $tAlt $tDir] {}
		if {"[string range [getMapFeature $NX $NY] end-2 end]" ne "[string range $i1 1 3]"} {return [list $tAlt $tDir $Itin]}
	}
	foreach c $i1D {
		if {"$c" == "L"} {
			set tDir [expr ($Dir-45)%360]
		} elseif {"$c" == "R"} {
			set tDir [expr ($Dir+45)%360]
		} elseif {[regexp -nocase {A[0-9]} $c]} {
			set tAlt [string index $c end]
		} elseif {[lsearch -exact {0 45 90 135 180 225 270 315} $c] > -1} {
			set tDir $c
		}
	}
	set Itin [lrange $Itin 1 end]
	return [list $tAlt $tDir $Itin]
}


proc refreshSideBar {} {
global DB

	.c1 delete all
	set pY 5
	set clr(A) "#90E090" ; set clr(E) "#9090E0"
	foreach p $DB(Planes) {
		.c1 create rectangle 0 $pY 150 [expr $pY+50] -fill [lindex {"#806060" "#807060" "#808060" "#608060" "#608080" "#606080" "#806080"} $DB(P,$p,Color)] -outline [lindex {"#604040" "#605040" "#606040" "#406040" "#406060" "#404060" "#604060"} $DB(P,$p,Color)] -tag t_pl_$p
		set ty $DB(P,$p,Type) ; set cl $DB(P,$p,Color) ; set di $DB(P,$p,CurrD) ; set fl $DB(P,$p,Fuel)
		set im "pl_${ty}_${cl}_$di"
		.c1 create image 0 [expr $pY+2] -image $im -anchor nw -tag t_pl_$p
		if {$fl > 50} {
			set cl1 "#C0FFC0" ; set cl2 "#80C080"
		} elseif {$fl > 25} {
			set cl1 "#FFFFC0" ; set cl2 "#C0C080"
		} else {
			set cl1 "#FFC0C0" ; set cl2 "#C08080"
		}
		.c1 create line 49 [expr $pY+47] [expr 49+$fl] [expr $pY+47] -fill $cl1 -tag t_pl_$p
		.c1 create line 49 [expr $pY+48] [expr 49+$fl] [expr $pY+48] -fill $cl2 -tag t_pl_$p
		.c1 create text 70 [expr $pY+2]  -text [format "%1s%[expr $DB(P,$p,CurrA)+1]s%1d" $p " " $DB(P,$p,CurrA)] -font $DB(MapFont) -anchor nw -fill white -tag t_pl_$p
		set St [string index $DB(P,$p,Source) 0] ; set Sn [string range $DB(P,$p,Source) 2 4]
		set Tt [string index $DB(P,$p,Target) 0] ; set Tn [string range $DB(P,$p,Target) 2 4]
		.c1 create text  55 [expr $pY+17] -text "$Sn" -font $DB(MapFont) -anchor nw -fill $clr($St) -tag t_pl_$p
		.c1 create text  95 [expr $pY+17] -text "--"  -font $DB(MapFont) -anchor nw -fill black     -tag t_pl_$p
		.c1 create text 115 [expr $pY+17] -text "$Tn" -font $DB(MapFont) -anchor nw -fill $clr($Tt) -tag t_pl_$p
		.c1 create text  50 [expr $pY+32] -text $DB(P,$p,Itiner) -font $DB(MapFont) -anchor nw -fill black -tag t_pl_$p
		.c1 bind t_pl_$p <1> "focusPlane $p"
		incr pY 55
	}
	incr pY 20
	.c1 config -scrollregion [list 0 0 150 $pY]
	.lg config -text "Pl: $DB(SafePlanes) | Ti: $DB(TotalTime)"
}


proc focusPlane {p} {
global DB

	.c delete t_route
	set SY [.sy get] ; set HeiCorr [expr 0.5*([lindex $SY 1]-[lindex $SY 0])]
	set SX [.sx get] ; set WidCorr [expr 0.5*([lindex $SX 1]-[lindex $SX 0])]
	.c yview moveto [expr 46.0*$DB(P,$p,CurrY)/$DB(H)-$HeiCorr]
	.c xview moveto [expr 46.0*$DB(P,$p,CurrX)/$DB(W)-$WidCorr]
	updatePlaneDetails $p
	focus .e ; .e icursor end
}


proc updatePlaneDetails {p} {
global DB

	.c delete t_route
	array set ty {P Propeller J Jet}
	.ls config -text "$ty($DB(P,$p,Type)) Airplane \"$p\"  |  From [string map {, :} $DB(P,$p,Source)]  To [string map {, :} $DB(P,$p,Target)]  |  Heading:$DB(P,$p,CurrD)(-->$DB(P,$p,TargD))  Alt:$DB(P,$p,CurrA)(-->$DB(P,$p,TargA))  Fuel:$DB(P,$p,Fuel)"
	set DB(Command) "$p "
	append DB(Command) [lrange $DB(P,$p,Itiner) 0 end]
	focus .e ; .e icursor end
}


proc importPlaneItiner {} {
global DB

	set DB(Command) [string toupper $DB(Command)]
	set p [lindex $DB(Command) 0] ; set DB(Command) [lrange $DB(Command) 1 end]
	if {[lsearch -exact $DB(Planes) $p] > -1} {
		set DB(P,$p,Itiner) $DB(Command)
	}
	set DB(Command) ""
	refreshSideBar
}


proc pauseOnOff {} {
global PAUSED

	set PAUSED [expr !$PAUSED]
	.bp config -relief [expr $PAUSED?"sunken":"raised"]
}


proc showPlaneRoute {p} {
global DB

	.c delete t_route

	# Fuel Range
	set XC $DB(P,$p,CurrX) ; set YC $DB(P,$p,CurrY)
	set XL [expr ($XC-$DB(P,$p,Fuel))*46] ; set XR [expr ($XC+$DB(P,$p,Fuel)+1)*46]
	set YT [expr ($YC-$DB(P,$p,Fuel))*46] ; set YB [expr ($YC+$DB(P,$p,Fuel)+1)*46]
	.c create line $XL $YT $XR $YT -fill white -tag t_route
	.c create line $XR $YT $XR $YB -fill white -tag t_route
	.c create line $XL $YB $XR $YB -fill white -tag t_route
	.c create line $XL $YT $XL $YB -fill white -tag t_route

	# Calculated route
	foreach v {Itiner Target Fuel CurrX CurrY CurrA CurrD TargA TargD} {set my$v $DB(P,$p,$v)}
	set myRoute {}
	set EndRoute 0
	while {!$EndRoute} {
		lappend myRoute [list $myCurrX $myCurrY $myCurrA]
		if {[checkTargetReached $myCurrX $myCurrY $myCurrA $myCurrD $DB(P,$p,Target)]} {
			set EndRoute 1 ; # 1 is for OK
		} else {
			set Ans [interpItiner $myCurrX $myCurrY $myCurrA $myCurrD $myTargA $myTargD $myItiner]
			set myTargA [lindex $Ans 0]
			set myTargD [lindex $Ans 1]
			set myItiner [lindex $Ans 2]

			foreach {myNextX myNextY myNextA myNextD} [checkNextStep $myCurrX $myCurrY $myCurrA $myCurrD $myTargA $myTargD] {}

			###BUG: Unfortunately this is calculating with the current (not future) position of all other planes.
			set Ans [checkCrashConditions $p $myCurrA $myTarget $myFuel $myNextX $myNextY $myNextA $myNextD]
			if {[lindex $Ans 0]} {
				set EndRoute 2 ; # 2 is for Crashed
#				lappend myRoute [list $myNextX $myNextY $myNextA]
			}

			set myCurrX $myNextX ; set myCurrY $myNextY ; set myCurrA $myNextA ; set myCurrD $myNextD ; incr myFuel -1
		}
	}

	# Draw that shit
	for {set i 1} {$i < [llength $myRoute]} {incr i} {
		set PrevC [lindex $myRoute [expr $i-1]] ; set ThisC [lindex $myRoute $i]
		foreach {PrevX PrevY PrevA} $PrevC {}
		foreach {ThisX ThisY ThisA} $ThisC {}
		set Col [lindex {"#000040" "#000070" "#0000A0" "#0000D0" "#0000FF" "#3030FF" "#6060FF" "#9090FF" "#B8B8FF" "#E8E8FF"} $ThisA]
		.c create line [expr 46*$PrevX+23] [expr 46*$PrevY+23] [expr 46*$ThisX+23] [expr 46*$ThisY+23] -width 3 -fill $Col -tag t_route
	}
	if {$EndRoute == 2} {
		.c create image [expr $ThisX*46] [expr $ThisY*46] -image i_expl -anchor nw -tag t_route
	}
}


#################### MAIN PART ####################


grid [canvas .c -scrollregion {0 0 100 100}] -column 0 -row 0 -sticky news -padx 5 -pady 5
grid [scrollbar .sy -orient vertical -width 10]   -column 1 -row 0 -sticky nws -padx 5 -pady 5
grid [scrollbar .sx -orient horizontal -width 10] -column 0 -row 1 -sticky ew -padx 5 -pady 5
.c config -yscrollcommand {.sy set} -xscrollcommand {.sx set}
.sy config -command {.c yview}
.sx config -command {.c xview}
grid [canvas .c1 -scrollregion {0 0 150 100} -width 150] -column 2 -row 0 -rowspan 2 -sticky news -padx 5 -pady 5
grid [scrollbar .sy1 -orient vertical -width 10] -column 3 -row 0 -rowspan 2 -sticky ns -padx 5 -pady 5
.c1 config -yscrollcommand {.sy1 set}
.sy1 config -command {.c1 yview}
grid [label .ls -relief ridge -font [font actual "Courier 10 bold"] -bg darkblue -fg cyan] -column 0 -row 2 -sticky news -padx 5 -pady 5
grid [label .bp -bg red -fg black -text "P" -font $DB(MapFont) -relief raised] -column 1 -row 2 -sticky news -padx 5 -pady 5
grid [label .lg -relief sunken -font [font actual "Courier 10 bold"] -fg black -anchor w -justify left] -column 2 -row 2 -sticky news -padx 5 -pady 5
grid [entry .e -textvariable DB(Command) -font [font actual "Courier 10 bold"] -bg "#004000" -fg yellow -justify left] -column 0 -row 3 -columnspan 4 -sticky news -padx 5 -pady 5
grid rowconf . 0 -weight 1 ; grid columnconf . 0 -weight 1
wm proto . WM_DELETE_WINDOW {
	set DB(CRASHED) 1
	lappend DB(CrashLog) "GAME INTERRUPTED!!!\n"
	foreach a [after info] {after cancel $a}
	set kuki 1
}
bind .e <Return> importPlaneItiner
bind .bp <1> pauseOnOff

set GameName [tk_getOpenFile -initialdir "games" -title "Select a Base Map"]
if {![string length $GameName]} {destroy . ; return}
set DB(GameName) [file tail [file dirname $GameName]]
image create photo i_basemap -format jpeg -file "games/$DB(GameName)/BaseMap.jpg"

set fin [open "games/$DB(GameName)/Config.txt" r]
while {![eof $fin]} {
	set sList [gets $fin]
	switch -nocase -- [lindex $sList 0] {
		W {set DB(W) [lindex $sList 1]}
		H {set DB(H) [lindex $sList 1]}
		D {set DB(Delay) [lindex $sList 1]}
		M {set DB(MaxPlanes) [lindex $sList 1]}
		F {set DB(PlaneRandom) [lindex $sList 1]}
		A {
			foreach {_ Name X Y D Full} $sList {}
			lappend DB(Airports) $Name
			set DB(A,$Name,X) $X
			set DB(A,$Name,Y) $Y
			set DB(A,$Name,D) $D
			set DB(A,$Name,Full) $Full
		}
		E {
			foreach {_ Name X Y D Full} $sList {}
			lappend DB(Exits) $Name
			set DB(E,$Name,X) $X
			set DB(E,$Name,Y) $Y
			set DB(E,$Name,D) $D
			set DB(E,$Name,Full) $Full
		}
		B {
			foreach {_ Name X Y Full} $sList {}
			lappend DB(Beacons) $Name
			set DB(B,$Name,X) $X
			set DB(B,$Name,Y) $Y
			set DB(B,$Name,Full) $Full
		}
	}
}
close $fin

.c config -scrollregion [list 0 0 $DB(W) $DB(H)]
.c create image 0 0 -image i_basemap -anchor nw
for {set i 0} {$i <= $DB(W)} {incr i 46} {
	.c create line $i 0 $i $DB(H) -width 1 -fill "#202020"
#	.c create text [expr $i+5] 5 -anchor nw -font $DB(MapFont) -fill white -text [expr $i/46]
}
for {set i 0} {$i <= $DB(H)} {incr i 46} {
	.c create line 0 $i $DB(W) $i -width 1 -fill "#202020"
#	.c create text 5 [expr $i+5] -anchor nw -font $DB(MapFont) -fill white -text [expr $i/46]
}

foreach i $DB(Beacons) {
	set _tmp [.c create image [expr 46*$DB(B,$i,X)]   [expr 46*$DB(B,$i,Y)]    -image be_0 -anchor nw]
	.c create text  [expr 46*$DB(B,$i,X)+2] [expr 46*$DB(B,$i,Y)+46] -font $DB(MapFont) -anchor sw -fill "#FFC0E0" -text $i
	.c bind $_tmp <1> "showDetails $i"
	.c bind $_tmp <3> "append DB(Command) @$i: ; .e icursor end"
}
foreach i $DB(Exits) {
	set _tmp [.c create image [expr 46*$DB(E,$i,X)]   [expr 46*$DB(E,$i,Y)]    -image ex_$DB(E,$i,D) -anchor nw]
	.c create text  [expr 46*$DB(E,$i,X)+2] [expr 46*$DB(E,$i,Y)+46] -font $DB(MapFont) -anchor sw -fill "#C0C0FF" -text $i
	.c bind $_tmp <1> "showDetails $i"
	.c bind $_tmp <3> "append DB(Command) +$i: ; .e icursor end"
}
foreach i $DB(Airports) {
	set _tmp [.c create image [expr 46*$DB(A,$i,X)-4] [expr 46*$DB(A,$i,Y)-4]  -image ai_$DB(A,$i,D) -anchor nw]
	.c create text  [expr 46*$DB(A,$i,X)+2] [expr 46*$DB(A,$i,Y)+46] -font $DB(MapFont) -anchor sw -fill "#C0FFC0" -text $i
	.c bind $_tmp <1> "showDetails $i"
	.c bind $_tmp <3> "append DB(Command) +$i: ; .e icursor end"
}

while {!$DB(CRASHED)} {
	if {!$PAUSED} {
		incr DB(PlaneTimer) -1
		incr DB(TotalTime)
		set PlanesToRemove {}
		foreach p $DB(Planes) {
			if {("$DB(P,$p,Type)" eq "P") && ([expr $DB(TotalTime)%2])} continue
			if {[checkTargetReached $DB(P,$p,CurrX) $DB(P,$p,CurrY) $DB(P,$p,CurrA) $DB(P,$p,CurrD) $DB(P,$p,Target)]} {
				incr DB(SafePlanes)
				lappend PlanesToRemove $p
			}
		}
		foreach p $PlanesToRemove {removePlane $p}
		foreach p $DB(Planes) {
			if {("$DB(P,$p,Type)" eq "P") && ([expr $DB(TotalTime)%2])} continue
			set Ans [interpItiner $DB(P,$p,CurrX) $DB(P,$p,CurrY) $DB(P,$p,CurrA) $DB(P,$p,CurrD) $DB(P,$p,TargA) $DB(P,$p,TargD) $DB(P,$p,Itiner)]
			set DB(P,$p,TargA) [lindex $Ans 0]
			set DB(P,$p,TargD) [lindex $Ans 1]
			set DB(P,$p,Itiner) [lindex $Ans 2]
		}
		foreach p $DB(Planes) {
			if {("$DB(P,$p,Type)" eq "P") && ([expr $DB(TotalTime)%2])} continue
			foreach {NX NY NA ND} [checkNextStep $DB(P,$p,CurrX) $DB(P,$p,CurrY) $DB(P,$p,CurrA) $DB(P,$p,CurrD) $DB(P,$p,TargA) $DB(P,$p,TargD)] {}
			set DB(P,$p,NextX) $NX ; set DB(P,$p,NextY) $NY
			set DB(P,$p,NextA) $NA ; set DB(P,$p,NextD) $ND
		}
		foreach p $DB(Planes) {
			if {("$DB(P,$p,Type)" eq "P") && ([expr $DB(TotalTime)%2])} continue
			set Ans [checkCrashConditions $p $DB(P,$p,CurrA) $DB(P,$p,Target) $DB(P,$p,Fuel) $DB(P,$p,NextX) $DB(P,$p,NextY) $DB(P,$p,NextA) $DB(P,$p,NextD)]
			set DB(CRASHED) [lindex $Ans 0]
			set DB(CrashLog) [lrange $Ans 1 end]
		}
		if {$DB(CRASHED)} continue
		foreach p $DB(Planes) {
			if {("$DB(P,$p,Type)" eq "P") && ([expr $DB(TotalTime)%2])} continue
			performNextStep $p
		}

		if {!$DB(PlaneTimer)} initNewPlane
	}
	refreshSideBar
	after [expr $DB(Delay)*1000] {set kuki 1}
	update idletasks
	vwait kuki
}

tk_messageBox -type ok -icon warning -title "GAME OVER" -message "[lindex $DB(CrashLog) 0]\nTime Played: $DB(TotalTime)\nSafe Planes: $DB(SafePlanes)"
destroy .
return
