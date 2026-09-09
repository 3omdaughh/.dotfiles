#!/bin/sh

choice=$(printf "Sleep\nShutdown\nReboot\nExit\n" | wmenu -p "Power Menu:" -f "JetBrainsMono Nerd Font 10")

[ "$choice" = "Sleep" ] && systemctl suspend
[ "$choice" = "Shutdown" ] && poweroff
[ "$choice" = "Reboot" ] && reboot
[ "$choice" = "Exit" ] && pkill dwl

