#!/bin/sh

battery_status=$(acpi -b)
thermal_status=$(acpi -t)

printf "%s\n%s\n" "$battery_status" "$thermal_status" | \
wmenu -p "Battery | Thermal Status:" -f "JetBrainsMono Nerd Font 10"
