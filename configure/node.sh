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
if ! nvm install --lts; then
	echo -e "${yellow}Warning: Failed to install Node LTS${reset}" >&2
	return 0
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

npm install -g npm || echo -e "${yellow}Warning: Failed to upgrade npm${reset}"
