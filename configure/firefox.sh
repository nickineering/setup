# shellcheck shell=bash
# shellcheck disable=SC2154 # Variables like $yellow defined in lib/colors.sh
# Sourced by run.sh (requires lib/colors.sh, lib/backup.sh)

# Install custom Firefox settings
FIREFOX_FOLDER="$HOME/Library/Application Support/Firefox/Profiles"
if [ ! -d "$FIREFOX_FOLDER" ]; then
	# Firefox not launched yet - run.sh will remind user at the end
	export FIREFOX_NEEDS_SETUP=1
else
	FIREFOX_PROFILE=$(find "$FIREFOX_FOLDER" -maxdepth 1 -name '*.dev-edition-default' 2>/dev/null | head -n1)
	if [ "$FIREFOX_PROFILE" = "" ]; then
		echo -e "${dim}Could not find Firefox profile folder. Skipping Firefox settings...${reset}"
	else

		backup_or_delete "$FIREFOX_PROFILE/user.js"
		if ! ln -sf "$DOTFILES/user.js" "$FIREFOX_PROFILE/user.js"; then
			echo -e "${yellow}Warning: Failed to link Firefox user.js${reset}"
		fi
	fi
fi
