(* ========================================================================= *)
(* Convenient library functions.                                             *)
(*                                                                           *)
(*       John Harrison, University of Cambridge Computer Laboratory          *)
(*                                                                           *)
(*            (c) Copyright, University of Cambridge 1998                    *)
(*              (c) Copyright, John Harrison 1998-2007                       *)
(* ========================================================================= *)

let fail() = failwith "";;

(* ------------------------------------------------------------------------- *)
(* Combinators.                                                              *)
(* ------------------------------------------------------------------------- *)

let curry f x y = f(x,y);;

let uncurry f(x,y) = f x y;;

let I x = x;;

let K x y = x;;

let C f x y = f y x;;

let W f x = f x x;;

let (o) = fun f g x -> f(g x);;

let (F_F) = fun f g (x,y) -> (f x,g y);;

let (|>) = fun x f -> f x;;

(* ------------------------------------------------------------------------- *)
(* List basics.                                                              *)
(* ------------------------------------------------------------------------- *)

let hd l =
  match l with
   h::t -> h
  | _ -> failwith "hd";;

let tl l =
  match l with
   h::t -> t
  | _ -> failwith "tl";;

let map f =
  let rec mapf l =
    match l with
      [] -> []
    | (x::t) -> let y = f x in y::(mapf t) in
  mapf;;

let rec last l =
  match l with
    [x] -> x
  | (h::t) -> last t
  | [] -> failwith "last";;

let rec butlast l =
  match l with
    [_] -> []
  | (h::t) -> h::(butlast t)
  | [] -> failwith "butlast";;

let rec el n l =
  if n = 0 then hd l else el (n - 1) (tl l);;

let rev =
  let rec rev_append acc l =
    match l with
      [] -> acc
    | h::t -> rev_append (h::acc) t in
  fun l -> rev_append [] l;;

let rec map2 f l1 l2 =
  match (l1,l2) with
    [],[] -> []
  | (h1::t1),(h2::t2) -> let h = f h1 h2 in h::(map2 f t1 t2)
  | _ -> failwith "map2: length mismatch";;
