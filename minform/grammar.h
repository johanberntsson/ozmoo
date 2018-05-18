! ----------------------------------------------------------------------------
!  mInform version of GRAMMAR.  The original work is:
!  (c) Graham Nelson 1993, 1994, 1995, 1996 but freely usable (see manuals)
!  the reductions are (c) Dave Bernazzani 2004.
! ----------------------------------------------------------------------------

! ----------------------------------------------------------------------------
!  The "meta-verbs", commands to the game rather than in the game, come first:
! ----------------------------------------------------------------------------

System_file;

Verb meta "score"
                *                                -> Score;
Verb meta "q" "quit"
                *                                -> Quit;
Verb meta "restore"
                *                                -> Restore;
Verb meta "restart"
                *                                -> Restart;
Verb meta "save"
                *                                -> Save;
Verb meta "script"
                *                                -> ScriptOn
                * "off"                          -> ScriptOff
                * "on"                           -> ScriptOn;
Verb meta "noscript" "unscript"
                *                                -> ScriptOff;
              
Verb meta "version"
                *                                -> Version;
                
! ----------------------------------------------------------------------------
!  Debugging grammar
! ----------------------------------------------------------------------------

#ifdef DEBUG;
Verb meta "trace"
                *                                -> TraceOn
                * number                         -> TraceLevel
                * "on"                           -> TraceOn
                * "off"                          -> TraceOff;
Verb meta "actions"
                *                                -> ActionsOn
                * "on"                           -> ActionsOn
                * "off"                          -> ActionsOff;
Verb meta "routines"
                *                                -> RoutinesOn
                * "on"                           -> RoutinesOn
                * "off"                          -> RoutinesOff;
Verb meta "timers" "daemons"
                *                                -> TimersOn
                * "on"                           -> TimersOn
                * "off"                          -> TimersOff;
Verb meta "recording"
                *                                -> CommandsOn
                * "on"                           -> CommandsOn
                * "off"                          -> CommandsOff;
Verb meta "replay"
                *                                -> CommandsRead;
Verb meta "random"
                *                                -> Predictable;
Verb meta "purloin"
                * multi                          -> XPurloin;
Verb meta "abstract"
                * noun "to" noun                 -> XAbstract;
Verb meta "tree"
                *                                -> XTree
                * noun                           -> XTree;
Verb meta "goto"
                * number                         -> Goto;
Verb meta "gonear"
                * noun                           -> Gonear;
Verb meta "scope"
                *                                -> Scope
                * noun                           -> Scope;
#endif;

! ----------------------------------------------------------------------------
!  And now the game verbs.
! ----------------------------------------------------------------------------

Verb "take" "get"
                * "all"                          -> TakeAll
                * "out"                          -> Exit
                * "off"                          -> Exit
                * "up"                           -> Exit
                * multi                          -> Take
                * multiinside "from" noun        -> Remove
                * "in" noun                      -> Enter
                * "into" noun                    -> Enter
                * "on" noun                      -> Enter
                * multiinside "off" noun         -> Remove;

#IFDEF MINFORM_WEAR;
extend "take"
                * "off" worn                     -> Disrobe
                * "off" noun                     -> GetOff;
#ENDIF;


Verb "stand"
                *                                -> Exit
                * "up"                           -> Exit
                * "on" noun                      -> Enter;

Verb "remove"
                * multi                          -> Take
                * multiinside "from" noun        -> Remove;

Verb "put"
                * multiexcept "in" noun          -> Insert
                * multiexcept "inside" noun      -> Insert
                * multiexcept "into" noun        -> Insert
                * multiexcept "on" noun          -> PutOn
                * multiexcept "onto" noun        -> PutOn
                * "down" multiheld               -> Drop
                * multiheld "down"               -> Drop;

#IFDEF MINFORM_WEAR;
extend "remove" first
                * held                           -> Disrobe;
Verb "shed" "doff" "disrobe"
                * held                           -> Disrobe; 
Verb "wear" "don"
                * held                           -> Wear;
extend "put" first
                * "on" held                      -> Wear;

#ENDIF;

Verb "insert"
                * multiexcept "in" noun          -> Insert
                * multiexcept "into" noun        -> Insert;

Verb "empty"
                * noun                           -> Empty
                * "out" noun                     -> Empty
                * noun "out"                     -> Empty
                * noun "to" noun                 -> EmptyT
                * noun "into" noun               -> EmptyT
                * noun "on" noun                 -> EmptyT
                * noun "onto" noun               -> EmptyT;

Verb "drop" "throw" "discard"
                * multiheld                      -> Drop
                * multiexcept "in" noun          -> Insert
                * multiexcept "into" noun        -> Insert
                * multiexcept "on" noun          -> PutOn
                * multiexcept "onto" noun        -> PutOn
                * multiexcept "down" noun        -> Insert
                * held "at" noun                 -> ThrowAt
                * held "against" noun            -> ThrowAt;

Verb "give" "pay" "offer" "feed"
                * creature held                  -> GiveR
                * held "to" creature             -> Give;

Verb "show" "present" "display"
                * creature held                  -> ShowR
                * held "to" creature             -> Show;

[ ADirection; if (noun in compass) rtrue; rfalse; ];

Verb "go" "walk" "run"
                *                                -> VagueGo
                * noun=ADirection                -> Go
                * noun                           -> Enter
                * "into" noun                    -> Enter
                * "in" noun                      -> Enter
                * "inside" noun                  -> Enter
                * "through" noun                 -> Enter;

Verb "leave"
    *                                           -> VagueGo
    * noun=ADirection                           -> Go
    * noun                                      -> Exit;

Verb "inventory" "i"
                *                                -> Inv;

[ ConTopic w; consult_from = wn;
  do w=NextWordStopped();
  until (w==-1 || (w=='to' && action_to_be==##Answer));
  wn--;
  consult_words = wn-consult_from;
  if (consult_words==0) return -1;
  if (action_to_be==##Ask or ##Answer or ##Tell)
  {   w=wn; wn=consult_from; parsed_number=NextWord();
      if (parsed_number=='the' && consult_words>1) parsed_number=NextWord();
      wn=w; return 1;
  }
  return 0;
];

[ ConTopicI w;
  consult_from = wn;
  do w=NextWordStopped(); until (w=='in' or -1); if (w==-1) return -1;
  wn--; consult_words = wn-consult_from;
  if (consult_words==0) return -1; return 0; ];

Verb "look" "l"
                *                                -> Look
                * "at" noun                      -> Examine
                * "inside" noun                  -> Search
                * "in" noun                      -> Search
                * "into" noun                    -> Search
                * "through" noun                 -> Search
                * "up" ConTopicI "in" noun       -> Consult;

Verb "consult"  * noun "about" ConTopic          -> Consult
                * noun "on" ConTopic             -> Consult;

Verb "open" "uncover"
                * noun                           -> Open
                * noun "with" held               -> Unlock;
                
Verb "close" "shut" "cover"
                * noun                           -> Close
                * "up"                           -> Close
                * "off" noun                     -> SwitchOff;

Verb "enter"
                *                                -> GoIn
                * noun                           -> Enter;

Verb "sit" "lie"
                * "on" noun                      -> Enter
                * "in" noun                      -> Enter
                * "inside" noun                  -> Enter;

Verb "in" 
                *                                -> GoIn;

Verb "exit" "out"
                * noun                           -> Exit
                *                                -> Exit;
                
Verb "examine" "x" "watch" "describe" "check"
                * noun                           -> Examine;

Verb "read"
                * noun                           -> Examine
                * "about" ConTopicI "in" noun    -> Consult
                * ConTopicI "in" noun            -> Consult;

Verb "search"
                * noun                           -> Search;

Verb "set" "adjust"
                * noun                           -> Set
                * noun "to" special              -> SetTo;
                
Verb "pull" "drag"
                * noun                           -> Pull;
                
Verb "push" "move" "shift" "press"
                * noun                           -> Push
                * noun noun                      -> PushDir;
                
Verb "turn" "rotate" "twist" "unscrew" "screw"
                * noun                           -> Turn
                * noun "on"                      -> Switchon
                * noun "off"                     -> Switchoff
                * "on" noun                      -> Switchon
                * "off" noun                     -> Switchoff;

Verb "switch"
                * noun                           -> Switchon
                * noun "on"                      -> Switchon
                * noun "off"                     -> Switchoff
                * "on" noun                      -> Switchon
                * "off" noun                     -> Switchoff;

Verb "lock"
                * noun "with" held               -> Lock;

Verb "unlock"
                * noun "with" held               -> Unlock;

Verb "attack" "break" "smash" "hit" "fight" "crack"
     "destroy" "murder" "kill" "punch" "kick"
                * noun                           -> Attack;
                
Verb "wait" "z"
                *                                -> Wait;
                
Verb "answer" "say" "shout" "speak"
                * ConTopic "to" creature         -> Answer;
                
Verb "tell"
                * creature "about" ConTopic      -> Tell;
                
Verb "ask"
                * creature "about" ConTopic      -> Ask
                * creature "for" noun            -> AskFor;
                
Verb "eat"
                * held                           -> Eat;
                
Verb "climb" "scale"
                * noun                           -> Climb
                * "up" noun                      -> Climb
                * "over" noun                    -> Climb;
                
Verb "swim" "dive"
                *                                -> Swim;
                
Verb "smell" "sniff"
                *                                -> Smell
                * noun                           -> Smell;

Verb "hear" "listen"
                *                                -> Listen
                * noun                           -> Listen
                * "to" noun                      -> Listen;
Verb "taste"
                * noun                           -> Taste;

Verb "touch" "feel"
                * noun                           -> Touch;

Verb "rub" "shine" "polish" "sweep" "clean" "wipe" "scrub"
                * noun                           -> Rub;

Verb "tie" "attach" "fasten"
                * noun                           -> Tie
                * noun "to" noun                 -> Tie;

Verb "burn" "light"
                * noun                           -> Burn
                * noun "with" held               -> Burn;
                
Verb "drink" "swallow" "sip"
                * noun                           -> Drink;

Verb "fill"
                * noun                           -> Fill;

Verb "cut" "slice" "chop"
                * noun                           -> Cut;

Verb "jump" "hop"
                *                                -> Jump
                * "over" noun                    -> JumpOver;

Verb "dig"      * noun                           -> Dig
                * noun "with" held               -> Dig;

! ----------------------------------------------------------------------------
!  Final task: provide trivial routines if the user hasn't already:
! ----------------------------------------------------------------------------

#Stub TimePasses      0;
#Stub DeathMessage    0;
#Stub NewRoom         0;
#Stub LookRoutine     0;
#Stub AfterLife       0;
#Stub GamePreRoutine  0;
#Stub GamePostRoutine 0;
#Stub AfterPrompt     0;
#Stub BeforeParsing   0;
#Stub InScope         1;
#Stub UnknownVerb     1;
#Stub PrintVerb       1;
#Stub ParserError     1;
#Stub ParseNumber     2;
#Stub ChooseObjects   2;

#IFNDEF ParseNoun;
Constant Make__PN;
#ENDIF;
#IFDEF Make__PN;
[ ParseNoun obj; obj=obj; return -1; ];
#ENDIF;
#Default Story 0;
#Default Headline 0;

! ----------------------------------------------------------------------------

