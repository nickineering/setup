#!/bin/bash
# * Bash 3.2 (2007)

# This is the entrypoint
# Run to setup a new Mac or reconfigure an existing Mac

# Bash strict mode
set -euo pipefail

# Print commands as they are run
set -v

# Start running the print utility first so we can update the user on progress.
# We must save the file first because we are on Bash 3.2
if ! curl -fsSL https://raw.githubusercontent.com/nickineering/setup/master/util/print.sh >/tmp/print.sh; then
	echo "Error: Failed to download print utility. Check your internet connection." >&2
	exit 1
fi
# shellcheck source=util/print.sh
source /tmp/print.sh

print_green "Please leave everything closed and wait for your Mac to be configured. \
This will take a while." "AUTOMATICALLY CONFIGURING MAC"

# Install Homebrew, a Mac package manager
if command -v brew; then
	brew upgrade || print_green "Warning: Some Homebrew packages failed to upgrade"
	print_green "Upgraded Homebrew packages"
else
	print_green "Installing Homebrew..."
	HOMEBREW_INSTALL_SCRIPT=$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)
	if [ "$HOMEBREW_INSTALL_SCRIPT" = "" ]; then
		echo "Error: Failed to download Homebrew installer" >&2
		exit 1
	fi
	if ! NONINTERACTIVE=1 /bin/bash -c "$HOMEBREW_INSTALL_SCRIPT"; then
		echo "Error: Homebrew installation failed" >&2
		exit 1
	fi
	eval "$(/opt/homebrew/bin/brew shellenv)"
	print_green "Installed Homebrew"
fi

# Make a projects directory and clone the repo into it
mkdir -p ~/projects
export SETUP=~/projects/setup
brew install git # Use Homebrew so that updates are easy
if [ -d "$SETUP" ]; then
	git -C "$SETUP" pull || print_green "Warning: Failed to pull latest commits"
	print_green "Pulled latest commits from repo"
else
	if ! git clone https://github.com/nickineering/setup.git "$SETUP"; then
		echo "Error: Failed to clone setup repo" >&2
		exit 1
	fi
	print_green "Cloned repo into projects directory"
fi

# MacOS comes with Bash 3.2, but we want the latest. Download the latest Bash and then
# continue using it.
if ! brew install bash; then
	echo "Error: Failed to install bash via Homebrew" >&2
	exit 1
fi
source "$SETUP"/util/setup.sh
