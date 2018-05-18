! ----------------------------------------------------------------------------
!  mInform version of VERBLIB.  The original work is:
!  (c) Graham Nelson 1993, 1994, 1995, 1996 but freely usable (see manuals)
!  the reductions are (c) Dave Bernazzani 2004.
! ----------------------------------------------------------------------------
System_file;

Default MAX_CARRIED  100;
Default MAX_SCORE    0;
Default OBJECT_SCORE 4;
Default ROOM_SCORE   5;

! ----------------------------------------------------------------------------
!  Next the WriteListFrom routine, a flexible object-lister taking care of
!  plurals, inventory information, various formats and so on.  This is used
!  by everything in the library which ever wants to list anything.
!
!  If there were no objects to list, it prints nothing and returns false;
!  otherwise it returns true.
!
!  o is the object, and style is a bitmap, whose bits are given by:
! ----------------------------------------------------------------------------

Constant NEWLINE_BIT    1;    !  New-line after each entry
Constant INDENT_BIT     2;    !  Indent each entry by depth
Constant FULLINV_BIT    4;    !  Full inventory information after entry
Constant ENGLISH_BIT    8;    !  English sentence style, with commas and and
Constant RECURSE_BIT   16;    !  Recurse downwards with usual rules
Constant ALWAYS_BIT    32;    !  Always recurse downwards
Constant TERSE_BIT     64;    !  More terse English style
Constant PARTINV_BIT  128;    !  Only brief inventory information after entry
Constant DEFART_BIT   256;    !  Use the definite article in list
Constant WORKFLAG_BIT 512;    !  At top level (only), only list objects
                              !  which have the "workflag" attribute
Constant ISARE_BIT   1024;    !  Print " is" or " are" before list
Constant CONCEAL_BIT 2048;    !  Omit objects with "concealed" or "scenery":
                              !  if WORKFLAG_BIT also set, then does _not_
                              !  apply at top level, but does lower down
Constant NOARTICLE_BIT 4096;  !  Print no articles, definite or not

[ NextEntry o depth;
  o=sibling(o);
  if (c_style & WORKFLAG_BIT ~= 0 && depth==0)
  {   while (o~=0 && o hasnt workflag) o=sibling(o);
      return o;
  }
  if (c_style & CONCEAL_BIT ~= 0)
      while (o~=0 && (o has concealed || o has scenery)) o=sibling(o);
  return o;
];

[ WriteListFrom o style depth;
  c_style=style;
  if (style & WORKFLAG_BIT ~= 0)
  {   
    while (o~=0 && o hasnt workflag) o=sibling(o);
  }
  else
  {   if (c_style & CONCEAL_BIT ~= 0)
          while (o~=0 && (o has concealed || o has scenery)) o=sibling(o);
  }
  if (o==0) rfalse;
  WriteListR(o,depth);
  rtrue;
];


[ WriteListR o depth stack_pointer  classes_p sizes_p i j n;
  classes_p = match_classes + stack_pointer;
  sizes_p   = match_list + stack_pointer;

  for (i=o,j=0:i~=0 && (j+stack_pointer)<128:i=NextEntry(i,depth),j++)
  {   
      classes_p->j=0;
  }

  if (c_style & ISARE_BIT ~= 0)
  {   if (j==1) print " is"; else print " are";
      if (c_style & NEWLINE_BIT ~= 0) print ":^"; else print " ";
      c_style = c_style - ISARE_BIT;
  }

  stack_pointer = stack_pointer+j+1;

  n=j;

  for (i=1, j=o: i<=n: j=NextEntry(j,depth), i++)
  {   
      WriteBeforeEntry(j,depth);
      if (c_style & DEFART_BIT ~= 0) DefArt(j); else InDefArt(j);
      WriteAfterEntry(j,depth,stack_pointer);
      if (c_style & ENGLISH_BIT ~= 0)
      {   if (i==n-1) print " and ";
          if (i<n-1) print ", ";
      }
  }
];


[ WriteBeforeEntry o depth  flag;
  if (c_style & INDENT_BIT ~= 0) spaces 2*(depth+wlf_indent);

  if (c_style & FULLINV_BIT ~= 0)
  {   if (o.invent~=0)
      {   inventory_stage=1;
          flag=PrintOrRun(o,invent,1);
          if (flag==1 && c_style & NEWLINE_BIT ~= 0) new_line;
      }
  }
  return flag;
];


[ WriteAfterEntry o depth stack_p  flag flag2 comb;

  if (c_style & PARTINV_BIT ~= 0)
  {   comb=0;
      if (o has container && o hasnt open)     comb=comb+2;
      if ((o has container && (o has open || o has transparent))
          && (child(o)==0)) comb=comb+4;
      if (comb==2) print " (which is closed)";
      if (comb==4) print " (which is empty)";
      if (comb==6) print " (which is closed and empty)";
  }

  if (c_style & FULLINV_BIT ~= 0)
  {   if (o.invent ~= 0)
      {   inventory_stage=2;
          if (RunRoutines(o,invent)~=0)
          {   if (c_style & NEWLINE_BIT ~= 0) new_line;
              rtrue;
          }
      }
#IFDEF MINFORM_WEAR;
      if (o has worn)  { print " (being worn"; flag2=1; }
#ENDIF;
      if (o has container)
      {   if (o has openable)
          {   if (flag2==1) print " and ";
              else print " (which is ";
              if (o has open)
              {   print "open";
                  if (child(o)==0) print " but empty";
              }
              else print "closed";
              if (o has lockable && o has locked) print " and locked";
              flag2=1;
          }
          else
              if (child(o)==0)
              {   if (flag2==1) print " and empty";
                  else print " (which is empty)";
              }
      }
      if (flag2==1) print ")";
  }

  if (c_style & ALWAYS_BIT ~= 0 && child(o)~=0)
  {   if (c_style & ENGLISH_BIT ~= 0) print " containing ";
      flag=1;
  }

  if (c_style & RECURSE_BIT ~= 1 && child(o)~=0)
  {   if (o has supporter)
      {   if (c_style & ENGLISH_BIT ~= 0)
          {   if (c_style & TERSE_BIT ~= 0)
              print " (on "; else print ", on top of ";
              if (o has animate) print "whom "; else print "which ";
          }
          flag=1;
      }
      if (o has container && (o has open || o has transparent))
      {   if (c_style & ENGLISH_BIT ~= 0)
          {   if (c_style & TERSE_BIT ~= 0)
                  print " (in "; else print ", inside ";
              if (o has animate) print "whom "; else print "which ";
          }
          flag=1;
      }
  }

  if (flag==1 && c_style & ENGLISH_BIT ~= 0)
  {   if (children(o) > 1) print "are "; else print "is ";
  }

  if (c_style & NEWLINE_BIT ~= 0) new_line;

  if (flag==1) WriteListR(child(o),depth+1,stack_p);

  if (flag==1 && c_style & TERSE_BIT ~= 0) print ")";
];

! ----------------------------------------------------------------------------
!   A cunning routine (which could have been a daemon, but isn't, for the
!   sake of efficiency) to move objects which could be in many rooms about
!   so that the player never catches one not in place
! ----------------------------------------------------------------------------

[ MoveFloatingObjects i k l m address;
  for (i=selfobj+1: i<=top_object: i++)
  {   address=i.&found_in;
      if (address~=0 && i hasnt absent)
      {   if (ZRegion(address-->0)==2)
          {   if (indirect(address-->0) ~= 0) move i to location;
          }
          else
          {   k=i.#found_in;
              for (l=0: l<k/2: l++)
              {   m=address-->l;
                  if (m==location || m in location) move i to location;
              }
          }
      }
  }
];

! ----------------------------------------------------------------------------
!   Two little routines for moving the player safely.
! ----------------------------------------------------------------------------

[ PlayerTo newplace flag;

  move player to newplace;
  while (parent(newplace) ~= 0) newplace = parent(newplace);
  location = newplace;
  MoveFloatingObjects();
  if (flag == 0) <Look>;
  if (flag == 1) { NoteArrival(); ScoreArrival(); }
  if (flag == 2) LookSub();
];

[ MovePlayer direc; <Go direc>; <Look>; ];

[ QuitSub; quit; ];

[ RestartSub; @restart; ];

[ RestoreSub;
  restore Rmaybe;
  return L__M(##Restore,1);
  .RMaybe; L__M(##Restore,2);
];

[ SaveSub;
  save Smaybe;
  return L__M(##Restore,1);
  .SMaybe; L__M(##Restore,2);
];

[ ScriptOnSub;
  if (transcript_mode==1) return L__M(##ScriptOn,1);
  transcript_mode=1;
  0-->8 = (0-->8)|1;
  L__M(##ScriptOn,2); VersionSub();
];

[ ScriptOffSub;
  if (transcript_mode==0) return L__M(##ScriptOff,1);
  L__M(##ScriptOff,2);
  transcript_mode=0;
  0-->8 = (0-->8)&$fffe;
];

! ----------------------------------------------------------------------------
!   The scoring system
! ----------------------------------------------------------------------------

[ ScoreSub;
  L__M(##Score);
];

! ----------------------------------------------------------------------------
!   Real verbs start here: Inventory
! ----------------------------------------------------------------------------

[ InvSub;
  if (child(player)==0) return L__M(##Inv,1);
  L__M(##Inv,2);
  print ":^";
  WriteListFrom(child(player), (FULLINV_BIT + INDENT_BIT + NEWLINE_BIT + RECURSE_BIT), 1);
  AfterRoutines();
];

! ----------------------------------------------------------------------------
!   Object movement verbs
! ----------------------------------------------------------------------------

[TakeAllSub;
    "You must take things individually.";
];
    
[ TakeSub;
  if (RTakeSub(location)~=0) rtrue;
  if (AfterRoutines()==1) rtrue;
  if (keep_silent==1) rtrue;
  L__M(##Take,1);
];

[ RTakeSub fromobj i j k postonobj;
  if (noun==player) return L__M(##Take,5);
  if (noun has animate) return L__M(##Take,2,noun);
  if (parent(player)==noun) return L__M(##Take,4,noun);

  i=parent(noun);
  if (i==player) return L__M(##Take,5);

  if (i has container || i has supporter)
  {   postonobj=i;
      k=action; action=##LetGo;
      if (RunRoutines(i,before)~=0) { action=k; rtrue; }
      action=k;
  }

  while (i~=fromobj && i~=0)
  {   if (i hasnt container && i hasnt supporter)
      {   if (i has animate) return L__M(##Take,6,i);
          if (i has transparent) return L__M(##Take,7,i);
          return L__M(##Take,8);
      }
      if (i has container && i hasnt open)
          return L__M(##Take,9,i);
      i=parent(i);
      if (i==player) i=fromobj;
  }
  if (noun has scenery or static) return L__M(##Take,10);

  k=0; objectloop (j in player) if (j hasnt worn) k++;

  if (k >= ValueOrRun(player,capacity))
  {   
      return L__M(##Take,12);
  }
  move noun to player;

  if (postonobj~=0)
  {   k=action; action=##LetGo;
      if (RunRoutines(postonobj,after)~=0) { action=k; rtrue; }
      action=k;
  }
  rfalse;
];

[ DropSub i;
  i=parent(noun);
  if (i==location) return L__M(##Drop,1);
  if (i~=player) return L__M(##Drop,2);
#IFDEF MINFORM_WEAR;
  if (noun has worn)
  {   L__M(##Drop,3,noun);
      <Disrobe noun>;
      if (noun has worn) rtrue;
  }
#ENDIF;
  move noun to parent(player);
  if (AfterRoutines()==1) rtrue;
  if (keep_silent==1) rtrue;
  return L__M(##Drop,4);
];

[ RemoveSub i;
  i=parent(noun);
  if (i has container && i hasnt open) return L__M(##Remove,1);
  if (i~=second) return L__M(##Remove,2);
  if (i has animate) return L__M(##Take,6,i);
  if (RTakeSub(second)~=0) rtrue;
  action=##Take;   if (AfterRoutines()==1) rtrue;
  action=##Remove; if (AfterRoutines()==1) rtrue;

  if (keep_silent==1) rtrue;
  return L__M(##Remove,4);
];

[ IndirectlyContains o1 o2;  ! Does o1 already (ultimately) have o2?
  while (o2~=0)
  {   
      if (o1==o2) rtrue;
      o2=parent(o2);
  }
  rfalse;
];

[ PutOnSub;
  receive_action=##PutOn; 
  if (second==d_obj) { <Drop noun>; rfalse; }
  if (parent(noun)~=player) return L__M(##Insert,1);

  if (second>1)
  {   action=##Receive;
      if (RunRoutines(second,before)~=0) { action=##PutOn; rtrue; }
      action=##PutOn;
  }

  if (IndirectlyContains(noun,second)==1) return L__M(##Miscellany,1);
  if (second hasnt supporter) return L__M(##PutOn,3,second);
  if (parent(second)==player) return L__M(##PutOn,4);
#IFDEF MINFORM_WEAR;
  if (noun has worn)
  {   L__M(##PutOn,5);
      <Disrobe noun>;
      if (noun has worn) rtrue;
  }
#ENDIF;
  if (children(second)>=ValueOrRun(second,capacity))
      return L__M(##PutOn,6,second);

  move noun to second;

  if (AfterRoutines()==1) rtrue;

  if (second>1)
  {   action=##Receive;
      if (RunRoutines(second,after)~=0) { action=##PutOn; rtrue; }
      action=##PutOn;
  }

  if (keep_silent==1) rtrue;
  L__M(##PutOn,8,noun);
];

[ InsertSub;
  receive_action = ##Insert;
  if (second==d_obj ) <<Drop noun>>;
  if (parent(noun)~=player) return L__M(##Insert,1);

  if (second>1)
  {   action=##Receive;
      if (RunRoutines(second,before)~=0) { action=##Insert; rtrue; }
      action=##Insert;
  }
  if (second hasnt container) return L__M(##Insert,2);
  if (second hasnt open)      return L__M(##Insert,3);
  if (IndirectlyContains(noun,second)==1) return L__M(##Insert,5);
#IFDEF MINFORM_WEAR;
  if (noun has worn)
  {   L__M(##Insert,6);
      <Disrobe noun>; if (noun has worn) rtrue;
  }
#ENDIF;
  if (children(second)>=ValueOrRun(second,capacity))
      return L__M(##Insert,7,second);

  move noun to second;

  if (AfterRoutines()==1) rtrue;

  if (second>1)
  {   action=##Receive;
      if (RunRoutines(second,after)~=0) { action=##Insert; rtrue; }
      action=##Insert;
  }
  if (keep_silent==1) rtrue;
  L__M(##Insert,9,noun);
];

[ TransferSub i act_needed k postonobj par;
  act_needed=##Drop;
  if (second ~= 0)
  {
      if (second has container) 
         act_needed=##Insert;
      else
          if (second has supporter) act_needed=##PutOn;
  }

  i=parent(noun);
  .DoTransfer;
  if (noun notin player)
  {
      par = parent(noun);
      if (par has container || par has supporter)
      {   postonobj=par;
          k=action; action=##LetGo;
          if (RunRoutines(par,before)~=0) { action=k; rtrue; }
          action=k;
      }
      move noun to player;
      if (postonobj~=0)
      {   k=action; action=##LetGo;
          if (RunRoutines(postonobj,after)~=0) { action=k; rtrue; }
          action=k;
      }
  }
  if (act_needed==##Drop)   <<Drop noun>>;
  if (act_needed==##Insert) <<Insert noun second>>;
  if (act_needed==##PutOn)  <<PutOn noun second>>;
];

[ EmptySub;
  second=d_obj; EmptyTSub();
];

[ EmptyTSub i j;
  if (noun hasnt container) return L__M(##EmptyT,1,noun);
  if (noun hasnt open) return L__M(##EmptyT,2,noun);
  if (second~=d_obj)
  {   if (second hasnt container) return L__M(##EmptyT,1,second);
      if (second hasnt open) return L__M(##EmptyT,2,second);
  }
  if (noun notin player) return L__M(##Transfer,1);
  i=child(noun);
  if (i==0) return L__M(##EmptyT,3,noun);
  while (i~=0)
  {   j=sibling(i);
      PrintShortName(i); print ": ";
      <Transfer i second>;
      i=j;
  }
];

[ GiveSub;
  if (parent(noun)~=player) return L__M(##Give,1,noun);
  if (second==player)  return L__M(##Give,2,noun);
  if (RunLife(second,##Give)~=0) rfalse;
  L__M(##Give,3,second);
];

[ GiveRSub; <Give second noun>; ];

[ ShowSub;
  if (parent(noun)~=player) return L__M(##Show,1,noun);
  if (second==player) <<Examine noun>>;
  if (RunLife(second,##Show)~=0) rfalse;
  L__M(##Show,2,second);
];

[ ShowRSub; <Show second noun>; ];

! ----------------------------------------------------------------------------
!   Travelling around verbs
! ----------------------------------------------------------------------------

[ EnterSub i;
  if (noun has door) <<Go noun>>;
  i=parent(player);
  if (i~=location) return L__M(##Enter,1,i);
  i=parent(noun);
  if (i==compass) <<Go noun>>;
  if (noun hasnt enterable) return L__M(##Enter,2);
  if (noun has container && noun hasnt open) return L__M(##Remove,1);
  if (i~=location)  return L__M(##Enter,4);
  move player to noun;
  if (AfterRoutines()==1) rtrue;
  if (keep_silent==1) rtrue;
  L__M(##Enter,5,noun);
  Locale(noun);
];

[ GetOffSub;
  if (parent(player)==noun) <<Exit>>;
  L__M(##GetOff,1,noun);
];

[ ExitSub p;
  p=parent(player);
  if (p==location)
  {   if (location.out_to~=0) <<Go out_obj>>;
      return L__M(##Exit,1);
  }
  if (p has container && p hasnt open)
      return L__M(##Exit,2,p);
  move player to location;
  if (AfterRoutines()==1) rtrue;
  if (keep_silent==1) rtrue;
  L__M(##Exit,3,p); LookSub();
];

[ VagueGoSub; L__M(##VagueGo); 
];

[ GoInSub;
  <<Go in_obj>>;
];

[ GoSub i j k movewith thedir;
  movewith=0;
  i=parent(player);
  if (i~=location)
  {
      j=location;
      k=RunRoutines(i,before); if (k~=3) location=j;
      if (k==1)
      {   movewith=i; i=parent(i); jump gotroom; }
      if (k==0) L__M(##Go,1,i); rtrue;
  }
  .gotroom;
  thedir=noun.door_dir;
  if (ZRegion(thedir)==2) thedir=RunRoutines(noun,door_dir);
  
  j=i.thedir; k=ZRegion(j);
  if (k==3) { print (string) j; new_line; rfalse; }
  if (k==2) { j=RunRoutines(i,thedir);
              if (j==1) rtrue;
            }

  if (k==0 || j==0)
  {   
      if (i.cant_go ~= 0) PrintOrRun(i, cant_go);
      rfalse;
  }

  if (j has door)
  {   if (j has concealed) return L__M(##Go,2);
      if (j hasnt open)
      {
          return L__M(##Go,2);
      }
      if (ZRegion(j.door_to)==2) j=RunRoutines(j,door_to);
      else j=j.door_to;
      if (j==0) return L__M(##Go,6,j);
      if (j==1) rtrue;
  }
  if (movewith==0) move player to j; else move movewith to j;
  
  location=j; MoveFloatingObjects();
 
  if (AfterRoutines()==1) rtrue;
  if (keep_silent==1) rtrue;
  LookSub();
];

! ----------------------------------------------------------------------------
!   Describing the world.  SayWhatsOn(object) does just that (producing
!   no text if nothing except possibly "scenery" and "concealed" items are).
!   Locale(object) runs through the "tail end" of a Look-style room
!   description for the contents of the object, printing up suitable
!   descriptions as it goes.
! ----------------------------------------------------------------------------

[ SayWhatsOn descon j f;
  if (descon==parent(player)) rfalse;
  objectloop (j in descon)
      if (j hasnt concealed && j hasnt scenery) f=1;
  if (f==0) rfalse;
  L__M(##Look, 4, descon); rtrue;
];

[ Locale descin text1 text2  o p k j flag f2;

  objectloop (o in descin) give o ~workflag;

  k=0;
  objectloop (o in descin)
      if (o hasnt concealed && o~=parent(player))
      {  if (o hasnt scenery)
         {   give o workflag; k++;
             p=initial; f2=0;
             if (o has door && o hasnt open) { p=when_closed; f2=1; }
             if (o has switchable && o hasnt on) { p=when_off; f2=1; }
             if (o has container && o hasnt open && o.&when_closed~=0)
             {   p=when_closed; f2=1; }
             if (o hasnt moved || o.describe~=NULL || f2==1)
             {   if (o.describe~=NULL && RunRoutines(o,describe)~=0)
                 {   flag=1;
                     give o ~workflag; k--;
                 }    
                 else
                 {   j=o.p;
                     if (j~=0)
                     {   new_line;
                         PrintOrRun(o,p);
                         flag=1;
                         give o ~workflag; k--;
                         if (o has supporter && child(o)~=0) SayWhatsOn(o);
                     }
                 }
             }
         }
         else
             if (o has supporter && child(o)~=0) SayWhatsOn(o);
      }

  if (k==0) return 0;

  if (text1~=0)
  {   new_line;
      if (flag==1) text1=text2;
      print (string) text1, " ";
      WriteListFrom(child(descin),
          WORKFLAG_BIT + RECURSE_BIT
          + PARTINV_BIT + TERSE_BIT + CONCEAL_BIT);
      return k;
  }

  if (flag==1) L__M(##Look,5,descin); else L__M(##Look,6,descin);
];

[ NoteArrival descin;
  descin=location;
  if (descin~=lastdesc)
  {   if (descin.initial~=0) PrintOrRun(descin, initial);
      NewRoom();
      !MoveFloatingObjects();
      lastdesc=descin;
  }
];

[ ScoreArrival;
  if (location hasnt visited)
  {   give location visited;
      if (location has scored)
      {   score=score+ROOM_SCORE;
          places_score=places_score+ROOM_SCORE;
      }
  }
];

[ LookSub ;
  if (parent(player)==0) return RunTimeError(10);
  NoteArrival();
  new_line;
#IFV5; style bold; #ENDIF;
  PrintShortName(location);
#IFV5; style roman; #ENDIF;
  new_line;

  if (location.describe~=NULL) 
  {
      RunRoutines(location,describe);
  }
  else
  {   
      if (location.description==0) RunTimeError(11,location);
      else PrintOrRun(location,description);
  }

  Locale(location);

  LookRoutine();
  ScoreArrival();

  action=##Look;
  if (AfterRoutines()==1) rtrue;
];

[ ExamineSub i;
  i=noun.description;
  if (i==0)
  {   if (noun has container) <<Search noun>>;
      if (noun has switchable) { L__M(##Examine,3,noun); rfalse; }
      return L__M(##Examine,2,noun);
  }
  PrintOrRun(noun, description);
  if (noun has switchable) L__M(##Examine,3,noun);
  if (AfterRoutines()==1) rtrue;
];

[ SearchSub i f;
  objectloop (i in noun) if (i hasnt concealed) f=1;
  if (noun has supporter)
  {   if (f==0) return L__M(##Search,2,noun);
      return L__M(##Search,3,noun);
  }
  if (noun hasnt container) return L__M(##Search,4);
  if (noun hasnt transparent && noun hasnt open)
      return L__M(##Search,5);
  if (AfterRoutines()==1) rtrue;

  i=children(noun);
  if (f==0) return L__M(##Search,6,noun);
  L__M(##Search,7,noun);
];

! ----------------------------------------------------------------------------
!   Verbs which change the state of objects without moving them
! ----------------------------------------------------------------------------

[ UnlockSub;
  if (noun hasnt lockable) return L__M(##Lock,1);
  if (noun hasnt locked)   return L__M(##Unlock,2);
  if (noun.with_key~=second) return L__M(##Lock,4);
  give noun ~locked;
  if (AfterRoutines()==1) rtrue;
  if (keep_silent==1) rtrue;
  L__M(##Unlock,4,noun);
];

[ LockSub;
  if (noun hasnt lockable) return L__M(##Lock,1);
  if (noun has locked)     return L__M(##Lock,2);
  if (noun has open)       return L__M(##Lock,3);
  if (noun.with_key~=second) return L__M(##Lock,4);
  give noun locked;
  if (AfterRoutines()==1) rtrue;
  if (keep_silent==1) rtrue;
  L__M(##Lock,5,noun);
];

[ SwitchonSub;
  if (noun hasnt switchable) return L__M(##SwitchOn,1);
  if (noun has on) return L__M(##SwitchOn,2, 1);
  give noun on;
  if (AfterRoutines()==1) rtrue;
  if (keep_silent==1) rtrue;
  L__M(##SwitchOn,3,noun); 
];

[ SwitchoffSub;
  if (noun hasnt switchable) return L__M(##SwitchOn,1);
  if (noun hasnt on) return L__M(##SwitchOn,2, 2);
  give noun ~on;
  if (AfterRoutines()==1) rtrue;
  if (keep_silent==1) rtrue;
  L__M(##SwitchOn,4,noun);
];

[ OpenSub;
  if (noun hasnt openable) return L__M(##Open,1);
  if (noun has locked)     return L__M(##Open,2);
  if (noun has open)       return L__M(##Open,3);
  give noun open;
  if (AfterRoutines()==1) rtrue;
  if (keep_silent==1) rtrue;
  if (noun has container && noun hasnt transparent && child(noun)~=0)
      return L__M(##Open,4,noun);
  L__M(##Open,5,noun);
];

[ CloseSub;
  if (noun hasnt openable) return L__M(##Close,1);
  if (noun hasnt open)     return L__M(##Close,2);
  give noun ~open;
  if (AfterRoutines()==1) rtrue;
  if (keep_silent==1) rtrue;
  L__M(##Close,3,noun);
];

#IFDEF MINFORM_WEAR;
[ DisrobeSub;
  if (noun hasnt worn) return L__M(##Disrobe,1);
  give noun ~worn;
  if (AfterRoutines()==1) rtrue;
  if (keep_silent==1) rtrue;
  L__M(##Disrobe,2,noun);
];

[ WearSub;
  if (noun hasnt clothing)  return L__M(##Wear,1);
  if (parent(noun)~=player) return L__M(##Wear,2);
  if (noun has worn)        return L__M(##Wear,3);
  give noun worn;
  if (AfterRoutines()==1) rtrue;
  if (keep_silent==1) rtrue;
  L__M(##Wear,4,noun);
];
#ENDIF;  !MINFORM_WEAR

[ EatSub;
  if (noun hasnt edible) return L__M(##Eat,1);
  remove noun;
  if (AfterRoutines()==1) rtrue;
  if (keep_silent==1) rtrue;
  L__M(##Eat,2,noun);
];

! ----------------------------------------------------------------------------
!   Verbs which are really just stubs (anything which happens for these
!   actions must happen in before rules)
! ----------------------------------------------------------------------------

[ BurnSub; L__M(##Burn); ];
[ SmellSub; L__M(##Smell,1); ];
[ ListenSub; L__M(##Listen,2); ];
[ TasteSub; L__M(##Taste,3); ];
[ DigSub; L__M(##Dig); ];
[ CutSub; L__M(##Cut); ];
[ JumpSub; L__M(##Jump); ];
[ JumpOverSub; L__M(##JumpOver); ];
[ TieSub; L__M(##Tie); ];
[ DrinkSub; L__M(##Miscellany,1); ];
[ FillSub; L__M(##Miscellany,1); ];
[ SwimSub; L__M(##Miscellany,1); ];
[ RubSub; L__M(##Rub); ];
[ SetSub; L__M(##Set); ];
[ SetToSub; L__M(##SetTo); ];
[ ClimbSub; L__M(##Climb); ];
[ ConsultSub; L__M(##Consult,1,noun); ];
[ TouchSub;L__M(##Touch); ];
[ PullSub;
  if (noun has static or scenery or animate)   return L__M(##Miscellany,1);
  L__M(##Pull,3);
];
[ PushSub;
   PullSub();  
];
[ TurnSub;
   PullSub();  
];

[ WaitSub;
  if (AfterRoutines()==1) rtrue;
  L__M(##Wait);
];

[ PushDirSub; L__M(##Miscellany,1); ];

[ AllowPushDir i;
  if (parent(second)~=compass) return L__M(##PushDir,2);
  if (second==u_obj or d_obj)  return L__M(##PushDir,3);
  AfterRoutines(); i=noun; move i to player;
  <Go second>;
  move i to location;
];

[ ThrowAtSub;
  if (second>1)
  {   action=##ThrownAt;
      if (RunRoutines(second,before)~=0) { action=##ThrowAt; rtrue; }
      action=##ThrowAt;
  }
  if (second hasnt animate) return L__M(##ThrowAt,1);
  if (RunLife(second,##ThrowAt)~=0) rfalse;
  L__M(##ThrowAt,2);
];

[ AttackSub;
  if (noun has animate && RunLife(noun,##Attack)~=0) rfalse;
  L__M(##Miscellany, 1); ];

[ AnswerSub;
  if (RunLife(second,##Answer)~=0) rfalse;
  L__M(##Answer);
];  

[ TellSub;
  if (noun==player) return L__M(##Tell);
  if (RunLife(noun,##Tell)~=0) rfalse;
  L__M(##Tell,2);
];  
  
[ AskSub;
  if (RunLife(noun,##Ask)~=0) rfalse;
  L__M(##Ask);
];  

[ AskForSub;
  if (noun==player) <<Inv>>;
  L__M(##Order,1,noun);
];

! ----------------------------------------------------------------------------
!   Debugging verbs
! ----------------------------------------------------------------------------

#IFDEF DEBUG;
[ TraceOnSub; parser_trace=2; "[Trace on.]"; ];
[ TraceLevelSub; parser_trace=noun;
  print "[Parser tracing set to level ", parser_trace, ".]^"; ];
[ TraceOffSub; parser_trace=0; "Trace off."; ];
[ RoutinesOnSub;  debug_flag=debug_flag | 1; "[Routine listing on.]"; ];
[ RoutinesOffSub; debug_flag=debug_flag & 6; "[Routine listing off.]"; ];
[ ActionsOnSub;  debug_flag=debug_flag | 2; "[Action listing on.]"; ];
[ ActionsOffSub; debug_flag=debug_flag & 5; "[Action listing off.]"; ];
[ TimersOnSub;  debug_flag=debug_flag | 4; "[Timers listing on.]"; ];
[ TimersOffSub; debug_flag=debug_flag & 3; "[Timers listing off.]"; ];
[ CommandsOnSub;
  @output_stream 4; xcommsdir=1; "[Command recording on.]"; ];
[ CommandsOffSub;
  if (xcommsdir==1) @output_stream -4;
  xcommsdir=0;
  "[Command recording off.]"; ];
[ CommandsReadSub;
  @input_stream 1; xcommsdir=2; "[Replaying commands.]"; ];
[ PredictableSub i; i=random(-100);
  "[Random number generator now predictable.]"; ];
[ XPurloinSub; move noun to player; give noun moved ~concealed; "[Purloined.]"; ];
[ XAbstractSub; move noun to second; "[Abstracted.]"; ];

[ XObj obj f;
  if (parent(obj)==0) PrintShortName(obj); else InDefArt(obj);
  print " (", obj, ") ";
  if (f==1) { print "(in "; PrintShortName(parent(obj));
              print " ", parent(obj), ")"; }
  new_line;
  if (child(obj)==0) rtrue;
  WriteListFrom(child(obj),
      FULLINV_BIT + INDENT_BIT + NEWLINE_BIT + ALWAYS_BIT, 1);
];
[ XTreeSub i;
  if (noun==0)
  {   for (i=selfobj+1:i<=top_object:i++)
      {   if (parent(i)==0) XObj(i);
      }
      rfalse;
  }
  XObj(noun,1);
];
[ GotoSub;
  if (noun>top_object || noun<=selfobj || parent(noun)~=0)
      "[Not a safe place.]";
  PlayerTo(noun);
];
[ GonearSub x; x=noun; while (parent(x)~=0) x=parent(x); PlayerTo(x); ];
[ Print_ScL obj; print_ret ++x_scope_count, ": ", (a) obj, " (", obj, ")"; ];
[ ScopeSub; x_scope_count=0; LoopOverScope(#r$Print_ScL, noun);
  if (x_scope_count==0) "Nothing is in scope.";
];
#ENDIF;

! ----------------------------------------------------------------------------
!   Finally: virtually all the text produced by library routines, except for
!   some parser errors (which are indirected through ParserError).
! ----------------------------------------------------------------------------

[ L__M act n x1 s;
  s=sw__var; sw__var=act; if (n==0) n=1;
  L___M(n,x1);
  sw__var=s;
];

[ L___M n x1 s;
  s=action;

#IFDEF LibraryMessages;
  lm_n=n; lm_o=x1;
  action=sw__var;
  if (RunRoutines(LibraryMessages,before)~=0) { action=s; rfalse; }
  action=s;
#ENDIF;
  
  Prompt:  print "^>"; rtrue;
  Miscellany:
           if (n==1) "Sorry, can't do that.";
           if (n==3) { print "You have died"; rtrue; }
           if (n==4) { print "You have won"; rtrue; }
           if (n==5) "^Restart, Restore or Quit?";
  Order:   CDefArt(x1); " has better things to do.";
  Restore: if (n==1) "Failed.";
           "Ok.";
  ScriptOn: if (n==1) "Already on.";
           "Start of a transcript of";
  ScriptOff: if (n==1) "Already off.";
           "^End of transcript.";
  Score:   print "You have scored ",score, " out of ", MAX_SCORE,", in ", turns, " turns.^";
  Inv:     if (n==1) "You are carrying nothing.";
           print "You are carrying"; rtrue;
  Take:    if (n==1) "Taken.";
           if (n==2) {print "You can't take "; DefArt(x1); ".";}
           if (n==4) "You can't reach that here.";
           if (n==5) "You already have that.";
           if (n==6) { print "That belongs to "; DefArt(x1); "."; }
           if (n==7) { print "That's a part of "; DefArt(x1); "."; }
           if (n==8) "That isn't available.";
           if (n==9) { CDefArt(x1); " is not open."; }
           if (n==10) "Not portable.";
           if (n==12) "Carrying too much.";
  Drop:    if (n==1) "Already on the floor.";
           if (n==2) "You haven't got that.";
#IFDEF MINFORM_WEAR;
           if (n==3) { print "(first taking "; DefArt(x1); " off)"; }
#ENDIF;
           "Dropped.";
  Remove:  if (n==1) "But it's closed.";
           if (n==2) "But it isn't there now.";
           "Removed.";
  PutOn:
           if (n==3) "That would achieve nothing.";
           if (n==4) "You lack the dexterity.";
#IFDEF MINFORM_WEAR;
           if (n==5) "(first taking it off)^";
#ENDIF;
           if (n==6) { print "No room on "; DefArt(x1); "."; }
           print "You put "; DefArt(x1); print " on "; DefArt(second); ".";
  Insert:  if (n==1) "You must be holding it first.";
           if (n==2) "That can't contain things.";
           if (n==3) "Alas, it is closed.";
!           if (n==4) "You'll need to take it off first.";
           if (n==5) "You can't put something inside itself.";
#IFDEF MINFORM_WEAR;
           if (n==6) "(first taking it off)^";
#ENDIF;
           if (n==7) { print "No room left in "; DefArt(x1); "."; }
           print "You put "; DefArt(x1); print " into "; DefArt(second); ".";
  EmptyT:  if (n==1) { CDefArt(x1); " can't contain things."; }
           if (n==2) { CDefArt(x1); " is closed."; }
           CDefArt(x1); " is empty already.";
  Transfer: if (n==1) "That isn't in your possession.";
  Give:    if (n==1) { print "You aren't holding "; DefArt(x1); "."; }
           if (n==2) "To yourself?";
           CDefArt(x1); " doesn't seem interested.";
  Show:    if (n==1) { print "You aren't holding "; DefArt(x1); "."; }
           CDefArt(x1); " is unimpressed.";
  Enter:   if (n==1) { print "But you're already ";
                       if (x1 has supporter) print "on ";
                       else print "in "; DefArt(x1); "."; }
           if (n==2) "That's not something you can enter.";
           if (n==4) "Must be on the floor.";
           print "You get "; if (x1 has supporter) print "onto ";
           else print "into "; DefArt(x1); ".";
  GetOff:  print "But you aren't on "; DefArt(x1); " at the moment.";
  Exit:    if (n==1) "But you aren't in anything at the moment.";
           if (n==2) { print "You can't get out of the closed ";
                       PrintShortName(x1); "."; }
           print "You get "; if (x1 has supporter) print "off ";
           else print "out of "; DefArt(x1); ".";
  VagueGo: "Specify a compass direction.";
  Go:      if (n==1)
           {   print "You'll have to get ";
               if (x1 has supporter) print "off "; else print "out of ";
               DefArt(x1); " first.";
           }
           if (n==2) "You can't go that way.";
           print "You can't, since "; DefArt(x1); " leads nowhere.";
  Look:    if (n==4)
           {   print "^On "; DefArt(x1);
               WriteListFrom(child(x1),
                   ENGLISH_BIT + RECURSE_BIT + PARTINV_BIT
                   + TERSE_BIT + ISARE_BIT + CONCEAL_BIT);
               ".";
           }
           if (x1~=location) { print "^In "; DefArt(x1); print " you"; }
           else print "^You";
           print " can "; if (n==5) print "also "; print "see ";
           WriteListFrom(child(x1),
                ENGLISH_BIT + WORKFLAG_BIT + RECURSE_BIT
                + PARTINV_BIT + TERSE_BIT + CONCEAL_BIT);
           if (x1~=location) ".";
           " here.";
  Examine: if (n==2) { print "You see nothing special about ";
                       Defart(x1); "."; }
           CDefArt(x1); print " is currently switched ";
           if (x1 has on) "on."; else "off.";
  Search:  
           if (n==2) { print "There is nothing on "; DefArt(x1); "."; }
           if (n==3)
           {   print "On "; DefArt(x1);
               WriteListFrom(child(x1),
                   TERSE_BIT + ISARE_BIT + CONCEAL_BIT);
               ".";
           }
           if (n==4) "You find nothing of interest.";
           if (n==5) "Can't, it's closed.";
           if (n==6) { CDefArt(x1); " is empty."; }
           print "In "; DefArt(x1);
           WriteListFrom(child(x1),
               TERSE_BIT + ENGLISH_BIT + ISARE_BIT + CONCEAL_BIT);
           ".";
  Unlock:  if (n==2) "It's unlocked already.";
           print "You unlock "; DefArt(x1); ".";

  Lock:    if (n==1) "That's not a lockable item.";
           if (n==2) "It's locked already.";
           if (n==3) "Must close it first.";
           if (n==4) "That doesn't fit the lock.";
           print "You lock "; DefArt(x1); ".";

  SwitchOn:if (n==1) "That's not something you can switch.";
           if (n==2) {print "That's already "; if (x1==1) "on."; else "off.";return true;}
           if (n==3) {print "You switch "; DefArt(x1); " on.";}
           print "You switch "; DefArt(x1); " off.";
           
  Open:    if (n==1) "That's not something you can open.";
           if (n==2) "It seems to be locked.";
           if (n==3) "It's already open.";
           if (n==4)
           {   print "You open "; DefArt(x1); print ", revealing ";
               if (WriteListFrom(child(x1),
                   ENGLISH_BIT + TERSE_BIT + CONCEAL_BIT)==0) "nothing.";
               ".";
           }
           print "You open "; DefArt(x1); ".";
  Close:   if (n==1) "That's not something you can close.";
           if (n==2) "It's already closed.";
           print "You close "; DefArt(x1); ".";
#IFDEF MINFORM_WEAR;
  Disrobe: if (n==1) "You're not wearing that.";
           print "You take off "; DefArt(x1); ".";
  Wear:    if (n==1) "You can't wear that!";
           if (n==2) "You're not holding that!";
           if (n==3) "You're already wearing that!";
           print "You put on "; DefArt(x1); ".";
#ENDIF;
  Eat:     if (n==1) "Not edible.";
           print "You eat "; DefArt(x1); ".";
  Smell:   "You smell nothing unexpected.";
  Listen:  "You hear nothing unexpected.";
  Taste:   "You taste nothing unexpected.";
  Touch:   "You feel nothing unexpected.";
  Burn, Climb, Set, SetTo, Rub, JumpOver, Tie, Dig, Cut, Jump: "That would achieve nothing here.";
  Pull, Push, Turn: "Nothing obvious happens.";
  PushDir: "Not that way you can't.";
  ThrowAt: if (n==1) "Futile.";
           "You lack the nerve.";
  Tell:    "There is no reaction.";
  Answer, Ask:  "There is no reply.";
  Wait:    "Time passes.";
  Consult: print "You discover nothing of interest in "; DefArt(x1); ".";
];

! ----------------------------------------------------------------------------

