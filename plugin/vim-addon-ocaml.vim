let s:efm = 'set efm=%+AFile\ \"%f\"\\,\ line\ %l\\,\ characters\ %c-%*\\d:,%Z%m'
call actions#AddAction('ocamlc current file', {'action': funcref#Function('actions#CompileRHSSimple', {'args': [[s:efm], ["ocamlc", '-o', funcref#Function('return expand("%:r:t")'), funcref#Function('return expand("%")')]]})})
call actions#AddAction('ocamlc run result', {'action': funcref#Function('actions#CompileRHSSimple', {'args': [[], [funcref#Function('return "./".expand("%:r:t")')]]})})

call actions#AddAction('ocamlopt current file', {'action': funcref#Function('actions#CompileRHSSimple', {'args': [[s:efm], ["ocamlopt", '-o', funcref#Function('return expand("%:r:t")'), funcref#Function('return expand("%")')]]})})
