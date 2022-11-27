#!/usr/local/bin/bash

# Add $1 to the Mac dock
# $1 == the string name of an app without the file extension
# $2 == "System" if an Apple app; unset otherwise
add_to_dock () {
    local location="/Applications/"
    # If it's a system app use a different location
    if [ -n "$2" ]
    then
        location="/System/Applications/"
    fi
    defaults write com.apple.dock persistent-apps -array-add '<dict><key>tile-data</key><dict><key>file-data</key><dict><key>_CFURLString</key><string>'$location"$1"'.app</string><key>_CFURLStringType</key><integer>0</integer></dict></dict></dict>'
}
