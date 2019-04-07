let namespace = "GObject"
let typelib = Gi.Repository.require namespace ()
let struct_name = "Value"

let test_baseinfo_get_type () =
  match Gi.Repository.find_by_name namespace struct_name with
  | None -> prerr_endline "No base info found"; exit 1
  | Some base_info ->
      match Gi.Base_info.get_type base_info with
        | Struct -> print_endline "It works!"
      | _ -> prerr_endline "Bad type"; exit 1

let () = test_baseinfo_get_type ()
