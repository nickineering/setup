# shellcheck shell=bash
# shellcheck disable=SC2034,SC2154
#
# ── Homebrew Install ─────────────────────────────────────────────────────────
# Diffs desired state (state/*.txt) against what's installed and adds anything
# missing. Also prompts the user to remove packages/casks that were deleted
# from state files (detected in step 01).
# Requires: lib/packages.sh (parse_state_file, set_difference, install_missing,
#           get_installed_packages, get_installed_casks, prompt_uninstall)
# Requires: steps/01 (removed_packages, removed_casks)
# ─────────────────────────────────────────────────────────────────────────────
: "${SETUP:?}" "${removed_packages?}" "${removed_casks?}"

# Get full desired state and install anything missing
desired_packages=$(parse_state_file "$SETUP/state/brew_packages.txt")
installed_packages=$(get_installed_packages)
missing_packages=$(set_difference "$installed_packages" "$desired_packages")
if [[ -n "$missing_packages" ]]; then
	install_missing package "$missing_packages"
else
	info "All packages installed"
fi
echo ""

# Finish installing chromedriver
CHROMEDRIVER_PATH="$(brew --prefix)/bin/chromedriver"
if [[ -f "$CHROMEDRIVER_PATH" ]]; then
	xattr -d com.apple.quarantine "$CHROMEDRIVER_PATH" 2>/dev/null || true
fi

echo "› Casks:"
desired_casks=$(parse_state_file "$SETUP/state/brew_casks.txt")
installed_casks=$(get_installed_casks)
missing_casks=$(set_difference "$installed_casks" "$desired_casks")
if [[ -n "$missing_casks" ]]; then
	install_missing cask "$missing_casks"
else
	info "All casks installed"
fi

# Prompt for removals from state file changes (detected in step 1)
[[ -n "$removed_packages" ]] && prompt_uninstall package "$removed_packages"
[[ -n "$removed_casks" ]] && prompt_uninstall cask "$removed_casks"
echo ""
