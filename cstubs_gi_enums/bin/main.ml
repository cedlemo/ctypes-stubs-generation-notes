open Ctypes
open Foreign

module Stubs = Bindings.Enums(Bindings_stubs)

(* From GObject-Introspection lib *)

type repository = unit ptr option
let repository_typ : repository typ = ptr_opt void

type typelib = unit ptr
let typelib : typelib typ = ptr void

type gerror_t
let gerror : gerror_t structure typ = structure "GError"
let f_message = field gerror "message" (string)
let _ = seal gerror

let get_default =
  foreign "g_irepository_get_default" (void @-> returning repository_typ)

let require ?repository namespace ?version () =
  let require_raw =
  foreign "g_irepository_require"
    (repository_typ @-> string @-> string_opt @-> int @->  ptr (ptr gerror) @-> returning (ptr_opt void)) in
  let error_addr = allocate_n (ptr gerror) ~count:1 in
  let repo = match repository with None -> None | Some r -> r in
  match require_raw repo namespace version 0 error_addr with
  | None ->
    let message = begin
      match version with
      | None -> "Unable to load namespace " ^ namespace
      | Some v ->
        Printf.sprintf "Unable to load namespace %s version %s" namespace v
    end
    in Error message
  | Some typelib_ptr ->
      match coerce (ptr gerror) (ptr_opt gerror) (!@error_addr) with
      | None ->let typelib_ptr' = coerce (ptr void) (typelib) typelib_ptr in
          Ok typelib_ptr'
      | Some error -> Error (getf !@error f_message)

module Base_info = struct
  type t
  let baseinfo : t structure typ = structure "Base_info"

  let get_type =
      foreign "g_base_info_get_type"
        (ptr baseinfo @-> returning Stubs.baseinfo_type)
end

let find_by_name ?repository namespace name =
  let find_by_name_raw =
    foreign "g_irepository_find_by_name"
      (repository_typ @-> string @-> string @-> returning (ptr_opt Base_info.baseinfo))
  in
  let repo = match repository with None -> None | Some r -> r in
  match find_by_name_raw repo namespace name with
  | None -> None
  | Some info -> let _ = Gc.finalise (fun i -> Base_info.base_info_unref i) info
    in Some info

let main () =
  ()

let () = main ()
