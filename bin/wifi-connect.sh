#!/bin/bash

# Get the list of available Wi-Fi networks (excluding the header line)
network_list=$(nmcli -t -f SSID device wifi list | sed '/^--/d')

# Show the list in a vertical dmenu and store the selected SSID
selected_network=$(echo "$network_list" | dmenu -l 10 -p "Select Wi-Fi Network:")

# If a network was selected
if [ -n "$selected_network" ]; then
    # Ask for the password via dmenu
    password=$(dmenu -p "Enter password for $selected_network:")

    # Check if a password was entered
    if [ -n "$password" ]; then
        # Attempt to connect to the selected network using the entered password
        nmcli device wifi connect "$selected_network" password "$password" && \
        notify-send "Connected to $selected_network" || \
        notify-send "Failed to connect to $selected_network"
    else
        notify-send "No password entered!"
    fi
else
    notify-send "No network selected!"
fi

