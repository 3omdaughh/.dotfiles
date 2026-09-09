#!/bin/sh

export XDG_CURRENT_DESKTOP=wlroots
export XDG_SESSION_TYPE=wayland

slstatus -s | dwl -s "sh -c 'dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE; swaybg -i ~/Pictures/dedsecx4.jpg & mako & swhks & swhkd & $HOME/.local/bin/usb-mount daemon & $HOME/.local/bin/lock-daemon &'"
