vim9script 

def Compile()
	w
	cd %:p:h
	silent !pdflatex %:p
	cd -
	redraw!
enddef

def Openpdf()
	silent !zathura '%:p:r'.pdf & disown
enddef

nnoremap <buffer> <leader>c <ScriptCmd>Compile()<LF>
nnoremap <buffer> <leader>r <ScriptCmd>Openpdf()<LF>

nnoremap <buffer> <leader>s :so ~/.vim/ftplugin/tex.vim<LF>
