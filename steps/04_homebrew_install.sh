# shellcheck shell=bash
# shellcheck disable=SC2034,SC2154
#
# Diffs desired state (state/*.txt) against what's installed and adds anything
# missing. Prompts to remove packages/casks deleted from state (detected in step 01).

: "${SETUP:?}" "${removed_packages?}" "${removed_casks?}"

desired_packages=$(parse_state_file "$SETUP/state/brew_packages.txt")
installed_packages=$(get_installed_packages)
missing_packages=$(set_difference "$installed_packages" "$desired_packages")
if [[ -n "$missing_packages" ]]; then
	install_missing package "$missing_packages"
else
	info "All packages installed"
fi
echo ""

# macOS quarantines chromedriver since it's not from the App Store
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

[[ -n "$removed_packages" ]] && prompt_uninstall package "$removed_packages"
[[ -n "$removed_casks" ]] && prompt_uninstall cask "$removed_casks"
echo ""
