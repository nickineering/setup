#!/opt/homebrew/bin/bash

# Setup Node Version Manager (NVM) for local JavaScript
mkdir -p ~/.nvm
export NVM_DIR="$HOME/.nvm"

# This Bash script has an unset variable, so we have to temporarily allow that
set +u
# shellcheck disable=SC1091
[ -s "$(brew --prefix)/opt/nvm/nvm.sh" ] && \. "$(brew --prefix)/opt/nvm/nvm.sh"

# nvm version has an unbound variable, so we have to temporarily allow that
set +u
PREVIOUS_NODE_VERSION=$(nvm current)
# shellcheck disable=SC1090
nvm install --lts
NEW_NODE_VERSION=$(nvm current)
if [ "$PREVIOUS_NODE_VERSION" != "$NEW_NODE_VERSION" ]; then
	nvm uninstall "$PREVIOUS_NODE_VERSION"
fi
npm install -g npm
# Now we re-enable strict mode
set -u
