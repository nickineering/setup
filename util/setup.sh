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

# Trap handler for cleanup on interruption
CURRENT_STEP=""
# shellcheck disable=SC2329  # Invoked by trap
cleanup_on_interrupt() {
	echo "" >&2
	echo "Setup interrupted!" >&2
	if [ "$CURRENT_STEP" != "" ]; then
		echo "Stopped during: $CURRENT_STEP" >&2
	fi
	echo "To resume, run: $SETUP/util/setup.sh" >&2
	echo "Backups (if any) are in: ~/Documents/backups/" >&2
	exit 130
}
trap cleanup_on_interrupt INT TERM

# Validate that a required state file exists and is readable
require_state_file() {
	local file="$SETUP/state/$1"
	if [ ! -f "$file" ]; then
		echo "Error: Required state file not found: $file" >&2
		exit 1
	fi
	if [ ! -r "$file" ]; then
		echo "Error: State file not readable: $file" >&2
		exit 1
	fi
}

# Validate all required state files exist before starting
for state_file in linked_files.txt brew_packages.txt brew_casks.txt vscode_extensions.txt copied_files.txt; do
	require_state_file "$state_file"
done
print_green "Validated all required state files"

CURRENT_STEP="backing up existing files"
# Move all files that will be destroyed to the backups folder so they are not overwritten
source backup_or_delete.sh
while IFS= read -r file; do
	backup_or_delete ~/"$file"
done <"$SETUP"/state/linked_files.txt
backup_or_delete "$HOME/Library/Application Support/Code/User/settings.json"
backup_or_delete "$HOME/Library/Application Support/ruff/ruff.toml"
backup_or_delete ~/dprint.jsonc
print_green "Deleted existing links so they can be freshly created"

CURRENT_STEP="configuring Homebrew taps"
# Brew taps
brew tap beeftornado/rmtree # Run `brew rmtree` to remove package and dependencies
brew tap hashicorp/tap      # For Terraform

CURRENT_STEP="installing Homebrew packages"
# Install Homebrew packages
source strip_comments.sh
while IFS= read -r package; do
	package_name=$(strip_comments "$package")
	# Skip empty lines
	[ "$package_name" = "" ] && continue
	if ! brew install "$package_name"; then
		echo "Warning: Failed to install package: $package_name" >&2
	fi
done <"$SETUP"/state/brew_packages.txt
# Finish installing chromedriver (may fail if chromedriver wasn't installed)
CHROMEDRIVER_PATH="$(brew --prefix)/bin/chromedriver"
if [ -f "$CHROMEDRIVER_PATH" ]; then
	xattr -d com.apple.quarantine "$CHROMEDRIVER_PATH" 2>/dev/null || true
fi
print_green "Installed Homebrew packages"

CURRENT_STEP="installing Homebrew casks"
# Install Homebrew casks
while IFS= read -r cask; do
	cask_name=$(strip_comments "$cask")
	# Skip empty lines
	[ "$cask_name" = "" ] && continue
	if ! brew install --cask "$cask_name"; then
		echo "Warning: Failed to install cask: $cask_name" >&2
	fi
done <"$SETUP"/state/brew_casks.txt
print_green "Installed Homebrew casks"

CURRENT_STEP="installing VSCode extensions"
# Install VSCode extensions. View current with `code --list-extensions`
if command -v code &>/dev/null; then
	while IFS= read -r extension; do
		# Skip empty lines
		[ "$extension" = "" ] && continue
		if ! code --install-extension "$extension"; then
			echo "Warning: Failed to install VSCode extension: $extension" >&2
		fi
	done <"$SETUP"/state/vscode_extensions.txt
	print_green "Installed VSCode extensions"
else
	print_green "Warning: VSCode CLI not found. Skipping extension installation."
fi

CURRENT_STEP="configuring Zsh"
# Configure Zsh to use Oh My Zsh. Affects ~/.zshrc so must be before linking.
source configure_zsh.sh

CURRENT_STEP="copying template files"
# Copy templates for customization files if they do not already exist
while IFS= read -r file; do
	if [ -e ~/"$file" ]; then
		print_green "A ~/$file file already exists. If you'd like to replace it please \
do so manually."
	else
		cp "$SETUP/copied/$file" ~/
	fi
done <"$SETUP"/state/copied_files.txt

CURRENT_STEP="creating symlinks"
# Link custom settings so that they are updated automatically when changes are pulled
while IFS= read -r file; do
	# Skip empty lines
	[ "$file" = "" ] && continue
	if [ ! -f "$DOTFILES/$file" ]; then
		echo "Warning: Dotfile not found: $DOTFILES/$file" >&2
		continue
	fi
	if ! ln -sfn "$DOTFILES/$file" ~/; then
		echo "Warning: Failed to link $file" >&2
	fi
done <"$SETUP"/state/linked_files.txt

# Link VSCode settings if the directory exists
VSCODE_USER_DIR="$HOME/Library/Application Support/Code/User"
if [ -d "$VSCODE_USER_DIR" ]; then
	if ! ln -sfn "$DOTFILES"/settings.json "$VSCODE_USER_DIR/settings.json"; then
		echo "Warning: Failed to link VSCode settings.json" >&2
	fi
else
	print_green "Warning: VSCode user directory not found. Skipping settings link."
fi

# Link dprint config (from repo root, not linked/, to avoid dprint excluding linked/)
if ! ln -sfn "$SETUP"/dprint.jsonc ~/dprint.jsonc; then
	echo "Warning: Failed to link dprint.jsonc" >&2
fi

source configure_firefox.sh

# Create Vim directories
mkdir -p ~/.vim/swaps/
mkdir -p ~/.vim/backups/
mkdir -p ~/.vim/undo/

print_green "Copied and linked required files"

CURRENT_STEP="configuring Ruff"
source configure_ruff.sh
print_green "Configured Ruff"

CURRENT_STEP="configuring Claude"
source configure_claude.sh

CURRENT_STEP="configuring Python"
source configure_python.sh
print_green "Completed Python installs"

CURRENT_STEP="configuring Node"
source configure_node.sh
print_green "Completed installs. Now configuring settings..."

# Configure Zoom to automatically update (if Zoom is installed)
ZOOM_DAEMON="/Library/LaunchDaemons/us.zoom.ZoomDaemon.plist"
if [ -f "$ZOOM_DAEMON" ]; then
	sudo launchctl load -w "$ZOOM_DAEMON" 2>/dev/null || print_green "Warning: Failed to configure Zoom auto-update"
else
	print_green "Zoom daemon not found. Skipping auto-update configuration."
fi

CURRENT_STEP="configuring macOS"
# Configures the operating system on import
source configure_macos.sh

print_green "Configured MacOS. Now downloading OS updates. This could take a while..."

CURRENT_STEP="installing macOS updates"
# Install MacOS updates
sudo softwareupdate -i -a

print_green "Please follow the instructions in $SETUP/MANUAL_STEPS.md and then reboot \
your computer." "AUTOMATED CONFIGURATION COMPLETE"
