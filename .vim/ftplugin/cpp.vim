vim9script

# Function to compile the current C++ file
def Compile()
	w   #Save the current file
	cd %:p:h  # Change directory to the file's location
	silent !g++ %:p -o 'output'
	cd -  #Return to the original directory
	redraw!
enddef

# Function to run the compiled C++ program
def Run()
	silent !./output  
	redraw!
enddef

# Mappings
nnoremap <buffer> <leader>c <ScriptCmd>Compile()<LF>  
nnoremap <buffer> <leader>r <ScriptCmd>Run()<LF>  

# Source the file again with leader + s
nnoremap <buffer> <leader>s :so ~/.vim/ftplugin/cpp.vim<LF>

