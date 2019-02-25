# Understanding Ctypes stubs generator.

## Introduction

As mentionned in the [README.md](https://github.com/ocamllabs/ocaml-ctypes/blob/master/examples/cstubs_structs/README.md),

> Ctypes is generally used to specify how to call C code using a DSL that is executed at runtime.

But this has some limitations with:
- data types like:
  * structures
  * [enums](https://discuss.ocaml.org/t/ctypes-enum-how-to-make-it-work/456/4?u=cedlemo)
- constants

## The default example.

### Write a stubs module that is a functor which defines the bindings.

* bindings.ml
```ocaml
module Stubs = functor (S : Cstubs_structs.TYPE) -> struct
  module Tm = struct
    type tm
    type t = tm Ctypes.structure
    let t : t S.typ = S.structure "tm"
    let tm_hour = S.(field t "tm_hour" int)
    let tm_year = S.(field t "tm_year" int)

    let () = S.seal t
  end

  module Limits = struct
    let shrt_max = S.(constant "SHRT_MAX" short)
  end
end
```

### Write a module that uses the bindings module and outputs a C file.

* bindings_c_gen.ml

```ocaml
let c_headers = "#include <time.h>\n#include <limits.h>"

let main () =
  let stubs_out = open_out "bindings_stubs_gen.c" in
  let stubs_fmt = Format.formatter_of_out_channel stubs_out in
  Format.fprintf stubs_fmt "%s@\n" c_headers;
  Cstubs_structs.write_c stubs_fmt (module Bindings.Stubs);
  Format.pp_print_flush stubs_fmt ();
  close_out stubs_out

let () = main ()
```

### Launch the different phases of compile and file generation

