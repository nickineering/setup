#!/opt/homebrew/bin/bash

# Setup Node Version Manager (NVM) for local JavaScript
mkdir -p ~/.nvm
export NVM_DIR="$HOME/.nvm"

NVM_SCRIPT="$(brew --prefix)/opt/nvm/nvm.sh"
if [ ! -s "$NVM_SCRIPT" ]; then
	echo "Error: NVM script not found at $NVM_SCRIPT. Is nvm installed via brew?" >&2
	exit 1
fi

# This Bash script has an unset variable, so we have to temporarily allow that
set +u
# shellcheck disable=SC1090
\. "$NVM_SCRIPT"

PREVIOUS_NODE_VERSION=$(nvm current)
# shellcheck disable=SC1090
if ! nvm install --lts; then
	echo "Error: Failed to install Node LTS" >&2
	set -u
	exit 1
fi

NEW_NODE_VERSION=$(nvm current)
if [ "$PREVIOUS_NODE_VERSION" != "$NEW_NODE_VERSION" ] && [ "$PREVIOUS_NODE_VERSION" != "none" ] && [ "$PREVIOUS_NODE_VERSION" != "system" ]; then
	nvm uninstall "$PREVIOUS_NODE_VERSION" || print_green "Warning: Failed to uninstall previous Node version"
fi

if ! npm install -g npm; then
	print_green "Warning: Failed to upgrade npm"
fi
# Now we re-enable strict mode
set -u
