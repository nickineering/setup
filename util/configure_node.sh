#!/usr/local/bin/bash

# Setup Node Version Manager (NVM) for local JavaScript
mkdir -p ~/.nvm
export NVM_DIR="$HOME/.nvm"
# shellcheck disable=SC1091
[ -s "$(brew --prefix)/opt/nvm/nvm.sh" ] && \. "$(brew --prefix)/opt/nvm/nvm.sh"

PREVIOUS_NODE_VERSION=$(nvm version)
# shellcheck disable=SC1090
nvm install --lts
NEW_NODE_VERSION=$(nvm version)
if [ "$PREVIOUS_NODE_VERSION" != "$NEW_NODE_VERSION" ]; then
    nvm uinstall "$PREVIOUS_NODE_VERSION"
fi

npm install -g npm
