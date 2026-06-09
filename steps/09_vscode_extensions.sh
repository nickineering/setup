# shellcheck shell=bash
# shellcheck disable=SC2034,SC2154
#
# ── VSCode Extensions ────────────────────────────────────────────────────────
# Installs missing extensions, prompts for removals from state file changes
# (detected in step 01), then updates all installed extensions. Retries the
# update once on ENOTEMPTY (a transient race in the VSCode CLI).
# Requires: lib/packages.sh (parse_state_file, set_difference, install_missing,
#           get_installed_extensions, prompt_uninstall)
# Requires: steps/01 (removed_extensions)
# ─────────────────────────────────────────────────────────────────────────────
: "${SETUP:?}" "${removed_extensions?}"

if command -v code &>/dev/null; then
	desired_extensions=$(parse_state_file "$SETUP/state/vscode_extensions.txt" | tr '[:upper:]' '[:lower:]')
	installed_extensions=$(get_installed_extensions)
	missing_extensions=$(set_difference "$installed_extensions" "$desired_extensions")
	if [[ -n "$missing_extensions" ]]; then
		install_missing extension "$missing_extensions"
	else
		echo -e "${dim}All extensions installed${reset}"
	fi
	# Handle removals from state file changes
	[[ -n "$removed_extensions" ]] && prompt_uninstall extension "$removed_extensions"
	echo ""

	echo -e "${bold}${cyan}=== Updating VSCode extensions ===${reset}"
	update_output=$(NODE_NO_WARNINGS=1 code --update-extensions 2>&1)
	if echo "$update_output" | grep -q "ENOTEMPTY"; then
		sleep 2
		update_output=$(NODE_NO_WARNINGS=1 code --update-extensions 2>&1)
	fi
	if [[ "$update_output" == "No extension to update" ]]; then
		echo -e "${dim}All extensions up to date${reset}"
	else
		echo "$update_output"
	fi
else
	echo -e "${dim}VSCode CLI not found - skipping (install VSCode cask first)${reset}"
fi
echo ""
