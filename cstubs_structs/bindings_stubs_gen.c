#include <time.h>
#include <limits.h>
#if !__USE_MINGW_ANSI_STDIO && (defined(__MINGW32__) || defined(__MINGW64__))
#define __USE_MINGW_ANSI_STDIO 1
#endif

#include <stdio.h>
#include <stddef.h>
#include "ctypes_cstubs_internals.h"

int main(void)
{

  puts("include Ctypes");
  puts("let lift x = x");
  puts("open Ctypes_static");
  puts("");
  puts("let rec field : type t a. t typ -> string -> a typ -> (a, t) field =");
  puts("  fun s fname ftype -> match s, fname with");
  puts("  | Struct ({ tag = \"tm\"} as s'), \"tm_year\" ->");
  printf("    let f = {ftype; fname; foffset = %zu} in \n",
        offsetof(struct tm, tm_year));
  puts("    (s'.fields <- BoxedField f :: s'.fields; f)");
  puts("  | Struct ({ tag = \"tm\"} as s'), \"tm_hour\" ->");
  printf("    let f = {ftype; fname; foffset = %zu} in \n",
        offsetof(struct tm, tm_hour));
  puts("    (s'.fields <- BoxedField f :: s'.fields; f)");
  puts("  | View { ty }, _ ->");
  puts("    let { ftype; foffset; fname } = field ty fname ftype in");
  puts("    { ftype; foffset; fname }");
  puts("  | _ -> failwith (\"Unexpected field \"^ fname)");
  puts("");
  puts("let rec seal : type a. a typ -> unit = function");
  puts("  | Struct ({ tag = \"tm\"; spec = Incomplete _ } as s') ->");
  printf("    s'.spec <- Complete { size = %zu; align = %zu }\n",
        sizeof(struct tm), offsetof(struct { char c; struct tm x; }, x));
  puts("  | Struct { tag; spec = Complete _ } ->");
  puts("    raise (ModifyingSealedType tag)");
  puts("  | Union { utag; uspec = Some _ } ->");
  puts("    raise (ModifyingSealedType utag)");
  puts("  | View { ty } -> seal ty");
  puts("  | _ ->");
  puts("    raise (Unsupported \"Sealing a non-structured type\")");
  puts("");
  puts("type 'a const = 'a");
  puts("let constant (type t) name (t : t typ) : t = match t, name with");
  {
     enum { check_SHRT_MAX_const = (int)SHRT_MAX };
     short v = (SHRT_MAX);
     printf("  | Ctypes_static.Primitive Cstubs_internals.Short, \"SHRT_MAX\" ->\n    %hd\n",
           v);
     
  }
  puts("  | _, s -> failwith (\"unmatched constant: \"^ s)");
  puts("");
  puts("let enum (type a) name ?typedef ?unexpected (alist : (a * int64) list) =");
  puts("  match name with");
  puts("  | s ->");
  puts("    failwith (\"unmatched enum: \"^ s)");
  
  return 0;
}
