vim ocaml scritps
====================

This collection includes well known scripts I was pointed to such as ocaml
indentation, annot support as well as omni completion support

I modified the indenting slightly so that the args  ".." and x y are not
indented at all. (Using vim indentation they are indented the same as Printf
which is annoying)

let f x =
  let y = x + 1 in
  Printf.printf
    "%d + 1 = %d"
    x y

completion details:
====================

All completion is based on .mli files found in all tag files.
If you don't have tags, tell Vim which .mli files to use:

let g:vim_addon_ocaml = { 'provide_additional_mlis': function('name of function returning a list of .mli files') }

a) name completion:
  all .mli files are grepped for the name
  Additionally all let bindings found in current buffer are taken into account

b) type completion:

  con:str           finnds concat : string -> string

  :^int->string$    finds string_of_int

c) var based completion (not that well tested)

  x:conc

  the type of x is looked up by .annot files (you must have created the musing ocamlc or ocamelopt)
  Then b) completion is used using the type of x.


For both b) and c) the completion result is
(concat x)

Its not perfect - but its a starting point.


goto feature:
====================

press gf on a thing to make Vim try to find the definition. These locations are considered:
- by tags
- by tag (and matching module name. Eg String.concat)
- lets in other **/MODULE.ml files whith matching module name
- type definition (experimental)


TIPS:
====================

* learn about vim-addon-actions

* consider putting this into your ~/.ctags file

  --langmap=OCaml:.sml,OCaml:.ml
  --regex-ocaml=/^[ \t]*external[ \t]+([A-Za-z0-9_]+)/\1/c,v/
  --regex-OCaml=/^[ \t]*datatype[ \t]+([A-Z'a-z0-9_]+)/\1/d,datatype/
  --regex-OCaml=/^[ \t]*and[ \t]+([A-Z'a-z0-9_]+)/\1/d,datatype/
  --regex-OCaml=/^[ \t]*withtype[ \t]+([A-Z'a-z0-9_]+)/\1/w,withtype/
  --regex-OCaml=/^[ \t]*structure[ \t]+([A-Z'a-z0-9_]+)/\1/s,structure/
  --regex-OCaml=/[ \t]*val[ \t]+([A-Z'a-z0-9_]+)/\1/v,val/
  --regex-OCaml=/^[ \t]*fun[ \t]+([A-Z'a-z0-9_]+)/\1/f,fun/
  --regex-OCaml=/^[ \t]*type[ \t]+([A-Z'a-z0-9_]+)/\1/t,type/
  --regex-OCaml=/\|[ \t]*([A-Z'a-z0-9_]+)[^-]*$/\1/c,cons/


  (verify that ctags --list-maps has an ocaml entry. If it doesn't upgrade
  exuberant ctags)
  
  If you want to tag ocaml sources you have to apply ctags.patch preventing some segfaults


HapPy vimming!


TODO / bugs
==================
local vals/vars in buf have no type hinting in completion
... many more
