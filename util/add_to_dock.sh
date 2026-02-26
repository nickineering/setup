#!/opt/homebrew/bin/bash

# Add $1 to the Mac dock
# $1 == the string name of an app without the file extension
# $2 == "System" if an Apple app; unset otherwise
# Returns 0 on success, 1 if app not found
add_to_dock() {
	if [ "${1:-}" = "" ]; then
		echo "Error: add_to_dock requires an app name argument" >&2
		return 1
	fi

	local location="/Applications/"
	# If it's a system app use a different location
	if [[ $# -ge 2 ]]; then
		location="/System/Applications/"
	fi

	local app_path="$location$1.app"
	if [ ! -d "$app_path" ]; then
		echo "Warning: App not found at $app_path, skipping dock addition" >&2
		return 1
	fi

	defaults write com.apple.dock persistent-apps -array-add '<dict><key>tile-data</key><dict><key>file-data</key><dict><key>_CFURLString</key><string>'"$app_path"'</string><key>_CFURLStringType</key><integer>0</integer></dict></dict></dict>'
}
