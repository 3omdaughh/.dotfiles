#
# ~/.bash_profile
#

[[ -f ~/.bashrc ]] && . ~/.bashrc

export WEB_BROWSER="firefox"
export BROWSER="firefox"
export MUSIC_PLAYER="spotify"
export TERMINAL="st"
export TERM="st"
export EDITOR="vim"
export CALCURSE_PAGER="glow"
export MERGETOOL="vimdiff"

[[ ! $DISPLAY && $(tty) = "/dev/tty1" ]]  &&  startx
