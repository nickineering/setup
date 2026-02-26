#!/opt/homebrew/bin/bash

# Install custom Firefox settings
FIREFOX_FOLDER="$HOME/Library/Application Support/Firefox/Profiles"
if [ ! -d "$FIREFOX_FOLDER" ]; then
	print_green "Firefox profiles folder not found. You must sign in to Firefox and then run this script again or run the after_signin.sh script."
else
	FIREFOX_PROFILE=$(find "$FIREFOX_FOLDER" -maxdepth 1 -name '*.dev-edition-default' 2>/dev/null | head -n1)
	if [ "$FIREFOX_PROFILE" = "" ]; then
		print_green "Could not find Firefox profile folder. Skipping Firefox settings..."
	else
		backup_or_delete "$FIREFOX_PROFILE"/user.js
		if ! ln -s "$DOTFILES"/user.js "$FIREFOX_PROFILE"; then
			print_green "Warning: Failed to link Firefox user.js"
		fi
	fi
fi
