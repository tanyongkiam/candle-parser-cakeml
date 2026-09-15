Theory candleParserOracle
Ancestors
  caml_parser
Libs
  preamble mlstringSyntax[qualified]

val _ = use "oracle_support.sml";

val cases = [
  ("empty", ""),
  ("declaration", "let x = 1;;"),
  ("multiple", "let x = 1;; let y = x + 2;;"),
  ("lexical-error", "\\"),
  ("parser-error", "let = ;;"),
  ("trailing-input", "let x = 1;; )"),
  ("cakeml", "(*CML val x = 1; *)"),
  ("cakeml-error", "(*CML val = ; *)"),
  ("numbers", "let x = (0xff,0o17,0b101,1_234L,1.2,1e2);;"),
  ("comments", "(* a (* nested *) comment *)\nlet x = 'a';;"),
  ("unterminated", "let x = \"oops"),
  ("float-location", "let x = 1.2;;\nlet y = 3;;")
];

fun oracle (name,source) = let
  val input = stringSyntax.lift_string bool source;
  val lexed = rhs (concl (EVAL ``caml_lex$lexer_fun ^input``));
  val parsed = rhs (concl (EVAL ``caml_parser$run ^input``));
  val tree = rhs (concl (EVAL
    ``caml_parser$destResult (pegexec$peg_exec camlPEG$camlPEG
        (camlPEG$pnt camlPEG$nStart) ^lexed [] NONE [] pegexec$done pegexec$failed)``));
in
  print ("LEX_GOLDEN " ^ "(" ^ quoted name ^ "," ^ quoted source ^ "," ^ value lexed ^ "),\n");
  print ("TREE_GOLDEN " ^ "(" ^ quoted name ^ "," ^ quoted source ^ "," ^ value tree ^ "),\n");
  print ("PARSE_GOLDEN " ^ "(" ^ quoted name ^ "," ^ quoted source ^ "," ^ value parsed ^ "),\n")
end;
val _ = List.app oracle cases;

val lexer_cases = ListPair.zip
  (List.tabulate (256, fn n => "byte-" ^ Int.toString n),
   List.tabulate (256, fn n => String.str (Char.chr n))) @
  List.map (fn s => ("lex-" ^ s,s)) [
    "0x", "0XFF", "0x_1", "0xG", "0o8", "0o377", "0b2", "0b101n",
    "1_", "1__2", "123l", "123L", "123n", "0xffL", "1e", "1e+", "1e-2",
    "1e2", "1E+2_3", "1.", "1._", "1..2", "1.2e3", "1.2e-3", "0x1.2",
    "\"\\000\\255\\x00\\xff\\o377\"", "\"\\256\"", "\"\\o400\"",
    "\"\\xgg\"", "\"\\q\"", "\"\\\"\\\\\\'\\n\\r\\t\\b\\ \"",
    "'a'", "'\\n'", "'\\xff'", "'\\256'", "'ab'", "'a", "'", "''",
    "(*", "(*)", "(**)", "(* (* *) *)", "*)", "(*\n*)x", "(*\"*)\"*)",
    "(*CML*)", "(*CML val x=1; (*inner*) *)", "(*CML", "(*cml x*)",
    "A A_a A_aA _ __ x' 'a Text_io", "! !! ? ~ ~~ ** += != := :: ; ;; ;;;",
    "let\r\nx=1;;", "\tlet\tx=1;;", "\"a\nb\"x", "#use \"x\";;"
  ];
fun lexer_oracle (name,source) = let
  val input = stringSyntax.lift_string bool source;
  val lexed = rhs (concl (EVAL ``caml_lex$lexer_fun ^input``));
in print ("LEX_GOLDEN (" ^ quoted name ^ "," ^ quoted source ^ "," ^ value lexed ^ "),\n") end;
val _ = List.app lexer_oracle lexer_cases;

(* Layer fixtures use the original PEG and converter. No candidate code is
   loaded. Keep failures and complete-input checks, rather than filtering out
   inputs which the reference rejects. *)
fun layer_oracle tag (nonterm,converter,sources) = let
  val nt = prim_mk_const {Thy="camlPEG",Name=nonterm};
  val conv0 = prim_mk_const {Thy="camlPtreeConversion",Name=converter};
  val conv = if converter = "ptree_Expr" then mk_comb(conv0,nt) else conv0;
  fun one source = let
    val input = stringSyntax.lift_string bool source;
    val parsed = rhs (concl (EVAL
      ``caml_parser$destResult (pegexec$peg_exec camlPEG$camlPEG
          (camlPEG$pnt ^nt) (caml_lex$lexer_fun ^input)
          [] NONE [] pegexec$done pegexec$failed)``));
    val result = rhs (concl (EVAL
      ``case ^parsed of
          peg$Success _ [pt] _ => ^conv pt
        | peg$Failure loc msg => INL (loc,mlstring$implode msg)
        | _ => INL (location$unknown_loc,mlstring$implode "layer: expected one tree")``));
  in print (tag ^ " (" ^ value nt ^ "," ^ quoted converter ^ "," ^
            quoted source ^ "," ^ value result ^ "),\n") end;
in List.app one sources end;

val _ = List.app (layer_oracle "NAME_GOLDEN") [
  ("nIdent","ptree_Ident",["x","X","x'","_","let",""]),
  ("nValueName","ptree_ValueName",["x","foo_bar","(+)","(or)","(!=)","(THEN)","(THENL)","(::)"]),
  ("nConstrName","ptree_ConstrName",["Some","Bad_file_name","Pp_data","Xy_z","lower"]),
  ("nModuleName","ptree_ModuleName",["Text_io","Pretty_printer","Command_line","Word8_array","Other"]),
  ("nModTypeName","ptree_ModTypeName",["S","sig_name"]),
  ("nFieldName","ptree_FieldName",["field","Field"]),
  ("nOperatorName","ptree_OperatorName",["lsl","lsr","asr","**","*","mod","land","lor","lxor","/","+","-","-.","<",">","=","!=","<>","&&","&","||","or","o","F_F","THEN","THENC","THENL","THEN_TCL","ORELSE","ORELSEC","ORELSE_TCL","@","^","!","~+",":=","<-",""])
];
val _ = List.app (layer_oracle "PATH_GOLDEN") [
  ("nValuePath","ptree_ValuePath",["x","Text_io.print","Aa.Bb.(+)","Aa.(or)","Aa.Bb.x","A."]),
  ("nModulePath","ptree_ModulePath",["Aa","Aa.Bb.Cc","Text_io.Command_line","A.lower"]),
  ("nConstr","ptree_Constr",["Some","Bad_file_name","Pretty_printer.Pp_data","A.B.C","A.B.Bad_file_name"]),
  ("nTypeConstr","ptree_TypeConstr",["int","Aa.t","Text_io.t","Aa.Bb.list"]),
  ("nModTypePath","ptree_ModTypePath",["S","Aa.Bb.S","Pretty_printer.S"])
];
val _ = List.app (layer_oracle "TYPE_GOLDEN") [
  ("nType","ptree_Type",["'a","int","Aa.t","'a list","'a list option",
    "('a,'b) pair","('a,int,string) Aa.t","int * bool * string",
    "int -> bool -> string","(int -> bool) -> string","int * bool -> string",
    "('a * 'b) list","((int))","int list option","'a -> 'a list",
    "","int *","int ->","(int,bool)","'","int )"])
];
val _ = List.app (layer_oracle "LITERAL_GOLDEN") [
  ("nLiteral","ptree_Literal",["0","123","0xff","0o17","0b101","123L",
    "'a'","'\\n'","\"a\\000b\"","true","false","1.2",""])
];
val _ = List.app (layer_oracle "PATTERN_GOLDEN") [
  ("nPattern","ptree_Pattern",["_","x","(+) ","0","-1","'a'","\"x\"","true","false",
    "()","[]","[x;y;z]","[x;]","(x,y,z)","x::y::zs","x,y::zs","x::xs,y",
    "Some x","Some (x,y)","Some _","Abs (x,y)","Var _","Const _","Comb (x,y)",
    "Tyapp (x,y)","Sequent (x,y)","Append (x,y)","Pretty_printer.Pp_data (x,y)",
    "Aa.Abs (x,y)","Bad_file_name","x | y","Some (x | y)","(x | y,z | w)",
    "x as y","x as y as z","x::xs as all","x as a :: xs","x | y as z",
    "(x : int)","((x | y) : 'a)","Foo {x;y}","Foo {x;y;}","(Foo {x})",
    "Some (Foo {x})","(Foo {x},y)","","x::","[x","x as","(x :)"])
];

val _ = List.app (layer_oracle "RECORD_GOLDEN") [
  ("nRecord","ptree_Record",["{x:int}","{x:int;}","{z:int;a:bool}",
    "{x:int;x:bool}","{f:'a -> int; g:('a * bool) list}",
    "{}","{mutable x:int}","{x:}","{x:int;;}","{x:int"])
];
val _ = List.app (layer_oracle "CTOR_GOLDEN") [
  ("nConstrDecl","ptree_ConstrDecl",["Foo","Bad_file_name","Pp_data",
    "Some of int","Foo of int * bool","Foo of (int * bool)",
    "Foo of 'a list * ('a -> bool)","Foo of {z:int;a:bool}",
    "Foo of {x:int;}","Foo of {x:int;x:bool}","Foo of","foo","Foo of {}"])
];
val _ = List.app (layer_oracle "TYPEDEFS_GOLDEN") [
  ("nTypeDefs","ptree_TypeDefs",["t","'a t","('a,'b) pair","t = int",
    "'a t = 'a list","('a,'b) t = 'a -> 'b","t = Foo","t = | Foo",
    "t = Foo | Bar of int * bool","t = Foo of {z:int;a:bool}",
    "'a tree = Leaf of 'a | Node of 'a tree * 'a tree",
    "t = Foo and u = Bar of t","t = int and u = bool",
    "t = Foo and u = int","'a t and u","t = Foo of {x:int;x:bool}",
    "t =","t = Foo |","('a,) t","t and",""])
];
val _ = List.app (layer_oracle "EXCEPTION_GOLDEN") [
  ("nExcDefinition","ptree_ExcDefinition",["exception Foo","exception Bad_file_name",
    "exception Foo of int","exception Foo of int * bool * string",
    "exception Foo of (int * bool)","exception Foo of {x:int}",
    "exception Foo = Bar","exception Foo = Aa.Bar","exception","exception Foo of"])
];
val _ = List.app (layer_oracle "UNIT_GOLDEN") [
  ("nExcType","ptree_ExcType",["exception Foo","exception Foo of int * bool",
    "exception Foo of {x:int}","exception Foo = Bar"]),
  ("nValType","ptree_ValType",["val x : int","val (+) : int -> int -> int",
    "val (!=) : int -> bool","val x :","val x = 1"]),
  ("nOpenMod","ptree_OpenMod",["open Text_io","open Aa.Bb","open A","open"]),
  ("nIncludeMod","ptree_IncludeMod",["include Pretty_printer","include Aa.Bb","include"])
];

val cake_cases = ListPair.zip
  (List.tabulate (256, fn n => "cake-byte-" ^ Int.toString n),
   List.tabulate (256, fn n => String.str (Char.chr n))) @
  List.map (fn s => ("cake-" ^ s,s)) [
    "", "val x = 1;", "val x = 1", "val x=1; val y=2", "val x=1; val y=2;",
    "val x = let val y=1; in y end;", "structure Aa = struct val x=1; end;",
    "signature Ss = sig val x:int; end;", "val x = (1;2);", ") ;", "end;",
    "local val x=1; in val y=x; end;", "(*nested (* comment *) *) val x=1;",
    "(*", "*)x;", "(*)", "(*\n*)x;", "val x=1; (*trailing*)",
    "0x 0xff 0xGG", "0w 0wx 0w12 0wxAb 0wfoo", "~1 ~0x12 12_3 1.2",
    "'a '2 ' _ __ _a", "Foo.Bar.x Foo.Bar.+ Foo. Foo.( Foo._",
    "#\"a\" #\"\" #\"ab\"", "\"\\000\\255\\a\\b\\t\\n\\v\\f\\r\"",
    "\"\\256\"x;", "\"\\1\"x;", "\"\\^A\"x;", "\"\\q\"x;", "\"a\nb\"x;",
    "#(foo bar) x;", "#(foo\nbar) x;", "#(unfinished", "#\"\\255\";",
    "and andalso as case datatype else end eqtype exception fn fun handle if in include",
    "let local of op open orelse raise rec sharing sig signature struct structure then type val where while with withtype",
    "# ( ) * , -> ... : :> ; = => [ ] _ { } |", "val\r\nx\t=1;"
  ];
fun cake_oracle (name,source) = let
  val input = stringSyntax.lift_string bool source;
  val tokens = rhs (concl (EVAL ``lexer_fun$lexer_fun ^input``));
in
  print ("CAKELEX_GOLDEN (" ^ quoted name ^ "," ^ quoted source ^ "," ^ value tokens ^ "),\n")
end;
val _ = List.app cake_oracle cake_cases;
val _ = print ("CAKE_CASE_COUNT " ^ Int.toString (List.length cake_cases) ^ "\n");

(* The pragma route unwraps pegexec.Result, NOT caml_parser.destResult:
   success may contain leftovers. Compare them and the retained error exactly. *)
fun cake_grammar_oracle (ntname,sources) =
  List.app (fn source => let
    val nt = prim_mk_const {Thy="gram",Name=ntname};
    val input = stringSyntax.lift_string bool source;
    val tokens = rhs (concl (EVAL ``lexer_fun$lexer_fun ^input``));
    val result = rhs (concl (EVAL
      ``pegexec$destResult (pegexec$peg_exec cmlPEG$cmlPEG
          (cmlPEG$pnt ^nt) ^tokens [] NONE [] pegexec$done pegexec$failed)``));
  in
    print ("CAKEGRAMMAR_GOLDEN (" ^ value nt ^ "," ^ quoted source ^ "," ^
           value result ^ "),\n")
  end) sources;
val cake_grammar_cases = [
  ("nV",["x","!","~","before","Upper",""]),
  ("nTyvarN",["'a",""]),
  ("nFQV",["M.x","M.+","M.C","M._",""]),
  ("nEapp",["f x y","C x",""]),
  ("nElist1",["x,y,z",""]),
  ("nMultOps",["*","div","mod","&",""]),
  ("nAddOps",["+","||",""]),
  ("nRelOps",["=","<>","==",""]),
  ("nListOps",["::",":=",""]),
  ("nCompOps",[":=","o",""]),
  ("nOpID",["M.C","op","*","=","+",""]),
  ("nEliteral",["0wx10","#\"a\"","#(call)","~1","\"abc\"",""]),
  ("nEbase",["()","(x)","(x,y,z)","(x;y)","[]","[x,y]","let open M.N; val x=1 in x;x end","op +",""]),
  ("nEseq",["x;y;z",""]),
  ("nEmult",["a * b div c",""]),
  ("nEadd",["a+b-c",""]),
  ("nElistop",["x::y::zs",""]),
  ("nErel",["a<b=c",""]),
  ("nEcomp",["f o g := h",""]),
  ("nEbefore",["x before y before z",""]),
  ("nEtyped",["x : 'a -> int",""]),
  ("nElogicAND",["a andalso b andalso c",""]),
  ("nElogicOR",["a orelse b andalso c",""]),
  ("nEhandle",["x handle A => 1 | B => 2",""]),
  ("nE",["if x then y else z","fn x => x","raise E","case x of C y => y | _ => 1","if x then y","(x,y","f x + y * z :: zs",""]),
  ("nPEs",["C x => x | D y => y",""]),
  ("nPE",["if x then y else z | C => q","case x of C => 1","fn x => x","raise E","x handle C => 1",""]),
  ("nPEsfx",["handle C => 1","| C => 1",""]),
  ("nAndFDecls",["f x = x and g y = y",""]),
  ("nFDecl",["f x y : int = x",""]),
  ("nPbaseList1",["x (y,z) _",""]),
  ("nType",["'a * bool -> ('a,int) M.pair list","int ->","int *",""]),
  ("nDType",["int list option",""]),
  ("nTbase",["('a,int) pair","(int)","'a","M.t",""]),
  ("nPTbase",["('a -> bool)",""]),
  ("nTypeList2",["int,bool,string",""]),
  ("nTypeList1",["int,bool",""]),
  ("nTbaseList",["int ('a -> bool) 'a",""]),
  ("nTyOp",["M.t","+",""]),
  ("nUQTyOp",["int","+",""]),
  ("nPType",["int * bool * 'a",""]),
  ("nTypeName",["('a,'b) t","'a t","t",""]),
  ("nTyVarList",["'a,'b,'c",""]),
  ("nTypeDec",["datatype 'a t = C 'a | D int bool and u = U t",""]),
  ("nDtypeDecl",["'a t = C 'a | D int bool",""]),
  ("nDconstructor",["C int bool","C of int",""]),
  ("nUQConstructorName",["C","c",""]),
  ("nConstructorName",["M.N.C","C","M.x",""]),
  ("nPbase",["_","~1","\"x\"","#\"x\"","op +","[]","[x,y]",""]),
  ("nPapp",["C x y z","C","x",""]),
  ("nPcons",["x::y::zs",""]),
  ("nPas",["all as x::xs",""]),
  ("nPattern",["all as C x y :: zs : 'a list","C x y","_",""]),
  ("nPatternList",["x,y,z",""]),
  ("nPtuple",["()","(x)","(x,y,z)",""]),
  ("nLetDec",["val x = 1","fun f x = x","open M.N",""]),
  ("nLetDecs",["val x=1; fun f y=y open M.N;",""]),
  ("nDecl",["val x=1","exception E int bool","local val x=1 in val y=x end","open A.type","open A.B",""]),
  ("nTypeAbbrevDec",["type 'a t = 'a list",""]),
  ("nDecls",["datatype t=C; type u=t; exception E; open M.N",""]),
  ("nOptTypEqn",["= int",""]),
  ("nSpecLine",["val x : int","type t","type t = int","exception E int","datatype t=C",""]),
  ("nSpecLineList",["val x:int; type t = int; exception E",""]),
  ("nSignatureValue",["sig val x:int; type t end",""]),
  ("nOptionalSignatureAscription",[":> sig val x:int end",""]),
  ("nStructName",["M","m",""]),
  ("nModPath",["M.N","A.type","type.A","A.B.+","while","A.while","A.before",""]),
  ("nStructure",["structure M :> sig val x:int end = struct val x=1 end",""]),
  ("nTopLevelDecs",["",";","val x=1; val y=2","val x=1 )","val = ;","structure M = struct open A.B; val x=1 end; M.x;","local val x=1 in val y=x end;","(*comment*) val x=1;","1;2;","val x=1 val y=2","val x=1 2;","datatype t=C | D int; val x=C;","val x = let in () end;","val x = if x then y;","\\","val x=1; (*unterminated"]),
  ("nNonETopLevelDecs",["val x=1; 2;",";val x=1","1;",""])
];
val _ = List.app cake_grammar_oracle cake_grammar_cases;
val _ = print ("CAKE_GRAMMAR_CASE_COUNT " ^ Int.toString
  (List.foldl (fn ((_,sources),n) => n + List.length sources) 0 cake_grammar_cases) ^ "\n");

(* Keep values of different reference result types in a test-only tagged sum.
   This does not change the candidate's AST representation or parser API. *)
fun cake_conversion_oracle (ntname,convname,tag,sources) =
  List.app (fn source => let
    val nt = prim_mk_const {Thy="gram",Name=ntname};
    val conv0 = prim_mk_const {Thy="cmlPtreeConversion",Name=convname};
    val conv1 = if convname = "ptree_Type" then mk_comb(conv0,nt) else conv0;
    val conv = inst (Type.match_type (#1 (dom_rng (type_of conv1)))
                    ``:gram$mlptree``) conv1;
    val input = stringSyntax.lift_string bool source;
    val result = rhs (concl (EVAL
      ``case pegexec$destResult (pegexec$peg_exec cmlPEG$cmlPEG
          (cmlPEG$pnt ^nt) (lexer_fun$lexer_fun ^input)
          [] NONE [] pegexec$done pegexec$failed) of
          peg$Success rest [pt] eo => ^conv pt
        | _ => NONE``));
    val output =
      if optionSyntax.is_some result then
        "(Some (CakeConversionTests." ^ tag ^ " " ^ value (optionSyntax.dest_some result) ^ "))"
      else if optionSyntax.is_none result then "None"
      else raise Fail ("unevaluated CakeML conversion: " ^ term_to_string result);
  in print ("CAKECONVERSION_GOLDEN (" ^ value nt ^ "," ^ quoted convname ^ "," ^
            quoted source ^ "," ^ output ^ "),\n")
  end) sources;
val cake_conversion_cases = [
  ("nUQTyOp","ptree_UQTyop","Name",["int","+","","let"]),
  ("nTyvarN","ptree_TyvarN","Name",["'a","'Z","x",""]),
  ("nTyOp","ptree_Tyop","Id",["M.N.t","list","+",""]),
  ("nType","ptree_Type","Typ",["'a","int","M.t","'a list option","('a,'b) M.pair","int * bool * string","int -> bool -> string","(int -> bool) -> string","int * bool -> 'a list","('a * 'b) list","((int))","","int ->","int *","(int,bool)"]),
  ("nDType","ptree_Type","Typ",["int list option","'a","('a,int) pair",""]),
  ("nTbase","ptree_Type","Typ",["int","'a","(int -> bool)","('a,int) M.pair",""]),
  ("nTypeList2","ptree_Typelist2","Types",["int,bool,string","int",""]),
  ("nTypeList1","ptree_TypeList1","Types",["int","int,bool","int,",""]),
  ("nPType","ptree_PType","Types",["int","int * bool * 'a","int *",""]),
  ("nTypeName","ptree_TypeName","TypeName",["t","'a t","('a,'b,'c) t","('a,'a) t","","('a,) t"]),
  ("nUQConstructorName","ptree_UQConstructorName","Name",["C","Bad_file_name","lower",""]),
  ("nConstructorName","ptree_ConstructorName","Id",["C","A.B.C","A.lower",""]),
  ("nPTbase","ptree_PTbase","Typ",["'a","M.t","(int * bool)","(int -> bool)",""]),
  ("nTbaseList","ptree_TbaseList","Types",["","int bool","(int * bool) 'a","int list"]),
  ("nDconstructor","ptree_Dconstructor","Ctor",["C","C int bool","C (int * bool)","C ('a -> bool) 'a","C of int",""]),
  ("nDtypeDecl","ptree_DtypeDecl","Dtype",["t = C","'a t = Nil | Cons 'a ('a t)","t = C int bool | D","t = C | C","","t ="]),
  ("nTypeDec","ptree_TypeDec","Datatype",["datatype t = C","datatype 'a t = Nil | Cons 'a ('a t) and u = U int bool","datatype t = C | C","","datatype"]),
  ("nTypeAbbrevDec","ptree_TypeAbbrevDec","Dec",["type t=int","type 'a t = 'a list","type ('a,'b) t = 'a * 'b","type t =","","type t=int )"]),
  ("nMultOps","ptree_Op","Id",["*","div","mod","%","&",""]),
  ("nAddOps","ptree_Op","Id",["+","-","^","||",""]),
  ("nRelOps","ptree_Op","Id",["=","<>","==","~~",""]),
  ("nListOps","ptree_Op","Id",["@","::",":=",""]),
  ("nCompOps","ptree_Op","Id",[":=","o",""]),
  ("nV","ptree_V","Name",["x","foo'","!","~","before",""]),
  ("nFQV","ptree_FQV","Id",["x","M.x","A.B.+","A.B.C",""]),
  ("nStructName","ptree_StructName","Name",["M","lower","while","","type"]),
  ("nModPath","ptree_ModPath","Path",["A.B.C","lower","A.while","A.type","type.A",""]),
  ("nOptTypEqn","ptree_OptTypEqn","OptType",["","= int","= 'a -> bool","="]),
  ("nSpecLine","ptree_SpecLine","Unit",["val x:int","type t","type 'a t = 'a list","exception E int bool","datatype t = C","val x:",""]),
  ("nSpecLineList","ptree_SpeclineList","Unit",["",";","val x:int; type t; exception E int","val x:"]),
  ("nSignatureValue","ptree_SignatureValue","Unit",["sig end","sig val x:int; type t; datatype u=C; exception E int end","sig type t=int end","sig val x: end",""]),
  ("nEliteral","ptree_Eliteral","Exp",
    ["0","~1","0xff","#\"a\"","#\"\\255\"","\"a\\000b\"","0w0","0w1","0wxFFFFFFFFFFFFFFFF","0w18446744073709551616","0wx10000000000000001","#(foo bar)","#(unfinished",""])
];
val _ = List.app cake_conversion_oracle cake_conversion_cases;
val _ = print ("CAKE_CONVERSION_CASE_COUNT " ^ Int.toString
  (List.foldl (fn ((_,_,_,sources),n) => n + List.length sources) 0 cake_conversion_cases) ^ "\n");

(* Golden comparisons retain all constructor-valued arguments and results.
   Generated closures call only the named candidate helper, never the oracle. *)
fun helper_oracle tag module_name (name,call) = let
  val (head,args) = strip_comb call;
  val {Name,...} = dest_thy_const head;
  val cname = case Name of "Papply" => "papply" | "Eseq_encode" => "eseq_encode"
    | "MAP_OUTR" => "map_outr" | _ => Name;
  val actual = module_name ^ cname ^ " " ^ join " "
    (map (fn t => value (rhs (concl (EVAL t)))) args);
  val expected = value (rhs (concl (EVAL call)));
in
  print (tag ^ "_GOLDEN (" ^ quoted name ^ ",(fn _ => (" ^ actual ^ ") = " ^
         expected ^ ")),\n")
end;
val cake_helper_cases = [
  ("seq-empty",``cmlPtreeConversion$Eseq_encode ([]:ast$exp list)``),
  ("seq-one",``cmlPtreeConversion$Eseq_encode [(ast$Lit (ast$IntLit 1))]``),
  ("seq-three",``cmlPtreeConversion$Eseq_encode [(ast$Lit (ast$IntLit 1));(ast$Lit (ast$IntLit 2));(ast$Lit (ast$IntLit 3))]``),
  ("strip-plain",``cmlPtreeConversion$strip_loc_expr (ast$Lit (ast$IntLit 1))``),
  ("strip-one",``cmlPtreeConversion$strip_loc_expr (ast$Lannot (ast$Lit (ast$IntLit 1)) (location$Locs (location$POSN 1 2) (location$POSN 1 5)))``),
  ("strip-nested",``cmlPtreeConversion$strip_loc_expr (ast$Lannot (ast$Lannot (ast$Lit (ast$IntLit 1)) (location$Locs (location$POSN 1 2) (location$POSN 1 5))) (location$Locs (location$POSN 2 3) (location$POSN 2 8)))``),
  ("merge-none",``cmlPtreeConversion$merge_locsopt NONE (SOME (location$Locs (location$POSN 1 2) (location$POSN 1 5)))``),
  ("merge-some",``cmlPtreeConversion$merge_locsopt (SOME (location$Locs (location$POSN 1 2) (location$POSN 1 5))) (SOME (location$Locs (location$POSN 2 3) (location$POSN 2 8)))``),
  ("annot-none",``cmlPtreeConversion$optLannot NONE (ast$Lannot (ast$Lit (ast$IntLit 1)) (location$Locs (location$POSN 1 2) (location$POSN 1 5)))``),
  ("annot-some",``cmlPtreeConversion$optLannot (SOME (location$Locs (location$POSN 2 3) (location$POSN 2 8))) (ast$Lannot (ast$Lit (ast$IntLit 1)) (location$Locs (location$POSN 1 2) (location$POSN 1 5)))``),
  ("bind-existing",``cmlPtreeConversion$bind_loc (ast$Lannot (ast$Lit (ast$IntLit 1)) (location$Locs (location$POSN 1 2) (location$POSN 1 5))) (location$Locs (location$POSN 2 3) (location$POSN 2 8))``),
  ("bind-new",``cmlPtreeConversion$bind_loc (ast$Lit (ast$IntLit 1)) (location$Locs (location$POSN 1 2) (location$POSN 1 5))``),
  ("apply-ref",``cmlPtreeConversion$mkAst_App (ast$Con (SOME (namespace$Short «Ref»)) []) (ast$Lannot (ast$Lit (ast$IntLit 2)) (location$Locs (location$POSN 2 3) (location$POSN 2 8)))``),
  ("apply-annot-ref",``cmlPtreeConversion$mkAst_App (ast$Lannot (ast$Con (SOME (namespace$Short «Ref»)) []) (location$Locs (location$POSN 1 2) (location$POSN 1 5))) (ast$Lannot (ast$Lit (ast$IntLit 2)) (location$Locs (location$POSN 2 3) (location$POSN 2 8)))``),
  ("apply-ref-with-arg",``cmlPtreeConversion$mkAst_App (ast$Con (SOME (namespace$Short «Ref»)) [(ast$Lit (ast$IntLit 1))]) (ast$Lannot (ast$Lit (ast$IntLit 2)) (location$Locs (location$POSN 2 3) (location$POSN 2 8)))``),
  ("apply-con-plain",``cmlPtreeConversion$mkAst_App (ast$Con (SOME (namespace$Short «C»)) []) (ast$Lit (ast$IntLit 1))``),
  ("apply-con-both-located",``cmlPtreeConversion$mkAst_App (ast$Lannot (ast$Con (SOME (namespace$Short «C»)) []) (location$Locs (location$POSN 1 2) (location$POSN 1 5))) (ast$Lannot (ast$Lit (ast$IntLit 2)) (location$Locs (location$POSN 2 3) (location$POSN 2 8)))``),
  ("apply-con-one-located",``cmlPtreeConversion$mkAst_App (ast$Con (SOME (namespace$Short «C»)) []) (ast$Lannot (ast$Lit (ast$IntLit 2)) (location$Locs (location$POSN 2 3) (location$POSN 2 8)))``),
  ("apply-tuple",``cmlPtreeConversion$mkAst_App (ast$Con NONE [(ast$Lit (ast$IntLit 1))]) (ast$Lannot (ast$Lit (ast$IntLit 2)) (location$Locs (location$POSN 2 3) (location$POSN 2 8)))``),
  ("apply-ffi",``cmlPtreeConversion$mkAst_App (ast$App (ast$FFI «foo») [(ast$Lit (ast$IntLit 1))]) (ast$Lannot (ast$Lit (ast$IntLit 2)) (location$Locs (location$POSN 2 3) (location$POSN 2 8)))``),
  ("apply-located-ffi",``cmlPtreeConversion$mkAst_App (ast$Lannot (ast$App (ast$FFI «foo») []) (location$Locs (location$POSN 1 2) (location$POSN 1 5))) (ast$Lannot (ast$Lit (ast$IntLit 2)) (location$Locs (location$POSN 2 3) (location$POSN 2 8)))``),
  ("apply-ordinary",``cmlPtreeConversion$mkAst_App (ast$Lannot (ast$Lit (ast$IntLit 1)) (location$Locs (location$POSN 1 2) (location$POSN 1 5))) (ast$Lannot (ast$Lit (ast$IntLit 2)) (location$Locs (location$POSN 2 3) (location$POSN 2 8)))``),
  ("apply-nonffi-app",``cmlPtreeConversion$mkAst_App (ast$App ast$Opref [(ast$Lit (ast$IntLit 1))]) (ast$Lit (ast$IntLit 2))``),
  ("let-any",``cmlPtreeConversion$letFromPat ast$Pany (ast$Lit (ast$IntLit 1)) (ast$Lit (ast$IntLit 2))``),
  ("let-var-pattern",``cmlPtreeConversion$letFromPat (ast$Pvar «x») (ast$Lit (ast$IntLit 1)) (ast$Lit (ast$IntLit 2))``),
  ("let-con-pattern",``cmlPtreeConversion$letFromPat (ast$Pcon (SOME (namespace$Short «C»)) []) (ast$Lit (ast$IntLit 1)) (ast$Lit (ast$IntLit 2))``),
  ("pat-apply-con",``cmlPtreeConversion$Papply (ast$Pcon (SOME (namespace$Short «C»)) []) (ast$Pvar «x»)``),
  ("pat-apply-other",``cmlPtreeConversion$Papply (ast$Pvar «x») ast$Pany``),
  ("pat-ref",``cmlPtreeConversion$maybe_handleRef (ast$Pcon (SOME (namespace$Short «Ref»)) [(ast$Pvar «x»)])``),
  ("pat-ref-wrong-arity",``cmlPtreeConversion$maybe_handleRef (ast$Pcon (SOME (namespace$Short «Ref»)) [])``),
  ("pat-qualified-ref",``cmlPtreeConversion$maybe_handleRef (ast$Pcon (SOME (namespace$Long «M» (namespace$Short «Ref»))) [(ast$Pvar «x»)])``),
  ("ffi-op",``cmlPtreeConversion$destFFIop (ast$FFI «foo»)``),
  ("nonffi-op",``cmlPtreeConversion$destFFIop ast$Opref``),
  ("constructor-",``cmlPtreeConversion$isConstructor ""``),
  ("symbolic-",``cmlPtreeConversion$isSymbolicConstructor ""``),
  ("constructor-::",``cmlPtreeConversion$isConstructor "::"``),
  ("symbolic-::",``cmlPtreeConversion$isSymbolicConstructor "::"``),
  ("constructor-C",``cmlPtreeConversion$isConstructor "C"``),
  ("symbolic-C",``cmlPtreeConversion$isSymbolicConstructor "C"``),
  ("constructor-lower",``cmlPtreeConversion$isConstructor "lower"``),
  ("symbolic-lower",``cmlPtreeConversion$isSymbolicConstructor "lower"``),
  ("constructor-+",``cmlPtreeConversion$isConstructor "+"``),
  ("symbolic-+",``cmlPtreeConversion$isSymbolicConstructor "+"``),
  ("constructor-Ref",``cmlPtreeConversion$isConstructor "Ref"``),
  ("symbolic-Ref",``cmlPtreeConversion$isSymbolicConstructor "Ref"``)
];
val _ = List.app (helper_oracle "CAKEHELPER" "CakeExpressionSupport.") cake_helper_cases;
val _ = print ("CAKE_HELPER_CASE_COUNT " ^ Int.toString (List.length cake_helper_cases) ^ "\n");

val record_prep_sources = [
  "t = int", "t = int and u = bool", "t", "t = Foo", "t = Foo of int * bool | Bar",
  "t = Foo of {z:int;a:bool;m:string}",
  "t = Foo of {x:int;x:bool}",
  "t = Foo of {z:int;a:bool} and u = Bar of {y:string;b:int}",
  "t = int and u = Foo of {b:bool;a:int}",
  "t = Foo of {x:int;xx:bool;x:string}"
];
val record_prep_count = ref 0;
fun record_prep_oracle source = let
  val input = stringSyntax.lift_string bool source;
  val metadata = rhs (concl (EVAL
    ``case caml_parser$destResult (pegexec$peg_exec camlPEG$camlPEG
          (camlPEG$pnt camlPEG$nTypeDefs) (caml_lex$lexer_fun ^input)
          [] NONE [] pegexec$done pegexec$failed) of
        peg$Success rest [pt] eo => camlPtreeConversion$ptree_TypeDefs pt
      | _ => INL (location$unknown_loc,«unexpected fixture syntax»)``));
  val tdefs = #1 (sumSyntax.dest_inr metadata);
  fun one suffix call =
    (record_prep_count := !record_prep_count + 1;
     helper_oracle "RECORDPREP" "CandleTypeDeclarations." (source ^ "/" ^ suffix,call));
  val split = rhs (concl (EVAL ``camlPtreeConversion$partition_types ^tdefs``));
  val datas = #1 (listSyntax.dest_list (#2 (pairSyntax.dest_pair split)));
  fun data_one data = let
    val sorted = rhs (concl (EVAL ``camlPtreeConversion$sort_records ^data``));
  in
    one "sort" ``camlPtreeConversion$sort_records ^data``;
    one "extract" ``camlPtreeConversion$extract_record_defns ^sorted``;
    one "strip" ``camlPtreeConversion$strip_record_fields ^sorted``
  end;
in
  one "partition" ``camlPtreeConversion$partition_types ^tdefs``;
  List.app data_one datas
end;
val _ = List.app record_prep_oracle record_prep_sources;
val _ = print ("RECORD_PREP_CASE_COUNT " ^ Int.toString (!record_prep_count) ^ "\n");

(* Deferred until the user supplies a usable Ast.Ident and expression conversion
   is implemented. These results are generated now but NOT in the passing suite.
   Preserve source inputs, including SML string gaps, from active camlTests calls. *)
val deferred_expression_cases = [
  (* camlTestsScript.sml:195 *)
  ("nExpr","ptree_Expr",["raise (Fail \"5\")"]),
  (* camlTestsScript.sml:200 *)
  ("nExpr","ptree_Expr",["raise (f x)"]),
  (* camlTestsScript.sml:468 *)
  ("nExpr","ptree_Expr",["x.Cons.foo"]),
  (* camlTestsScript.sml:474 *)
  ("nExpr","ptree_Expr",["Foo {x with foo = bar}"]),
  (* camlTestsScript.sml:481 *)
  ("nExpr","ptree_Expr",["Foo {x with foo = bar;}"]),
  (* camlTestsScript.sml:488 *)
  ("nExpr","ptree_Expr",["Foo {x with foo = bar; baz = quux;}"]),
  (* camlTestsScript.sml:495 *)
  ("nExpr","ptree_Expr",["Bar.Foo {x with foo = bar; baz = quux;}"]),
  (* camlTestsScript.sml:506 *)
  ("nExpr","ptree_Expr",["Foo { foo = 5; bar = true }"]),
  (* camlTestsScript.sml:514 *)
  ("nExpr","ptree_Expr",["Foo { f2 = 2; f1 = 1; f3 = 3;}"]),
  (* camlTestsScript.sml:519 *)
  ("nExpr","ptree_Expr",["Bar.Foo { f2 = 2; f1 = 1; f3 = 3;}"]),
  (* camlTestsScript.sml:584 *)
  ("nExpr","ptree_Expr",["true || let y = z in y"]),
  (* camlTestsScript.sml:589 *)
  ("nExpr","ptree_Expr",["let y = z in y || true"]),
  (* camlTestsScript.sml:594 *)
  ("nExpr","ptree_Expr",["0 + match x with y -> z"]),
  (* camlTestsScript.sml:601 *)
  ("nExpr","ptree_Expr",["- fun x -> x"]),
  (* camlTestsScript.sml:606 *)
  ("nENeg","ptree_Expr",[" - let y = z in y"]),
  (* camlTestsScript.sml:612 *)
  ("nExpr","ptree_Expr",["a, [], fun x -> ()"]),
  (* camlTestsScript.sml:617 *)
  ("nExpr","ptree_Expr",["a, match x with y -> z, w"]),
  (* camlTestsScript.sml:624 *)
  ("nExpr","ptree_Expr",["match x with y -> z, w"]),
  (* camlTestsScript.sml:630 *)
  ("nExpr","ptree_Expr",["match !myref () with a -> b"]),
  (* camlTestsScript.sml:637 *)
  ("nExpr","ptree_Expr",["f !myref"]),
  (* camlTestsScript.sml:642 *)
  ("nExpr","ptree_Expr",["x && y"]),
  (* camlTestsScript.sml:647 *)
  ("nExpr","ptree_Expr",["x || y"]),
  (* camlTestsScript.sml:652 *)
  ("nExpr","ptree_Expr",["if x || y then x && y"]),
  (* camlTestsScript.sml:659 *)
  ("nExpr","ptree_Expr",["(n-1)"]),
  (* camlTestsScript.sml:664 *)
  ("nExpr","ptree_Expr",["(n -1)"]),
  (* camlTestsScript.sml:669 *)
  ("nExpr","ptree_Expr",["-1"]),
  (* camlTestsScript.sml:674 *)
  ("nExpr","ptree_Expr",["(+) ; 2"]),
  (* camlTestsScript.sml:679 *)
  ("nExpr","ptree_Expr",["function x -> y ; function a -> b"]),
  (* camlTestsScript.sml:709 *)
  ("nExpr","ptree_Expr",["if x;y then  z"]),
  (* camlTestsScript.sml:714 *)
  ("nExpr","ptree_Expr",["if y then z; w"]),
  (* camlTestsScript.sml:719 *)
  ("nExpr","ptree_Expr",["fun x -> y ; z"]),
  (* camlTestsScript.sml:724 *)
  ("nExpr","ptree_Expr",["(fun x -> y) ; z"]),
  (* camlTestsScript.sml:729 *)
  ("nExpr","ptree_Expr",["[let x = a in x; let y = b in y]"]),
  (* camlTestsScript.sml:738 *)
  ("nExpr","ptree_Expr",["match x with \
  \ | a -> f; c \
  \ | b -> q; w"]),
  (* camlTestsScript.sml:749 *)
  ("nExpr","ptree_Expr",["if b then let x = z in a; b"]),
  (* camlTestsScript.sml:759 *)
  ("nExpr","ptree_Expr",["foo; if b then print (); bar"]),
  (* camlTestsScript.sml:768 *)
  ("nExpr","ptree_Expr",["foo; let x = z in y ; bar"]),
  (* camlTestsScript.sml:776 *)
  ("nExpr","ptree_Expr",["let (:=) x = z in w"]),
  (* camlTestsScript.sml:781 *)
  ("nExpr","ptree_Expr",["(:=)"]),
  (* camlTestsScript.sml:786 *)
  ("nExpr","ptree_Expr",["let _ = Ref x in z"]),
  (* camlTestsScript.sml:821 *)
  ("nExpr","ptree_Expr",["let [x; y] = z in w"]),
  (* camlTestsScript.sml:828 *)
  ("nExpr","ptree_Expr",["let a x = y and b x = z in w"]),
  (* camlTestsScript.sml:834 *)
  ("nExpr","ptree_Expr",["let f x y = x in z"]),
  (* camlTestsScript.sml:839 *)
  ("nExpr","ptree_Expr",["let f (x,y) = x in z"]),
  (* camlTestsScript.sml:845 *)
  ("nExpr","ptree_Expr",["let f x = x in y"]),
  (* camlTestsScript.sml:850 *)
  ("nExpr","ptree_Expr",["let rec f x = x in y"]),
  (* camlTestsScript.sml:855 *)
  ("nExpr","ptree_Expr",["let rec f x y = x in z"]),
  (* camlTestsScript.sml:860 *)
  ("nExpr","ptree_Expr",["let _ = print \"foo\" in\
  \  let z = 10 in\
  \  let (x,y) = g z in\
  \  let rec h x = x + 1 in\
  \  x + y"]),
  (* camlTestsScript.sml:875 *)
  ("nExpr","ptree_Expr",["let (x,y) = g z in\
  \  let [h] = f a in\
  \  x + y * h"]),
  (* camlTestsScript.sml:887 *)
  ("nExpr","ptree_Expr",["fun x -> x"]),
  (* camlTestsScript.sml:892 *)
  ("nExpr","ptree_Expr",["fun (x, y) -> x + y"]),
  (* camlTestsScript.sml:899 *)
  ("nExpr","ptree_Expr",["fun x y z -> y"]),
  (* camlTestsScript.sml:904 *)
  ("nExpr","ptree_Expr",["fun z (x, y) w -> x + y"]),
  (* camlTestsScript.sml:911 *)
  ("nExpr","ptree_Expr",["(x : int)"]),
  (* camlTestsScript.sml:916 *)
  ("nExpr","ptree_Expr",["(x : int) + 3"]),
  (* camlTestsScript.sml:922 *)
  ("nExpr","ptree_Expr",["(=)"]),
  (* camlTestsScript.sml:927 *)
  ("nExpr","ptree_Expr",["(THEN)"]),
  (* camlTestsScript.sml:932 *)
  ("nExpr","ptree_Expr",["(mod)"]),
  (* camlTestsScript.sml:946 *)
  ("nExpr","ptree_Expr",["f (+) 10"]),
  (* camlTestsScript.sml:951 *)
  ("nExpr","ptree_Expr",["(+) 10 11"]),
  (* camlTestsScript.sml:956 *)
  ("nExpr","ptree_Expr",["(THEN) t1 t2"]),
  (* camlTestsScript.sml:961 *)
  ("nExpr","ptree_Expr",["t1 THEN t2"]),
  (* camlTestsScript.sml:966 *)
  ("nExpr","ptree_Expr",["t1 * t2"]),
  (* camlTestsScript.sml:971 *)
  ("nExpr","ptree_Expr",["()"]),
  (* camlTestsScript.sml:976 *)
  ("nExpr","ptree_Expr",["begin end"]),
  (* camlTestsScript.sml:981 *)
  ("nExpr","ptree_Expr",["Some begin end"]),
  (* camlTestsScript.sml:986 *)
  ("nExpr","ptree_Expr",[" match x with\
  \ | [] -> 3\
  \ | [e;_] -> e"]),
  (* camlTestsScript.sml:997 *)
  ("nExpr","ptree_Expr",[" match x with\
  \ | Some 3 | Some 4 -> e\
  \ | _ -> d"]),
  (* camlTestsScript.sml:1008 *)
  ("nExpr","ptree_Expr",[" match x with \
  \ | [] -> 3\
  \ | [] :: _ -> 1\
  \ | (h::t) :: rest -> 2"]),
  (* camlTestsScript.sml:1028 *)
  ("nExpr","ptree_Expr",["match x with \n\
  \| h::t when P -> z \n\
  \| [] -> z \n\
  \| _ -> w"]),
  (* camlTestsScript.sml:1043 *)
  ("nExpr","ptree_Expr",["match x with \n\
  \| r1 when x1 -> y1\n\
  \| r2 -> y2\n\
  \| r3 when x3 -> y3\n\
  \| r4 -> y4\n"]),
  (* camlTestsScript.sml:1064 *)
  ("nExpr","ptree_Expr",[" try f x with Ea _ -> g x\
  \            | Eb -> h"]),
  (* camlTestsScript.sml:1074 *)
  ("nExpr","ptree_Expr",["try f ()\n\
  \with Bar when P -> X"]),
  (* camlTestsScript.sml:1088 *)
  ("nExpr","ptree_Expr",[" function Ca _ -> A\
  \        | Cb -> B"]),
  (* camlTestsScript.sml:1096 *)
  ("nExpr","ptree_Expr",["[3;4]"]),
  (* camlTestsScript.sml:1101 *)
  ("nExpr","ptree_Expr",["[ ]"]),
  (* camlTestsScript.sml:1106 *)
  ("nExpr","ptree_Expr",["3::t = l"]),
  (* camlTestsScript.sml:1113 *)
  ("nExpr","ptree_Expr",["3 < x = true"]),
  (* camlTestsScript.sml:1120 *)
  ("nExpr","ptree_Expr",["(x,y,4)"]),
  (* camlTestsScript.sml:1125 *)
  ("nExpr","ptree_Expr",["Cons (x,3)"]),
  (* camlTestsScript.sml:1130 *)
  ("nExpr","ptree_Expr",["FUNCTION (x,3)"]),
  (* camlTestsScript.sml:1135 *)
  ("nExpr","ptree_Expr",["- 3"]),
  (* camlTestsScript.sml:1142 *)
  ("nExpr","ptree_Expr",["if a then b"]),
  (* camlTestsScript.sml:1147 *)
  ("nExpr","ptree_Expr",["if a;c then b"]),
  (* camlTestsScript.sml:1152 *)
  ("nExpr","ptree_Expr",["Con (a,b,c)"]),
  (* camlTestsScript.sml:1162 *)
  ("nExpr","ptree_Expr",["print \"hello\nworld\""]),
  (* camlTestsScript.sml:1430 *)
  ("nExpr","ptree_Expr",["Pretty_printer.token"]),
  (* camlTestsScript.sml:1434 *)
  ("nExpr","ptree_Expr",["Pretty_printer.Text_io.stuff"]),
  (* camlTestsScript.sml:1438 *)
  ("nExpr","ptree_Expr",["Comb (x, y)"]),
  (* camlTestsScript.sml:1443 *)
  ("nExpr","ptree_Expr",["Abs (x, y)"]),
  (* camlTestsScript.sml:1448 *)
  ("nExpr","ptree_Expr",["Var (x, y)"]),
  (* camlTestsScript.sml:1453 *)
  ("nExpr","ptree_Expr",["Sequent (x, y)"]),
  (* camlTestsScript.sml:1458 *)
  ("nExpr","ptree_Expr",["Const (x, y)"]),
  (* camlTestsScript.sml:1463 *)
  ("nExpr","ptree_Expr",["Pretty_printer.Pp_data (x, y)"]),
  (* camlTestsScript.sml:1468 *)
  ("nExpr","ptree_Expr",["Comb (Var (v, s), Const (w, t))"]),
  (* camlTestsScript.sml:1484 *)
  ("nExpr","ptree_Expr",["Append (Append (v, s), Append (w, t))"]),
  (* camlTestsScript.sml:1538 *)
  ("nExpr","ptree_Expr",["!s.[c]"]),
  (* camlTestsScript.sml:1545 *)
  ("nExpr","ptree_Expr",["-  a.( i) + 3"]),
  (* camlTestsScript.sml:1587 *)
  ("nExpr","ptree_Expr",["-1"]),
  (* camlTestsScript.sml:1596 *)
  ("nExpr","ptree_Expr",["a . ( i)"]),
  (* camlTestsScript.sml:1602 *)
  ("nExpr","ptree_Expr",["Double.(-)"]),
  (* camlTestsScript.sml:1634 *)
  ("nExpr","ptree_Expr",["fun x,y -> z"]),
  (* Additional variable-bearing, control-flow and malformed-input cases. *)
  ("nExpr","ptree_Expr",[
    "x",
    "Aa.Bb.x",
    "Aa.(+)",
    "assert x",
    "lazy x",
    "while p do f x done",
    "for i = lo to hi do f i done",
    "for i = hi downto lo do f i done",
    "fun (Foo {x;y}) -> x",
    "let Foo {x;y} = r in x",
    "function Foo {x;y} when p x -> y | _ -> z",
    "match x with Foo {a;b} when p -> a | _ -> b",
    "if x then (a,b) else (c,d)",
    "if x then a,b else c,d",
    "x lsl y + z",
    "x ** y ** z",
    "x @ y ^ z",
    "r := x; y",
    "let rec f = function x -> f x in f",
    "let rec f (x,y) = f (x,y) in f",
    "",
    "x )",
    "fun -> x",
    "let x = in y",
    "match x with",
    "try x with",
    "if x then",
    "while x do",
    "for i = x to y do",
    "Foo {x =}",
    "a.(",
    "x <- y"
  ])
];
val _ = List.app (layer_oracle "EXPR_GOLDEN") deferred_expression_cases;
val _ = print ("DEFERRED_EXPR_CASE_COUNT " ^ Int.toString
  (List.foldl (fn ((_,_,sources),n) => n + List.length sources) 0 deferred_expression_cases) ^ "\n");

(* Deferred declaration and public-parser vectors. The inherited cases retain
   the original converter entry point; Definition inputs additionally get a
   final ;; for the separately evaluated public-parser wrapper. *)
val deferred_declaration_cases = [
  ("camlTests:205","nStart","ptree_Start","let x = 2 ;; (*CML val x = 5; print \"z\"; fun ref x = Ref x; *)"),
  ("camlTests:213","nStart","ptree_Start","(*CML val x = x; (*CML comments and pragmas are skipped *) val y = y;*)"),
  ("camlTests:220","nStart","ptree_Start","let x = (*CML val x = x; *) 6;;"),
  ("camlTests:526","nStart","ptree_Start","type rec1 = Foo of {f3: t3; f1: t1; f2: t2};;"),
  ("camlTests:531","nStart","ptree_Start","type rec1 = Foo of {foo: int; bar: bool};;"),
  ("camlTests:564","nStart","ptree_Start","let f d (Foo {c; a}) b = z;;"),
  ("camlTests:568","nStart","ptree_Start","match y with\
  \  Foo {z} -> f z;;"),
  ("camlTests:574","nStart","ptree_Start","match y with\
  \  Bar.Foo {z} -> f z;;"),
  ("camlTests:687","nDefinition","ptree_Definition"," let print_stdout printer data =\
  \   let st = empty () in\
  \   printer st data;\
  \   let tok = to_token st in\
  \   let apps = Pretty_core.print (!margin) tok in\
  \   App_list.iter (output_string stdout) apps"),
  ("camlTests:1170","nDefinition","ptree_Definition"," let v = A\
  \ and c = B"),
  ("camlTests:1177","nDefinition","ptree_Definition"," let rec f x = A\
  \ and g y = B"),
  ("camlTests:1184","nDefinition","ptree_Definition","type t = s"),
  ("camlTests:1189","nDefinition","ptree_Definition","type ('a, 'b) t = Cn of 'a * 'b"),
  ("camlTests:1194","nDefinition","ptree_Definition","type ('a, 'b) t = Cn of ('a)"),
  ("camlTests:1199","nDefinition","ptree_Definition"," type t = Ca\
  \        | Cb\
  \ and s = Dd of t"),
  ("camlTests:1207","nDefinition","ptree_Definition","exception This of 'a * 'b"),
  ("camlTests:1212","nDefinition","ptree_Definition","exception This of 'a"),
  ("camlTests:1217","nDefinition","ptree_Definition","type 'a tree = Lf1 | Nd of 'a tree * 'a * 'a tree | Lf2 of int"),
  ("camlTests:1230","nDefinition","ptree_Definition"," module Queue = struct\
  \   type 'a queue = 'a list * 'a list\
  \   ;;\
  \   let enqueue (xs, ys) y = (xs, y::ys)\
  \   ;;\
  \   let rec dequeue (xs, ys) =\
  \     match xs with\
  \     | x::xs -> Some (x, (xs, ys))\
  \     | [] ->\
  \         (match ys with\
  \         | [] -> None\
  \         | _ -> dequeue (List.rev ys, []))\
  \   ;;\
  \   let empty = ([], [])\
  \   ;;\
  \   let flush (xs, ys) = xs @ List.rev ys\
  \   ;;\
  \ end (* struct *)"),
  ("camlTests:1252","nDefinition","ptree_Definition"," module Buffer = struct\
  \   type 'a buffer = 'a Queue.queue ref\
  \   ;;\
  \   let enqueue q x = q := Queue.enqueue (!q) x\
  \   ;;\
  \   let dequeue q =\
  \     match Queue.dequeue (!q) with\
  \     | None -> None\
  \     | Some (x, q') ->\
  \         q := q';\
  \         Some x\
  \   ;;\
  \   let empty () = ref Queue.empty\
  \   ;;\
  \   let flush q =\
  \     let els = Queue.flush (!q) in\
  \     q := Queue.empty;\
  \     els\
  \   ;;\
  \ end (* struct *)"),
  ("camlTests:1280","nDefinition","ptree_Definition","type ('a,'b) t"),
  ("camlTests:1285","nDefinition","ptree_Definition","type tyname"),
  ("camlTests:1290","nDefinition","ptree_Definition","type ('a,'b) t = B1a | A1b"),
  ("camlTests:1295","nDefinition","ptree_Definition","type t = Ba1 | Ab1"),
  ("camlTests:1300","nDefinition","ptree_Definition","type t = z"),
  ("camlTests:1330","nDefinition","ptree_Definition"," module type SIGNAME = sig \
  \   val x : t \
  \   val y : d \
  \ end"),
  ("camlTests:1338","nDefinition","ptree_Definition"," module type Sig_Name3 = sig \
  \   type t = foo \
  \   val x : t \
  \   val y : d \
  \ end"),
  ("camlTests:1347","nDefinition","ptree_Definition"," module type Sig_Name3 = sig \
  \   type 'a t \
  \ end"),
  ("camlTests:1354","nDefinition","ptree_Definition","module Mod : Ssig = struct end"),
  ("camlTests:1359","nDefinition","ptree_Definition","module type sign = sig end"),
  ("camlTests:1496","nStart","ptree_Start","let x = 2 ;; (*CML val x = 5; print \"z\"; fun ref x = Ref x; *)"),
  ("camlTests:1516","nStart","ptree_Start","let x : int = 2 ;;"),
  ("camlTests:1521","nStart","ptree_Start","let _ = let x : int = 2 in x;;"),
  ("camlTests:1528","nStart","ptree_Start","let (x : int) = 2 ;;"),
  ("camlTests:1561","nStart","ptree_Start","let rec f : t = e ;;"),
  ("camlTests:1572","nStart","ptree_Start","let rec f = e\
  \ and g = 3;;"),
  ("camlTests:1618","nStart","ptree_Start","let f (Some x) = y"),
  ("camlTests:1626","nStart","ptree_Start","let f Some x = y"),
  ("camlTests:1641","nStart","ptree_Start","let f x,y = z"),
  ("camlTests:1647","nStart","ptree_Start","let x,y = z"),
  ("abbreviation-order","nStart","ptree_Start","type t = int and u = bool;;"),
  ("mixed-type-group","nStart","ptree_Start","type t = int and u = Foo;;"),
  ("record-duplicate","nStart","ptree_Start","type t = Foo of {x:int;x:bool};;"),
  ("record-sorted","nStart","ptree_Start","type t = Foo of {z:int;a:bool;m:string};;"),
  ("record-mutual","nStart","ptree_Start","type t = Foo of {z:int;a:bool} and u = Bar of {y:string;b:int};;"),
  ("type-nonrec","nStart","ptree_Start","type nonrec t = int;;"),
  ("record-binding","nStart","ptree_Start","let Foo {x;y} = r;;"),
  ("recursive-pattern","nStart","ptree_Start","let rec f (x,y) = f (x,y) and g z = f z;;"),
  ("module-variables","nStart","ptree_Start","module Aa = struct let x = y;; let f z = x + z;; end;;"),
  ("open-path","nStart","ptree_Start","open Aa.Bb;;"),
  ("include-path","nStart","ptree_Start","include Aa.Bb;;"),
  ("module-functor","nStart","ptree_Start","module Aa (Bb : Ss) = struct end;;"),
  ("mixed-cml","nStart","ptree_Start","let x = y;; (*CML val z = x; *) let f a = z;;"),
  ("cml-function","nStart","ptree_Start","(*CML fun f (x,y) = x; val z = f (1,2); *)"),
  ("cml-open","nStart","ptree_Start","(*CML structure M = struct val x=1 end; open M; val y=x; *)"),
  ("cml-let-open","nStart","ptree_Start","(*CML val x = let open M.N in y end; *)"),
  ("cml-pattern","nStart","ptree_Start","(*CML val Ref x = y; val (a::b) = zs; *)"),
  ("cml-signature","nStart","ptree_Start","(*CML structure M :> sig val x:int end = struct val x=y end; *)"),
  ("cml-tail","nStart","ptree_Start","(*CML val x=y; ) *)"),
  ("cml-invalid-declaration","nStart","ptree_Start","(*CML val = ; *)"),
  ("cml-lexical-error","nStart","ptree_Start","(*CML val x = \"\\q\"; *)"),
  ("cml-nested-comment","nStart","ptree_Start","(*CML (*a (*b*) c*) val x=y; *)"),
  ("trailing-junk","nStart","ptree_Start","let x = y;; )"),
  ("missing-binding","nStart","ptree_Start","let f x = ;;")
];
fun public_oracle (name,source) = let
  val input = stringSyntax.lift_string bool source;
  val result = rhs (concl (EVAL ``caml_parser$run ^input``));
in print ("PARSE_GOLDEN (" ^ quoted name ^ "," ^ quoted source ^ "," ^
          value result ^ "),\n") end;
val _ = List.app (fn (name,nt,conv,source) =>
  layer_oracle "DECL_GOLDEN" (nt,conv,[source])) deferred_declaration_cases;
val _ = List.app (fn (name,nt,conv,source) =>
  public_oracle (name,if nt = "nDefinition" then source ^ ";;" else source))
  deferred_declaration_cases;
val _ = print ("DEFERRED_DECL_CASE_COUNT " ^ Int.toString (List.length deferred_declaration_cases) ^ "\n");
val _ = print ("DEFERRED_PUBLIC_CASE_COUNT " ^ Int.toString
  (List.length cases + List.length deferred_declaration_cases) ^ "\n");
