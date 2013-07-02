let s:efm = 'set efm=%+AFile\ \"%f\"\\,\ line\ %l\\,\ characters\ %c-%*\\d:,%Z%m'
let s:opts = [ '-pp', 'camlp4o' ]
call actions#AddAction('ocamlc current file', {'follow_up' : 'run compiler result', 'action': funcref#Function('actions#CompileRHSSimple', {'args': [[s:efm], ["ocamlc", '-g', '-annot', '-pp', 'camlp4o', '-o', funcref#Function('return expand("%:r:t")'), funcref#Function('return expand("%")')]]})})
call actions#AddAction('ocamlopt current file', {'follow_up' : 'run compiler result', 'action': funcref#Function('actions#CompileRHSSimple', {'args': [[s:efm], ["ocamlopt", '-g', '-annot', '-pp', 'camlp4o', '-o', funcref#Function('return expand("%:r:t")'), funcref#Function('return expand("%")')]]})})

command! OcamlSetEFM exec s:efm

" vam#DefineAndBind('s:c','g:addon_ocaml','{}')
if !exists('g:addon_ocaml') | let g:addon_ocaml = {} | endif | let s:c = g:addon_ocaml

command! -nargs=0 MLFunctionByTye call vim_addon_ocaml#FunctionByType()

" ocaml can't cope with UTF-8 (yet?)
augroup SET_ENCODING_FOR_OCAML_FILES
  autocmd BufReadPre,BufNewFile *.ml,*.mli setlocal fileencoding=latin1
augroup end


exec vam#DefineAndBind('s:l','g:vim_addon_toggle_buffer','{}')
let s:l['ocaml_ml'] = funcref#Function('return vim_addon_toggle#Substitute('.string('\.ml').','.string('.mli').')')
let s:l['ocaml_mli'] = funcref#Function('return vim_addon_toggle#Substitute('.string('\.mli').','.string('.ml').')')


call on_thing_handler#AddOnThingHandler('g', funcref#Function('vim_addon_ocaml#GFHandler'))
