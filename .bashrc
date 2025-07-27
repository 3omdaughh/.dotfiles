#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ls='ls --color=auto'
alias grep='grep --color=auto'

PS1='[\u@\h \W]\$ '

## pacman

alias i='sudo pacman -S'
alias u='sudo pacman -Syu'
alias q='sudo pacman -Ss'

## AUR 

alias iy='yay -S'
alias uy='yay -Syu'
alias qy='yay -Ss'

## general

alias b='acpi -b'
alias vi='vim'
alias ll='ls -l' 
set -o vi
alias dotfiles='/usr/bin/git --git-dir=/home/omdaughh/.dotfiles/ --work-tree=/home/omdaughh'
