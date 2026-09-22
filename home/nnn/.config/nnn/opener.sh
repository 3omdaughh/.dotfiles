#!/bin/sh
# nnn custom opener.
# Rule: nnn must never be replaced. Text opens in a tmux pane beside nnn;
# GUI viewers are detached so dwl tiles them without blocking nnn.

f="$1"
[ -z "$f" ] && exit 1
[ -d "$f" ] && exit 0

mime=$(file -bL --mime-type -- "$f")

# detach fully: new session, no tty, no stdio, so nnn's TUI is never corrupted
gui() { setsid -f "$@" >/dev/null 2>&1; }

edit() {
    if [ -n "$TMUX" ]; then
        tmux split-window -h -c "$(dirname -- "$f")" "${EDITOR:-vim}" "$f"
    else
        gui foot -e "${EDITOR:-vim}" "$f"
    fi
}

case "$mime" in
    application/pdf|application/epub*|application/postscript|image/vnd.djvu)
        gui zathura "$f" ;;
    image/*)
        gui swayimg "$f" ;;
    video/*|audio/*)
        gui xdg-open "$f" ;;
    text/*|inode/x-empty|application/json|application/xml|application/javascript|application/x-shellscript|application/x-desktop)
        edit ;;
    *)
        if [ "$(file -bL --mime-encoding -- "$f")" = binary ]; then
            gui xdg-open "$f"
        else
            edit
        fi ;;
esac
