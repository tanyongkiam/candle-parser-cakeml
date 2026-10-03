Theory candleHelpersOracle
Ancestors
  caml_parser
Libs
  preamble mlstringSyntax[qualified]

val _ = load "oracle_support";
(* Inputs are literal HOL terms and their native representation, not candidate
   expectations. Result products for build_letrec cross the exported-Ast ABI. *)
val x = "(Var (Short «x»))";
val y = "(Var (Short «y»))";
val nx = "(Ast.Ident (Ast.Short \"x\"))";
val ny = "(Ast.Ident (Ast.Short \"y\"))";
val p = "(INR (Pvar «p»))";
val np = "(Inr (Ast.Pvar \"p\"))";
val r = "(INL (Short «Rec»,[«a»;«b»]))";
val nr = "(Inl (Ast.Short \"Rec\",[\"a\",\"b\"]))";
val w = "(INR Pany)";
val nw = "(Inr Ast.Pany)";
val cases =
  map (fn s => ("binop/" ^ s,"build_binop «" ^ s ^ "» " ^ x ^ " " ^ y,
    "build_binop " ^ quoted s ^ " " ^ nx ^ " " ^ ny,false)) ["+","&&","||"] @
  [("list","build_list_exp [" ^ x ^ ";" ^ y ^ "]","build_list_exp [" ^ nx ^ "," ^ ny ^ "]",false),
   ("raise","build_funapp (Var (Short «raise»)) [" ^ x ^ ";" ^ y ^ "]",
    "build_funapp (Ast.Ident (Ast.Short \"raise\")) [" ^ nx ^ "," ^ ny ^ "]",false),
   ("qualified-raise","build_funapp (Var (Long «Aa» (Short «raise»))) [" ^ x ^ "]",
    "build_funapp (Ast.Ident (Ast.Long \"Aa\" (Ast.Short \"raise\"))) [" ^ nx ^ "]",false),
   ("annotated-raise","build_funapp (Lannot (Var (Short «raise»)) ast$NoLocs) [" ^ x ^ "]",
    "build_funapp (Ast.Lannot (Ast.Ident (Ast.Short \"raise\")) Ast.Nolocs) [" ^ nx ^ "]",false),
   ("record-duplicate-fields","build_record_cons [«Aa»;«Rec»] [(«z»," ^ x ^ ");(«a»," ^ y ^ ");(«z»," ^ y ^ ")]",
    "build_record_cons [\"Aa\",\"Rec\"] [(\"z\"," ^ nx ^ "),(\"a\"," ^ ny ^ "),(\"z\"," ^ ny ^ ")]",false),
   ("record-empty-path","build_record_cons_id [«a»] []","build_record_cons_id [\"a\"] []",false),
   ("record-update","build_record_upd (Long «Aa» (Short «Rec»)) " ^ x ^ " («a»," ^ y ^ ")",
    "build_record_upd (Ast.Long \"Aa\" (Ast.Short \"Rec\")) " ^ nx ^ " (\"a\"," ^ ny ^ ")",false),
   ("record-projection","build_record_proj (Short «Rec») «a» " ^ x,
    "build_record_proj (Ast.Short \"Rec\") \"a\" " ^ nx,false),
   ("record-match","mk_record_match (Short «Rec») [«b»;«a»] «recv» " ^ x,
    "mk_record_match (Ast.Short \"Rec\") [\"b\",\"a\"] \"recv\" " ^ nx,false)] @
  map (fn (name,h,n) => ("lambda/" ^ name,"build_fun_lam " ^ x ^ " [" ^ h ^ "]",
    "build_fun_lam " ^ nx ^ " [" ^ n ^ "]",false)) [("var",p,np),("record",r,nr),("wildcard",w,nw)] @
  map (fn (name,h,n) => ("letrec/" ^ name,"build_letrec [(«f»," ^ h ^ "," ^ x ^ ")]",
    "build_letrec [(\"f\"," ^ n ^ "," ^ nx ^ ")]",true))
    [("empty","[]","[]"),("var","[" ^ p ^ "]","[" ^ np ^ "]"),
     ("record","[" ^ r ^ "]","[" ^ nr ^ "]"),("wildcard","[" ^ w ^ "]","[" ^ nw ^ "]")] @
  map (fn (name,h,n) => ("lets/" ^ name,"build_lets " ^ y ^ " [INL (" ^ h ^ "," ^ x ^ ")]",
    "build_lets " ^ ny ^ " [Inl (" ^ n ^ "," ^ nx ^ ")]",false))
    [("var",p,np),("record",r,nr),("wildcard",w,nw),
     ("constructor","INR (Pcon (SOME (Short «Some»)) [Pvar «p»])",
      "Inr (Ast.Pcon (Some (Ast.Short \"Some\")) [Ast.Pvar \"p\"])")] @
  [("lets-function","build_lets " ^ y ^ " [INR («f»,[" ^ p ^ "]," ^ x ^ ")]",
    "build_lets " ^ ny ^ " [Inr (\"f\",[" ^ np ^ "]," ^ nx ^ ")]",false),
   ("smart-wildcard","SmartMat «m» [(" ^ w ^ "," ^ x ^ ")]",
    "smartMat \"m\" [(" ^ nw ^ "," ^ nx ^ ")]",false),
   ("match-record","build_match " ^ y ^ " [(" ^ r ^ "," ^ x ^ ",NONE)]",
    "build_match " ^ ny ^ " [(" ^ nr ^ "," ^ nx ^ ",None)]",false),
   ("match-guard","build_match " ^ y ^ " [(" ^ p ^ "," ^ x ^ ",SOME " ^ y ^ ");(" ^ w ^ "," ^ y ^ ",NONE)]",
    "build_match " ^ ny ^ " [(" ^ np ^ "," ^ nx ^ ",Some " ^ ny ^ "),(" ^ nw ^ "," ^ ny ^ ",None)]",false),
   ("handle-empty","build_handle " ^ x ^ " []","build_handle " ^ nx ^ " []",false),
   ("function-record","build_function [(" ^ r ^ "," ^ x ^ ",NONE)]",
    "build_function [(" ^ nr ^ "," ^ nx ^ ",None)]",false),
   ("guard-empty-tail","build_pmatch «m» [] [(" ^ p ^ "," ^ x ^ ",SOME " ^ y ^ ")]",
    "build_pmatch \"m\" [] [(" ^ np ^ "," ^ nx ^ ",Some " ^ ny ^ ")]",false),
   ("record-functions","build_rec_funs (unknown_loc,«Rec»,[«a»;«b»])",
    "build_rec_funs (CandleSupport.unknown_loc,\"Rec\",[\"a\",\"b\"])",false)];

fun oracle (name,call,native,nested) = let
  val tm = Parse.Term [QUOTE ("camlPtreeConversion$" ^ call)];
  val result = rhs (concl (EVAL tm));
in print ("CANDLEHELPER_GOLDEN (" ^ quoted name ^ ",fn _ => CandleDeclarations." ^ native ^
  " = " ^ encode nested result ^ "),\n") end;
val _ = List.app oracle cases;
val _ = print ("CANDLE_HELPER_COUNT " ^ Int.toString (List.length cases) ^ "\n");
