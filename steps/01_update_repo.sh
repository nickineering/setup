# shellcheck shell=bash
# shellcheck disable=SC2034,SC2154
#
# ── Update Repo ──────────────────────────────────────────────────────────────
# Snapshots state files before and after pulling, then diffs them to find what
# was added or removed upstream. The removed_* variables are consumed by steps
# 4 (packages/casks), 7 (npm), and 9 (extensions) to prompt for uninstalls.
# Requires: lib/packages.sh (parse_state_file, set_difference)
# ─────────────────────────────────────────────────────────────────────────────
: "${SETUP:?}"

# Capture state before pull (for detecting changes after pull)
old_packages=$(parse_state_file "$SETUP/state/brew_packages.txt")
old_casks=$(parse_state_file "$SETUP/state/brew_casks.txt")
old_extensions=$(parse_state_file "$SETUP/state/vscode_extensions.txt" | tr '[:upper:]' '[:lower:]')
old_npm=$(parse_state_file "$SETUP/state/npm_packages.txt")

pull_output=$(git -C "$SETUP" pull 2>&1) || {
	echo -e "${yellow}Warning: git pull failed (local changes?) - state file changes won't be detected${reset}"
}
if [[ "$pull_output" == "Already up to date." ]]; then
	echo -e "${dim}Up to date${reset}"
else
	echo "$pull_output"
fi

# Compare after pull to find what changed
new_packages=$(parse_state_file "$SETUP/state/brew_packages.txt")
new_casks=$(parse_state_file "$SETUP/state/brew_casks.txt")
new_extensions=$(parse_state_file "$SETUP/state/vscode_extensions.txt" | tr '[:upper:]' '[:lower:]')
new_npm=$(parse_state_file "$SETUP/state/npm_packages.txt")

# Calculate removals from state file changes (will prompt user in later steps)
removed_packages=$(set_difference "$new_packages" "$old_packages")
removed_casks=$(set_difference "$new_casks" "$old_casks")
removed_extensions=$(set_difference "$new_extensions" "$old_extensions")
removed_npm=$(set_difference "$new_npm" "$old_npm")
echo ""
