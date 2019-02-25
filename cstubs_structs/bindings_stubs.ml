include Ctypes
let lift x = x
open Ctypes_static

let rec field : type t a. t typ -> string -> a typ -> (a, t) field =
  fun s fname ftype -> match s, fname with
  | Struct ({ tag = "tm"} as s'), "tm_year" ->
    let f = {ftype; fname; foffset = 20} in 
    (s'.fields <- BoxedField f :: s'.fields; f)
  | Struct ({ tag = "tm"} as s'), "tm_hour" ->
    let f = {ftype; fname; foffset = 8} in 
    (s'.fields <- BoxedField f :: s'.fields; f)
  | View { ty }, _ ->
    let { ftype; foffset; fname } = field ty fname ftype in
    { ftype; foffset; fname }
  | _ -> failwith ("Unexpected field "^ fname)

let rec seal : type a. a typ -> unit = function
  | Struct ({ tag = "tm"; spec = Incomplete _ } as s') ->
    s'.spec <- Complete { size = 56; align = 8 }
  | Struct { tag; spec = Complete _ } ->
    raise (ModifyingSealedType tag)
  | Union { utag; uspec = Some _ } ->
    raise (ModifyingSealedType utag)
  | View { ty } -> seal ty
  | _ ->
    raise (Unsupported "Sealing a non-structured type")

type 'a const = 'a
let constant (type t) name (t : t typ) : t = match t, name with
  | Ctypes_static.Primitive Cstubs_internals.Short, "SHRT_MAX" ->
    32767
  | _, s -> failwith ("unmatched constant: "^ s)

let enum (type a) name ?typedef ?unexpected (alist : (a * int64) list) =
  match name with
  | s ->
    failwith ("unmatched enum: "^ s)
