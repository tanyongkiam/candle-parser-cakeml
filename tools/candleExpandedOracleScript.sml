Theory candleExpandedOracle
Ancestors
  caml_parser
Libs
  preamble mlstringSyntax[qualified]

(* Independent executable tests only: original HOL parser, no candidate code. *)
val _ = use "oracle_support.sml";
val _ = use "expanded_cases.sml";

fun inherited_oracle (name,nonterm,converter,source) =
  if String.isSubstring "(*CML" source then
    print ("INHERITED_EXCLUDED " ^ name ^ " CakeML pragma (user-deferred)\n")
  else let
    val nt = prim_mk_const {Thy="camlPEG",Name=nonterm};
    val conv0 = prim_mk_const {Thy="camlPtreeConversion",Name=converter};
    val conv = if converter = "ptree_Expr" then mk_comb(conv0,nt) else conv0;
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
    val native = "CandleDeclarations." ^ converter ^
      (if converter = "ptree_Expr" then " " ^ value nt else "");
  in print ("INHERITED_GOLDEN (" ^ quoted name ^ ",fn _ => ConversionTests.run " ^
       value nt ^ " (" ^ native ^ ") " ^ quoted source ^ " = " ^ value result ^ "),\n") end;

fun public_oracle (name,source) = let
  val input = stringSyntax.lift_string bool source;
  val result = rhs (concl (EVAL ``caml_parser$run ^input``));
in print ("EXPANDED_GOLDEN (" ^ quoted name ^ "," ^ quoted source ^ "," ^ value result ^ "),\n") end;

val _ = List.app inherited_oracle inherited_cases;
val _ = List.app public_oracle expanded_public_cases;
val _ = print "EXPANDED_ORACLE_COMPLETE\n";
