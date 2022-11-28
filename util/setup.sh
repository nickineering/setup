#!/usr/local/bin/bash

# This script continues what bootstrap.sh started

# Abort on error
set -e

# Print commands that are run as they are run
set -v

export MAC=~/projects/mac
export DOTFILES=$MAC/linked
cd "$MAC"/util

# Generic printing utility
source print.sh

# Move all files that will be destroyed to the backups folder so they are not overwritten
source backup_or_delete.sh
while IFS= read -r file; do
    backup_or_delete ~/"$file"
done <"$MAC"/state/linked_files.txt
backup_or_delete "$HOME/Library/Application Support/Code/User/settings.json"
print_green "Deleted existing links so they can be freshly created"

# Install Homebrew packages
while IFS= read -r line; do
    # Remove comments
    package=$(echo "$line" | head -n1 | awk '{print $1;}')
    brew install "$package"
done <"$MAC"/state/brew_packages.txt
print_green "Installed Homebrew packages"

brew tap homebrew/cask-versions # Supplies firefox-developer-edition

# Install Homebrew casks
while IFS= read -r line; do
    # Remove comments
    cask=$(echo "$line" | head -n1 | awk '{print $1;}')
    brew install --cask "$cask"
done <"$MAC"/state/brew_casks.txt
print_green "Installed Homebrew casks"

# ColorSlurp color picker - get any color on screen
mas install 1287239339
print_green "Installed Mac App Store apps"

# Install VSCode extensions. View current with `code --list-extensions`
while IFS= read -r extension; do
    code --install-extension "$extension"
done <"$MAC"/state/vscode_extensions.txt
print_green "Installed VSCode extensions"

# Configure Zsh to use Oh My Zsh. Affects ~/.zshrc so must be before linking.
source configure_zsh.sh

# Copy templates for customization files if they do not already exist
while IFS= read -r file; do
    if [ -e ~/"$2" ]; then
        print_green "A ~/$file file already exists. If you'd like to replace it please \
do so manually."
    else
        cp "$MAC/copied/$file" ~/
    fi
done <"$MAC"/state/copied_files.txt

# Link custom settings to that they are updated automatically when changes are pulled
while IFS= read -r file; do
    ln -s "$DOTFILES/$file" ~/
done <"$MAC"/state/linked_files.txt
ln -s "$DOTFILES"/settings.json "$HOME/Library/Application Support/Code/User/"

# Install custom Firefox settings
FIREFOX_FOLDER="$HOME/Library/Application Support/Firefox/Profiles"
FIREFOX_PROFILE=$(find "$FIREFOX_FOLDER" -name '*.dev-edition-default')
if [ -z "$FIREFOX_PROFILE" ]; then
    print_green "Could not find Firefox profile folder. Skipping Firefox settings..."
else
    backup_or_delete "$FIREFOX_PROFILE"/user.js
    ln -s "$DOTFILES"/user.js "$FIREFOX_PROFILE"
fi

print_green "Copied and linked required files"

# Pyenv configuration
# Load these here to avoid sourcing our profile
export PYENV_ROOT="$HOME/.pyenv"
command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"
MATCHING_PY=$(pyenv install --list | grep --extended-regexp "^\s*[0-9][0-9.]*[0-9]\s*$")
LATEST_PY=$(echo "$MATCHING_PY" | tail -1 | xargs)
# Must check if we already have the latest to prevent pyenv error
HAS_LATEST=$(pyenv versions | grep "$LATEST_PY")
if [ ! "$HAS_LATEST" ]; then
    pyenv install "$LATEST_PY"
fi
pyenv global "$LATEST_PY"
pyenv shell "$LATEST_PY"
pip install --upgrade pip

# Delete any existing pip packages and then reinstall fresh
pip freeze | xargs pip uninstall -y
# Keep Python utility packages as globals
while IFS= read -r package; do
    pip install "$package"
done <"$MAC"/state/python_packages.txt
print_green "Completed Python installs"

# Setup Node Version Manager (NVM) for local JavaScript
mkdir -p ~/.nvm
export NVM_DIR="$HOME/.nvm"
# shellcheck disable=SC1091
[ -s "$(brew --prefix)/opt/nvm/nvm.sh" ] && \. "$(brew --prefix)/opt/nvm/nvm.sh"
# shellcheck disable=SC1090
nvm install --lts

print_green "Completed installs. Now configuring settings..."

# Configures the operating system on import
source configure_macos.sh

print_green "Please follow the instructions in $MAC/MANUAL_STEPS.md and then reboot \
your computer." "AUTOMATED CONFIGURATION COMPLETE"
