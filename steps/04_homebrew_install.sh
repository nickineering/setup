# shellcheck shell=bash
# shellcheck disable=SC2034,SC2154
#
# Diffs desired formulae against what's installed and adds anything missing.
# Cask installs/uninstalls are deferred to the privileged section (step 12).

: "${SETUP:?}" "${removed_packages?}"

desired_packages=$(parse_state_file "$SETUP/state/brew_packages.txt")
installed_packages=$(get_installed_packages)
missing_packages=$(set_difference "$installed_packages" "$desired_packages")
if [[ -n "$missing_packages" ]]; then
	install_missing package "$missing_packages"
else
	info "All packages installed"
fi

[[ -n "$removed_packages" ]] && prompt_uninstall package "$removed_packages"
echo ""
