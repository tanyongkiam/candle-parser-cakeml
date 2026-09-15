Theory candleLimitsOracle
Ancestors
  caml_parser
Libs
  preamble mlstringSyntax[qualified]

(* Executable reference evaluation only; no authored theorem proofs. *)
val _ = use "oracle_support.sml";
val _ = use "limits_cases.sml";
fun limits_oracle (name,source) = let
  val input = stringSyntax.lift_string bool source;
  val result = rhs (concl (EVAL ``caml_parser$run ^input``));
in print ("LIMITS_GOLDEN (" ^ quoted name ^ "," ^ quoted source ^ "," ^ value result ^ "),\n") end;
val _ = List.app limits_oracle limits_cases;
val _ = print "LIMITS_ORACLE_COMPLETE\n";
