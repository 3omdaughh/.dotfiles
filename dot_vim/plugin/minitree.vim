" minitree.vim — minimalist file explorer
" Commands: :MiniTree  :MiniTreeToggle  :MiniTreeFind
" Press ? inside the tree for the key list.

if exists('g:loaded_minitree') || &compatible
  finish
endif
let g:loaded_minitree = 1

let g:minitree_width       = get(g:, 'minitree_width', 30)
let g:minitree_show_hidden = get(g:, 'minitree_show_hidden', 0)

let s:expanded = {}
let s:clip     = {'path': '', 'mode': ''}
let s:root     = ''
let s:hidden   = g:minitree_show_hidden

" ------------------------------------------------------- filetype dispatch
"
" Rule: anything you would edit opens in Vim. Everything else is handed to an
" external viewer. Unknown extensions fall back to Vim unless `file` reports
" the contents as binary.

" extension groups -> external command; override with g:minitree_openers
let s:opener_groups = {
      \ 'mp4,mkv,avi,mov,webm,flv,wmv,m4v,mpg,mpeg,ogv,3gp,ts':      'vlc',
      \ 'mp3,flac,wav,m4a,aac,ogg,oga,opus,wma,mid,midi':            'vlc',
      \ 'pdf,ps,eps,djvu,cbz':                                       'zathura',
      \ 'doc,docx,odt,rtf,xls,xlsx,ods,csv,ppt,pptx,odp,odg,odf':    'libreoffice',
      \ 'png,jpg,jpeg,gif,bmp,webp,tif,tiff,ico,avif,heic,xpm,ppm':  'xdg-open',
      \ 'zip,tar,gz,bz2,xz,7z,rar,zst,iso,deb,rpm':                  'xdg-open',
      \ 'ttf,otf,woff,woff2,epub,mobi,blend,psd,xcf,sqlite,db':      'xdg-open',
      \ }

" text extensions -> always Vim
let s:text_groups = join([
      \ 'c,h,cc,cpp,cxx,hpp,hh,hxx,ino,m,mm',
      \ 'py,pyw,rb,pl,pm,lua,tcl,r,jl,php,ex,exs,erl,hrl',
      \ 'js,mjs,cjs,jsx,ts,tsx,vue,svelte,coffee',
      \ 'go,rs,java,kt,kts,scala,swift,cs,fs,vb,dart,groovy',
      \ 'hs,lhs,ml,mli,clj,cljs,edn,lisp,el,scm,rkt,nim,zig,v,d,cr,pas,f,f90,for,asm,s',
      \ 'sh,bash,zsh,fish,ksh,ps1,bat,cmd,awk,sed,vim,vimrc',
      \ 'sql,graphql,gql,proto,thrift,idl',
      \ 'conf,cfg,ini,toml,yaml,yml,json,json5,jsonc,xml,plist,properties,env,rc,desktop,service,spec',
      \ 'html,htm,xhtml,css,scss,sass,less,styl,jinja,j2,twig,erb,ejs,hbs,mustache,pug,haml',
      \ 'txt,md,markdown,rst,adoc,asciidoc,org,tex,latex,ltx,sty,cls,bib,log,diff,patch,srt,vtt,po,pot',
      \ 'make,mk,cmake,gradle,sbt,bazel,bzl,nix,dockerfile,gitignore,gitconfig,editorconfig,lock',
      \ ], ',')

" flatten "a,b,c" keys into ext -> cmd
function! s:Flatten(groups) abort
  let l:map = {}
  for [l:exts, l:cmd] in items(a:groups)
    for l:e in split(l:exts, ',')
      let l:map[l:e] = l:cmd
    endfor
  endfor
  return l:map
endfunction

let s:openers = s:Flatten(s:opener_groups)
call extend(s:openers, s:Flatten(get(g:, 'minitree_openers', {})))

let s:text_ext = {}
for s:e in split(s:text_groups . ',' . get(g:, 'minitree_text_extra', ''), ',')
  if !empty(s:e)
    let s:text_ext[s:e] = 1
  endif
endfor
unlet! s:e

" extensionless names that are still text
let s:text_names = {}
for s:n in ['makefile', 'dockerfile', 'rakefile', 'gemfile', 'vagrantfile',
      \ 'license', 'readme', 'changelog', 'authors', 'copying', 'install',
      \ 'notes', 'todo', 'pkgbuild', 'cmakelists.txt']
  let s:text_names[s:n] = 1
endfor
unlet! s:n

function! s:IsBinary(path) abort
  if !executable('file')
    return 0
  endif
  let l:enc = system('file -b --mime-encoding -- ' . shellescape(a:path))
  return l:enc =~# 'binary'
endfunction

" returns the external command for a path, or '' when Vim should open it
function! s:OpenerFor(path) abort
  let l:ext  = tolower(fnamemodify(a:path, ':e'))
  let l:name = tolower(fnamemodify(a:path, ':t'))

  if has_key(s:text_ext, l:ext) || has_key(s:text_names, l:name)
    return ''
  endif
  if has_key(s:openers, l:ext)
    return s:openers[l:ext]
  endif
  if empty(l:ext)
    return ''
  endif
  " unknown extension: trust the content, prefer Vim
  return s:IsBinary(a:path) ? 'xdg-open' : ''
endfunction

function! s:LaunchExternal(cmd, path) abort
  let l:cmd = a:cmd
  if !executable(l:cmd)
    if l:cmd ==# 'libreoffice' && executable('soffice')
      let l:cmd = 'soffice'
    elseif executable('xdg-open')
      let l:cmd = 'xdg-open'
    else
      call s:Err('no handler found for ' . fnamemodify(a:path, ':t'))
      return
    endif
  endif
  silent call system(l:cmd . ' ' . shellescape(a:path) . ' >/dev/null 2>&1 &')
  redraw!
  echo l:cmd . ': ' . fnamemodify(a:path, ':t')
endfunction

" ---------------------------------------------------------------- helpers

function! s:Err(msg) abort
  echohl ErrorMsg | echomsg 'minitree: ' . a:msg | echohl None
endfunction

function! s:Join(dir, name) abort
  return substitute(a:dir, '/\+$', '', '') . '/' . a:name
endfunction

function! s:CmpI(a, b) abort
  let l:x = tolower(a:a)
  let l:y = tolower(a:b)
  return l:x ==# l:y ? 0 : (l:x > l:y ? 1 : -1)
endfunction

" returns [dirs, files], each sorted case-insensitively
function! s:Listdir(dir) abort
  let l:names = []
  try
    if exists('*readdir')
      let l:names = readdir(a:dir)
    else
      let l:names = map(glob(a:dir . '/*', 1, 1) + glob(a:dir . '/.*', 1, 1),
            \ 'fnamemodify(v:val, ":t")')
      call filter(l:names, 'v:val !=# "." && v:val !=# ".."')
    endif
  catch
    return [[], []]
  endtry

  if !s:hidden
    call filter(l:names, 'v:val[0] !=# "."')
  endif

  let l:dirs = []
  let l:files = []
  for l:n in l:names
    if isdirectory(s:Join(a:dir, l:n))
      call add(l:dirs, l:n)
    else
      call add(l:files, l:n)
    endif
  endfor
  return [sort(l:dirs, function('s:CmpI')), sort(l:files, function('s:CmpI'))]
endfunction

" ---------------------------------------------------------------- render

function! s:Build(dir, depth, lines, nodes) abort
  let [l:dirs, l:files] = s:Listdir(a:dir)
  let l:pad = repeat('  ', a:depth)

  for l:d in l:dirs
    let l:p = s:Join(a:dir, l:d)
    let l:open = has_key(s:expanded, l:p)
    call add(a:lines, l:pad . (l:open ? '▾ ' : '▸ ') . l:d . '/')
    call add(a:nodes, {'path': l:p, 'dir': 1})
    if l:open
      call s:Build(l:p, a:depth + 1, a:lines, a:nodes)
    endif
  endfor

  for l:f in l:files
    call add(a:lines, l:pad . '  ' . l:f)
    call add(a:nodes, {'path': s:Join(a:dir, l:f), 'dir': 0})
  endfor
endfunction

function! s:Render(...) abort
  let l:keep = a:0 ? a:1 : s:CurPath()

  let l:lines = [fnamemodify(s:root, ':~')]
  let l:nodes = [{'path': s:root, 'dir': 1}]
  call s:Build(s:root, 0, l:lines, l:nodes)

  setlocal modifiable
  silent %delete _
  call setline(1, l:lines)
  setlocal nomodifiable nomodified
  let b:minitree_nodes = l:nodes

  for l:i in range(len(l:nodes))
    if l:nodes[l:i].path ==# l:keep
      call cursor(l:i + 1, 1)
      return
    endif
  endfor
  call cursor(min([2, line('$')]), 1)
endfunction

" ---------------------------------------------------------------- nodes

function! s:Node() abort
  if !exists('b:minitree_nodes')
    return {}
  endif
  let l:i = line('.') - 1
  if l:i < 0 || l:i >= len(b:minitree_nodes)
    return {}
  endif
  return b:minitree_nodes[l:i]
endfunction

function! s:CurPath() abort
  let l:n = s:Node()
  return empty(l:n) ? '' : l:n.path
endfunction

" dir to act inside: node itself if dir, else its parent
function! s:TargetDir() abort
  let l:n = s:Node()
  if empty(l:n)
    return s:root
  endif
  return l:n.dir ? l:n.path : fnamemodify(l:n.path, ':h')
endfunction

" ---------------------------------------------------------------- window

function! s:FindWin() abort
  for l:w in range(1, winnr('$'))
    if getbufvar(winbufnr(l:w), '&filetype') ==# 'minitree'
      return l:w
    endif
  endfor
  return -1
endfunction

function! s:Syntax() abort
  syntax clear
  syntax match MiniTreeRoot /\%1l.*/
  syntax match MiniTreeDir  /^\s*[▸▾].*$/
  highlight default link MiniTreeRoot Title
  highlight default link MiniTreeDir  Directory
endfunction

function! s:Setup() abort
  setlocal buftype=nofile bufhidden=wipe noswapfile nobuflisted
  setlocal nonumber norelativenumber nowrap nolist nospell
  setlocal cursorline foldcolumn=0 winfixwidth
  if has('signs')
    setlocal signcolumn=no
  endif
  setlocal filetype=minitree
  call s:Maps()
  call s:Syntax()
endfunction

function! s:OpenWin() abort
  let l:w = s:FindWin()
  if l:w != -1
    execute l:w . 'wincmd w'
    return
  endif
  " root follows the working directory until the user changes it with c/u
  if empty(s:root)
    let s:root = getcwd()
  endif
  execute 'topleft vertical ' . g:minitree_width . ' new'
  call s:Setup()
  call s:Render('')
endfunction

function! s:Toggle() abort
  let l:w = s:FindWin()
  if l:w != -1
    execute l:w . 'wincmd w'
    close
  else
    call s:OpenWin()
  endif
endfunction

" jump to a normal (non-tree) window, creating one if the tree is alone
function! s:GotoTarget() abort
  for l:w in range(1, winnr('$'))
    if getbufvar(winbufnr(l:w), '&filetype') !=# 'minitree'
      execute l:w . 'wincmd w'
      return
    endif
  endfor
  botright vertical new
endfunction

" ---------------------------------------------------------------- actions

function! s:OpenFile(path, mode) abort
  " non-editable files go to an external viewer; splits are meaningless there
  let l:app = s:OpenerFor(a:path)
  if !empty(l:app)
    call s:LaunchExternal(l:app, a:path)
    return
  endif

  let l:esc = fnameescape(a:path)
  if a:mode ==# 'tab'
    execute 'tabedit ' . l:esc
    return
  endif
  call s:GotoTarget()
  if a:mode ==# 'vsplit'
    execute 'vsplit ' . l:esc
  elseif a:mode ==# 'split'
    execute 'split ' . l:esc
  else
    execute 'edit ' . l:esc
  endif
endfunction

function! s:Enter(mode) abort
  let l:n = s:Node()
  if empty(l:n) || line('.') == 1
    return
  endif
  if l:n.dir
    if has_key(s:expanded, l:n.path)
      call remove(s:expanded, l:n.path)
    else
      let s:expanded[l:n.path] = 1
    endif
    call s:Render(l:n.path)
  else
    call s:OpenFile(l:n.path, a:mode)
  endif
endfunction

" force a file into Vim, bypassing the external-viewer dispatch
function! s:ForceEdit() abort
  let l:n = s:Node()
  if empty(l:n) || l:n.dir || line('.') == 1
    return
  endif
  call s:GotoTarget()
  execute 'edit ' . fnameescape(l:n.path)
endfunction

" collapse the directory containing the cursor node
function! s:CollapseParent() abort
  let l:n = s:Node()
  if empty(l:n)
    return
  endif
  let l:parent = l:n.dir && has_key(s:expanded, l:n.path)
        \ ? l:n.path
        \ : fnamemodify(l:n.path, ':h')
  if has_key(s:expanded, l:parent)
    call remove(s:expanded, l:parent)
  endif
  call s:Render(l:parent)
endfunction

function! s:UpRoot() abort
  let l:parent = fnamemodify(s:root, ':h')
  if l:parent ==# s:root
    return
  endif
  let s:expanded[s:root] = 1
  let l:old = s:root
  let s:root = l:parent
  call s:Render(l:old)
endfunction

function! s:SetRoot() abort
  let l:n = s:Node()
  if empty(l:n) || !l:n.dir
    return
  endif
  let s:root = l:n.path
  call s:Render('')
endfunction

function! s:ToggleHidden() abort
  let s:hidden = !s:hidden
  call s:Render(s:CurPath())
endfunction

function! s:Create() abort
  let l:dir = s:TargetDir()
  let l:name = input('New (trailing / = directory): ')
  redraw
  if empty(l:name)
    return
  endif

  let l:path = s:Join(l:dir, l:name)
  let l:isdir = l:name =~# '/$'
  let l:clean = substitute(l:path, '/\+$', '', '')

  if isdirectory(l:clean) || filereadable(l:clean)
    call s:Err('Already exists: ' . l:clean)
    return
  endif

  try
    if l:isdir
      call mkdir(l:clean, 'p')
    else
      call mkdir(fnamemodify(l:clean, ':h'), 'p')
      call writefile([], l:clean)
    endif
  catch
    call s:Err('Create failed: ' . v:exception)
    return
  endtry

  let s:expanded[l:dir] = 1
  call s:Render(l:clean)
endfunction

function! s:Rename() abort
  let l:n = s:Node()
  if empty(l:n) || line('.') == 1
    return
  endif
  let l:old = fnamemodify(l:n.path, ':t')
  let l:input = input('Rename: ', l:old)
  redraw
  if empty(l:input) || l:input ==# l:old
    return
  endif

  " bare name stays in place; a path with / or ~ moves the node
  let l:new = l:input =~# '^[~/]'
        \ ? expand(l:input)
        \ : s:Join(fnamemodify(l:n.path, ':h'), l:input)
  let l:new = substitute(l:new, '/\+$', '', '')

  if isdirectory(l:new) || filereadable(l:new)
    call s:Err('Already exists: ' . l:new)
    return
  endif
  call mkdir(fnamemodify(l:new, ':h'), 'p')
  if rename(l:n.path, l:new) != 0
    call s:Err('Rename failed')
    return
  endif
  if has_key(s:expanded, l:n.path)
    call remove(s:expanded, l:n.path)
  endif
  call s:Render(l:new)
endfunction

function! s:Delete() abort
  let l:n = s:Node()
  if empty(l:n) || line('.') == 1
    return
  endif
  let l:what = l:n.dir ? 'directory and ALL its contents' : 'file'
  let l:ok = confirm('Permanently delete ' . l:what . "?\n" . l:n.path,
        \ "&No\n&Yes", 1, 'Question')
  if l:ok != 2
    return
  endif
  if delete(l:n.path, l:n.dir ? 'rf' : '') != 0
    call s:Err('Delete failed: ' . l:n.path)
    return
  endif
  if has_key(s:expanded, l:n.path)
    call remove(s:expanded, l:n.path)
  endif
  call s:Render('')
endfunction

function! s:Yank(mode) abort
  let l:n = s:Node()
  if empty(l:n) || line('.') == 1
    return
  endif
  let s:clip = {'path': l:n.path, 'mode': a:mode}
  echo (a:mode ==# 'copy' ? 'copied: ' : 'cut: ') . fnamemodify(l:n.path, ':t')
endfunction

function! s:Paste() abort
  if empty(s:clip.path)
    call s:Err('nothing copied or cut')
    return
  endif
  if !isdirectory(s:clip.path) && !filereadable(s:clip.path)
    call s:Err('source gone: ' . s:clip.path)
    let s:clip = {'path': '', 'mode': ''}
    return
  endif

  let l:dstdir = s:TargetDir()
  let l:dst = s:Join(l:dstdir, fnamemodify(s:clip.path, ':t'))

  if l:dst ==# s:clip.path
    call s:Err('source and destination are the same')
    return
  endif
  " refuse to move a directory into itself
  if isdirectory(s:clip.path) && stridx(l:dstdir . '/', s:clip.path . '/') == 0
    call s:Err('cannot paste a directory into itself')
    return
  endif

  if isdirectory(l:dst) || filereadable(l:dst)
    if confirm('Overwrite?' . "\n" . l:dst, "&No\n&Yes", 1, 'Question') != 2
      return
    endif
    call delete(l:dst, 'rf')
  endif

  let l:cmd = (s:clip.mode ==# 'copy' ? 'cp -r ' : 'mv ')
        \ . shellescape(s:clip.path) . ' ' . shellescape(l:dst)
  let l:out = system(l:cmd)
  if v:shell_error
    call s:Err(substitute(l:out, '\n', ' ', 'g'))
    return
  endif

  if s:clip.mode ==# 'cut'
    if has_key(s:expanded, s:clip.path)
      call remove(s:expanded, s:clip.path)
    endif
    let s:clip = {'path': '', 'mode': ''}
  endif

  let s:expanded[l:dstdir] = 1
  call s:Render(l:dst)
endfunction

" reveal the file in the current window
function! s:Reveal() abort
  let l:file = expand('%:p')
  if empty(l:file) || !filereadable(l:file)
    call s:OpenWin()
    return
  endif
  if empty(s:root)
    let s:root = getcwd()
  endif
  if stridx(l:file, s:root . '/') != 0
    let s:root = fnamemodify(l:file, ':h')
  endif
  let l:p = fnamemodify(l:file, ':h')
  while strlen(l:p) > strlen(s:root)
    let s:expanded[l:p] = 1
    let l:p = fnamemodify(l:p, ':h')
  endwhile
  call s:OpenWin()
  call s:Render(l:file)
endfunction

function! s:Help() abort
  echo join([
        \ '<CR>/o  open      s  vsplit    i  hsplit   t  tab',
        \ 'e  force-edit in Vim (skip external viewer)',
        \ 'x  collapse       u  root up   c  root=dir R  refresh',
        \ 'a  new (a/ =dir)  r  rename    D  delete',
        \ 'yy copy           dd cut       p  paste',
        \ 'H  hidden files   q  close     ?  this help',
        \ ], "\n")
endfunction

" ---------------------------------------------------------------- maps

function! s:Maps() abort
  nnoremap <buffer><silent><nowait> <CR> :call <SID>Enter('edit')<CR>
  nnoremap <buffer><silent><nowait> o    :call <SID>Enter('edit')<CR>
  nnoremap <buffer><silent><nowait> s    :call <SID>Enter('vsplit')<CR>
  nnoremap <buffer><silent><nowait> i    :call <SID>Enter('split')<CR>
  nnoremap <buffer><silent><nowait> t    :call <SID>Enter('tab')<CR>
  nnoremap <buffer><silent><nowait> e    :call <SID>ForceEdit()<CR>
  nnoremap <buffer><silent><nowait> x    :call <SID>CollapseParent()<CR>
  nnoremap <buffer><silent><nowait> u    :call <SID>UpRoot()<CR>
  nnoremap <buffer><silent><nowait> c    :call <SID>SetRoot()<CR>
  nnoremap <buffer><silent><nowait> R    :call <SID>Render(<SID>CurPath())<CR>
  nnoremap <buffer><silent><nowait> a    :call <SID>Create()<CR>
  nnoremap <buffer><silent><nowait> r    :call <SID>Rename()<CR>
  nnoremap <buffer><silent><nowait> D    :call <SID>Delete()<CR>
  nnoremap <buffer><silent><nowait> yy   :call <SID>Yank('copy')<CR>
  nnoremap <buffer><silent><nowait> dd   :call <SID>Yank('cut')<CR>
  nnoremap <buffer><silent><nowait> p    :call <SID>Paste()<CR>
  nnoremap <buffer><silent><nowait> H    :call <SID>ToggleHidden()<CR>
  nnoremap <buffer><silent><nowait> q    :close<CR>
  nnoremap <buffer><silent><nowait> ?    :call <SID>Help()<CR>
endfunction

" ---------------------------------------------------------------- public

command! MiniTree       call <SID>OpenWin()
command! MiniTreeToggle call <SID>Toggle()
command! MiniTreeFind   call <SID>Reveal()

" don't leave a lone tree window behind
augroup minitree_auto
  autocmd!
  autocmd BufEnter * if winnr('$') == 1 && &filetype ==# 'minitree' | quit | endif
augroup END
