let s:efm = 'set efm=%+AFile\ \"%f\"\\,\ line\ %l\\,\ characters\ %c-%*\\d:,%Z%m'
let s:opts = [ '-pp', 'camlp4o' ]
call actions#AddAction('ocamlc current file', {'action': funcref#Function('actions#CompileRHSSimple', {'args': [[s:efm], ["ocamlc", '-annot', '-pp', 'camlp4o', '-o', funcref#Function('return expand("%:r:t")'), funcref#Function('return expand("%")')]]})})
call actions#AddAction('ocamlc run result', {'action': funcref#Function('actions#CompileRHSSimple', {'args': [[], [funcref#Function('return "./".expand("%:r:t")')]]})})
call actions#AddAction('ocamlopt current file', {'action': funcref#Function('actions#CompileRHSSimple', {'args': [[s:efm], ["ocamlopt", '-annot', '-pp', 'camlp4o', '-o', funcref#Function('return expand("%:r:t")'), funcref#Function('return expand("%")')]]})})

command! OcamlSetEFM exec s:efm



" ocaml completion
"
"
call vim_addon_completion#RegisterCompletionFunc({
      \ 'description' : '.ml ocaml completion based on various strategies',
      \ 'completeopt' : 'preview,menu,menuone',
      \ 'scope' : 'ocaml',
      \ 'func': 'vim_addon_ocaml#OcamlComplete'
      \ })

command! -nargs=0 MLFunctionByTye call vim_addon_ocaml#FunctionByType()

" ocaml can't cope with UTF-8 (yet?)
augroup SET_ENCODING_FOR_OCAML_FILES
  autocmd BufReadPre,BufNewFile *.ml,*.mli setlocal encoding=latin1 | setlocal fileencoding=latin1
augroup end
