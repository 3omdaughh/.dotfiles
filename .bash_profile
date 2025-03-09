#
# ~/.bash_profile
#

[[ -f ~/.bashrc ]] && . ~/.bashrc

export WEB_BROWSER="firefox"
export BROWSER="firefox"
export MUSIC_PLAYER="spotify"
export TERMINAL="st"
export TERM="st"

[[ ! $DISPLAY && $(tty) = "/dev/tty1" ]]  &&  startx
