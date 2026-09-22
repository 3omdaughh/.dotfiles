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

# ===== nnn =====
# Layout/behaviour mirrors the reference demo: detail view, contexts,
# preview pane on the right. Colors use terminal palette slots 00-0f so
# nnn follows foot.ini instead of hardcoding a scheme.
export NNN_OPTS="d"           # d: detail mode (no -e: opener handles text)
export NNN_OPENER="$HOME/.config/nnn/opener.sh"
export NNN_COLORS='41234123'  # contexts 1-8 cycle blue, red, green, yellow
# file-type colors, strict order:
# block char dir exec regular hardlink symlink details orphan fifo socket unknown
export NNN_FCOLORS='0e060c0b000d0a0309050401'
export NNN_TRASH=1

# --- preview pane (preview-tui) ---
export NNN_FIFO=/tmp/nnn.fifo
export NNN_PLUG='p:preview-tui;f:fzcd;o:fzopen;d:diffs;i:imgview;x:xdgdefault'
export NNN_SPLIT='v'          # v = side-by-side
export NNN_SPLITSIZE=50
export NNN_ICONLOOKUP=1       # icons inside directory previews
export NNN_BATSTYLE='plain'   # no line numbers, matches the demo
export NNN_BATTHEME='ansi'    # bat follows the terminal palette too
export NNN_TERMINAL='foot'    # fallback when not inside tmux
# preview-tui has NO autodetect for image backends: without this it falls
# through to printing binary info. chafa renders sixel, which foot supports.
export NNN_PREVIEWIMGPROG='chafa -f sixel --animate off'

# cd on quit: use `n` instead of `nnn`
n() {
    [ "${NNNLVL:-0}" -eq 0 ] || { echo "nnn already running"; return; }
    export NNN_TMPFILE="${XDG_CONFIG_HOME:-$HOME/.config}/nnn/.lastd"
    command nnn "$@"
    [ ! -f "$NNN_TMPFILE" ] || { . "$NNN_TMPFILE"; rm -f "$NNN_TMPFILE"; }
}
