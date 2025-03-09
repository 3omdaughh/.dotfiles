# Keyboard Set
setxkbmap -layout us,ara -option grp:alt_space_toggle caps:swapescape
setxkbmap -option caps:swapescape

# Wallpaper
feh --bg-fill Pictures/dedsecx4.jpg

# Statusbar
/home/$USER/dwm-bar/dwm_bar.sh &

# Battery notify
$HOME/bin/battery_notify.sh &

# Keybindings 
sxhkd &

# Start dwm
dwm
