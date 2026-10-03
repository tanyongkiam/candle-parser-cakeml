Theory candleLimitsOracle
Ancestors
  caml_parser
Libs
  preamble mlstringSyntax[qualified]

(* Executable reference evaluation only; no authored theorem proofs. *)
val _ = load "oracle_support";
val _ = load "limits_cases";
fun limits_oracle (name,source) = let
  val input = stringSyntax.lift_string bool source;
  val result = rhs (concl (EVAL ``caml_parser$run ^input``));
in print ("LIMITS_GOLDEN (" ^ quoted name ^ "," ^ quoted source ^ "," ^ public_value result ^ "),\n") end;
val _ = List.app limits_oracle limits_cases;
val _ = print "LIMITS_ORACLE_COMPLETE\n";
