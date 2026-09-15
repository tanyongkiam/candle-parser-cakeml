(* ========================================================================= *)
(* More syntax constructors, and prelogical utilities like matching.         *)
(*                                                                           *)
(*       John Harrison, University of Cambridge Computer Laboratory          *)
(*                                                                           *)
(*            (c) Copyright, University of Cambridge 1998                    *)
(*              (c) Copyright, John Harrison 1998-2007                       *)
(*     (c) Copyright, Andrea Gabrielli, Marco Maggesi 2017-2018              *)
(* ========================================================================= *)

needs "fusion.ml";;

(* ------------------------------------------------------------------------- *)
(* Create probably-fresh variable                                            *)
(* ------------------------------------------------------------------------- *)

let genvar =
  let gcounter = ref 0 in
  fun ty -> let count = !gcounter in
             (gcounter := count + 1;
              mk_var("_"^(string_of_int count),ty));;

(* ------------------------------------------------------------------------- *)
(* Convenient functions for manipulating types.                              *)
(* ------------------------------------------------------------------------- *)

let dest_fun_ty ty =
  match ty with
    Tyapp("fun",[ty1;ty2]) -> (ty1,ty2)
  | _ -> failwith "dest_fun_ty";;

let rec occurs_in ty bigty =
  bigty = ty ||
  is_type bigty && exists (occurs_in ty) (snd(dest_type bigty));;

let rec tysubst alist ty =
  try rev_assoc ty alist with Failure _ ->
  if is_vartype ty then ty else
  let tycon,tyvars = dest_type ty in
  mk_type(tycon,map (tysubst alist) tyvars);;

(* ------------------------------------------------------------------------- *)
(* A bit more syntax.                                                        *)
(* ------------------------------------------------------------------------- *)

let bndvar tm =
  try fst(dest_abs tm)
  with Failure _ -> failwith "bndvar: Not an abstraction";;

let body tm =
  try snd(dest_abs tm)
  with Failure _ -> failwith "body: Not an abstraction";;

let list_mk_comb(h,t) = rev_itlist (C (curry mk_comb)) t h;;

let list_mk_abs(vs,bod) = itlist (curry mk_abs) vs bod;;

let strip_comb = rev_splitlist dest_comb;;

let strip_abs = splitlist dest_abs;;
