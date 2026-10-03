(* This driver evaluates only the read-only reference, never the candidate.
   Export constructor values, not pretty-printed/truncated ASTs. *)
open preamble;
(* The specialized PEG compute rules retain these record projections. Add
   their evaluated values without unfolding the entire grammar rule map. *)
val _ = computeLib.add_funs (map
  (SIMP_CONV (srw_ss()) [camlPEGTheory.camlPEG_def])
  (map (fn s => Parse.Term [QUOTE s])
    ["camlPEG$camlPEG.anyEOF", "camlPEG$camlPEG.tokFALSE",
     "camlPEG$camlPEG.tokEOF", "camlPEG$camlPEG.notFAIL"]));
val _ = computeLib.add_funs (map
  (SIMP_CONV (srw_ss()) [cmlPEGTheory.cmlPEG_def])
  (map (fn s => Parse.Term [QUOTE s])
    ["cmlPEG$cmlPEG.anyEOF", "cmlPEG$cmlPEG.tokFALSE",
     "cmlPEG$cmlPEG.tokEOF", "cmlPEG$cmlPEG.notFAIL"]));
(* CakeML source does not accept SML's control escapes such as \^@. Encode
   non-printable bytes as three decimal digits, including inside char values. *)
fun quoted s = "\"" ^ String.translate (fn c =>
  if c = #"\"" then "\\\"" else if c = #"\\" then "\\\\"
  else if Char.ord c < 32 orelse Char.ord c >= 127 then
    "\\" ^ StringCvt.padLeft #"0" 3 (Int.toString (Char.ord c))
  else String.str c) s ^ "\"";
fun join sep xs = String.concatWith sep xs;
(* Port-private tuples are flat source tuples. Inside the exported Ast types,
   HOL products retain their binary, right-associated representation. *)
fun encode_with location_module nested tm =
  if mlstringSyntax.is_mlstring_literal tm then
    quoted (mlstringSyntax.dest_mlstring tm)
  else if stringSyntax.is_string_literal tm then quoted (stringSyntax.fromHOLstring tm)
  else if numSyntax.is_numeral tm then Arbnum.toString (numSyntax.dest_numeral tm)
  else if wordsSyntax.is_n2w tm andalso type_of tm = Parse.Type [QUOTE ":word64"] then
    "(Word64.fromInt " ^ encode_with location_module nested (#1 (wordsSyntax.dest_n2w tm)) ^ ")"
  else if stringSyntax.is_char_literal tm then
    "#" ^ quoted (String.str (stringSyntax.fromHOLchar tm))
  else if listSyntax.is_list tm then
    "[" ^ join "," (map (encode_with location_module nested) (#1 (listSyntax.dest_list tm))) ^ "]"
  else if pairSyntax.is_pair tm then
    let val parts = if nested then
          let val (a,b) = pairSyntax.dest_pair tm in [a,b] end
        else pairSyntax.strip_pair tm
    in "(" ^ join "," (map (encode_with location_module nested) parts) ^ ")" end
  else let
    val (head,args) = strip_comb tm;
    val {Thy,Name,...} = dest_thy_const head;
    val name =
      if Thy = "integer" andalso Name = "int_of_num" then ""
      else if Thy = "integer" andalso Name = "int_neg" then "~"
      else if not (TypeBase.is_constructor head) then
        raise Fail ("unevaluated oracle term: " ^ term_to_string tm)
      else if Thy = "sum" then (if Name = "INL" then "Inl" else "Inr")
      else if Thy = "option" then (if Name = "NONE" then "None" else "Some")
      else if Thy = "bool" then (if Name = "T" then "True" else "False")
      else if Thy = "one" then "()"
      else if Thy = "caml_lex" then "CandleTokens." ^ Name
      else if Thy = "tokens" then "CakeTokens." ^ Name
      else if Thy = "camlPEG" then "CandleGrammar.N" ^ String.extract (Name,1,NONE)
      else if Thy = "gram" then "CakeGrammar.N" ^ String.extract (Name,1,NONE)
      else if Thy = "camlPtreeConversion" andalso String.isPrefix "Pp_" Name then
        "CandlePatterns." ^ Name
      else if Thy = "grammar" andalso Name = "TOK" then ""
      else if Thy = "grammar" then "CandleTree." ^ Name
      else if Thy = "peg" then "CandlePeg." ^ Name
      else if Thy = "location" then location_module ^ "." ^
        (case Name of "POSN" => "Posn" | "UNKNOWNpt" => "Unknownpt"
         | "EOFpt" => "Eofpt" | _ => Name)
      else if Thy = "ast" orelse Thy = "namespace" then
        (* Match ml_translatorLib.tag_name's constructor spelling, including
           current NoLocs/IntT, without another datatype inventory. *)
        "Ast." ^ (if Name = "Var" then "Ident" else
          String.str (Char.toUpper (String.sub (Name,0))) ^
          String.map Char.toLower (String.extract (Name,1,NONE)))
      else raise Fail ("unmapped oracle constructor: " ^ Thy ^ "$" ^ Name ^ " in " ^ term_to_string tm);
  in if null args then name
     else "(" ^ name ^ " " ^ join " "
       (map (encode_with location_module (nested orelse Thy = "ast")) args) ^ ")" end;
val encode = encode_with "CandleLocation";
val value = encode false;
val public_value = encode_with "CandleParser" false;
