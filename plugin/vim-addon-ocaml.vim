let s:efm = 'set efm=%+AFile\ \"%f\"\\,\ line\ %l\\,\ characters\ %c-%*\\d:,%Z%m'
call actions#AddAction('ocamlc current file', {'action': funcref#Function('actions#CompileRHSSimple', {'args': [[s:efm], ["ocamlc", '-annot', '-o', funcref#Function('return expand("%:r:t")'), funcref#Function('return expand("%")')]]})})
call actions#AddAction('ocamlc run result', {'action': funcref#Function('actions#CompileRHSSimple', {'args': [[], [funcref#Function('return "./".expand("%:r:t")')]]})})

call actions#AddAction('ocamlopt current file', {'action': funcref#Function('actions#CompileRHSSimple', {'args': [[s:efm], ["ocamlopt", '-annot', '-o', funcref#Function('return expand("%:r:t")'), funcref#Function('return expand("%")')]]})})



" ocaml completion
"
"
call vim_addon_completion#RegisterCompletionFunc({
      \ 'description' : '.ml ocaml completion based on various strategies',
      \ 'completeopt' : 'preview,menu,menuone',
      \ 'scope' : 'ocaml',
      \ 'func': 'vim_addoon_ocaml#OcamlComplete'
      \ })
