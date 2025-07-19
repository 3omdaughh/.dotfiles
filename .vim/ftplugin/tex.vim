vim9script 

compiler tex

def Compile()
	w
	cd %:p:h
	silent make
	cd -

	cwindow
	redraw!
enddef

def Openpdf()
	silent !zathura '%:p:r'.pdf & disown
enddef

nnoremap <buffer> <leader>c <ScriptCmd>Compile()<LF>
nnoremap <buffer> <leader>r <ScriptCmd>Openpdf()<LF>

nnoremap <buffer> <leader>s :so ~/.vim/ftplugin/tex.vim<LF>
