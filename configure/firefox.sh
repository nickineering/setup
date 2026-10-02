# shellcheck shell=bash
# shellcheck disable=SC2154 # Variables like $yellow defined in lib/colors.sh
# Sourced by run.sh (requires lib/colors.sh, lib/backup.sh)

# Install custom Firefox settings
FIREFOX_FOLDER="$HOME/Library/Application Support/Firefox/Profiles"
if [ ! -d "$FIREFOX_FOLDER" ]; then
	# Firefox not launched yet - run.sh will remind user at the end
	export FIREFOX_NEEDS_SETUP=1
elif [ ! -r "$FIREFOX_FOLDER" ]; then
	# macOS withholds Firefox's profile data from processes without Full Disk
	# Access. The directory still stats, so -d above passes and every attempt to
	# read it fails with EPERM.
	#
	# This is what made the whole run die here, silently: the old code listed the
	# directory with `find ... 2>/dev/null | head -n1`, so the EPERM went to
	# /dev/null, pipefail turned find's non-zero status into a failed command
	# substitution, and errexit took run.sh down with it. No message, no step 10.
	# Reported rather than hidden, because it is fixable and the user has to know.
	warn "Cannot read $FIREFOX_FOLDER - macOS is withholding access"
	echo -e "  ${dim}Grant your terminal Full Disk Access in System Settings > Privacy & Security, then re-run.${reset}"
else
	# A glob rather than `find | head`: no pipeline, so nothing for pipefail to
	# trip over, and no second process whose early exit can SIGPIPE the first.
	# nullglob is restored afterwards because this file is sourced into run.sh.
	firefox_had_nullglob=0
	if shopt -q nullglob; then firefox_had_nullglob=1; fi
	shopt -s nullglob
	firefox_profiles=("$FIREFOX_FOLDER"/*.dev-edition-default)
	if ((firefox_had_nullglob == 0)); then shopt -u nullglob; fi

	if ((${#firefox_profiles[@]} == 0)); then
		info "Could not find Firefox profile folder. Skipping Firefox settings..."
	else
		FIREFOX_PROFILE="${firefox_profiles[0]}"
		backup_or_delete "$FIREFOX_PROFILE/user.js"
		if ! ln -sf "$DOTFILES/user.js" "$FIREFOX_PROFILE/user.js"; then
			warn "Failed to link Firefox user.js"
		fi
	fi
	unset firefox_had_nullglob firefox_profiles
fi
