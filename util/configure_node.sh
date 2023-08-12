#!/usr/local/bin/bash

# Setup Node Version Manager (NVM) for local JavaScript
mkdir -p ~/.nvm
export NVM_DIR="$HOME/.nvm"
# shellcheck disable=SC1091
[ -s "$(brew --prefix)/opt/nvm/nvm.sh" ] && \. "$(brew --prefix)/opt/nvm/nvm.sh"
# shellcheck disable=SC1090
nvm install --lts

npm install -g @githubnext/github-copilot-cli
