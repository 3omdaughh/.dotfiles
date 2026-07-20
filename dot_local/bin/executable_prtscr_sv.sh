#!/bin/bash

DIR="$HOME/Pictures/Screenshots"
BASE="screenshot"

# Find next available number
i=1
while [[ -e "$DIR/${BASE}_$i.png" ]]; do
    ((i++))
done

# Take the screenshot
grim -g "$(slurp)" "$DIR/${BASE}_$i.png"

notify-send "Screenshot saved!" "$DIR/${BASE}_$i.png"
