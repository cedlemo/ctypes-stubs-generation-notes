# Understanding Ctypes C stubs generation.

* [Introduction](#introduction)
* [1 The default example](#1-the-default-example)
  * [1 a Write a stubs module that is a functor which defines the bindings](#1-a-write-a-stubs-module-that-is-a-functor-which-defines-the-bindings)
  * [1 b Write a module that uses the bindings module and outputs a C file](#1-b-write-a-module-that-uses-the-bindings-module-and-outputs-a-c-file)
  * [1 c Launch the different phases of compile and file generation](#1-c-launch-the-different-phases-of-compile-and-file-generation)
  * [1 d Using Dune with the default example](#1-d-using-dune-with-the-default-example)
    * [Description of the dune files](#description-of-the-dune-files)
* [2 Cstubs Enums bindings from the GObject-Introspection library](#2-enums-bindings-from-the-gobject-introspection-library)
  * [2 a Introduction](#2-a-introduction)
  * [2 b Directory structure](#2-b-directory-strutcure)
  * [2 c The config directory](#2-c-the-config-directory)
  * [2 d The bindings directory](#2-d-the-bindings-directory)
  * [2 e The stubgen directory](#2-e-the-stubgen-directory)
  * [2 f The lib directory](#2-f-the-lib-directory)
* [Conclusion](#conclusion)

## Introduction

As mentionned in the [README.md of the Ctypes Cstubs example](https://github.com/ocamllabs/ocaml-ctypes/blob/master/examples/cstubs_structs/README.md),

> Ctypes is generally used to specify how to call C code using a DSL that is executed at runtime.

But this has some limitations with:
- data types like:
  * structures
  * [enums](https://discuss.ocaml.org/t/ctypes-enum-how-to-make-it-work/456/4)
- constants

In order to be able to circumvent thoses limitations, there is the Cstubs module of Ctypes.

I first describe the steps in the default example [cstubs_structs](https://github.com/ocamllabs/ocaml-ctypes/blob/master/examples/cstubs_structs) from the git repository of Ctypes, then I explain how to build it with dune.

In the second part I explain how to use the Cstubs enum bindings generator for
the GObject-Introspection library and how to build those bindings with dune. This
example shows how to discover the compile flags and use them for all the involved build steps.

## 1 The default example

### 1 a Write a stubs module that is a functor which defines the bindings

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

### 1 b Write a module that uses the bindings module and outputs a C file

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

### 1 c Launch the different phases of compile and file generation

Here are the all the steps needed to use the Ctypes stubs:

1. Write a stubs module that is a functor which defines the bindings.
2. Write a module that uses the bindings module and outputs a C file.
3. Compile the program from step 2 and execute it.
4. Compile the C program generated in step 3.
5. Run the C program from step 4, generating an ML module.
6. Compile the module generated in step 5.

The following schema illustrates those steps:

![Ctypes Stubs generation schema](https://github.com/cedlemo/ctypes-stubs-generation-notes/raw/master/Ctypes_Stubs_generation.png)

### 1 d Using Dune with the default example

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

## 2 Cstubs Enums bindings from the GObject-Introspection library

### 2 a Introduction
In this example I will describe how to use the Ctypes Stubs module to bind C enums
 with `Cstubs.Types.TYPE.enum`. The enum used comes from the `gobject-introspection`
 library and is called `GITypeInfo`. Here is it's declaration:

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

In order to test if the bindings works, I will need to create bindings for the
following functions:

* `g_irepository_find_by_name`
* `g_irepository_require`
* `g_base_info_get_type`
* `g_base_info_unref`

and data structures:
* `Base_info`
* `GError`

Without going too much in the details because this is related to the basic usage
of Ctypes, the idea to test the bindings is :
* to load the GObject-Introspection repository of the `GObject` namespace (ie. we
load the description of the library `GObject`)
* then search the [`Value` structure in the current repository](https://developer.gnome.org/gobject/stable/gobject-Generic-values.html#GValue-struct) and get it as a `Base_info` type.
* then test if our bindings match it as a `GI_INFO_TYPE_STRUCT`.

So the main executable will look like this:

```ocaml
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
Here is the file hierarchy for this:
```

### 2 b Directory structure

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
├── lib
│   ├── dune
│   └── gi.ml
└── stubgen
    ├── bindings_c_gen.ml
    └── dune
```

* the **bin** directory contains the main executable used to test the bindings.
* the **config** directory contains the `discover.exe` code that is used to discover
 the libs and flags needed to compile the intermediate code generator and library.
* the **bindings** directory contains the code that defines the enum bindings and
 that will be used by the C Stubs generator `bindings_c_gen.ml`.
* the **stubgen** directory contains the C Stubs generator `bindings_c_gen.ml`
* the **lib** directory will contains all the bindings in a library called *gi*.

### 2 c The config directory

In the config directory, there are 2 files, the *dune* file and the *discover.ml* file.

The *dune* file is really simple, it declares an executable called *discover.exe*
that depends on the libraries base, stdio and configurator.

```dune
(executable
 (name discover)
 (libraries base stdio configurator))
```

The `discover.exe` binary creates different files that will be used to pass flags during
the compilation steps of both C and OCaml binaries. Those flags are of two types:
* cflags: compiler parameters (flags) that can be for example [`-pthread`](https://stackoverflow.com/questions/2127797/significance-of-pthread-flag-when-compiling) and include directories information (`-I/usr/lib/libffi-3.2.1/include`).
Those flags are used in the early stage of the C compilation process, the [*preprocessing* step](https://stackoverflow.com/questions/6264249/how-does-the-compilation-linking-process-work).
* libs: those flags which look like this `-lgirepository-1.0` or `-L/usr/lib/../lib`
are used during the C linking phases. The `-lgirepository-1.0` flag tells the compiler
to link the girepository library to the program, while the `-L/usr/lib/../lib` tells
the compilater where to search for library.

The [OCaml compiler accepts the following options](https://caml.inria.fr/pub/docs/manual-ocaml/native.html):
* -cclib -llibname Pass the -llibname option to the linker . This causes the given C library to be linked with the program.
Those files are generated at build time and can be found in *_build/default/stubgen*.
* -ccopt option Pass the given option to the C compiler and linker. For instance,-ccopt -Ldir causes the C linker to search for C libraries in directory dir.

   - *c_flags.sexp*

   ```
   (-I/usr/lib/libffi-3.2.1/include -I/usr/include/gobject-introspection-1.0 -I/usr/include/glib-2.0 -I/usr/lib/glib-2.0/include -I/usr/lib/libffi-3.2.1/include -pthread)
   ```
   - *c_library_flags.sexp*
   ```
   (-L/usr/lib/../lib -lffi -lgirepository-1.0 -lgobject-2.0 -lglib-2.0)
   ```
   - *ccopts.sexp*
   ```
   (-Wl,-no-as-needed)
   ```
   - *c_library_flags*
   ```
   -L/usr/lib/../lib -lffi -lgirepository-1.0 -lgobject-2.0 -lglib-2.0
   ```
   - *c_flags*
   ```
   -I/usr/lib/libffi-3.2.1/include -I/usr/include/gobject-introspection-1.0 -I/usr/include/glib-2.0 -I/usr/lib/glib-2.0/include -I/usr/lib/libffi-3.2.1/include -pthread
   ```

When one of those files is needed, for a build step, one will just use those kind of
rules in the *dune* file:

```
(rule
  (targets c_flags.sexp c_library_flags.sexp ccopts.sexp)
  (deps    (:x ../config/discover.exe))
  (action  (run %{x} -ocamlc %{ocamlc}))
)
```

### 2 d The bindings directory

in a *bindings.ml* file, a variant type called *baseinfo_type* is defined:

```ocaml
type baseinfo_type =
  | Invalid (** invalid type *)
  | Function (** function, see Function_info *)
  | Callback (** callback, see Function_info *)
  | Struct (** struct, see Struct_info *)
  | Boxed (** boxed, see Struct_info or Union_info *)
  | Enum (** enum, see Enum_info *)
  | Flags (** flags, see Enum_info *)
  | Object (** object, see Object_info *)
  | Interface (** interface, see Interface_info *)
  | Constant (** contant, see Constant_info *)
  | Invalid_0 (** deleted, used to be GI_INFO_TYPE_ERROR_DOMAIN. *)
  | Union (** union, see Union_info *)
  | Value (** enum value, see Value_info *)
  | Signal (** signal, see Signal_info *)
  | Vfunc (** virtual function, see VFunc_info *)
  | Property (** GObject property, see Property_info *)
  | Field (** struct or union field, see Field_info *)
  | Arg (** argument of a function or callback, see Arg_info *)
  | Type (** type information, see Type_info *)
  | Unresolved (** unresolved type, a type which is not present in the typelib, or any of its dependencies. *)
```

and in a functor called *Enums*, we define the bindings between the variant type
tags and the corresponding enum values:

```ocaml
module Enums = functor (T : Cstubs.Types.TYPE) -> struct
  let gi_info_type_invalid = T.constant "GI_INFO_TYPE_INVALID" T.int64_t
  let gi_info_type_function = T.constant "GI_INFO_TYPE_FUNCTION" T.int64_t
  (*
    ...
  *)
  let gi_info_type_type = T.constant "GI_INFO_TYPE_TYPE" T.int64_t
  let gi_info_type_unresolved = T.constant "GI_INFO_TYPE_UNRESOLVED" T.int64_t

  let baseinfo_type = T.enum "GIInfoType" ~typedef:true [
      Invalid, gi_info_type_invalid;
      Function, gi_info_type_function;
      (*
        ...
      *)
      Type, gi_info_type_type;
      Unresolved, gi_info_type_unresolved;
    ]
      ~unexpected:(fun _x -> assert false)
end
```

The dune file is really simple:

```
(library
  (name bindings)
  (libraries ctypes.stubs ctypes)
)
```
It just defines the library name and its dependencies.

### 2 e The stubgen directory

There are two files, the *bindings_c_gen.ml* and its build file called *dune*.
In this directory, a *bindings_c_gen.exe* file is generated with the following
rule:

```
(executable
 (name bindings_c_gen)
 (modules bindings_c_gen)
 (libraries bindings ctypes.stubs ctypes))
```

When executed, this program generates the *bindings_stubs_gen.c*, which is the C
source code for the bindings generator.

```
(rule
 (targets bindings_stubs_gen.c)
 (deps (:stubgen ../stubgen/bindings_c_gen.exe))
 (action (with-stdout-to %{targets} (run %{stubgen} -c))))
```

The following dune rule is used to build the *bindings_stubs_gen.exe*:
```
(rule (targets bindings_stubs_gen.exe)
 (deps bindings_stubs_gen.c c_flags c_library_flags)
 (action
  (bash
   "%{cc} bindings_stubs_gen.c -I `dirname %{lib:ctypes:ctypes_cstubs_internals.h}` -I %{ocaml_where} $(< c_flags) $(< c_library_flags) -o %{targets}"))
)
```
The particularity of this rule is that it uses the **bash** stanza to call the C
compiler with `%{cc}`. [This is variable automatically expanded by dune](https://dune.readthedocs.io/en/latest/dune-files.html?expansion#variables-expansion).

The executable is then used to generate the *bindings_stubs.ml* file in the
*bindings* directory.

### 2 f The lib directory

This is the final directory in which the classical Ctypes bindings will be "merged"
with the automatically generated bindings for the enum in order to create a
library for the bindings.

The library depends on the *Bindings_stubs*, and the build step needs some flags to compile.
The following rules describe to dune how to generate those dependencies.

```
(rule
  (targets c_flags.sexp c_library_flags.sexp ccopts.sexp)
  (deps    (:x ../config/discover.exe))
  (action  (run %{x} -ocamlc %{ocamlc}))
)

(rule
  (targets bindings_stubs.ml)
  (deps ../stubgen/bindings_stubs_gen.exe)
  (action (with-stdout-to %{targets} (run %{deps} -ml))))
```

The library is build with :

```
(library
 (name        gi)
  (libraries ctypes ctypes.foreign str bindings )
  (c_flags         (:include c_flags.sexp))
  (c_library_flags (:include c_library_flags.sexp))
  (ocamlopt_flags (-ccopt (:include ccopts.sexp)))
)
```

# Conclusion

In the main application, the *gi* library with the bindings can then be used:

```ocaml
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
```

Run the build process and the executable with `dune exec bin/main.exe --profile=release`.
The following output is displayed:

```
It works!
```
