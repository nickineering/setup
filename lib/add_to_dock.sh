# shellcheck shell=bash
# Sourced by configure/macos.sh - add apps to macOS Dock

# Add $1 to the Mac dock (idempotent - skips if already present)
# $1 == the string name of an app without the file extension
# $2 == "System" if an Apple app; unset otherwise
# Returns 0 on success, 1 if app not found, 2 if already in dock
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

	# Check if app is already in dock (idempotent)
	# Dock stores paths as file:// URLs with URL encoding (spaces -> %20)
	local url_encoded_path="${app_path// /%20}"
	if defaults read com.apple.dock persistent-apps 2>/dev/null | grep -q "$url_encoded_path"; then
		return 2
	fi

	defaults write com.apple.dock persistent-apps -array-add '<dict><key>tile-data</key><dict><key>file-data</key><dict><key>_CFURLString</key><string>'"$app_path"'</string><key>_CFURLStringType</key><integer>0</integer></dict></dict></dict>'
}
