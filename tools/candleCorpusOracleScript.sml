Theory candleCorpusOracle
Ancestors
  caml_parser
Libs
  preamble mlstringSyntax[qualified]

val _ = use "oracle_support.sml";
val _ = use "corpus_cases.sml";
fun corpus_oracle (name,source) = let
  val input = stringSyntax.lift_string bool source;
  val result = rhs (concl (EVAL ``caml_parser$run ^input``));
in print ("CORPUS_GOLDEN (" ^ quoted name ^ "," ^ quoted source ^ "," ^ value result ^ "),\n") end;
val _ = List.app corpus_oracle corpus_cases;
val _ = print "CORPUS_ORACLE_COMPLETE\n";
