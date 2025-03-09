#!/bin/bash

# Check if the microphone is in use
mic_in_use=$(pactl list sources | grep "State: RUNNING" | wc -l)

# Check if screen sharing is active (this is dependent on your screen sharing tool)
# Example for x11vnc, or modify for other tools you use
screen_sharing=$(ps aux | grep -E "(zoom|slack|teams|obs|discord|x11vnc)" | grep -v grep | wc -l)

# Set mic status message
if [ "$mic_in_use" -gt 0 ]; then
    mic_status="Mic: In use"
else
    mic_status="Mic: Not in use"
fi

# Set screen sharing status message
if [ "$screen_sharing" -gt 0 ]; then
    screen_status="Screen Sharing: Active"
else
    screen_status="Screen Sharing: Inactive"
fi

# Combine status messages
status_message="$mic_status\n$screen_status"

# Pass the system status to dmenu
echo -e "$status_message" | dmenu -p "System Status:"

