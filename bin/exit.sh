#!/bin/sh

choice=$(echo -e "Sleep\nShutdown\nReboot\nExit" | dmenu)

[ $choice = "Sleep" ] && systemctl suspend
[ $choice = "Shutdown" ] && poweroff
[ $choice = "Reboot" ] && reboot
[ $choice = "Exit" ] && pkill dwm
