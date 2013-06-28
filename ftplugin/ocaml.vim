" Marc Weber: TODO review

" Language:    OCaml
" Maintainer:  David Baelde        <firstname.name@ens-lyon.org>
"              Mike Leary          <leary@nwlink.com>
"              Markus Mottl        <markus.mottl@gmail.com>
"              Stefano Zacchiroli  <zack@bononia.it>
" URL:         http://www.ocaml.info/vim/ftplugin/ocaml.vim
" Last Change: 2009 Nov 10 - Added support for looking up definitions
"                            (MM for <ygrek@autistici.org>)
"              2009 Sep 10 - Fixed .annot support for OCaml 3.11
"                            (MM for <ygrek@autistici.org>)
"              2006 May 01 - Added .annot support for file.whateverext (SZ)
"
"              2013 Jun 16   Made loading python lazy, adding efm trace line
"                            move python code into its own file
"                            always provide mappings, even if python is not
"                            supported (will show error when its used)
"                            moving vim_addon_ocaml#OMLetFoldLevel into
"                            autoload/vim_addon_ocaml.vim - drop some finish
"                            guards.
"
"                            Rewrite some mappings I care about using s:c lhs
"                            configuration

if !exists('g:addon_ocaml') | let g:addon_ocaml = {} | endif | let s:c = g:addon_ocaml

let s:c.map_print_type = get(s:c, 'map_print_type', '\t')
let s:c.map_goto = get(s:c, 'map_goto', '\d')


" Error handling -- helps moving where the compiler wants you to go
let s:cposet=&cpoptions
set cpo-=C

" Add mappings, unless the user didn't want this.
if !exists("no_plugin_maps") && !exists("no_ocaml_maps")
  " (un)commenting
  if !hasmapto('<Plug>Comment')
    nmap <buffer> <LocalLeader>c <Plug>LUncomOn
    vmap <buffer> <LocalLeader>c <Plug>BUncomOn
    nmap <buffer> <LocalLeader>C <Plug>LUncomOff
    vmap <buffer> <LocalLeader>C <Plug>BUncomOff
  endif

  nnoremap <buffer> <Plug>LUncomOn mz0i(* <ESC>$A *)<ESC>`z
  nnoremap <buffer> <Plug>LUncomOff :s/^(\* \(.*\) \*)/\1/<CR>:noh<CR>
  vnoremap <buffer> <Plug>BUncomOn <ESC>:'<,'><CR>`<O<ESC>0i(*<ESC>`>o<ESC>0i*)<ESC>`<
  vnoremap <buffer> <Plug>BUncomOff <ESC>:'<,'><CR>`<dd`>dd`<

  if !hasmapto('<Plug>Abbrev')
    iabbrev <buffer> ASF (assert false (* XXX *))
    iabbrev <buffer> ASS (assert (0=1) (* XXX *))
  endif
endif

" Let % jump between structure elements (due to Issac Trotts)
let b:mw = ''
let b:mw = b:mw . ',\<let\>:\<and\>:\(\<in\>\|;;\)'
let b:mw = b:mw . ',\<if\>:\<then\>:\<else\>'
let b:mw = b:mw . ',\<\(for\|while\)\>:\<do\>:\<done\>,'
let b:mw = b:mw . ',\<\(object\|sig\|struct\|begin\)\>:\<end\>'
let b:mw = b:mw . ',\<\(match\|try\)\>:\<with\>'
let b:match_words = b:mw

let b:match_ignorecase=0

" switching between interfaces (.mli) and implementations (.ml)
if !exists("g:did_ocaml_switch")
  let g:did_ocaml_switch = 1
  map <LocalLeader>s :call OCaml_switch(0)<CR>
  map <LocalLeader>S :call OCaml_switch(1)<CR>
  fun OCaml_switch(newwin)
    if (match(bufname(""), "\\.mli$") >= 0)
      let fname = substitute(bufname(""), "\\.mli$", ".ml", "")
      if (a:newwin == 1)
        exec "new " . fname
      else
        exec "arge " . fname
      endif
    elseif (match(bufname(""), "\\.ml$") >= 0)
      let fname = bufname("") . "i"
      if (a:newwin == 1)
        exec "new " . fname
      else
        exec "arge " . fname
      endif
    endif
  endfun
endif

" Folding support

" Get the modeline because folding depends on indentation
let s:s = line2byte(line('.'))+col('.')-1
if search('^\s*(\*:o\?caml:')
  let s:modeline = getline(".")
else
  let s:modeline = ""
endif
if s:s > 0
  exe 'goto' s:s
endif

" Get the indentation params
let s:m = matchstr(s:modeline,'default\s*=\s*\d\+')
if s:m != ""
  let s:idef = matchstr(s:m,'\d\+')
elseif exists("g:omlet_indent")
  let s:idef = g:omlet_indent
else
  let s:idef = 2
endif
let s:m = matchstr(s:modeline,'struct\s*=\s*\d\+')
if s:m != ""
  let s:i = matchstr(s:m,'\d\+')
elseif exists("g:omlet_indent_struct")
  let s:i = g:omlet_indent_struct
else
  let s:i = s:idef
endif

" Set the folding method
if exists("g:ocaml_folding")
  setlocal foldmethod=expr
  setlocal foldexpr=vim_addon_ocaml#OMLetFoldLevel(v:lnum)
endif

" - Only definitions below, executed once -------------------------------------

function! s:topindent(lnum)
  let l = a:lnum
  while l > 0
    if getline(l) =~ '\s*\%(\<struct\>\|\<sig\>\|\<object\>\)'
      return indent(l)
    endif
    let l = l-1
  endwhile
  return -s:i
endfunction

" .annot file support {{{1

" Vim support for OCaml .annot files (requires Vim with python support)
"
" Executing OCamlPrintType(<mode>) function will display in the Vim bottom
" line(s) the type of an ocaml value getting it from the corresponding .annot
" file (if any).  If Vim is in visual mode, <mode> should be "visual" and the
" selected ocaml value correspond to the highlighted text, otherwise (<mode>
" can be anything else) it corresponds to the literal found at the current
" cursor position.
"
" .annot files are parsed lazily the first time OCamlPrintType is invoked; is
" also possible to force the parsing using the OCamlParseAnnot() function.
"
" Typing '<LocalLeader>t' (usually ',t') will cause OCamlPrintType function 
" to be invoked with the right argument depending on the current mode (visual 
" or not).
"
" Copyright (C) <2003-2004> Stefano Zacchiroli <zack@bononia.it>
"
" Created:        Wed, 01 Oct 2003 18:16:22 +0200 zack
" LastModified:   Wed, 25 Aug 2004 18:28:39 +0200 zack
" LastModified:   June 2013 Marc Weber (moving py code into autoload/python-code.py)
"
" '<LocalLeader>d' will find the definition of the name under the cursor
" and position cursor on it (only for current file) or print fully qualified name
" (for external definitions). (ocaml >= 3.11)
"
" Additionally '<LocalLeader>t' will show whether function call is tail call
" or not. Current implementation requires selecting the whole function call
" expression (in visual mode) to work. (ocaml >= 3.11)
"
" Copyright (C) 2009 <ygrek@autistici.org>

" Its important to be lazy for speed reasons. On Windows the by .dll is load
" lazily. Thus only initialize if the user acutally wants to use Snipmate
let s:plugin_root = expand('<sfile>:h:h')
fun! s:c.Py(command)
  if !has_key(s:c, 'PyCommand')
    if !has_key(s:c, 'PyCommand')
      try
        " try python3
        py3 import vim; vim.command('let g:addon_ocaml.PyCommand = "py3 "')
      catch /.*/ 
        try
          " try python2
          py import vim; vim.command('let g:addon_ocaml.PyCommand = "py "')
        catch /.*/ | endtry
      endtry
    endif
  endif

  if !has_key(s:c, 'PyCommand') | throw "no working python found" | endif

  " load py code:
  if !has_key(s:c, 'did_python_setup')
    exec 'pyfile '.fnameescape(s:plugin_root.'/autoload/python-code.py')
    let s:c.did_python_setup = 1
  endif

  " run the python command
  exec s:c.PyCommand.a:command
endf


fun! OCamlParseAnnot()
  call s:c.Py("parseOCamlAnnot()")
endfun

exec 'nnoremap <buffer> '.s:c.map_print_type." :call g:addon_ocaml.Py('printOCamlType(\"normal\")')<CR>"
exec 'vnoremap  <buffer> '.s:c.map_print_type." :call g:addon_ocaml.Py('printOCamlType(\"visual\")')<CR>"
exec 'nnoremap <buffer> '.s:c.map_goto." :call g:addon_ocaml.Py('gotoOCamlDefinition(\"visual\")')<CR>"
exec 'vnoremap <buffer> '.s:c.map_goto." :call g:addon_ocaml.Py('gotoOCamlDefinition(\"normal\")')<CR>"

" }}}

let &cpoptions=s:cposet
unlet s:cposet

" vim:sw=2
