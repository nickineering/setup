#!/opt/homebrew/bin/bash

# This script continues what bootstrap.sh started

# Bash strict mode
set -euo pipefail

# Print commands as they are run
set -v

export SETUP=~/projects/setup
export DOTFILES=$SETUP/linked
cd "$SETUP"/util

# Generic printing utility
source print.sh

# Move all files that will be destroyed to the backups folder so they are not overwritten
source backup_or_delete.sh
while IFS= read -r file; do
	backup_or_delete ~/"$file"
done <"$SETUP"/state/linked_files.txt
backup_or_delete "$HOME/Library/Application Support/Code/User/settings.json"
backup_or_delete "$HOME/Library/Application Support/ruff/ruff.toml"
print_green "Deleted existing links so they can be freshly created"

# Brew taps
brew tap beeftornado/rmtree # Run `brew rmtree` to remove package and dependencies
brew tap hashicorp/tap      # For Terraform

# Install Homebrew packages
source strip_comments.sh
while IFS= read -r package; do
	brew install "$(strip_comments "$package")"
done <"$SETUP"/state/brew_packages.txt
# Finish installing chromedriver
xattr -d com.apple.quarantine chromedriver
print_green "Installed Homebrew packages"

# Install Homebrew casks
while IFS= read -r cask; do
	brew install --cask "$(strip_comments "$cask")"
done <"$SETUP"/state/brew_casks.txt
print_green "Installed Homebrew casks"

# Install VSCode extensions. View current with `code --list-extensions`
while IFS= read -r extension; do
	code --install-extension "$extension"
done <"$SETUP"/state/vscode_extensions.txt
print_green "Installed VSCode extensions"

# Configure Zsh to use Oh My Zsh. Affects ~/.zshrc so must be before linking.
source configure_zsh.sh

# Copy templates for customization files if they do not already exist
while IFS= read -r file; do
	if [ -e ~/"$file" ]; then
		print_green "A ~/$file file already exists. If you'd like to replace it please \
do so manually."
	else
		cp "$SETUP/copied/$file" ~/
	fi
done <"$SETUP"/state/copied_files.txt

# Link custom settings to that they are updated automatically when changes are pulled
while IFS= read -r file; do
	ln -s "$DOTFILES/$file" ~/
done <"$SETUP"/state/linked_files.txt
ln -s "$DOTFILES"/settings.json "$HOME/Library/Application Support/Code/User/"

source configure_firefox.sh

# Create Vim directories
mkdir -p ~/.vim/swaps/
mkdir -p ~/.vim/backups/
mkdir -p ~/.vim/undo/

print_green "Copied and linked required files"

source configure_ruff.sh
print_green "Configured Ruff"

source configure_python.sh
print_green "Completed Python installs"

source configure_node.sh
print_green "Completed installs. Now configuring settings..."

# Configure Zoom to automatically update
sudo launchctl load -w /Library/LaunchDaemons/us.zoom.ZoomDaemon.plist

# Configures the operating system on import
source configure_macos.sh

print_green "Configured MacOS. Now downloading OS updates. This could take a while..."

# Install MacOS updates
sudo softwareupdate -i -a

print_green "Please follow the instructions in $SETUP/MANUAL_STEPS.md and then reboot \
your computer." "AUTOMATED CONFIGURATION COMPLETE"
