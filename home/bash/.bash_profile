#
# ~/.bash_profile
#

[[ -f ~/.bashrc ]] && . ~/.bashrc

export WEB_BROWSER="firefox"
export BROWSER="firefox"
export MUSIC_PLAYER="spotify-launcher"
export TERMINAL="foot"
export TERM="foot"
export EDITOR="vim"
export MERGETOOL="vimdiff"

# Fallback only: SDDM owns tty1 now (sddm.service Conflicts=getty@tty1).
# This still fires if SDDM is disabled or stopped and you log in on tty1.
[[ ! $DISPLAY && ! $WAYLAND_DISPLAY && $(tty) = "/dev/tty1" ]] && ~/.local/bin/startwl.sh
