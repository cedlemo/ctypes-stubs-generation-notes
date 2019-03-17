# Understanding Ctypes C stubs generator.

* [Introduction](#introduction)
* [The default example](#the-default-example)
  * [Write a stubs module that is a functor which defines the bindings](Write-a-stubs-module-that-is-a-functor-which-defines-the-bindings)
  * [Write a module that uses the bindings module and outputs a C file](write-a-module-that-uses-the-bindings-module-and-outputs-a-c-file)
  * [Launch the different phases of compile and file generation](launch-the-different-phases-of-compile-and-file-generation)
  * [Using Dune with the default example](using-dune-with-the-default-example)
    * [Description of the dune files](description-of-the-dune-files)

* [Cstubs Enums bindings from the GObject-Introspection library](Enums bindings from the GObject-Introspection library)

## Introduction

As mentionned in the [README.md](https://github.com/ocamllabs/ocaml-ctypes/blob/master/examples/cstubs_structs/README.md),

> Ctypes is generally used to specify how to call C code using a DSL that is executed at runtime.

But this has some limitations with:
- data types like:
  * structures
  * [enums](https://discuss.ocaml.org/t/ctypes-enum-how-to-make-it-work/456/4?u=cedlemo)
- constants

In order to be able to circumvent thoses limitations, there is the Cstubs module of Ctypes.

## The default example

### Write a stubs module that is a functor which defines the bindings

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

### Write a module that uses the bindings module and outputs a C file

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

Here are the all the steps needed to use the Ctypes stubs:

1. Write a stubs module that is a functor which defines the bindings.
2. Write a module that uses the bindings module and outputs a C file.
3. Compile the program from step 2 and execute it.
4. Compile the C program generated in step 3.
5. Run the C program from step 4, generating an ML module.
6. Compile the module generated in step 5.

The following schema illustrates those steps:

![Ctypes Stubs generation schema](https://github.com/cedlemo/ctypes-stubs-generation-notes/raw/master/Ctypes_Stubs_generation.png)

### Using Dune with the default example

* https://github.com/ocaml/dune/issues/135
* https://github.com/janestreet/async_ssl

This is quite simple for the default example, we just need to create a new directory
tree that looks like that:

```
cstubs_structs_dune
├── bin
├── bindings
└── stubgen
```

The bin directory will contain the `main.ml`, which is the main program. The
bindings directory is dedicated to the Ctypes bindings we want to use and in the
stubgen there will be all the code generators.

Here is the directory tree with all the files of the default project:

```
cstubs_structs_dune
├── bin
│   ├── dune
│   └── main.ml
├── bindings
│   ├── bindings.ml
│   └── dune
├── dune-project
└── stubgen
    ├── bindings_c_gen.ml
    └── dune
```

#### Description of the dune files

* In the `bindings/dune` file

```
(library
 (name bindings)
 (synopsis "Ctypes bindings that describe the lib FFI")
 (libraries ctypes.stubs ctypes))
```

Here I declare a library with the name "bindings" so that it can be included in
the `bin/dune` file. In the last line there are the dependencies of the `bindings` library.

* In the `stubgen/dune` file

```
(executable
 (name bindings_c_gen)
 (modules bindings_c_gen)
 (libraries bindings ctypes.stubs ctypes))

(rule
 (targets bindings_stubs_gen.c)
 (deps (:stubgen ../stubgen/bindings_c_gen.exe))
 (action (with-stdout-to %{targets} (run %{stubgen} -c))))

(rule (targets bindings_stubs_gen.exe)
 (deps (:first_dep bindings_stubs_gen.c))
 (action
  (bash
   "%{cc} %{first_dep} -I `dirname %{lib:ctypes:ctypes_cstubs_internals.h}` -I %{ocaml_where} -o %{targets}"))
)
```

In the first part, there is the declaration of an OCaml executable : `bindings_c_gen.exe`,
generated from the file `stubgen/bindings_c_gen.ml` and from the `bindings` library,
this is the first part of the step 3 described previously.

Then a *rule* is declared, it describes how to generate the file `bindings_stubs_gen.c` from
the executable `bindings_c_gen.exe`, this is the second part of the step 3.

The last *rule* tells how the file `bindings_stubs_gen.c` is compiled into the
executable `bindings_stubs_gen.exe`, this is the step 4.

* In the `bin/dune` file

```
(executable (name main)
 (libraries bindings ctypes.stubs ctypes ctypes.foreign)
)

(rule
 (targets bindings_stubs.ml)
 (deps ../stubgen/bindings_stubs_gen.exe)
 (action (with-stdout-to %{targets} (run %{deps} -ml))))
```

In the first part, there is the declaration of an OCaml executable `main.exe` and
 its dependencies.

In the last part, there is the rule for the generation of the file `bindings_stubs.ml`
via the executable `bindings_stubs_gen.exe`, this is the part 5 described previously.

## Cstubs Enums bindings from the GObject-Introspection library

In this example I will describe how to use the Ctypes Stubs module to bind C enums
 with `Cstubs.Types.TYPE.enum` and especially the enum `GITypeInfo` whith a `discover.exe`
 application which will be able to get the libs and flags needed to compile the
 intermediate C generator.

```c
typedef enum
{
  GI_INFO_TYPE_INVALID,
  GI_INFO_TYPE_FUNCTION,
  GI_INFO_TYPE_CALLBACK,
  GI_INFO_TYPE_STRUCT,
  GI_INFO_TYPE_BOXED,
  GI_INFO_TYPE_ENUM,         /*  5 */
  GI_INFO_TYPE_FLAGS,
  GI_INFO_TYPE_OBJECT,
  GI_INFO_TYPE_INTERFACE,
  GI_INFO_TYPE_CONSTANT,
  GI_INFO_TYPE_INVALID_0,    /* 10 */
  GI_INFO_TYPE_UNION,
  GI_INFO_TYPE_VALUE,
  GI_INFO_TYPE_SIGNAL,
  GI_INFO_TYPE_VFUNC,
  GI_INFO_TYPE_PROPERTY,     /* 15 */
  GI_INFO_TYPE_FIELD,
  GI_INFO_TYPE_ARG,
  GI_INFO_TYPE_TYPE,
  GI_INFO_TYPE_UNRESOLVED
} GIInfoType;
```

Here is the file hierarchy for this:

```
/
├── bin
│   ├── dune
│   └── main.ml
├── bindings
│   ├── bindings.ml
│   └── dune
├── config
│   ├── discover.ml
│   └── dune
├── dune-project
└── stubgen
    ├── bindings_c_gen.ml
    └── dune
```
