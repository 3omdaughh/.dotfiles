#!/bin/bash

# File to store clipboard history
HISTORY_FILE="$HOME/.clipboard_history"
MAX_HISTORY=10

# Function to add clipboard content to history
add_to_history() {
    current_clipboard=$(xclip -o -selection clipboard 2>/dev/null)
    if [[ -n "$current_clipboard" && "$current_clipboard" != "$(tail -n 1 "$HISTORY_FILE" 2>/dev/null)" ]]; then
        echo "$current_clipboard" >> "$HISTORY_FILE"
        # Keep only the last MAX_HISTORY entries
        tail -n $MAX_HISTORY "$HISTORY_FILE" > "$HISTORY_FILE.tmp" && mv "$HISTORY_FILE.tmp" "$HISTORY_FILE"
    fi
}

# Function to select from history using dmenu
select_from_history() {
    if [[ ! -f "$HISTORY_FILE" || ! -s "$HISTORY_FILE" ]]; then
        notify-send "Clipboard History" "No clipboard history found!"  # Optional: notify if empty
        exit 0
    fi
    selection=$(tac "$HISTORY_FILE" | dmenu -i -p "Select clipboard entry:")
    if [[ -n "$selection" ]]; then
        echo -n "$selection" | xclip -selection clipboard
        notify-send "Clipboard History" "Copied to clipboard: $selection"  # Optional: notify success
    fi
}

# Main functionality
if [[ "$1" == "--add" ]]; then
    add_to_history
else
    select_from_history
fi

