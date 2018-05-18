! ----------------------------------------------------------------------------
!  mInform version of PARSER.  The original work is:
!  (c) Graham Nelson 1993, 1994, 1995, 1996 but freely usable (see manuals)
!  the reductions are (c) Dave Bernazzani 2004.
! ----------------------------------------------------------------------------

Abbreviate ". ";
Abbreviate ", ";
Abbreviate "You ";
Abbreviate "'t ";
Abbreviate "That's not something you can ";
Abbreviate "_to/";
Abbreviate "nothing";
Abbreviate "That ";
Abbreviate "close";
Abbreviate "already";
Abbreviate "(which is ";
Abbreviate " is ";
Abbreviate "thing";
Abbreviate "ed.";
Abbreviate "t's";
Abbreviate "lock";
Abbreviate "rea";
Abbreviate "witch";
Abbreviate "can";
Abbreviate "open";
Abbreviate "empty";
Abbreviate "You";
Abbreviate "t first.";
Abbreviate "rrying";
Abbreviate "contain";
Abbreviate "when_";
Abbreviate "that.";
Abbreviate "t wa";
Abbreviate "But you";
Abbreviate "t of";
Abbreviate "Tha";
Abbreviate "Res";
Abbreviate " the ";
Abbreviate "all";
Abbreviate "yourself";
Abbreviate "_to";
Abbreviate "ter";
Abbreviate "here";
Abbreviate "able";
Abbreviate "ing";
Abbreviate "are";
Abbreviate "have";
Abbreviate "and";
Abbreviate "unexpected";
Abbreviate "ion";
Abbreviate "side";
Abbreviate "talk";
Abbreviate "see";
Abbreviate "sco";
Abbreviate "ake";
Abbreviate "ame";
Abbreviate "urn";
Abbreviate " to ";
Abbreviate "ore";
Abbreviate "the";
Abbreviate "tha";
Abbreviate "you";
Abbreviate "ome";
Abbreviate "t i";
Abbreviate "off";
Abbreviate "rin";
Abbreviate "pec";
Abbreviate "on.";
Abbreviate "ste";

Constant LibSerial "041107";
Constant LibRelease "mInform v1.1";

System_file;

Constant LIBRARY_mInform;
Constant Grammar__Version 1;

Constant MAX_TIMERS  4;
Array  the_timers  --> MAX_TIMERS;

Array  buffer          string 64;
Array  parse           string 64;

#IFDEF DEBUG;
[ DebugAttribute a anames;
    if (a < 0 || a >= 48) print "<invalid attribute ", a, ">";
    else {
        anames = #identifiers_table; anames = anames + 2*(anames-->0);
        print (string) anames-->a;
    }
];
#ENDIF;
                                    ! calls to object routines, etc.
Attribute animate;
Attribute clothing;
Attribute concealed;
Attribute container;
Attribute door;
Attribute edible;
Attribute enterable;
Attribute general;
Attribute light;
Attribute lockable;
Attribute locked;
Attribute moved;
Attribute on;
Attribute open;
Attribute openable;
Attribute proper;
Attribute scenery;
Attribute scored;
Attribute static;
Attribute supporter;
Attribute switchable;
Attribute talkable;
Attribute transparent;
Attribute visited;
Attribute workflag;
Attribute worn;

Attribute absent;      !  Please, no psychoanalysis

Property additive before $ffff;
Property additive after  $ffff;
Property additive life   $ffff;

Property long n_to;  Property long s_to; !  Slightly wastefully, these are
Property long e_to;  Property long w_to; !  long (they might be routines)
Property long ne_to; Property long se_to;
Property long nw_to; Property long sw_to;
Property long u_to;  Property long d_to;
Property long in_to; Property long out_to;

Property door_to     alias n_to;     !  For economy: these properties are
Property when_closed alias s_to;     !  used only by objects which
Property with_key    alias e_to;     !  aren't rooms
Property door_dir    alias w_to;
Property invent      alias u_to;
Property add_to_scope alias se_to;
Property list_together alias sw_to;
Property react_before alias ne_to;
Property react_after  alias nw_to;
Property grammar     alias in_to;
Property orders      alias out_to;

Property long initial;
Property when_open   alias initial;
Property when_on     alias initial;
Property when_off    alias when_closed;
Property long description;
Property additive describe $ffff;
Property article "a";

Property cant_go "You can't go that way.";

Property long found_in;         !  For fiddly reasons this can't alias

Property long time_left;
Property long number;
Property additive time_out $ffff;
Property daemon alias time_out;
Property additive each_turn $ffff;

Property capacity 100;

Property long short_name 0;
Property long parse_name 0;

Fake_Action LetGo;
Fake_Action Receive;
Fake_Action ThrownAt;
Fake_Action Order;
Fake_Action Miscellany;
Fake_Action Prompt;
Fake_Action NotUnderstood;

[ Main; PlayTheGame(); ];

Constant NULL $ffff;

! ----------------------------------------------------------------------------
!  Attribute and property definitions
!  The compass, directions, darkness and player objects
!  Definitions of fake actions
!  Library global variables
!  Private parser variables
!  Keyboard reading
!  Parser, level 0: outer shell, conversation, errors
!                1: grammar lines
!                2: tokens
!                3: object lists
!                4: scope and ambiguity resolving
!                5: object comparisons
!                6: word comparisons
!                7: reading words and moving tables about
!  Main game loop
!  Action processing
!  Menus
!  Time: timers and daemons
!  Changing player personality
!  Printing short names
! ----------------------------------------------------------------------------

Object GameController "GameController";

! ----------------------------------------------------------------------------
! Construct the compass - a dummy object containing the directions, which also
! represent the walls in whatever room the player is in (these are given the
! general-purpose "number" property for the programmer's convenience)
! ----------------------------------------------------------------------------

Object compass "compass" has concealed;

Object n_obj "north wall" compass      
  with name "n" "north",       article "the", door_dir n_to, number 0
  has  scenery;
Object s_obj "south wall" compass      
  with name "s" "south",       article "the", door_dir s_to, number 0
  has  scenery;
Object e_obj "east wall" compass      
  with name "e" "east",        article "the", door_dir e_to, number 0
   has  scenery;
Object w_obj "west wall" compass       
  with name "w" "west",        article "the", door_dir w_to, number 0
   has  scenery;
Object ne_obj "ne wall" compass 
  with name "ne" "northeast",  article "the", door_dir ne_to, number 0
  has  scenery;
Object se_obj "sw wall" compass
  with name "se" "southeast",  article "the", door_dir se_to, number 0
  has  scenery;
Object nw_obj "nw wall" compass
  with name "nw" "northwest",  article "the", door_dir nw_to, number 0
  has  scenery;
Object sw_obj "sw wall" compass
  with name "sw" "southwest",  article "the", door_dir sw_to, number 0
  has  scenery;
Object u_obj "ceiling" compass         
  with name "u" "up" "ceiling",       article "the", door_dir u_to, number 0
   has  scenery;
Object d_obj "floor" compass
  with name "d" "down" "floor",       article "the", door_dir d_to, number 0
   has  scenery;
Object out_obj "outside" compass
  with                                article "the", door_dir out_to, number 0
   has  scenery;
Object in_obj "inside" compass
  with                                article "the", door_dir in_to, number 0
   has  scenery;

! ----------------------------------------------------------------------------
! Create the player object
! ----------------------------------------------------------------------------

Object selfobj "yourself"
  with description "As good-looking as ever.", number 0,
       before $ffff, after $ffff, life $ffff, each_turn $ffff,
       time_out $ffff, describe $ffff, capacity 100,
       parse_name 0, short_name 0, orders 0,
  has  concealed animate proper transparent;

! ----------------------------------------------------------------------------
! Globals: note that the first one defined gives the status line place, the
! next two the score/turns
! ----------------------------------------------------------------------------

Global location = 1;
Global sline1 = 0;
Global sline2 = 0;

Global score = 0;
Global turns = 1;
Global player;

Global deadflag = 0;

Global transcript_mode = 0;

Global last_score = 0;
Global notify_mode = 1;       ! Score notification

Global places_score = 0;
Global things_score = 0;
Global lastdesc = 0;

Global top_object = 0;
Global standard_interpreter = 0;

! ----------------------------------------------------------------------------
! Parser variables accessible to the rest of the game
! ----------------------------------------------------------------------------

Array  inputobjs       --> 16;       ! To hold parameters
Global actor           = 0;          ! Person asked to do something
Global actors_location = 0;          ! Like location, but for the actor
Global action          = 0;          ! Thing he is asked to do
Global inp1            = 0;          ! First parameter
Global inp2            = 0;          ! Second parameter
Global special_number1 = 0;          ! First number, if one was typed
Global noun            = 0;          ! First noun
Global second          = 0;          ! Second noun
Global special_word    = 0;          ! Dictionary address of "special"
Global parsed_number   = 0;          ! For user-supplied parsing routines
global meta;                         ! Verb is a meta-command (such as "save")
global reason_code;                  ! Reason for calling a life
global consult_from;                 ! Word that "consult" topic starts on
global consult_words;                ! ...and number of words in topic

#ifdef DEBUG;
global parser_trace = 0;             ! Set this to 1 to make the parser trace
                                     ! tokens and lines
global debug_flag = 0;               ! For debugging information
#ENDIF;

global lm_n;                         ! Parameters for LibraryMessages
global lm_o;

Constant REPARSE_CODE 10000;

Constant PARSING_REASON        0;
Constant TALKING_REASON        1;
Constant EACH_TURN_REASON      2;
Constant REACT_BEFORE_REASON   3;
Constant REACT_AFTER_REASON    4;
Constant LOOPOVERSCOPE_REASON  5;
Constant TESTSCOPE_REASON      6;

! ----------------------------------------------------------------------------
! The parser, beginning with variables private to itself:
! ----------------------------------------------------------------------------

global wn;                      ! Word number (counts from 1)
global num_words;               ! Number of words typed
global verb_word;               ! Verb word (eg, take in "take all" or
                                ! "dwarf, take all") - address in dictionary
global verb_wordnum;            ! and the number in typing order (eg, 1 or 3)

Array pattern --> 8;            ! For the current pattern match
global pcount;                  ! and a marker within it
Array pattern2 --> 8;           ! And another, which stores the best match
global pcount2;                 ! so far

global parameters;              ! Parameters (objects) entered so far
global params_wanted;           ! Number needed (may change in parsing)

global inferfrom;               ! The point from which the rest of the
                                ! command must be inferred
global inferword;               ! And the preposition inferred

Constant MATCH_LIST_SIZE 8;
Array  match_list    -> 8;
                                ! An array of matched objects so far
Array  match_classes -> 8;
                                ! An array of equivalence classes for them
global number_matched;          ! How many items in it?  (0 means none)
global number_of_classes;       ! How many equivalence classes?
global match_length;            ! How many typed words long are these matches?
global match_from;              ! At what word of the input do they begin?

global parser_action;           ! For the use of the parser when calling
global parser_one;              ! user-supplied routines
global parser_two;              !

global lookahead;               ! The token after the object now being matched
global not_holding;             ! Object to be automatically taken as an
                                ! implicit command
global best_etype;              ! Error number used within parser
global nextbest_etype;          ! Error number used within parser
global etype;                   ! Error number used for individual lines

global token_was;               ! For noun filtering by user routines

global advance_warning;         ! What a later-named thing will be

global placed_in_flag;          ! To do with PlaceInScope

global action_to_be;            ! So the parser can "cheat" in one case
global dont_infer;              ! Another dull flag

global scope_reason = PARSING_REASON;   ! For "each_turn" and reactions

global scope_token;             ! For scope:Routine tokens
global scope_error;
global scope_stage;

global ats_flag = 0;            ! For AddToScope routines

global usual_grammar_after = 0;
Global active_timers = 0;

! ----------------------------------------------------------------------------
!  Variables for Verblib
! ----------------------------------------------------------------------------

global inventory_stage = 1;
global c_style;
global wlf_indent;
global keep_silent;
global receive_action;

#ifdef DEBUG;
global xcommsdir;
Global x_scope_count;
#endif;

! ----------------------------------------------------------------------------
!  The comma_word is a special word, used to substitute commas in the input
! ----------------------------------------------------------------------------

Constant comma_word 'xcomma';

! ----------------------------------------------------------------------------
!  In Advanced games only, the DrawStatusLine routine does just that: this is
!  provided explicitly so that it can be Replace'd to change the style, and
!  as written it emulates the ordinary Standard game status line, which is
!  drawn in hardware
! ----------------------------------------------------------------------------
#IFV5;
[ DrawStatusLine width posa posb;
   @split_window 1; @set_window 1; @set_cursor 1 1; style reverse;
   width = 0->33; posa = width-26; posb = width-13;
   spaces (width);
   @set_cursor 1 2;  PrintShortName(location);
   if (width > 76)
   {   @set_cursor 1 posa; print "Score: ", sline1;
       @set_cursor 1 posb; print "Moves: ", sline2;
   }
   if (width > 63 && width <= 76)
   {   @set_cursor 1 posb; print sline1, "/", sline2;
   }
   @set_cursor 1 1; style roman; @set_window 0;
];
#ENDIF;

! ----------------------------------------------------------------------------
!  The Keyboard routine actually receives the player's words,
!  putting the words in "a_buffer" and their dictionary addresses in
!  "a_table".  It is assumed that the table is the same one on each
!  (standard) call.
!
!  It can also be used by miscellaneous routines in the game to ask
!  yes-no questions and the like, without invoking the rest of the parser.
!
!  Return the number of words typed
! ----------------------------------------------------------------------------

[ Keyboard  a_buffer a_table  nw;

    DisplayStatus();

    .FreshInput;

!  In case of an array entry corruption that shouldn't happen, but would be
!  disastrous if it did:

   a_buffer->0 = 64;
   a_table->0 = 64;

!  Print the prompt, and read in the words and dictionary addresses

    L__M(##Prompt);
    AfterPrompt();
    #IFV3; read a_buffer a_table; #ENDIF;
    temp_global = 0;
    #IFV5; read a_buffer a_table DrawStatusLine; #ENDIF;
    nw=a_table->1;

!  If the line was blank, get a fresh line
    if (nw == 0)
    { 
        jump FreshInput; 
    }
    return nw;
];

Constant STUCK_PE     1;
Constant UPTO_PE      2;
Constant NUMBER_PE    3;
Constant CANTSEE_PE   4;
Constant TOOLIT_PE    5;
Constant NOTHELD_PE   6;
Constant MULTI_PE     7;
Constant MMULTI_PE    8;
Constant VAGUE_PE     9;
Constant EXCEPT_PE    10;
Constant ANIMA_PE     11;
Constant VERB_PE      12;
Constant SCENERY_PE   13;
Constant ITGONE_PE    14;
Constant JUNKAFTER_PE 15;
Constant TOOFEW_PE    16;
Constant NOTHING_PE   17;
Constant ASKSCOPE_PE  18;

! ----------------------------------------------------------------------------
!  The Parser routine is the heart of the parser.
!
!  It returns only when a sensible request has been made, and puts into the
!  "results" buffer:
!
!  Word 0 = The action number
!  Word 1 = Number of parameters
!  Words 2, 3, ... = The parameters (object numbers), but
!                    00 means "multiple object list goes here"
!                    01 means "special word goes here"
!
!  (Some of the global variables above are really local variables for this
!  routine, because the Z-machine only allows up to 15 local variables per
!  routine, and Parser runs out.)
!
!  To simplify the picture a little, a rough map of this routine is:
!
!  (A)    Get the input, do "oops" and "again"
!  (B)    Is it a direction, and so an implicit "go"?  If so go to (K)
!  (C)    Is anyone being addressed?
!  (D)    Get the verb: try all the syntax lines for that verb
!  (E)        Go through each token in the syntax line
!  (F)           Check (or infer) an adjective
!  (G)            Check to see if the syntax is finished, and if so return
!  (H)    Cheaply parse otherwise unrecognised conversation and return
!  (I)    Print best possible error message
!  (J)    Retry the whole lot
!  (K)    Last thing: check for "then" and further instructions(s), return.
!
!  The strategic points (A) to (K) are marked in the commentary.
!
!  Note that there are three different places where a return can happen.
!
! ----------------------------------------------------------------------------
[ Parser  results   syntax line num_lines line_address i j
                    token l m;

!  **** (A) ****
  .ReType;

   Keyboard(buffer,parse);

  .ReParse;

!  Initially assume the command is aimed at the player, and the verb
!  is the first word

    num_words=parse->1;
    wn=1;
    BeforeParsing();
    num_words=parse->1;
#ifdef DEBUG;
    if (parser_trace>=4)
    {   print "[ ", num_words, " to parse: ";
        for (i=1:i<=num_words:i++)
        {   j=parse-->((i-1)*2+1);
            if (j == 0) print "? ";
            else
            {   if (UnsignedCompare(j, 0-->4)>=0
                    && UnsignedCompare(j, 0-->2)<0) print (address) j;
                else print j; print " ";
            }
        }
        print "]^";
    }
#endif;
    verb_wordnum=1;
    actor=player; actors_location=location;
    usual_grammar_after = 0;

  .AlmostReParse;

    token_was = 0; ! In case we're still in "user-filter" mode from last round
    scope_token = 0;
    action_to_be = NULL;

!  Begin from what we currently think is the verb word

  .BeginCommand;
    wn=verb_wordnum;
    verb_word = NextWordStopped();

!  If there's no input here, we must have something like
!  "person,".

    if (verb_word==-1)
    {   best_etype = STUCK_PE; jump GiveError; }

    if (usual_grammar_after==0)
    {   i = RunRoutines(actor, grammar);
#ifdef DEBUG;
        if (parser_trace>=2 && actor.grammar~=0 or NULL)
            print " [Grammar property returned ", i, "]^";
#endif;
        if (i<0) { usual_grammar_after = verb_wordnum; i=-i; }
        if (i==1)
        {   results-->0 = action;
            results-->1 = noun;
            results-->2 = second;
            rtrue;
        }
        if (i~=0) { verb_word = i; wn--; verb_wordnum--; }
        else
        {   wn = verb_wordnum; verb_word=NextWord();
        }
    }
    else usual_grammar_after=0;

!  **** (B) ****

!  If the first word is not listed as a verb, it must be a direction
!  or the name of someone to talk to
!  (NB: better avoid having a Mr Take or Mrs Inventory around...)

    if (verb_word==0 || ((verb_word->#dict_par1) & 1) == 0)
    {   

!  So is the first word an object contained in the special object "compass"
!  (i.e., a direction)?  This needs use of NounDomain, a routine which
!  does the object matching, returning the object number, or 0 if none found,
!  or REPARSE_CODE if it has restructured the parse table so that the whole parse
!  must be begun again...

        wn=verb_wordnum;
        l=NounDomain(compass,0,0); 
        if (l==REPARSE_CODE) jump ReParse;

!  If it is a direction, send back the results:
!  action=GoSub, no of arguments=1, argument 1=the direction.

        if (l~=0)
        {   results-->0 = ##Go;
            results-->1 = 1;
            results-->2 = l;
            jump LookForMore;
        }

!  **** (C) ****

!  Only check for a comma (a "someone, do something" command) if we are
!  not already in the middle of one.  (This simplification stops us from
!  worrying about "robot, wizard, you are an idiot", telling the robot to
!  tell the wizard that she is an idiot.)

        if (actor==player)
        {   for (j=2:j<=num_words:j++)
            {   i=NextWord(); if (i==comma_word) jump Conversation;
            }

            verb_word=UnknownVerb(verb_word);
            if (verb_word~=0) jump VerbAccepted;
        }

        best_etype=VERB_PE; jump GiveError;

!  NextWord nudges the word number wn on by one each time, so we've now
!  advanced past a comma.  (A comma is a word all on its own in the table.)

      .Conversation;
        j=wn-1;
        if (j==1) { jump ReType; }

!  Use NounDomain (in the context of "animate creature") to see if the
!  words make sense as the name of someone held or nearby

        wn=1; lookahead=1;
        scope_reason = TALKING_REASON;
        l=NounDomain(player,actors_location,6);
        scope_reason = PARSING_REASON;
        if (l==REPARSE_CODE) jump ReParse;

        if (l==0) { print "I can't figure out who you want to talk with.^"; jump ReType; }

!  The object addressed must at least be "talkable" if not actually "animate"
!  (the distinction allows, for instance, a microphone to be spoken to,
!  without the parser thinking that the microphone is human).

        if (l hasnt animate && l hasnt talkable)
        {   print "You can't talk to "; DefArt(l); print ".^"; jump ReType; }

!  Check that there aren't any mystery words between the end of the person's
!  name and the comma (eg, throw out "dwarf sdfgsdgs, go north").

        if (wn~=j)
        {   print "To talk, use ~someone, hello~.^";
            jump ReType;
        }

!  Set the global variable "actor", adjust the number of the first word,
!  and begin parsing again from there.

        verb_wordnum=j+1; actor=l;
        actors_location=l;
        while (parent(actors_location)~=0)
            actors_location=parent(actors_location);
#ifdef DEBUG;
        if (parser_trace>=1)
            print "[Actor is ", (the) actor, " in ",
                (name) actors_location, "]^";
#endif;
        jump BeginCommand;
    }

!  **** (D) ****

   .VerbAccepted;

!  We now definitely have a verb, not a direction, whether we got here by the
!  "take ..." or "person, take ..." method.  Get the meta flag for this verb:

    meta=((verb_word->#dict_par1) & 2)/2;

!  You can't order other people to "full score" for you, and so on...

    if (meta==1 && actor~=player)
    {   best_etype=VERB_PE; meta=0; jump GiveError; }

!  Now let i be the corresponding verb number, stored in the dictionary entry
!  (in a peculiar 255-n fashion for traditional Infocom reasons)...

    i=$ff-(verb_word->#dict_par2);

!  ...then look up the i-th entry in the verb table, whose address is at word
!  7 in the Z-machine (in the header), so as to get the address of the syntax
!  table for the given verb...

    syntax=(0-->7)-->i;

!  ...and then see how many lines (ie, different patterns corresponding to the
!  same verb) are stored in the parse table...

    num_lines=(syntax->0)-1;

#ifdef DEBUG;
   if (parser_trace>=1)
   {    print "[Parsing for the verb '", (address) verb_word,
              "' (", num_lines+1, " lines)]^";
   }
#endif;

   best_etype=STUCK_PE; nextbest_etype=best_etype;
!  "best_etype" is the current failure-to-match error - it is by default
!  the least informative one, "don't understand that sentence"


!  **** (E) ****

    for (line=0:line<=num_lines:line++)
    {   line_address = syntax+1+line*8;

#ifdef DEBUG;
        if (parser_trace>=1)
        {   print "[Line ", line, ": ", line_address->0, " parameters: ";
            for (pcount=1:pcount<=6:pcount++)
            {   token=line_address->pcount;
                print token, " ";
            }
            print " -> action ", line_address->7, "]^";
        }
#endif;

!  We aren't in "not holding" or inferring modes, and haven't entered
!  any parameters on the line yet, or any special numbers; the multiple
!  object is still empty.

        not_holding=0;
        inferfrom=0;
        parameters=0;
        params_wanted = line_address->0;
        special_word=0; 
        etype=STUCK_PE;
        action_to_be = line_address->7;

!  Put the word marker back to just after the verb

        wn=verb_wordnum+1;

!  An individual "line" contains six tokens...  There's a preliminary pass
!  first, to parse late tokens early if necessary (because of mi or me).
!  We also check to see whether the line contains any "multi"s.

        advance_warning=-1;
        for (i=0,m=0,pcount=1:pcount<=6:pcount++)
        {   scope_token=0;
            token=line_address->pcount;
            if (token==2) m++;
            if (token<180) i++;
            if (token==4 or 5 && i==1)
            {
#ifdef DEBUG;
                if (parser_trace>=2) print " [Trying look-ahead]^";
#endif;
                pcount++;
                while (pcount<=6 && line_address->pcount>=180) pcount++;
                token=line_address->(pcount-1);
                if (token>=180)
                {   j=AdjectiveAddress(token);

                    !  Now look for word with j, move wn, parse next
                    !  token...
                    while (wn <= num_words)
                    {   if (NextWord()==j)
                        {   l = NounDomain(actors_location,actor,token);
#ifdef DEBUG;
                            if (parser_trace>=2)
                            {   print " [Forward token parsed: ";
                                if (l==REPARSE_CODE) print "re-parse request]^";
                                if (l==1) print "but multiple found]^";
                                if (l==0) print "hit error ", etype, "]^";
                            }
#endif;
                            if (l==REPARSE_CODE) jump ReParse;
                            if (l>=2)
                            {   advance_warning = l;
#ifdef DEBUG;
                                if (parser_trace>=3)
                                {   DefArt(l); print "]^";
                                }
#endif;
                            }
                        }
                    }
                }
            }
        }

!  And now start again, properly, forearmed or not as the case may be.

        not_holding=0;
        inferfrom=0;
        parameters=0;
        special_word=0; 
        etype=STUCK_PE;
        action_to_be = line_address->7;
        wn=verb_wordnum+1;

!  "Pattern" gradually accumulates what has been recognised so far,
!  so that it may be reprinted by the parser later on

        for (pcount=1:pcount<=6:pcount++)
        {   pattern-->pcount=0; scope_token=0;

            token=line_address->pcount;

#ifdef DEBUG;
            if (parser_trace>=2)
            {   print " [Token ",pcount, " is ", token, ": ";
                if (token<16)
                {   if (token==0) print "<noun> or null";
                    if (token==1) print "<held>";
                    if (token==2) print "<multi>";
                    if (token==3) print "<multiheld>";
                    if (token==4) print "<multiexcept>";
                    if (token==5) print "<multiinside>";
                    if (token==6) print "<creature>";
                    if (token==7) print "<special>";
                    if (token==8) print "<number>";
                }
                if (token>=16 && token<48)
                    print "<noun filter by routine ",token-16, ">";
                if (token>=48 && token<80)
                    print "<general parse by routine ",token-48, ">";
                if (token>=80 && token<128)
                    print "<scope parse by routine ",token-80, ">";
                if (token>=128 && token<180)
                    print "<noun filter by attribute ",token-128, ">";
                if (token>180)
                {   print "<adjective ",255-token, " '",
                    (address) AdjectiveAddress(token), "'>";
                }
                print " at word number ", wn, "]^";
            }
#endif;

!  Lookahead is set to the token after this one, or 8 if there isn't one.
!  (Complicated because the line is padded with 0's.)

            m=pcount+1; lookahead=8;
            if (m<=6) lookahead=line_address->m;
            if (lookahead==0)
            {   m=parameters; if (token<=7) m++;
                if (m>=params_wanted) lookahead=8;
            }

!  **** (F) ****

!  When the token is a large number, it must be an adjective:
!  remember the adjective number in the "pattern".

            if (token>180)
            {   pattern-->pcount = REPARSE_CODE+token;

!  If we've run out of the player's input, but still have parameters to
!  specify, we go into "infer" mode, remembering where we are and the
!  adjective we are inferring...

                if (wn > num_words)
                {   if (inferfrom==0 && parameters<params_wanted)
                    { inferfrom=pcount; inferword=token; }

!  Otherwise, this line must be wrong.

                    if (inferfrom==0) break;
                }

!  Whereas, if the player has typed something here, see if it is the
!  required adjective... if it's wrong, the line must be wrong,
!  but if it's right, the token is passed (jump to finish this token).

                if (wn <= num_words && token~=AdjectiveWord()) break;
                jump TokenPassed;
            }

!  **** (G) ****
!  Check now to see if the player has entered enough parameters...
!  (since params_wanted is the number of them)

            if (parameters == params_wanted)
            {  
                if (wn <= num_words)
                {   for (m=0:m<8:m++) pattern2-->m=pattern-->m;
                        pcount2=pcount;
                        etype=UPTO_PE; break;
                }

#ifdef DEBUG;
                if (parser_trace>=1)
                    print "[Line successfully parsed]^";
#endif;

!  At this point the line has worked out perfectly, and it's a matter of
!  sending the results back...
!  ...pausing to explain any inferences made (using the pattern)...

                if (inferfrom~=0)
                {   print "("; PrintCommand(inferfrom,1); print ")^";
                }

!  ...and to copy the action number, and the number of parameters...

                results-->1 = params_wanted;
                results-->0 = line_address->7;

!  ...and declare the user's input to be error free...

!  ...and worry about the case where an object was allowed as a parameter
!  even though the player wasn't holding it and should have been: in this
!  event, keep the results for next time round, go into "not holding" mode,
!  and for now tell the player what's happening and return a "take" request
!  instead...

                if (not_holding~=0 && actor==player)
                {   
                   print "You need to be in possession of it first.^"; 
                   jump reType;
                }

!  (Notice that implicit takes are only generated for the player, and not
!  for other actors.  This avoids entirely logical, but misleading, text
!  being printed.)
!  ...and finish.

                rtrue;
            }

!  Otherwise, the player still has at least one parameter to specify: an
!  object of some kind is expected, and this we hand over to POL.

            if (token==6 && (action_to_be==##Answer or ##Ask or ##AskFor
                             || action_to_be==##Tell))
                scope_reason=TALKING_REASON;
            l=ParseObjectList(results,token);

            scope_reason=PARSING_REASON;
#ifdef DEBUG;
            if (parser_trace>=3)
            {   print "  [Parse object list replied with";
                if (l==REPARSE_CODE) print " re-parse request]^";
                if (l==0) print " token failed, error type ", etype, "]^";
                if (l==1) print " token accepted]^";
            }
#endif;
            if (l==REPARSE_CODE) jump ReParse;
            if (l==0)    break;

!  The token has been successfully passed; we are ready for the next.

            .TokenPassed;
        }

!  But if we get here it means that the line failed somewhere, so we continue
!  the outer for loop and try the next line...

        if (etype>best_etype)
        {   best_etype=etype;
        }
        if (etype~=ASKSCOPE_PE && etype>nextbest_etype)
        {   nextbest_etype=etype;
        }
   }

!  So that if we get here, each line for the specified verb has failed.

!  **** (H) ****

  .GiveError;
        etype=best_etype;

!  Errors are handled differently depending on who was talking.

!  If the command was addressed to somebody else (eg, "dwarf, sfgh") then
!  it is taken as conversation which the parser has no business in disallowing.

    if (actor~=player)
    {   
        if (usual_grammar_after>0)
        {   verb_wordnum = usual_grammar_after;
            jump AlmostReParse;
        }
        wn=verb_wordnum;
        special_word=NextWord();
        if (special_word=='xcomma')
        {   special_word=NextWord();
            verb_wordnum++;
        }
        results-->0=##NotUnderstood;
        results-->1=2;
        results-->2=1; special_number1=special_word;
        results-->3=actor;
        consult_from = verb_wordnum; consult_words = num_words-consult_from+1;
        rtrue;
    }

!  **** (I) ****

!  If the player was the actor (eg, in "take dfghh") the error must be printed,
!  and fresh input called for.  In three cases the oops word must be jiggled.

    if (ParserError(etype)~=0) jump ReType;

    if (etype==STUCK_PE)
             {   print "I didn't understand that.^"; }
    if (etype==UPTO_PE)
             {   print "I only understood you as far as wanting to ";
                 for (m=0:m<8:m++) pattern-->m = pattern2-->m;
                 pcount=pcount2; PrintCommand(0,1); print ".^";
             }
    if (etype==CANTSEE_PE)
             {   print "You can't see any such thing.^"; }
    if (etype==ANIMA_PE)
                 print "You can only do that to something animate.^";
    if (etype==VERB_PE)
                 print "Unknown command.^";
    if (etype==SCENERY_PE)
                 print "No need to concern yourself with that.^";
    if (etype==ASKSCOPE_PE)
    {            scope_stage=3;
                 if (indirect(scope_error)==-1)
                 {   best_etype=nextbest_etype; jump GiveError;  }
    }

!  **** (J) ****

!  And go (almost) right back to square one...

    jump ReType;

!  ...being careful not to go all the way back, to avoid infinite repetition
!  of a deferred command causing an error.


!  **** (K) ****

!  At this point, the return value is all prepared, and we are only looking
!  to see if there is a "then" followed by subsequent instruction(s).
    
   .LookForMore;

   if (wn>num_words) rtrue;

   best_etype=UPTO_PE; jump GiveError;
];


! ----------------------------------------------------------------------------
!  Descriptors()
!  Skips "the", and leaves wn pointing to the first misunderstood word.
!  Returns error number, or 0 if no error occurred
! ----------------------------------------------------------------------------

[ Descriptors o flag;
   for (flag=1:flag==1:)
   {   o=NextWord(); flag=0;
       if (o=='the') flag=1;
   }
   wn--;
];

! ----------------------------------------------------------------------------
!  CreatureTest: Will this person do for a "creature" token?
! ----------------------------------------------------------------------------

[ CreatureTest obj;
  if (obj has animate) rtrue;
  if (obj hasnt talkable) rfalse;
  if (action_to_be==##Ask or ##Answer or ##Tell
      || action_to_be==##AskFor) rtrue;
  rfalse;
];

! ----------------------------------------------------------------------------
!  ParseObjectList: Parses tokens 0 to 179, from the current word number wn
!
!  Returns:
!    REPARSE_CODE for "reconstructed input, please re-parse from scratch"
!    1            for "token accepted"
!    0            for "token failed"
!
!  (A)            Preliminaries and special/number tokens
!  (B)            Actual object names (mostly subcontracted!)
!  (C)            and/but and so on
!  (D)            Returning an accepted token
!
! ----------------------------------------------------------------------------
[ ParseObjectList results token  l single_object desc_wn oops_from;

    dont_infer=0;
    oops_from = 0;
!  **** (A) ****
!  We expect to find a list of objects next in what the player's typed.

  .ObjectList;

#ifdef DEBUG;
   if (parser_trace>=3) print "  [Object list from word ", wn, "]^";
#endif;

    if (token>=48 && token<80)
    {   l=indirect(#preactions_table-->(token-48));
#ifdef DEBUG;
        if (parser_trace>=3)
            print "  [Outside parsing routine returned ", l, "]^";
#endif;
        if (l<0) rfalse;
        if (l==0) { params_wanted--; rtrue; }  ! An adjective after all...
        if (l==1)
        {   
            special_number1 = parsed_number; !TBD, this is where ASK ROBOT ABOUT X broke.
        }
        if (l==REPARSE_CODE) return l;
        single_object=l; jump PassToken;
    }

    if (token>=80 && token<128)
    {   scope_token = #preactions_table-->(token-80);
        scope_stage = 1;
        l=indirect(scope_token);
#ifdef DEBUG;
        if (parser_trace>=3)
            print "  [Scope routine returned multiple-flag of ", l, "]^";
#endif;
        if (l==1) token=2; else token=0;
    }

    token_was=0;
    if (token>=16)
    {   token_was = token;
        token=0;
    }

!  Otherwise, we have one of the tokens 0 to 6, all of which really do mean
!  that objects are expected.

!  So now we parse any descriptive words

    desc_wn = wn;

    .TryAgain;

    Descriptors();

!  **** (B) ****

!  This is an actual specified object, and is therefore where a typing error
!  is most likely to occur, so we set:

    oops_from=wn;

!  In either case below we use NounDomain, giving it the token number as
!  context, and two places to look: among the actor's possessions, and in the
!  present location.  (Note that the order depends on which is likeliest.)

    l=NounDomain(actor, actors_location, token);
    if (l==REPARSE_CODE) return l;
    if (l==0) { etype=CantSee(); return l; }
    if (token==6 && CreatureTest(l)==0)   ! Animation is required
    {   
        etype=ANIMA_PE; jump FailToken; 
    } ! for token 6
        
    single_object = l;

!  The following moves the word marker to just past the named object...

    wn = oops_from + match_length;

!  **** (C) ****

!  Object(s) specified now
    .NextInList;

!  **** (D) ****

!  Happy or unhappy endings:

    .PassToken;

    results-->(parameters+2) = single_object;
    parameters++;
    pattern-->pcount = single_object;
    return 1;

    .FailToken;

    return 0;
];

! ----------------------------------------------------------------------------
!  NounDomain does the most substantial part of parsing an object name.
!
!  It is given two "domains" - usually a location and then the actor who is
!  looking - and a context (i.e. token type), and returns:
!
!   0    if no match at all could be made,
!   1    if a multiple object was made,
!   k    if object k was the one decided upon,
!   REPARSE_CODE if it asked a question of the player and consequently rewrote all
!        the player's input, so that the whole parser should start again
!        on the rewritten input.
!
!   In the case when it returns 1<k<REPARSE_CODE, it also sets the variable
!   length_of_noun to the number of words in the input text matched to the
!   noun.
!   In the case k=1, the multiple objects are added to multiple_object by
!   hand (not by MultiAdd, because we want to allow duplicates).
! ----------------------------------------------------------------------------

[ NounDomain domain1 domain2 context  first_word i answer_words;

#ifdef DEBUG;
  if (parser_trace>=4) print "   [NounDomain called at word ", wn, "^";
#endif;

  match_length=0; number_matched=0; match_from=wn; placed_in_flag=0;

  SearchScope(domain1, domain2, context);

#ifdef DEBUG;
  if (parser_trace>=4) print "   [ND made ", number_matched, " matches]^";
#endif;

  wn=match_from+match_length;

!  If nothing worked at all, leave with the word marker skipped past the
!  first unmatched word...

  if (number_matched==0) { wn++; rfalse; }

!  Suppose that there really were some words being parsed (i.e., we did
!  not just infer).  If so, and if there was only one match, it must be
!  right and we return it...

  if (match_from <= num_words)
  {   if (number_matched==1) { i=match_list-->0; return i; }

!  ...now suppose that there was more typing to come, i.e. suppose that
!  the user entered something beyond this noun.  Use the lookahead token
!  to check that if an adjective comes next, it is the right one.  (If
!  not then there must be a mistake like "press red buttno" where "red"
!  has been taken for the noun in the mistaken belief that "buttno" is
!  some preposition or other.)
!
!  If nothing ought to follow, then similarly there must be a mistake,
!  (unless what does follow is just a full stop, and or comma)

      if (wn<=num_words)
      {   i=NextWord(); wn--;
          if (lookahead==8) rfalse;
          if (lookahead>8)
          {   if (lookahead~=AdjectiveWord())
              { wn--;
#ifdef DEBUG;
                if (parser_trace>=3)
                print "   [ND failed at lookahead at word ", wn, "]^";
#endif;
                rfalse;
              }
              wn--;
          }
      }
  }

!  Now look for a good choice, if there's more than one choice...

  number_of_classes=0;
  
  if (number_matched==1) i=match_list-->0;
  if (number_matched>1)
  {   
      i=Adjudicate(context);
      if (i==-1) rfalse;
      if (i==1) rtrue;       !  Adjudicate has made a multiple
                             !  object, and we pass it on
  }

!  If i is non-zero here, one of two things is happening: either
!  (a) an inference has been successfully made that object i is
!      the intended one from the user's specification, or
!  (b) the user finished typing some time ago, but we've decided
!      on i because it's the only possible choice.
!  In either case we have to keep the pattern up to date,
!  note that an inference has been made and return.
!  (Except, we don't note which of a pile of identical objects.)

  if (i~=0)
  {   
      if (dont_infer==1) return i;
      if (inferfrom==0) inferfrom=pcount;
      pattern-->pcount = i;
      return i;
  }

!  Now we come to the question asked when the input has run out
!  and can't easily be guessed (eg, the player typed "take" and there
!  were plenty of things which might have been meant).

  .Incomplete;

  print "You'll need to be more specific.^";
  answer_words=Keyboard(buffer, parse);
  first_word=(parse-->1);
  return REPARSE_CODE;
];

! ----------------------------------------------------------------------------
!  The Adjudicate routine tries to see if there is an obvious choice, when
!  faced with a list of objects (the match_list) each of which matches the
!  player's specification equally well.
!
!  To do this it makes use of the context (the token type being worked on).
!  It counts up the number of obvious choices for the given context
!  (all to do with where a candidate is, except for 6 (animate) which is to
!  do with whether it is animate or not);
!
!  if only one obvious choice is found, that is returned;
!
!  if we are in indefinite mode (don't care which) one of the obvious choices
!    is returned, or if there is no obvious choice then an unobvious one is
!    made;
!
!  at this stage, we work out whether the objects are distinguishable from
!    each other or not: if they are all indistinguishable from each other,
!    then choose one, it doesn't matter which;
!
!  otherwise, 0 (meaning, unable to decide) is returned (but remember that
!    the equivalence classes we've just worked out will be needed by other
!    routines to clear up this mess, so we can't economise on working them
!    out).
!
!  Returns -1 if an error occurred
! ----------------------------------------------------------------------------

[ Adjudicate context i j k good_ones last n ultimate;

#ifdef DEBUG;
  if (parser_trace>=4)
      print "   [Adjudicating match list of size ", number_matched, "^";
#endif;

  j=number_matched-1; good_ones=0; last=match_list-->0;
  for (i=0:i<=j:i++)
  {   n=match_list-->i;
      if (n hasnt concealed)
      {   ultimate=n;
          do
              ultimate=parent(ultimate);
          until (ultimate==actors_location or actor or 0);

          if (context==0 && ultimate==actors_location &&
              (token_was==0 || UserFilter(n)==1)) { good_ones++; last=n; }
          if (context==1 && parent(n)==actor)     { good_ones++; last=n; }
          if (context==2 && ultimate==actors_location) 
                                                  { good_ones++; last=n; }
          if (context==3 && parent(n)==actor)     { good_ones++; last=n; }

          if (context==4 or 5)
          {   if (advance_warning==-1)
              {   if (parent(n)==actor) { good_ones++; last=n; }
              }
              else
              {   if (context==4 && parent(n)==actor && n~=advance_warning)
                  { good_ones++; last=n; }
                  if (context==5 && parent(n)==actor && n in advance_warning)
                  { good_ones++; last=n; }
              }
          }
          if (context==6 && CreatureTest(n)==1)   { good_ones++; last=n; }
      }
  }
  if (good_ones==1) return last;

  ! If there is ambiguity about what was typed, but it definitely wasn't
  ! animate as required, then return anything; higher up in the parser
  ! a suitable error will be given.  (This prevents a question being asked.)
  !
  if (context==6 && good_ones==0) return match_list-->0;

  n=1;
  for (i=0:i<number_matched:i++)
      if (match_classes-->i==0)
      {   
          match_classes-->i=n++; 
      }
  n--;

#ifdef DEBUG;
  if (parser_trace>=4)
  {   print "   Difficult adjudication with ", n, " equivalence classes:^";
      for (i=0:i<number_matched:i++)
      {   print "   "; CDefArt(match_list-->i);
          print " (", match_list-->i, ")  ---  ",match_classes-->i, "^";
      }
  }
#endif;

  number_of_classes = n;

  if (n>1)
  {   j=0; good_ones=0;
      for (i=0:i<number_matched:i++)
      {   k=ChooseObjects(match_list-->i,2);
          if (k==j) good_ones++;
          if (k>j) { j=k; good_ones=1; last=match_list-->i; }
      }
      if (good_ones==1)
      {
#ifdef DEBUG;
          if (parser_trace>=4)
              print "   ChooseObjects picked a best.]^";
#endif;
          return last;
      }
#ifdef DEBUG;
      if (parser_trace>=4)
          print "   Unable to decide: it's a draw.]^";
#endif;
      return 0;
  }

!  When the player is really vague, or there's a single collection of
!  indistinguishable objects to choose from, choose the one the player
!  most recently acquired, or if the player has none of them, then
!  the one most recently put where it is.

  if (n==1) dont_infer = 1;

  return BestGuess();
];

! ----------------------------------------------------------------------------
!  ScoreMatchL  scores the match list for quality in terms of what the
!  player has vaguely asked for.  Points are awarded for conforming with
!  requirements like "my", and so on.  If the score is less than the
!  threshold, block out the entry to -1.
!  The scores are put in the match_classes array, which we can safely
!  reuse by now.
! ----------------------------------------------------------------------------

[ ScoreMatchL  its_owner its_score obj i threshold a_s l_s;

  a_s = 30; l_s = 20;
  if (action_to_be == ##Take or ##Remove) { a_s=20; l_s=30; }

  for (i=0:i<number_matched:i++)
  {   obj = match_list-->i; its_owner = parent(obj); its_score=0;
      if (its_owner==actor)   its_score=a_s;
      if (its_owner==actors_location) its_score=l_s;
      if (its_score==0 && its_owner~=compass) its_score=10;

      its_score=its_score + ChooseObjects(obj,2);

      if (its_score < threshold) match_list-->i=-1;
      else
      {   match_classes-->i=its_score;
#ifdef DEBUG;
          if (parser_trace >= 4)
          {   print "   "; CDefArt(match_list-->i);
              print " (", match_list-->i, ") in "; DefArt(its_owner);
              print " scores ",its_score, "^";
          }
#endif;
      }
  }
  number_of_classes=2;
];

! ----------------------------------------------------------------------------
!  BestGuess makes the best guess it can out of the match list, assuming that
!  everything in the match list is textually as good as everything else;
!  however it ignores items marked as -1, and so marks anything it chooses.
!  It returns -1 if there are no possible choices.
! ----------------------------------------------------------------------------

[ BestGuess  earliest its_score best i;

  if (number_of_classes~=1) ScoreMatchL();

  earliest=0; best=-1;
  for (i=0:i<number_matched:i++)
  {   if (match_list-->i >= 0)
      {   its_score=match_classes-->i;
          if (its_score>best) { best=its_score; earliest=i; }
      }
  }
#ifdef DEBUG;
  if (parser_trace>=4)
  {   if (best<0)
          print "   Best guess ran out of choices^";
      else
      {   print "   Best guess "; DefArt(match_list-->earliest);
          print  " (", match_list-->earliest, ")^";
      }
  }
#endif;
  if (best<0) return -1;
  i=match_list-->earliest;
  match_list-->earliest=-1;
  return i;
];

! ----------------------------------------------------------------------------
!  PrintCommand reconstructs the command as it presently reads, from
!  the pattern which has been built up
!
!  If from is 0, it starts with the verb: then it goes through the pattern.
!  The other parameter is "emptyf" - a flag: if 0, it goes up to pcount:
!  if 1, it goes up to pcount-1.
!
!  Note that verbs and prepositions are printed out of the dictionary:
!  and that since the dictionary may only preserve the first six characters
!  of a word (in a V3 game), we have to hand-code the longer words needed.
!
!  (Recall that pattern entries are 0 for "multiple object", 1 for "special
!  word", 2 to 999 are object numbers and REPARSE_CODE+n means the preposition n)
! ----------------------------------------------------------------------------

[ PrintCommand from emptyf i j k f;
  if (from==0)
  {   
       i=verb_word; from=1; f=1;
       if (i==#n$l)         { print "look";              jump VerbPrinted; }
       if (i==#n$x)         { print "examine";           jump VerbPrinted; }
       if (PrintVerb(i)==0) print (address) i;
  }
  .VerbPrinted;

  j=pcount-emptyf;
  for (k=from:k<=j:k++)
  {   
      if (f==1) print (char) ' ';
      i=pattern-->k;
      if (i>=REPARSE_CODE)
      {   i=AdjectiveAddress(i-REPARSE_CODE);
          print (address) i;
      }
      else DefArt(i);
      .TokenPrinted;
      f=1;
  }
];

! ----------------------------------------------------------------------------
!  The CantSee routine returns a good error number for the situation where
!  the last word looked at didn't seem to refer to any object in context.
!
!  The idea is that: if the actor is in a location (but not inside something
!  like, for instance, a tank which is in that location) then an attempt to
!  refer to one of the words listed as meaningful-but-irrelevant there
!  will cause "you don't need to refer to that in this game" rather than
!  "no such thing" or "what's 'it'?".
!  (The advantage of not having looked at "irrelevant" local nouns until now
!  is that it stops them from clogging up the ambiguity-resolving process.
!  Thus game objects always triumph over scenery.)
! ----------------------------------------------------------------------------

[ CantSee  i w e;
    if (scope_token~=0) { scope_error = scope_token; return ASKSCOPE_PE; }

    wn--; w=NextWord();
    e=CANTSEE_PE;
    i=parent(actor);
    if (i has visited && Refers(i,w)==1) e=SCENERY_PE;
    if (etype>e) return etype;
    return e;
];


! ----------------------------------------------------------------------------
!  The UserFilter routine consults the user's filter (or checks on attribute)
!  to see what already-accepted nouns are acceptable
! ----------------------------------------------------------------------------

[ UserFilter obj;

  if (token_was>=128)
  {   if (obj has (token_was-128)) rtrue;
      rfalse;
  }
  noun=obj;
  return (indirect(#preactions_table-->(token_was-16)));
];

! ----------------------------------------------------------------------------
!  SearchScope  domain1 domain2 context
!
!  Works out what objects are in scope (possibly asking an outside routine),
!  but does not look at anything the player has typed.
! ----------------------------------------------------------------------------

[ SearchScope domain1 domain2 context i;

  i=0;
!  Everything is in scope to the debugging commands

#ifdef DEBUG;
  if (scope_reason==PARSING_REASON
      && (verb_word == 'purloin' or 'tree' or 'abstract'
          || verb_word == 'gonear' or 'scope'))
  {   for (i=selfobj+1:i<=top_object:i++) PlaceInScope(i);
      rtrue;
  }
#endif;

!  First, a scope token gets priority here:

  if (scope_token ~= 0)
  {   scope_stage=2;
      if (indirect(scope_token)~=0) rtrue;
  }

!  Next, call any user-supplied routine adding things to the scope,
!  which may circumvent the usual routines altogether if they return true:

  if (actor==domain1 or domain2 && InScope(actor)~=0) rtrue;

!  Pick up everything in the location except the actor's possessions;
!  then go through those.  (This ensures the actor's possessions are in
!  scope even in Darkness.)

  if (context==5 && advance_warning ~= -1)
  {   if (IsSeeThrough(advance_warning)==1)
          ScopeWithin(advance_warning, 0, context);
  }
  else
  {   ScopeWithin(domain1, domain2, context);
      ScopeWithin(domain2,0,context);
  }
];

! ----------------------------------------------------------------------------
!  IsSeeThrough is used at various places: roughly speaking, it determines
!  whether o being in scope means that the contents of o are in scope.
! ----------------------------------------------------------------------------

[ IsSeeThrough o;
  if (o has supporter
      || (o has transparent)
      || (o has container && o has open))
      rtrue;
  rfalse;
];

! ----------------------------------------------------------------------------
!  PlaceInScope is provided for routines outside the library, and is not
!  called within the parser (except for debugging purposes).
! ----------------------------------------------------------------------------

[ PlaceInScope thing;
   if (scope_reason~=PARSING_REASON or TALKING_REASON)
   {   DoScopeAction(thing); rtrue; }
   wn=match_from; TryGivenObject(thing); placed_in_flag=1;
];

! ----------------------------------------------------------------------------
!  DoScopeAction
! ----------------------------------------------------------------------------

[ DoScopeAction thing s p1;
  s = scope_reason; p1=parser_one;
#ifdef DEBUG;
  if (parser_trace>=5)
  {   print "[DSA on ", (the) thing, " with reason = ", scope_reason,
      " p1 = ", parser_one, " p2 = ", parser_two, "]^";
  }
#endif;
  switch(scope_reason)
  {   REACT_BEFORE_REASON:
          if (thing.react_before==0 or NULL) return;
#ifdef DEBUG;
          if (parser_trace>=2)
          {   print "[Considering react_before for ", (the) thing, "]^"; }
#endif;
          if (parser_one==0) parser_one = RunRoutines(thing,react_before);
      REACT_AFTER_REASON:
          if (thing.react_after==0 or NULL) return;
#ifdef DEBUG;
          if (parser_trace>=2)
          {   print "[Considering react_after for ", (the) thing, "]^"; }
#endif;
          if (parser_one==0) parser_one = RunRoutines(thing,react_after);
      EACH_TURN_REASON:
          if (thing.&each_turn==0) return;
#ifdef DEBUG;
          if (parser_trace>=2)
          {   print "[Considering each_turn for ", (the) thing, "]^"; }
#endif;
          PrintOrRun(thing, each_turn);
      TESTSCOPE_REASON:
          if (thing==parser_one) parser_two = 1;
      LOOPOVERSCOPE_REASON:
          indirect(parser_one,thing); parser_one=p1;
  }
  scope_reason = s;
];

! ----------------------------------------------------------------------------
!  ScopeWithin looks for objects in the domain which make textual sense
!  and puts them in the match list.  (However, it does not recurse through
!  the second argument.)
! ----------------------------------------------------------------------------

[ ScopeWithin domain nosearch context;

   if (domain==0) rtrue;

!  multiexcept doesn't have second parameter in scope
   if (context==4 && domain==advance_warning) rtrue;

!  Special rule: the directions (interpreted as the 12 walls of a room) are
!  always in context.  (So, e.g., "examine north wall" is always legal.)
!  (Unless we're parsing something like "all", because it would just slow
!  things down then, or unless the context is "creature".)

   if (domain==actors_location
       && scope_reason==PARSING_REASON && context~=6) ScopeWithin(compass);

!  Look through the objects in the domain

   objectloop (domain in domain) ScopeWithin_O(domain, nosearch, context);
];

[ ScopeWithin_O domain nosearch context i ad n;

!  If the scope reason is unusual, don't parse.

      if (scope_reason~=PARSING_REASON or TALKING_REASON)
      {   DoScopeAction(domain); jump DontAccept; }

!  If we're beyond the end of the user's typing, accept everything
!  (NounDomain will sort things out)

      if (match_from > num_words)
      {   
#ifdef DEBUG;
          i=parser_trace; parser_trace=0;
          if (i>=5) { print "     Out of text: matching "; DefArt(domain);
                      new_line; }
#endif;
          MakeMatch(domain,1);
#ifdef DEBUG;
          parser_trace=i; 
#ENDIF;
          jump DontAccept;
      }

!  "it" or "them" matches to the it-object only.  (Note that (1) this means
!  that "it" will only be understood if the object in question is still
!  in context, and (2) only one match can ever be made in this case.)

      wn=match_from;
      i=NounWord();
      if (i==4 && player==domain)  MakeMatch(player,1);
      
!  Construing the current word as the start of a noun, can it refer to the
!  object?

      wn--; TryGivenObject(domain);

      .DontAccept;

!  Shall we consider the possessions of the current object, as well?
!  Only if it's a container (so, for instance, if a dwarf carries a
!  sword, then "drop sword" will not be accepted, but "dwarf, drop sword"
!  will).
!  Also, only if there are such possessions.
!
!  Notice that the parser can see "into" anything flagged as
!  transparent - such as a dwarf whose sword you can get at.

      if (child(domain)~=0 && domain ~= nosearch && IsSeeThrough(domain)==1)
          ScopeWithin(domain,0,context);

!  Drag any extras into context

   ad = domain.&add_to_scope;
   if (ad ~= 0)
   {   if (UnsignedCompare(ad-->0,top_object) > 0)
       {   ats_flag = 2+context;
           RunRoutines(domain, add_to_scope);
           ats_flag = 0;
       }
       else
       {   n=domain.#add_to_scope;
           for (i=0:(2*i)<n:i++)
               ScopeWithin_O(ad-->i,0,context);
       }
   }
];

[ AddToScope obj;
   if (ats_flag>=2)
       ScopeWithin_O(obj,0,ats_flag-2);
];

! ----------------------------------------------------------------------------
!  MakeMatch looks at how good a match is.  If it's the best so far, then
!  wipe out all the previous matches and start a new list with this one.
!  If it's only as good as the best so far, add it to the list.
!  If it's worse, ignore it altogether.
!
!  The idea is that "red panic button" is better than "red button" or "panic".
!
!  number_matched (the number of words matched) is set to the current level
!  of quality.
!
!  We never match anything twice, and keep at most 32 equally good items.
! ----------------------------------------------------------------------------

[ MakeMatch obj quality i;
#ifdef DEBUG;
   if (parser_trace>=5) print "    Match with quality ",quality,"^";
#endif;
   if (token_was~=0 && UserFilter(obj)==0)
   {   #ifdef DEBUG;
       if (parser_trace>=5) print "    Match filtered out^";
       #endif;
       rtrue;
   }
   if (quality < match_length) rtrue;
   if (quality > match_length) { match_length=quality; number_matched=0; }
   else
   {   if (2*number_matched>=MATCH_LIST_SIZE) rtrue;
       for (i=0:i<number_matched:i++)
           if (match_list-->i==obj) rtrue;
   }
   match_list-->number_matched++ = obj;
#ifdef DEBUG;
   if (parser_trace>=5) print "    Match added to list^";
#endif;
];

! ----------------------------------------------------------------------------
!  TryGivenObject tries to match as many words as possible in what has been
!  typed to the given object, obj.  If it manages any words matched at all,
!  it calls MakeMatch to say so.  There is no return value.
! ----------------------------------------------------------------------------

[ TryGivenObject obj threshold k w j;

#ifdef DEBUG;
   if (parser_trace>=5)
   {   print "    Trying "; DefArt(obj);
       print " (", obj, ") at word ", wn, "^";
   }
#endif;

!  Ask the object to parse itself if necessary:

   if (obj.parse_name~=0)
   {   parser_action=-1; j=wn;
       k=RunRoutines(obj,parse_name);
       if (k>0)
       {   wn=j+k;
           .MMbyPN;
           MakeMatch(obj,k); rfalse;
       }
       if (k==0) jump NoWordsMatch;
   }

!  The default algorithm is simply to count up how many words pass the
!  Refers test:

   w = NounWord();
   if (w==4 && obj==player) { MakeMatch(obj,1); rfalse; }
      
   j=--wn;
   threshold = ParseNoun(obj);
#ifdef DEBUG;
   if (threshold>=0 && parser_trace>=5)
       print "    ParseNoun returned ", threshold, "^";
#endif;
   if (threshold<0) wn++;
   if (threshold>0) { k=threshold; jump MMbyPN; }
   if (threshold==0 || Refers(obj,w)==0)
   {   
       .NoWordsMatch;
       rfalse;
   }

   if (threshold<0)
   {   
        threshold=1; while (0~=Refers(obj,NextWord())) threshold++;
   }

   MakeMatch(obj,threshold);

#ifdef DEBUG;
   if (parser_trace>=5) print "    Matched^";
#endif;
];

! ----------------------------------------------------------------------------
!  Refers works out whether the word with dictionary address wd can refer to
!  the object obj, by seeing if wd is listed in the "names" property of obj.
! ----------------------------------------------------------------------------

[ Refers obj wd   k l m;
    if (obj==0) rfalse;
    k=obj.&1; l=(obj.#1)/2-1;
    for (m=0:m<=l:m++)
        if (wd==k-->m) rtrue;
    rfalse;
];

! ----------------------------------------------------------------------------
!  NounWord (which takes no arguments) returns:
!
!   4  if "me", "myself", "self"
!   0  if the next word is unrecognised or does not carry the "noun" bit in
!      its dictionary entry,
!   or the address in the dictionary if it is a recognised noun.
!
!  The "current word" marker moves on one.
! ----------------------------------------------------------------------------

[ NounWord i;
   i=NextWord();
   if (i=='me' or 'myself' or 'self') return 4;
   if (i==0) rfalse;
   if ((i->#dict_par1)&128 == 0) rfalse;
   return i;
];

! ----------------------------------------------------------------------------
!  AdjectiveWord (which takes no arguments) returns:
!
!   0  if the next word is listed in the dictionary as possibly an adjective,
!   or its adjective number if it is.
!
!  The "current word" marker moves on one.
! ----------------------------------------------------------------------------

[ AdjectiveWord i j;
   j=NextWord();
   if (j==0) rfalse;
   i=j->#dict_par1;
   if (i&8 == 0) rfalse;
   return(j->#dict_par3);
];

! ----------------------------------------------------------------------------
!  AdjectiveAddress works out the address in the dictionary of the word
!  corresponding to the given adjective number.
!
!  It should never produce the given error (which would mean that Inform
!  had set up the adjectives table incorrectly).
! ----------------------------------------------------------------------------

[ AdjectiveAddress n m;
   m=#adjectives_table;
   for (::)
   {   if (n==m-->1) return m-->0;
       m=m+4;
   }
   m=#adjectives_table; RunTimeError(1);
   return m;
];

! ----------------------------------------------------------------------------
!  NextWord (which takes no arguments) returns:
!
!  0            if the next word is unrecognised,
!  comma_word   if it is a comma character
!               (which is treated oddly by the Z-machine, hence the code)
!  or the dictionary address if it is recognised.
!  The "current word" marker is moved on.
!
!  NextWordStopped does the same, but returns -1 when input has run out
! ----------------------------------------------------------------------------

[ NextWord i j k;
   if (wn > parse->1) { wn++; rfalse; }
   i=wn*2-1; wn++;
   j=parse-->i;
   if (j==0)
   {   k=wn*4-3; i=buffer->(parse->k);
       if (i==',') j=comma_word;
   }
   return j;
];   

[ NextWordStopped;
   if (wn > parse->1) { wn++; return -1; }
   return NextWord();
];

[ WordAddress wordnum;
   return buffer + parse->(wordnum*4+1);
];

[ WordLength wordnum;
   return parse->(wordnum*4);
];

! ----------------------------------------------------------------------------
!  Useful routine: unsigned comparison (for addresses in Z-machine)
!    Returns 1 if x>y, 0 if x=y, -1 if x<y
!  ZRegion(addr) returns 1 if object num, 2 if in code area, 3 if in strings
! ----------------------------------------------------------------------------

[ UnsignedCompare x y u v;
  if (x==y) return 0;
  if (x<0 && y>=0) return 1;
  if (x>=0 && y<0) return -1;
  u = x&$7fff; v= y&$7fff;
  if (u>v) return 1;
  return -1;
];

[ ZRegion addr;
  if (addr==0) return 0;
  if (addr>=1 && addr<=top_object) return 1;
  if (UnsignedCompare(addr, #strings_offset)>=0) return 3;
  if (UnsignedCompare(addr, #code_offset)>=0) return 2;
  return 0;
];

[ PrintOrRun obj prop flag a;
  if (obj.#prop > 2) return RunRoutines(obj,prop);
  if (obj.prop==NULL) rfalse;
  a=ZRegion(obj.prop);
  if (a==0 or 1) return RunTimeError(2,obj,prop);
  if (a==3) { print (string) obj.prop; if (flag==0) new_line; rtrue; }
  return RunRoutines(obj,prop);
];

[ ValueOrRun obj prop a;
  a=ZRegion(obj.prop);
  if (a==2) return RunRoutines(obj,prop);
  return obj.prop;
];

#IFDEF DEBUG;
[ NameTheProperty prop;
  if (#identifiers_table-->prop == 0)
  {   print "property ", prop; return;
  }
  print (string) #identifiers_table-->prop;
];
#ENDIF;

[ RunRoutines obj prop i j k l m ssv;

   if (obj.prop==NULL or 0) rfalse;

#IFDEF DEBUG;
   if (debug_flag & 1 ~= 0 && prop~=short_name)
    print "[Running ", (NameTheProperty) prop, " for ", (name) obj,"]^";
#ENDIF;

   j=obj.&prop; k=obj.#prop; m=self; self=obj;
   ssv=sw__var;
   if (prop==life) sw__var=reason_code;
   else sw__var=action;
   for (i=0:i<k/2:i++)
   {   if (j-->i == NULL) { self=m; sw__var=ssv; rfalse; }
       l=ZRegion(j-->i);
       if (l==2)
       {   l=indirect(j-->i);
           if (l~=0) { self=m; sw__var=ssv; return l; }
       }
       else
       {   if (l==3) { print (string) j-->i; new_line; rtrue;}
           else RunTimeError(3,obj,prop);
       }
   }
   self=m; sw__var=ssv;
   rfalse;
];

! ----------------------------------------------------------------------------
!  End of the parser proper: the remaining routines are its front end.
! ----------------------------------------------------------------------------

[ DisplayStatus;
  sline1=score; sline2=turns; 
];

[ NotifyTheScore i;
  print "^[Your score has just gone ";
  if (last_score > score) { i=last_score-score; print "down"; }
  else { i=score-last_score; print "up"; }
  print " by ", i,"]^";
];

[ PlayTheGame i j;

   standard_interpreter = $32-->0;

   player = selfobj;
   top_object = #largest_object-255;
   selfobj.capacity = MAX_CARRIED;

   self = GameController; sender = GameController;
   j=Initialise();

   last_score = score;
   move player to location;
   while (parent(location)~=0) location=parent(location);
   objectloop (i in player) give i moved ~concealed;

   if (j~=2) Banner();
   <Look>;

   for (i=1:i<=100:i++) j=random(i);

   while (deadflag==0)
   {
       self = GameController; sender = GameController;
       if (score ~= last_score)
       {   if (notify_mode==1) NotifyTheScore(); last_score=score; }

      .late__error;

       inputobjs-->0 = 0; inputobjs-->1 = 0;
       inputobjs-->2 = 0; inputobjs-->3 = 0; meta=0;

       !  The Parser writes its results into inputobjs and meta,
       !  a flag indicating a "meta-verb".  This can only be set for
       !  commands by the player, not for orders to others.

       Parser(inputobjs);

       noun=0; second=0; action=0; 

       action=inputobjs-->0;

       !  Reverse "give fred biscuit" into "give biscuit to fred"

       if (action==##GiveR or ##ShowR)
       {   i=inputobjs-->2; inputobjs-->2=inputobjs-->3; inputobjs-->3=i;
           if (action==##GiveR) action=##Give; else action=##Show;
       }

       !  Convert "P, tell me about X" to "ask P about X"

       if (action==##Tell && inputobjs-->2==player && actor~=player)
       {   inputobjs-->2=actor; actor=player; action=##Ask;
       }

       !  Convert "ask P for X" to "P, give X to me"

       if (action==##AskFor && inputobjs-->2~=player && actor==player)
       {   actor=inputobjs-->2; inputobjs-->2=inputobjs-->3;
           inputobjs-->3=player; action=##Give;
       }

      .begin__action;
       inp1=0; inp2=0; i=inputobjs-->1;
       if (i>=1) inp1=inputobjs-->2;
       if (i>=2) inp2=inputobjs-->3;

       !  inp1 and inp2 hold: object numbers, or 0 for "multiple object",
       !  or 1 for "a number or dictionary address"

       noun=inp1; second=inp2;
       if (inp1==1) 
       {
            noun=special_number1;
       }
       if (inp2==1)
       {   
          second=special_number1;
       }

       !  noun and second equal inp1 and inp2, except that in place of 1
       !  they substitute the actual number or dictionary address

       if (actor~=player)
       {   
           !  The player's "orders" property can refuse to allow conversation
           !  here, by returning true.  If not, the order is sent to the
           !  other person's "orders" property.  If that also returns false,
           !  then: if it was a misunderstood command anyway, it is converted
           !  to an Answer action (thus "floyd, grrr" ends up as
           !  "say grrr to floyd").  If it was a good command, it is finally
           !  offered to the Order: part of the other person's "life"
           !  property, the old-fashioned way of dealing with conversation.

           j=RunRoutines(player,orders);
           if (j==0)
           {   j=RunRoutines(actor,orders);
               if (j==0)
               {   if (action==##NotUnderstood)
                   {   inputobjs-->3=actor; actor=player; action=##Answer;
                       jump begin__action;
                   }
                   if (RunLife(actor,##Order)==0) L__M(##Order,1,actor);
               }
           }
           jump turn__end;
       }

       !  So now we must have an ordinary parser-generated action, unless
       !  inp1 is a "multiple object", in which case we: (a) check the
       !  multiple list isn't empty; (b) warn the player if it has been
       !  cut short because of excessive size, and (c) generate a sequence
       !  of actions from the list (stopping on death or movement away).

       if (i==0 || inp1~=0) Process();
       else
       {
          RunTimeError(99);
       }

       .turn__end;

       !  No time passes if either (i) the verb was meta, or
       !  (ii) we've only had the implicit take before the "real"
       !  action to follow.

       if (deadflag==0 && meta==0) EndTurnSequence();
   }

   if (deadflag~=2) AfterLife();
   if (deadflag==0) jump late__error;

   print "^";
   if (deadflag==1) L__M(##Miscellany,3);
   if (deadflag==2) L__M(##Miscellany,4);
   if (deadflag>2)  { print " "; DeathMessage(); print " "; }
   print "^";
   ScoreSub();
   DisplayStatus();

   .RRQL;
   L__M(##Miscellany,5);
   print "> ";
   #IFV3; read buffer parse; #ENDIF;
   temp_global=0;
   #IFV5; read buffer parse DrawStatusLine; #ENDIF;
   i=parse-->1;
   if (i=='quit' or #n$q) quit;
   if (i=='restart')      @restart;
   if (i=='restore')      { RestoreSub(); }
   jump RRQL;
];

[ Process;
#IFDEF DEBUG;
   if (debug_flag & 2 ~= 0) TraceAction(0);
#ENDIF;
   if (meta==1 || BeforeRoutines()==0)
       indirect(#actions_table-->action);
];

#IFDEF DEBUG;
Array debug_anames table
[;##Inv "Inv";
  ##Take "Take";
  ##Drop "Drop";
  ##Remove "Remove";
  ##PutOn "PutOn";
  ##Insert "Insert";
  ##Enter "Enter";
  ##Exit "Exit";
  ##GetOff "GetOff";
  ##Go "Go";
  ##GoIn "GoIn";
  ##Look "Look";
  ##Examine "Examine";
  ##Search "Search";
  ##Give "Give";
  ##Show "Show";
  ##Unlock "Unlock";
  ##Lock "Lock";
  ##SwitchOn "SwitchOn";
  ##SwitchOff "SwitchOff";
  ##Open "Open";
  ##Close "Close";
!  ##Disrobe "Disrobe";
!  ##Wear "Wear";
  ##Eat "Eat";
  ##Burn "Burn";
  ##Consult "Consult";
  ##Smell "Smell";
  ##Listen "Listen";
  ##Taste "Taste";
  ##Touch "Touch";
  ##Dig "Dig";
  ##Cut "Cut";
  ##Jump "Jump";
  ##JumpOver "JumpOver";
  ##Tie "Tie";
  ##Drink "Drink";
  ##Fill "Fill";
  ##Attack "Attack";
  ##Swim "Swim";
  ##Rub "Rub";
  ##Set "Set";
  ##SetTo "SetTo";
  ##Pull "Pull";
  ##Push "Push";
  ##PushDir "PushDir";
  ##Turn "Turn";
  ##ThrowAt "ThrowAt";
  ##Answer "Answer";
  ##Ask "Ask";
  ##Tell "Tell";
  ##AskFor "AskFor";
  ##Climb "Climb";
  ##Wait "Wait";
  ##Order "Order";
  ##NotUnderstood "NotUnderstood";
];

[ DebugParameter w x n l;
  x=0-->4; x=x+(x->0)+1; l=x->0; n=(x+1)-->0; x=w-(x+3);
  print w;
  if (w>=1 && w<=top_object) print " (", (name) w, ")";
  if (x%l==0 && (x/l)<n) print " ('", (address) w, "')";
];

[ DebugAction a i;
  for (i=1:i<=debug_anames-->0:i=i+2)
  {   
      if (debug_anames-->i==a)
      {   print (string) debug_anames-->(i+1); rfalse; }
  }
  print a;
];

[ TraceAction source ar;
  if (source<2) { print "[Action "; DebugAction(action); }
  else
  {   if (ar==##Order)
      {   print "[Order to "; PrintShortName(actor); print ": ";
          DebugAction(action);
      }
      else
      {   print "[Life rule "; DebugAction(ar); }
  }
  if (noun~=0)   { print " with noun "; DebugParameter(noun);  }
  if (second~=0) { print " and second "; DebugParameter(second); }
  if (source==0) print " (from parser)";
  if (source==1) print " (from outside)";
  print "]^";
];
#ENDIF;

[ TestScope obj act a al sr x y;
  x=parser_one; y=parser_two;
  parser_one=obj; parser_two=0; a=actor; al=actors_location;
  sr=scope_reason; scope_reason=TESTSCOPE_REASON;
  if (act==0) actor=player; else actor=act;
  actors_location=actor;
  while (parent(actors_location)~=0)
      actors_location=parent(actors_location);
  SearchScope(location,player,0); scope_reason=sr; actor=a;
  actors_location=al; parser_one=x; x=parser_two; parser_two=y;
  return x;
];

[ LoopOverScope routine act x y a al;
  x = parser_one; y=scope_reason; a=actor; al=actors_location;
  parser_one=routine; if (act==0) actor=player; else actor=act;
  actors_location=actor;
  while (parent(actors_location)~=0)
      actors_location=parent(actors_location);
  scope_reason=LOOPOVERSCOPE_REASON;
  SearchScope(actors_location,actor,0);
  parser_one=x; scope_reason=y; actor=a; actors_location=al;
];

[ BeforeRoutines;
  if (GamePreRoutine()~=0) rtrue;
  if (RunRoutines(player,orders)~=0) rtrue;
  if (location~=0 && RunRoutines(location,before)~=0) rtrue;
  scope_reason=REACT_BEFORE_REASON; parser_one=0;
  SearchScope(location,player,0); scope_reason=PARSING_REASON;
  if (parser_one~=0) rtrue;
  if (inp1>1 && RunRoutines(inp1,before)~=0) rtrue;
  rfalse;
];

[ AfterRoutines;
  scope_reason=REACT_AFTER_REASON; parser_one=0;
  SearchScope(location,player,0); scope_reason=PARSING_REASON;
  if (parser_one~=0) rtrue;
  if (location~=0 && RunRoutines(location,after)~=0) rtrue;
  if (inp1>1 && RunRoutines(inp1,after)~=0) rtrue;
  return GamePostRoutine();
];

[ R_Process acti i j sn ss sa sse;
   sn=inp1; ss=inp2; sa=action; sse=self;
   inp1 = i; inp2 = j; noun=i; second=j; action=acti;

#IFDEF DEBUG;
   if (debug_flag & 2 ~= 0) TraceAction(1);
#ENDIF;

   if ((meta==1 || BeforeRoutines()==0) && action<256)
   {   indirect(#actions_table-->action);
       self=sse; inp1=sn; noun=sn; inp2=ss; second=ss; action=sa; rfalse;
   }
   self=sse; inp1=sn; noun=sn; inp2=ss; second=ss; action=sa; rtrue;
];

[ RunLife a j;
#IFDEF DEBUG;
   if (debug_flag & 2 ~= 0) TraceAction(2, j);
#ENDIF;
   reason_code = j; return RunRoutines(a,life);
];

[ StartTimer obj timer i;
   for (i=0:i<active_timers:i++)
       if (the_timers-->i==obj) rfalse;
   for (i=0:i<active_timers:i++)
       if (the_timers-->i==0) jump FoundTSlot;
   i=active_timers++;
   if (i >= MAX_TIMERS) RunTimeError(4);
   .FoundTSlot;
   if (obj.&time_left==0) RunTimeError(5,obj);
   the_timers-->i=obj; obj.time_left=timer;
];

[ StopTimer obj i;
   for (i=0:i<active_timers:i++)
       if (the_timers-->i==obj) jump FoundTSlot2;
   rfalse;
   .FoundTSlot2;
   if (obj.&time_left==0) RunTimeError(5,obj);
   the_timers-->i=0; obj.time_left=0;
];

[ StartDaemon obj i;
   for (i=0:i<active_timers:i++)
       if (the_timers-->i == $8000 + obj)
           rfalse;
   for (i=0:i<active_timers:i++)
       if (the_timers-->i==0) jump FoundTSlot3;
   i=active_timers++;
   if (i >= MAX_TIMERS) RunTimeError(4);
   .FoundTSlot3;
   the_timers-->i = $8000 + obj;
];

[ StopDaemon obj i;
   for (i=0:i<active_timers:i++)
       if (the_timers-->i == $8000 + obj) jump FoundTSlot4;
   rfalse;
   .FoundTSlot4;
   the_timers-->i=0;
];

[ EndTurnSequence i j;

   turns++;

   for (i=0: i<active_timers: i++)
   {   if (deadflag) return;
       j=the_timers-->i;
       if (j~=0)
       {   
           if (j & $8000) RunRoutines(j&$7fff,daemon);
           else
           {   
               if (j.time_left==0)
               {   
                   StopTimer(j);
                   RunRoutines(j,time_out);
               }
               else
                   j.time_left=j.time_left-1;
           }
       }
   }
   if (deadflag) return;

   scope_reason=EACH_TURN_REASON; verb_word=0;
   DoScopeAction(location); SearchScope(location,player,0);
   scope_reason=PARSING_REASON;
   if (deadflag) return;

   TimePasses();
   if (deadflag) return;
   objectloop (i in player)
       if (i hasnt moved)
       {   give i moved;
           if (i has scored)
           {   score=score+OBJECT_SCORE;
               things_score=things_score+OBJECT_SCORE;
           }
       }
];

[ ChangeDefault prop val;
   (0-->5)-->(prop-1) = val;
];

[ Indefart o;
   if (o hasnt proper) { PrintOrRun(o,article,1); print " "; }
   PrintShortName(o);
];

[ Defart o;
   if (o hasnt proper) print "the "; PrintShortName(o);
];

[ CDefart o;
   if (o hasnt proper) print "The "; PrintShortName(o);
];

[ PrintShortName o;
   if (o==0) { print "nothing"; rtrue; }
   if (o>top_object || o<0) { rtrue; }
   if (o==player) { print "yourself"; rtrue; }
   if (o.&short_name~=0 && PrintOrRun(o,short_name,1)~=0) rtrue;
   @print_obj o;
];

[ Banner i;
   if (Story ~= 0)
   {
#IFV5; style bold; #ENDIF;
   print (string) Story;
#IFV5; style roman; #ENDIF;
   }
   if (Headline ~= 0)
       print (string) Headline;
   print "Release ", (0-->1) & $03ff, " / Serial number ";
   for (i=18:i<24:i++) print (char) 0->i;
   print " / Inform v"; inversion;
   print " Library ", (string) LibRelease;
#ifdef DEBUG;
   print " D";
#endif;
   new_line;
   if (standard_interpreter > 0)
       print "Standard interpreter ",
           standard_interpreter/256, ".", standard_interpreter%256, "^";
];

[ VersionSub;
  Banner();
#IFV5;
  print "Interpreter ", 0->$1e, " Version ", (char) 0->$1f, " / ";
#ENDIF;
  print "Library serial number ", (string) LibSerial, "^";
];

[ RunTimeError n p1 p2;
#IFDEF DEBUG;
  print "** Library error ", n, " (", p1, ",", p2, ") **^** ";
  switch(n)
  {   1: print "Adjective not found (this should not occur)";
      2: print "Property value not routine or string: ~",
               (NameTheProperty) p2, "~ of ~", (name) p1, "~ (", p1, ")";
      3: print "Entry in property list not routine or string: ~",
               (NameTheProperty) p2, "~ list of ~", (name) p1,
               "~ (", p1, ")";
      4: print "Too many timers/daemons are active simultaneously.  The \
                limit is the library constant MAX_TIMERS (currently ",
                MAX_TIMERS, ") and should be increased";
      5: print "Object ~", (name) p1, "~ has no ~time_left~ property";
      6: print "The object ~", (name) p1, "~ cannot be active as a \
                daemon and as a timer at the same time";
      7: print "The object ~", (name) p1, "~ can only be used as a player \
                object if it has the ~number~ property";
      8: print "Attempt to take random entry from an empty table array";
      9: print p1, " is not a valid direction property number";
      10: print "The player-object is outside the object tree";
      11: print "The room ~", (name) p1, "~ has no ~description~ property";
      99: print "Multiple objects not allowed.";
      default: print "(unexplained)";
  }
  " **";
#IFNOT;
  print_ret "*LIBERR ", n, " (", p1, ",", p2, ")*";
#ENDIF;
];

! ----------------------------------------------------------------------------

