
let s:dir = expand('<sfile>',':h:h')

exec vam#DefineAndBind('s:c','g:vim_addon_ocaml','{}')

if !exists('g:vim_ocaml_ctags_command_recursive')
  let g:vim_ocaml_ctags_command_recursive = 'ctags -R'
endif

" sources: list of { dir: .. }
" to scan for 
fun! vim_addon_ocaml#SetupOcamlProject(sources)
  call vim_addon_ocaml#Tag_All(sources)

  let g:ocaml_sources = a:sources

  for source in g:ocaml_sources
    call vim_addon_ocaml#TagAndAdd(source.dir, '.')
  endfor

endf

" TODO refactor, shared by vim-haxe ?
fun! vim_addon_ocaml#TagAndAdd(d, pat)
  call vcs_checkouts#ExecIndir([{'d': a:d, 'c': g:vim_ocaml_ctags_command_recursive.' '.a:pat}])
  exec 'set tags+='.a:d.'/tags'
endf

" dosen't echo
" TODO merge with original code
fun! vim_addon_ocaml#TypeAtCursor()
  silent! unlet g:tmp
  py << EOF
parseOCamlAnnot()

def vimQuote(s):
  return '"%s"' % s.replace('"', '\\"').replace("\n", "\\n")

def ocaml_type_current_pos():
  try:
    (begin_mark,end_mark) = get_marks("normal")
    return annot.get_type(begin_mark, end_mark)
  except:
    return ""

vim.command("let g:tmp = %s" % vimQuote(ocaml_type_current_pos()) )
EOF
  return g:tmp
endfun

function! vim_addon_ocaml#BcAc()
  let pos = col('.') -1
  let line = getline('.')
  return [strpart(line,0,pos), strpart(line, pos, len(line)-pos)]
endfunction

fun! vim_addon_ocaml#GlobalVals(pattern)
  " TODO cache file list. This is slow!
  let tag_files = {}
endf

"}}}

" experimental
fun! vim_addon_ocaml#GotoThingHandler()
  let r = []
  let thing = expand('<cword>')
  " try to find type
  let t = vim_addon_ocaml#TypeAtCursor()
  if t != ""
    call extend(r, vim_addon_ocaml#GotoThingHandlerItems(t, 'type') )
  endif

  " name
  for t in [expand('<cWORD>'), thing]
    call extend(r, vim_addon_ocaml#GotoThingHandlerItems(t, 'name') )
  endfor
  return r
" a afile path:  "filename.file"
" a dict: { 'break': 1, 'filename' : file [, 'line_nr' line nr ] [, 'info' : 'shown before filename'] }
endf

" goto thing at cursor implementation {{{
fun! vim_addon_ocaml#GotoThingHandlerItems(thing, prefix)
  let r = []
  let split_ = split(a:thing, '\.')
  if len(split_) > 2
    " ExtString.String.nsplit -> [ExtString, nsplit]
    let split_ = [split_[0], split_[-1]]
  endif
  if len(split_) == 2
    for m in taglist('^'.split_[1].'$')
      let basename = fnamemodify(m.filename, ':t')
      " module match and name match: high priority:
      let top = basename =~? split_[0].'.ml[i]\?$'
      call add(r, { 'top': top, 'filename' : m.filename, 'line_nr': m.cmd, 'info' : a:prefix } )
    endfor

    if a:prefix == 'name'
      call  vim_addon_ocaml#FindInLocalMls(tolower(split_[0]), split_[1], r)
    endif
  else
    if a:prefix == 'name'
      call vim_addon_ocaml#FindInLocalMls('*', split_[0], r)
    endif
  endif
  return r
endf

"}}}
"
"on_thing_handler#HandleOnThing()


function! vim_addon_ocaml#OMLetFoldLevel(l)

  " This is for not merging blank lines around folds to them
  if getline(a:l) !~ '\S'
    return -1
  endif

  " We start folds for modules, classes, and every toplevel definition
  if getline(a:l) =~ '^\s*\%(\<val\>\|\<module\>\|\<class\>\|\<type\>\|\<method\>\|\<initializer\>\|\<inherit\>\|\<exception\>\|\<external\>\)'
    exe 'return ">' (indent(a:l)/s:i)+1 '"'
  endif

  " Toplevel let are detected thanks to the indentation
  if getline(a:l) =~ '^\s*let\>' && indent(a:l) == s:i+s:topindent(a:l)
    exe 'return ">' (indent(a:l)/s:i)+1 '"'
  endif

  " We close fold on end which are associated to struct, sig or object.
  " We use syntax information to do that.
  if getline(a:l) =~ '^\s*end\>' && synIDattr(synID(a:l, indent(a:l)+1, 0), "name") != "ocamlKeyword"
    return (indent(a:l)/s:i)+1
  endif

  " Folds end on ;;
  if getline(a:l) =~ '^\s*;;'
    exe 'return "<' (indent(a:l)/s:i)+1 '"'
  endif

  " Comments around folds aren't merged to them.
  if synIDattr(synID(a:l, indent(a:l)+1, 0), "name") == "ocamlComment"
    return -1
  endif

  return '='
endfunction

fun! vim_addon_ocaml#GFHandler() abort
  let res = [ expand(expand('%:h').'/'.matchstr(expand('<cWORD>'),'[^;()[\]]*')) ]
  for match in [matchstr(getline('.'), 'import\s*\zs[^;) \t]\+\ze'), matchstr(getline('.'), 'call\S*\s*\zs[^;) \t]\+\ze')]
    if match == "" | continue | endif
    call add(res, expand('%:h').'/'.match)
  endfor

  let r = matchlist(getline('.'), 'Called from file "\([^"]\+\)", line \(\d\+\)')
  if empty(r)
    return []
  else
    return [{ 'break': 1, 'filename' : r[1], 'line_nr': r[2] }]
  endif
endf


fun! vim_addon_ocaml#SpotAtCursor()
  let p = getpos('.')
  let r = {}
  let state = "out"
  let type = []
  for l in split(system('ocamlspot '.expand('%').':l'.p[1].'c'.p[2], ), "\n")
    let m = matchlist(l, '^\([^:]\+\): \(.*\)')
    if l =~ '^BYE!'
      let r[key] = lines
    elseif !empty(m) && m[1] != ''
      if exists('lines') | let r[key] = lines | endif
      let key = m[1]
      let lines = [m[2]]
    elseif lines != [] && exists('key')
      call add(lines, l)
    endif
  endfor
  if has_key(r, 'Spot')
    " l.Spot[0] looks like this: </pr/ocaml/lib_executable/mylib/pMap.ml:l21c4b448:l21c7b451>
    let m = matchlist(r.Spot[0], '^<\([^:]\+\):l\(\d\+\)c\(\d\+\)')
    let r.Spot = {'file': m[1], 'line': m[2], 'col' : m[3]}
  endif
  return r
endf

fun! vim_addon_ocaml#Type(mode)
  let d = vim_addon_ocaml#SpotOrAnnot()
  if d.ext == 'annot'
    call g:addon_ocaml.Py('printOCamlType("normal")')
  else
    let d = vim_addon_ocaml#SpotAtCursor()
    call buf_utils#GotoBuf('OCAML_TYPES', {'create_cmd': 'sp'})
    let lines = has_key(d, 'Val') ? d.Val : d.Type
    call append('$', lines)
    normal G
    wincmd w
  endif
endf

fun! vim_addon_ocaml#Goto(mode)
  let d = vim_addon_ocaml#SpotOrAnnot()
  if d.ext == 'annot'
    call g:addon_ocaml.Py('gotoOCamlDefinition("visual")')
  else
    let d = vim_addon_ocaml#SpotAtCursor()['Spot']
    exec 'e '.fnameescape(d.file)
    exec d.line
    exec 'normal '. d.col .'|'
  endif
endf


fun! vim_addon_ocaml#OCamlParseAnnot()
  call s:c.Py("parseOCamlAnnot()")
endfun

fun! vim_addon_ocaml#SpotOrAnnot()
  let cmt = expand('%:r').'.cmt'
  let annot = expand('%:r').'.annot'
  if filereadable(cmt)
    " use ocamlspot
    return {'ext' : 'cmt' }
  elseif filereadable(annot)
    " use .annot file
    return {'ext' : 'annot' }
  else
    throw "neither .annot nor .cmt (ocamlspot) file found"
  endif
endf

