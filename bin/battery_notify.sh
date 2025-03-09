#!/bin/bash

# Set the battery threshold (20%)
THRESHOLD=20

# Infinite loop to check battery level every 5 minutes
while true; do
    	# Get the current battery percentage
   	BATTERY_LEVEL=$(cat /sys/class/power_supply/BAT0/capacity)
    	BATTERY_STATUE=$(cat /sys/class/power_supply/AC/online)

    	# If the battery level is less than or equal to the threshold and the battery is not plugged in (BATTERY_STATUE=0), show a message
    	if [ "$BATTERY_LEVEL" -le "$THRESHOLD" ] && [ "$BATTERY_STATUE" -eq 0 ]; then
        	echo "Please plug the charger!" | dmenu -p "Battery level is low"
    	fi

    	# Wait for 5 minutes before checking again
    	sleep 300
done
