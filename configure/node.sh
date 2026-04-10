# shellcheck shell=bash
# shellcheck disable=SC2154 # Variables like $yellow defined in lib/colors.sh
# Sourced by run.sh after verifying nvm exists

# Setup Node Version Manager (NVM) for local JavaScript
mkdir -p ~/.nvm
export NVM_DIR="$HOME/.nvm"

NVM_SCRIPT="$(brew --prefix)/opt/nvm/nvm.sh"

# nvm.sh has unset variables, so temporarily disable strict mode
# Use trap to ensure we always re-enable it
_restore_strict_mode() { set -u; }
trap _restore_strict_mode RETURN

set +u
# shellcheck disable=SC1090 # Can't follow dynamic source path
\. "$NVM_SCRIPT"

PREVIOUS_NODE_VERSION=$(nvm current)
# shellcheck disable=SC1090 # nvm is a shell function, not a file
output=$(nvm install --lts 2>&1) || {
	echo -e "${yellow}Warning: Failed to install Node LTS${reset}" >&2
	return 0
}
# Only show output if a new version was installed
if [[ "$output" != *"already installed"* ]]; then
	echo "$output"
fi

NEW_NODE_VERSION=$(nvm current)
if [ "$PREVIOUS_NODE_VERSION" != "$NEW_NODE_VERSION" ] && [ "$PREVIOUS_NODE_VERSION" != "none" ] && [ "$PREVIOUS_NODE_VERSION" != "system" ]; then
	echo -n "Uninstall old Node version ${PREVIOUS_NODE_VERSION}? [y/N]: "
	read -r -n 1 confirm </dev/tty
	echo ""
	if [[ "$confirm" =~ ^[Yy]$ ]]; then
		nvm uninstall "$PREVIOUS_NODE_VERSION" || echo -e "${yellow}Warning: Failed to uninstall previous Node version${reset}"
	else
		echo -e "${dim}Kept ${PREVIOUS_NODE_VERSION}${reset}"
	fi
fi

# Update npm silently (warnings will still show on failure)
npm install -g --fund=false --audit=false npm >/dev/null 2>&1 || echo -e "${yellow}Warning: Failed to upgrade npm${reset}"

# Install missing global npm packages
NPM_STATE_FILE="$SETUP/state/npm_packages.txt"
if [[ -f "$NPM_STATE_FILE" ]]; then
	desired_npm=$(parse_state_file "$NPM_STATE_FILE")
	installed_npm=$(get_installed_npm_packages)
	missing_npm=$(set_difference "$installed_npm" "$desired_npm")
	if [[ -n "$missing_npm" ]]; then
		install_missing npm "$missing_npm"
	fi

	# Update all managed npm packages
	while IFS= read -r pkg; do
		[[ -z "$pkg" ]] && continue
		npm update -g --fund=false --audit=false "$pkg" >/dev/null 2>&1 || echo -e "${yellow}Warning: Failed to update $pkg${reset}"
	done <<<"$desired_npm"
fi
