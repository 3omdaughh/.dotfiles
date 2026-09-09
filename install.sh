#!/usr/bin/env bash
#
# install.sh — turn a fresh Arch install into this machine.
#
#   git clone <repo> ~/.dotfiles && ~/.dotfiles/install.sh
#
# Runs every step below in order. Each step is idempotent: re-running the
# script on an already-configured machine changes nothing that is already
# right. Run one step alone by naming it:
#
#   ./install.sh stow          # only re-link the home directory
#   ./install.sh sources       # only rebuild dwl / slstatus / swhkd
#
# Environment knobs:
#   DRY_RUN=1      print every privileged / mutating command instead of running it
#   FORCE_BUILD=1  rebuild the source programs even if they are already installed
#   SRC_DIR=...    where source clones live (default ~/Desktop/src)
#
# Read top to bottom: helpers first, then one function per step, then main.

set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="${SRC_DIR:-$HOME/Desktop/src}"
DRY_RUN="${DRY_RUN:-0}"
FORCE_BUILD="${FORCE_BUILD:-0}"

# shellcheck source=src/sources.conf
. "$DOTFILES/src/sources.conf"

STEPS=(packages doas yay aur stow system sources services groups)

# ---------------------------------------------------------------- helpers ---

log()  { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33mwarning:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

# run <cmd...>: execute, or just print when DRY_RUN=1.
run() {
    if [ "$DRY_RUN" = 1 ]; then printf '  + %s\n' "$*"; else "$@"; fi
}

# run_in <dir> <cmd...>: same, but inside a directory.
run_in() {
    local dir=$1; shift
    if [ "$DRY_RUN" = 1 ]; then printf '  + (cd %s && %s)\n' "$dir" "$*"; else (cd "$dir" && "$@"); fi
}

# root_cmd: the privilege tool to use right now.
# doas once it is installed and configured (the normal state of this machine),
# sudo on a fresh install where only the archinstall wheel rule exists,
# su as a last resort.
root_cmd() {
    if command -v doas >/dev/null 2>&1 && doas -n true >/dev/null 2>&1; then echo doas
    elif command -v sudo >/dev/null 2>&1; then echo sudo
    else echo su
    fi
}

# as_root <cmd...>: run a command as root through root_cmd.
as_root() {
    case "$(root_cmd)" in
        su) run su -c "$(printf '%q ' "$@")" ;;
        *)  run "$(root_cmd)" "$@" ;;
    esac
}

# pkglist <file>: the file's entries, minus comments and blank lines.
pkglist() { grep -vE '^\s*(#|$)' "$1"; }

# install_list <file> <install cmd...>: install everything in a list file.
# Tries one transaction first (fast); if that fails, falls back to one
# package at a time so a single renamed or vanished package cannot block
# the rest. Missing packages are reported at the end, never fatal.
install_list() {
    local file=$1; shift
    local pkgs; mapfile -t pkgs < <(pkglist "$file")
    [ "${#pkgs[@]}" -gt 0 ] || return 0
    if "$@" "${pkgs[@]}"; then return 0; fi
    warn "batch install failed, retrying one package at a time"
    local failed=()
    for p in "${pkgs[@]}"; do
        "$@" "$p" || failed+=("$p")
    done
    [ "${#failed[@]}" -eq 0 ] || warn "could not install: ${failed[*]}"
}

# ------------------------------------------------------------------ steps ---

step_packages() {
    log "Repo packages (packages/native.txt)"
    install_list "$DOTFILES/packages/native.txt" as_root pacman -Syu --needed --noconfirm
}

step_doas() {
    log "doas"
    # doas.conf is part of system/rootfs, but it is needed before that step
    # so that every later root command already goes through doas.
    as_root install -Dm644 "$DOTFILES/system/rootfs/etc/doas.conf" /etc/doas.conf
}

step_yay() {
    log "yay (AUR helper)"
    if command -v yay >/dev/null 2>&1; then echo "already installed"; return; fi
    local dir="$SRC_DIR/yay"
    [ -d "$dir/.git" ] || run git clone https://aur.archlinux.org/yay.git "$dir"
    # makepkg escalates through PACMAN_AUTH; point it at doas when doas works.
    PACMAN_AUTH="$(root_cmd)" run_in "$dir" makepkg -si --noconfirm --needed
}

step_aur() {
    log "AUR packages (packages/aur.txt)"
    command -v yay >/dev/null 2>&1 || die "yay is missing; run './install.sh yay' first"
    install_list "$DOTFILES/packages/aur.txt" run yay -S --needed --noconfirm --sudo "$(root_cmd)"
}

step_stow() {
    log "Stow home packages (home/*)"
    command -v stow >/dev/null 2>&1 || die "stow is missing; run './install.sh packages' first"
    local pkgs=() d
    for d in "$DOTFILES"/home/*/; do pkgs+=("$(basename "$d")"); done

    # A fresh user has real .bashrc/.bash_profile/... from /etc/skel. Stow
    # refuses to overwrite real files, so move anything in the way to a
    # dated backup directory first. Only files we ship are ever moved.
    local conflicts
    conflicts=$(stow -n -d "$DOTFILES/home" -t "$HOME" "${pkgs[@]}" 2>&1 \
        | sed -n 's/.*existing target is \(neither a link nor a directory\|not owned by stow\): //p' \
        || true)
    if [ -n "$conflicts" ]; then
        local backup="$HOME/.dotfiles-backup-$(date +%Y%m%d-%H%M%S)"
        echo "moving files that would block symlinks to $backup:"
        local f
        while IFS= read -r f; do
            echo "  $f"
            run mkdir -p "$backup/$(dirname "$f")"
            run mv "$HOME/$f" "$backup/$f"
        done <<< "$conflicts"
    fi

    # -R = restow: unlinks then relinks, so it also picks up files added to
    # a package since the last run and drops links to files that were removed.
    run stow -R -d "$DOTFILES/home" -t "$HOME" "${pkgs[@]}"
}

step_system() {
    log "System files (system/rootfs -> /)"
    # system/rootfs mirrors the filesystem root. Every file in it is copied to
    # the same path under /, keeping its mode bits. Ownership becomes root.
    local rel
    while IFS= read -r rel; do
        as_root install -D -m "$(stat -c %a "$DOTFILES/system/rootfs/$rel")" \
            "$DOTFILES/system/rootfs/$rel" "/$rel"
    done < <(cd "$DOTFILES/system/rootfs" && find . -type f | sed 's#^\./##' | sort)
}

# fetch_src <dir> <repo> <commit>
# Clone (if needed) and check out the pinned commit. Returns 1 if the clone
# has uncommitted changes — then it is the live, hand-edited tree and must not
# be touched; the caller builds it exactly as it is.
fetch_src() {
    local dir=$1 repo=$2 commit=$3
    if [ -d "$dir/.git" ]; then
        if [ -n "$(git -C "$dir" status --porcelain)" ]; then
            warn "$dir has uncommitted changes; building it as-is (no checkout, no patch)"
            return 1
        fi
        git -C "$dir" cat-file -e "$commit^{commit}" 2>/dev/null || run git -C "$dir" fetch -q origin
    else
        run git clone -q "$repo" "$dir"
    fi
    run git -C "$dir" checkout -q "$commit"
}

# apply_patch <dir> <patch>: apply unless already applied.
apply_patch() {
    local dir=$1 patch=$2
    [ -s "$patch" ] || return 0
    if git -C "$dir" apply --check "$patch" 2>/dev/null; then
        run git -C "$dir" apply "$patch"
    elif git -C "$dir" apply --reverse --check "$patch" 2>/dev/null; then
        echo "patch already applied"
    else
        die "$patch does not apply to $dir at $(git -C "$dir" rev-parse --short HEAD)"
    fi
}

# built <binary>: true when it is installed and FORCE_BUILD is off.
built() { [ "$FORCE_BUILD" != 1 ] && command -v "$1" >/dev/null 2>&1; }

step_sources() {
    log "Programs built from source (src/sources.conf)"
    run mkdir -p "$SRC_DIR"

    # -- dwl: Wayland compositor. Patched with a status bar (drwl.h), gaps and
    #    XWayland; the consolidated diff lives in src/dwl/dwl.patch.
    if built dwl; then echo "dwl: installed, skipping (FORCE_BUILD=1 to rebuild)"; else
        local d="$SRC_DIR/dwl"
        if fetch_src "$d" "$DWL_REPO" "$DWL_COMMIT"; then
            run cp "$DOTFILES/src/dwl/drwl.h" "$d/drwl.h"
            apply_patch "$d" "$DOTFILES/src/dwl/dwl.patch"
        fi
        run_in "$d" make
        as_root make -C "$d" install     # -> /usr/local/bin/dwl + wayland-sessions/dwl.desktop
    fi

    # -- slstatus: status text piped into dwl's bar (see startwl.sh).
    if built slstatus; then echo "slstatus: installed, skipping"; else
        local d="$SRC_DIR/slstatus"
        if fetch_src "$d" "$SLSTATUS_REPO" "$SLSTATUS_COMMIT"; then
            apply_patch "$d" "$DOTFILES/src/slstatus/slstatus.patch"
        fi
        run_in "$d" make
        as_root make -C "$d" install     # -> /usr/local/bin/slstatus
    fi

    # -- swhkd: hotkey daemon (Rust). Its Makefile hard-codes sudo for the
    #    setuid step, so install the two binaries by hand instead.
    if built swhkd; then echo "swhkd: installed, skipping"; else
        rustup show active-toolchain >/dev/null 2>&1 || run rustup default stable
        local d="$SRC_DIR/swhkd"
        fetch_src "$d" "$SWHKD_REPO" "$SWHKD_COMMIT" || true
        run_in "$d" make
        as_root install -Dm755 "$d/target/release/swhkd" /usr/bin/swhkd
        as_root chmod u+s /usr/bin/swhkd
        as_root install -Dm755 "$d/target/release/swhks" /usr/bin/swhks
        [ -f /etc/swhkd/swhkdrc ] || as_root install -Dm644 /dev/null /etc/swhkd/swhkdrc
    fi
}

step_services() {
    log "systemd units (system/services-*.txt)"
    local u
    while IFS= read -r u; do as_root systemctl enable "$u"; done \
        < <(pkglist "$DOTFILES/system/services-system.txt")
    while IFS= read -r u; do
        run systemctl --user enable "$u" \
            || warn "could not enable user unit $u (no user session bus?); re-run './install.sh services' after logging in"
    done < <(pkglist "$DOTFILES/system/services-user.txt")
}

step_groups() {
    log "Groups (system/groups.txt)"
    local g
    while IFS= read -r g; do
        if id -nG | tr ' ' '\n' | grep -qx "$g"; then echo "already in $g"; else as_root usermod -aG "$g" "$USER"; fi
    done < <(pkglist "$DOTFILES/system/groups.txt")
}

# ------------------------------------------------------------------- main ---

[ -f /etc/arch-release ] || die "this script is for Arch Linux"
[ "$(id -u)" -ne 0 ] || die "run as your normal user, not root"
[ "$DOTFILES" = "$HOME/.dotfiles" ] || warn "repo is at $DOTFILES, not ~/.dotfiles (fine, but the README assumes ~/.dotfiles)"
[ "$DRY_RUN" = 1 ] && echo "DRY RUN: nothing below is executed"

if [ $# -eq 0 ]; then
    for s in "${STEPS[@]}"; do "step_$s"; done
    log "Done"
    cat <<EOF
Next:
  - log out and back in (or reboot) so group changes and the SDDM session apply
  - pick the "dwl" session in SDDM
  - things this script does not restore: ~/.ssh, ~/.gnupg, browser profiles,
    fonts in ~/.local/share/fonts, personal data. Restore those from your
    encrypted backup by hand.
EOF
else
    for s in "$@"; do
        printf '%s\n' "${STEPS[@]}" | grep -qx "$s" || die "unknown step '$s' (steps: ${STEPS[*]})"
        "step_$s"
    done
fi
