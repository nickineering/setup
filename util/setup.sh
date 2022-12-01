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

# Brew taps
brew tap homebrew/cask-versions # Supplies firefox-developer-edition
brew tap beeftornado/rmtree     # Run `brew rmtree` to remove package and dependencies

# Install Homebrew packages
source strip_comments.sh
while IFS= read -r package; do
    brew install "$(strip_comments "$package")"
done <"$MAC"/state/brew_packages.txt
print_green "Installed Homebrew packages"

# Install Homebrew casks
while IFS= read -r cask; do
    brew install --cask "$(strip_comments "$cask")"
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

source configure_firefox.sh

# Create Vim directories
mkdir -p ~/.vim/swaps/
mkdir -p ~/.vim/backups/
mkdir -p ~/.vim/undo/

print_green "Copied and linked required files"

source configure_python.sh
print_green "Completed Python installs"

source configure_node.sh
print_green "Completed installs. Now configuring settings..."

# Configures the operating system on import
source configure_macos.sh

print_green "Configured MacOS. Now downloading OS updates. This could take a while..."

# Install MacOS updates
sudo softwareupdate -i -a

print_green "Please follow the instructions in $MAC/MANUAL_STEPS.md and then reboot \
your computer." "AUTOMATED CONFIGURATION COMPLETE"
