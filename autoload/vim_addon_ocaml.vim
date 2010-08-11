
let s:dir = expand('<sfile>',':h:h')


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
    let [bc,ac] = haskellcomplete#BcAc()
    let s:match_text = matchstr(bc, '\zs[^()[\]{}\t ]*$')
    let s:start = len(bc)-len(matchstr(bc,'\S*$'))
    return s:start
  else
    let matches = []
    let s:comma_compl = split(s:match_text,",",1)
    let s:type_compl = split(s:match_text,":",1)

    if len(s:comma_compl) == 2
      " A) completion
      silent! unlet g:tmp
      " move to cursor pos, so that type can be determined
      exec 'normal  '.s:start.'|'
      " get type of x
      py << EOF
py parseOCamlAnnot()
(begin_mark,end_mark) = get_marks(mode)
let g:tmp = annot.get_type(begin_mark, end_mark)
EOF
      py let g:tmp = 
      " silent! unlet g:tmp

      " for more complex types than string etc more complex processing has to
      " be dne here..

      " find all val lines in .mli files which take that argument
      call vim_addon_ocaml#ComplByType(g:tmp, s:comma_compl[0], s:comma_compl[1])
    elseif len(s:type_compl) == 2
      call vim_addon_ocaml#ComplByType(s:type_compl[1], "arg", s:type_compl[0])
    else
      " B) completion (names only)
      " add all vars in this buf
      for l in getline(0,line('$'))
        let name = matchstr(l, '\<let\s*\zs\S\+\ze')
        call complete_add({
              \  'word': name
              \ ,'menu': "local buf"
              \ } )
      endfor

      if complete_check() != 0 | return [] | endif
      " and everything which could possibly be imported (which can be found by
      " tag files)
      call vim_addon_ocaml#ComplByName(s:match_text)
    endif
    return matches
  endif
endf

fun! vim_addon_ocaml#ComplByType(type, arg, pat)
  " let g:cmds = []
  for mli in vim_addon_ocaml#MLIFiles()
    " TODO enhance pattern!
    let pat = a:pat == '' ? '.*' : a:pat.'.*'
    let cmd = "sed -n '".'s/^\(external\|val\)[ \t]\+\('.pat.'[ \t]*:[ \t]*.*'.a:type.'.*\)/\2/p'."' ".shellescape(mli)
    " call add(g:cmds, cmd)
    let lines = split(system(cmd),"\n")

    for l in lines
      let name_type = split(l,"\s*:\s*")
      " TODO put name at position of arg ?
      " echo "adding ".string(name_type).' '.mli
      call complete_add({
            \  'word': '('.name_type[0].' '.a:arg.')'
            \ ,'menu': name_type[1].' '.fnamemodify(mli, ':t')
            \ } )
    endfor
    if complete_check() != 0 | return | endif
  endfor
endf

fun! vim_addon_ocaml#ComplByName(pat)
  for mli in vim_addon_ocaml#MLIFiles()
    " TODO enhance pattern!
    let pat = a:pat == '' ? '.*' : a:pat
    let cmd = "sed -n '".'s/^\(external\|val\)[ \t]\+\('.pat.'[ \t]*:[ \t]*.*\)/\2/p'."' ".shellescape(mli)
    " call add(g:cmds, cmd)
    let lines = split(system(cmd),"\n")

    for l in lines
      let name_type = split(l,"\s*:\s*")
      if len(name_type) == 2
        " echo "adding ".string(name_type).' '.mli
        call complete_add({
              \  'word': name_type[0]
              \ ,'menu': name_type[1].' '.fnamemodify(mli, ':t')
              \ } )
      endif
    endfor
    if complete_check() != 0 | return | endif
  endfor
endf

function! haskellcomplete#BcAc()
  let pos = col('.') -1
  let line = getline('.')
  return [strpart(line,0,pos), strpart(line, pos, len(line)-pos)]
endfunction

fun! vim_addon_ocaml#GlobalVals(pattern)
  " TODO cache file list. This is slow!
  let tag_files = {}
endf

" find files of tag file, use FilesOfTagFileCached {{{
let s:ScanTagFile =  {'func': funcref#Function('vim_addon_ocaml#FilesOfTagFile'), 'version' : 5}
fun! vim_addon_ocaml#FilesOfTagFile(filename)
  return split(system("sed -n '".'s/^[^\t]*\t\([^\t]*.mli\)\t.*/\1/p'."' ".shellescape(a:filename)." | sort | uniq "),"\n")
endf

fun! vim_addon_ocaml#FilesOfTagFileCached(file)
  return cached_file_contents#CachedFileContents(a:file, s:ScanTagFile)
endf
"}}}

fun! vim_addon_ocaml#MLIFiles()
  let mlis = []
  for tagfile in tagfiles()
    if filereadable(tagfile)
      let tagfile_dir = fnamemodify(tagfile,':h')
      for f in vim_addon_ocaml#FilesOfTagFileCached(tagfile)
        let abs = tagfile_dir.'/'.f
        if filereadable(abs)
          call add(mlis, abs)
        elseif filereadable(f)
          call add(mlis, f)
        endif
      endfor
    endif
  endfor
  return mlis
endf


