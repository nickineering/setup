# shellcheck shell=bash
# shellcheck disable=SC2034,SC2154
#
# Snapshots state files before/after git pull to detect what was added or removed.
# The removed_* variables are consumed by steps 4, 6, 7, and 9.

: "${SETUP:?}"

# Capture state before pull
old_packages=$(parse_state_file "$SETUP/state/brew_packages.txt")
old_casks=$(parse_state_file "$SETUP/state/brew_casks.txt")
old_extensions=$(parse_state_file "$SETUP/state/vscode_extensions.txt" | tr '[:upper:]' '[:lower:]')
old_npm=$(parse_state_file "$SETUP/state/npm_packages.txt")
old_links=$(parse_state_file "$SETUP/state/linked_files.txt")
old_taps=$(parse_state_file "$SETUP/state/brew_taps.txt")

pull_output=$(git -C "$SETUP" pull 2>&1) || {
	warn "git pull failed (local changes?) - state file changes won't be detected"
}
if [[ "$pull_output" == "Already up to date." ]]; then
	info "Up to date"
else
	echo "$pull_output"
fi

# Capture state after pull
new_packages=$(parse_state_file "$SETUP/state/brew_packages.txt")
new_casks=$(parse_state_file "$SETUP/state/brew_casks.txt")
new_extensions=$(parse_state_file "$SETUP/state/vscode_extensions.txt" | tr '[:upper:]' '[:lower:]')
new_npm=$(parse_state_file "$SETUP/state/npm_packages.txt")
new_links=$(parse_state_file "$SETUP/state/linked_files.txt")
new_taps=$(parse_state_file "$SETUP/state/brew_taps.txt")

# Items present in old state but absent from new = removed upstream
removed_packages=$(set_difference "$new_packages" "$old_packages")
removed_casks=$(set_difference "$new_casks" "$old_casks")
removed_extensions=$(set_difference "$new_extensions" "$old_extensions")
removed_npm=$(set_difference "$new_npm" "$old_npm")
removed_links=$(set_difference "$new_links" "$old_links")
removed_taps=$(set_difference "$new_taps" "$old_taps")
echo ""
