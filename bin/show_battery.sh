#!/bin/bash

battery_status=$(acpi -b)
thermal_status=$(acpi -t)

echo -e "$battery_status\n$thermal_status" | dmenu  -p "Battery | Thermal Status:"
