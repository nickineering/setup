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
curl -s https://raw.githubusercontent.com/nickineering/setup/master/util/print.sh >/tmp/print.sh
# shellcheck source=util/print.sh
source /tmp/print.sh

print_green "Please leave everything closed and wait for your Mac to be configured. \
This will take a while." "AUTOMATICALLY CONFIGURING MAC"

# Install Homebrew, a Mac package manager
if command -v brew; then
	brew upgrade
	print_green "Upgraded Homebrew packages"
else
	print_green "Installing Homebrew. Please follow the on screen prompts to continue..."
	INTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
	eval "$(/opt/homebrew/bin/brew shellenv)"
	print_green "Installed Homebrew"
fi

# Make a projects directory and clone the repo into it
mkdir -p ~/projects
export SETUP=~/projects/setup
brew install git # Use Homebrew so that updates are easy
if [ -d "$SETUP" ]; then
	git -C $SETUP pull
	print_green "Pulled latest commits from repo"
else
	git clone https://github.com/nickineering/setup.git $SETUP
	print_green "Cloned repo into projects directory"
fi

# MacOS comes with Bash 3.2, but we want the latest. Download the latest Bash and then
# continue using it.
brew install bash
source $SETUP/util/setup.sh
