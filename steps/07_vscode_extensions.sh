# shellcheck shell=bash
# shellcheck disable=SC2034,SC2154
#
# Installs missing extensions, prompts for removals from state file changes
# (detected in step 01), then updates all installed extensions.
: "${SETUP:?}" "${removed_extensions?}"

if command -v code &>/dev/null; then
	desired_extensions=$(parse_state_file "$SETUP/state/vscode_extensions.txt" | tr '[:upper:]' '[:lower:]')
	installed_extensions=$(get_installed_extensions)
	missing_extensions=$(set_difference "$installed_extensions" "$desired_extensions")
	if [[ -n "$missing_extensions" ]]; then
		install_missing extension "$missing_extensions"
	else
		info "All extensions installed"
	fi
	# Handle removals from state file changes
	[[ -n "$removed_extensions" ]] && prompt_uninstall extension "$removed_extensions"
	echo ""

	action "Updating extensions..."
	update_output=$(NODE_NO_WARNINGS=1 code --update-extensions 2>&1)
	if echo "$update_output" | grep -q "ENOTEMPTY"; then
		# Transient race condition in VSCode CLI — retry once
		sleep 2
		update_output=$(NODE_NO_WARNINGS=1 code --update-extensions 2>&1)
	fi
	if [[ "$update_output" == "No extension to update" ]]; then
		info "All extensions up to date"
	else
		echo "$update_output"
	fi
else
	info "VSCode CLI not found - skipping"
fi
echo ""
