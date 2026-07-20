#!/bin/sh
grim -g "$(slurp)" - | wl-copy
notify-send "Screenshot saved to Clipboard!"

