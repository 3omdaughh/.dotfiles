#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ls='ls --color=auto'
alias grep='grep --color=auto'

## pacman

alias i='doas pacman -S'
alias u='doas pacman -Syu'
alias q='pacman -Ss'

## AUR 

alias iy='yay -S'
alias uy='yay -Syu'
alias qy='yay -Ss'

## general

alias vi='vim'
alias ll='ls -l' 
alias la='ls -la'
set -o vi


PS1='[\u@\h \W]\$ '
alias rdd='source ~/envs/rdd/bin/activate'
export PATH="$HOME/.local/bin:$PATH"
