
let s:dir = expand('<sfile>',':h:h')

exec scriptmanager#DefineAndBind('s:c','g:vim_addon_ocaml','{}')

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

"
" A)
" "x,typing" completion:
" Try to find a function you can pass x as argument:
" "abc",<c-x><c-o>:
" - (String.split "abc")
" - (String.concat "abc")
"
" B)
" "typing" completion:
" try to find useful stuff in scope and present this (TODO incomplete)
fun! vim_addon_ocaml#OcamlComplete(findstart, base)
  if a:findstart
    let [bc,ac] = vim_addon_ocaml#BcAc()
    let s:match_text = matchstr(bc, '\zs[^()[\]{}\t ]*$')
    let s:start = len(bc)-len(matchstr(bc,'\S*$'))
    return s:start
  else


    let patterns = vim_addon_completion#AdditionalCompletionMatchPatterns(a:base
        \ , "ocaml_completion", { 'match_beginning_of_string': 1})
    let additional_regex = get(patterns, 'vim_regex', "")

    let matches = []
    let s:dot_compl = split(a:base,'\.',1)
    let s:comma_compl = split(a:base,",",1)
    let s:type_compl = split(a:base,":",1)

    if len(s:comma_compl) == 2
      " A) completion
      silent! unlet g:tmp

      " move cursor to begin of thing at file. "x," move to x.
      let pos = getpos('.')
      let newpos = pos
      " [bufnum, lnum, col, off]
      let newpos[2] = s:start
      call setpos('.', newpos)
      let type = vim_addon_ocaml#TypeAtCursor()

      call vim_addon_ocaml#ComplByType(g:tmp, s:comma_compl[0], s:comma_compl[1], additional_regex, 1)
      " get type of x

      " for more complex types than string etc more complex processing has to
      " be dne here..

      " find all val lines in .mli files which take that argument
    elseif len(s:type_compl) == 2
      call vim_addon_ocaml#ComplByType(s:type_compl[1], "arg", s:type_compl[0], additional_regex, 0)


    elseif len(s:dot_compl) == 2
      call vim_addon_ocaml#ComplByName(s:dot_compl[1], additional_regex, {'mli_and_prefix': s:dot_compl[0]} )

    else
      " B) completion (names only)
      " add all vars in this buf
      for l in getline(0,line('$'))
        let name = matchstr(l, '\<let\s*\zs\S\+\ze')
        if name =~ '^'.a:base || (additional_regex != '' && name =~ additional_regex)
          call complete_add({
                \  'word': name
                \ ,'menu': "local buf"
                \ } )
        endif
      endfor

      if complete_check() != 0 | return [] | endif
      " and everything which could possibly be imported (which can be found by
      " tag files)
      call vim_addon_ocaml#ComplByName(a:base, additional_regex)
    endif
    return matches
  endif
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

fun! vim_addon_ocaml#ComplByType(type, arg, pat, additional_regex, parenthesis)
  " let g:cmds = []
  for mli in vim_addon_ocaml#MLIFiles()
    let pat = a:pat == '' ? '.*' : a:pat
    let type = substitute(a:type, '->','\\s*->\\s*','g')

    let file = vim_addon_ocaml#ParseMLICached(mli)
    for val in file['vals']
      if  (a:pat == '' || val['name'] =~ '^'.a:pat || (a:additional_regex != "" && val['name'] =~ a:additional_regex))
      \ && (type == '' || val['type'] =~ type)
        call complete_add({
              \  'word': a:parenthesis ? '('.val['name'].' '.a:arg.')' : val['name']
              \ ,'menu': val['args'].'->'.val['return_type'].' '.fnamemodify(mli, ':t')
              \ ,'dup':1
              \ } )
      endif
    endfor
    if complete_check() != 0 | return | endif
  endfor

endf

fun! vim_addon_ocaml#ComplByName(pat, additional_regex, ...)
  let opts = a:0 > 0 ? a:1 : {}
  " if option is set String. completion is used
  " so only complete with string.mli and append String. to the completion
  " string (this can be done smarter - who cares ?
  let mli_and_prefix = get(opts, 'mli_and_prefix', '')
  let mli_and_prefix_lower = tolower(mli_and_prefix)
  let prefix = mli_and_prefix == '' ? '' :  mli_and_prefix.'.'

  for mli in vim_addon_ocaml#MLIFiles()
    let mli_tail = fnamemodify(mli, ':t')
    if mli_and_prefix != '' && tolower(mli_tail) != mli_and_prefix_lower.'.mli'
      continue
    endif

    let pat = a:pat == '' ? '.*' : a:pat
    let file = vim_addon_ocaml#ParseMLICached(mli)
    for val in file['vals']
      if val['name'] =~ '^'.a:pat || a:pat == '' || (a:additional_regex != "" && val['name'] =~ a:additional_regex)
        call complete_add({
              \  'word': prefix.val['name']
              \ ,'menu': val['args'].'->'.val['return_type'].' '.mli_tail
              \ ,'dup':1
              \ } )
      endif
    endfor
    if complete_check() != 0 | return | endif
  endfor
endf

function! vim_addon_ocaml#BcAc()
  let pos = col('.') -1
  let line = getline('.')
  return [strpart(line,0,pos), strpart(line, pos, len(line)-pos)]
endfunction

fun! vim_addon_ocaml#GlobalVals(pattern)
  " TODO cache file list. This is slow!
  let tag_files = {}
endf

" find files of tag file, use FilesOfTagFileCached {{{
let s:ScanTagFile =  {'func': funcref#Function('vim_addon_ocaml#FilesOfTagFile'), 'version' : 5, 'use_file_cache' :1}
fun! vim_addon_ocaml#FilesOfTagFile(filename)
  return split(system("sed -n '".'s/^[^\t]*\t\([^\t]*.mli\)\t.*/\1/p'."' ".shellescape(a:filename)." | sort | uniq "),"\n")
endf

fun! vim_addon_ocaml#FilesOfTagFileCached(file)
  return cached_file_contents#CachedFileContents(a:file, s:ScanTagFile)
endf

let s:ScanMLI =  {'func': funcref#Function('vim_addon_ocaml#ParseMLI'), 'version' : 4, 'use_file_cache' :1}
fun! vim_addon_ocaml#ParseMLI(filename)
  let pat='.*'
  let cmd = "sed -n '".'s/^\(external\|val\)[ \t]\+\('.pat.'[ \t]*:[ \t]*.*\)/\2/p'."' ".shellescape(a:filename)
  " call add(g:cmds, cmd)
  let lines = split(system(cmd),"\n")

  let vals = []
  let file = {'vals': vals}

  for l in lines
    let name_type = matchlist(l,'\(\S\+\)\s*:\s*\(.*\)->\s*\([^=]*\)')
    if len(name_type) > 2
      let val = {
        \ 'line' : l,
        \ 'name' : name_type[1],
        \ 'args' : substitute(name_type[2],'\s*$','',''),
        \ 'return_type' :  name_type[3]
        \ }
      let val['type'] = val['args'].' -> '.val['return_type']
      call add(vals, val)
    endif
  endfor
  return file
endf

fun! vim_addon_ocaml#ParseMLICached(f)
  return cached_file_contents#CachedFileContents(a:f, s:ScanMLI)
endf

"}}}

fun! vim_addon_ocaml#MLIFiles()
  let mlis = {}
  for tagfile in tagfiles()
    if filereadable(tagfile)
      let tagfile_dir = fnamemodify(tagfile,':h')
      for f in vim_addon_ocaml#FilesOfTagFileCached(tagfile)
        let abs = tagfile_dir.'/'.f
        if filereadable(abs)
          let mlis[expand(abs)] = 1
        elseif filereadable(f)
          let mlis[expand(f)] = 1
        endif
      endfor
    endif
  endfor

  if has_key(s:c, "provide_additional_mlis")
    let F = s:c['provide_additional_mlis']
    for mli in call(additional_mlis)
      let mlis[expand(mli)] = 1
    endfor
  endif

  return keys(mlis)
endf

fun! vim_addon_ocaml#FunctionByType()
  let typeRegex = input('typeRegex :')

  let list = []

  for mli in vim_addon_ocaml#MLIFiles()
    let file = vim_addon_ocaml#ParseMLICached(mli)
    for val in file['vals']
      if val['line'] =~ typeRegex
        call add(list,  val['line'].' | '.mli)
      endif
    endfor
    if complete_check() != 0 | return | endif
  endfor

  let selection =  tlib#input#List("s","select func", list)

  echoe "TODO jumpt o location"

endf

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
  let split = split(a:thing, '\.')
  if len(split) == 2
    for m in taglist('^'.split[1])
      let basename = fnamemodify(m.filename, ':t')
      " module match and name match: high priority:
      let break = tolower(basename) == tolower(split[0]).'.mli'
      call add(r, { 'break': break, 'filename' : m.filename, 'line_nr': m.cmd, 'info' : a:prefix } )
    endfor
  endif
  return r
endf
"}}}
"
"on_thing_handler#HandleOnThing()
