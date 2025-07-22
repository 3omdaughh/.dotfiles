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

def OnError(channelname: channel, msg: string)
	echoerr "process has finished with error: " .. msg
enddef

def Openpdf()
	const proc = "zathura"
	const opta = "-c"
	const optb = "~/.config/zathura/synctex"
	const optc = expand('%:p:r') .. ".pdf"
	const optd = "--synctex-forward"
	const opte = line(".") .. ":" .. col(".") .. ":" .. expand('%:p')
	const cmd = [proc, opta, optb, optc, optd, opte]
	job_start(cmd, {"err_cb": OnError})
enddef

nnoremap <buffer> <leader>c <ScriptCmd>Compile()<LF>
nnoremap <buffer> <leader>r <ScriptCmd>Openpdf()<LF>

nnoremap <buffer> <leader>s :so ~/.vim/ftplugin/tex.vim<LF>
