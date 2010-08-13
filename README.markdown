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

TIPS:
====================

* learn about vim-addon-actions

* consider putting this into your ~/.ctags file

  --regex-ocaml=/^[ \t]*external[ \t]+([A-Za-z0-9_]+)/\1/c,v/

  (verify that ctags --list-maps has an ocaml entry. If it doesn't upgrade
  exuberant ctags)
  
  If you want to tag ocaml sources you have to apply ctags.patch preventing some segfaults


HapPy vimming!


TODO / bugs
==================
local vals/vars in buf have no type hinting in completion
... many more
