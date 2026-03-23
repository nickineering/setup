#!/bin/bash
# * Bash 3.2 (2007)

# This is the entrypoint
# Run to setup a new Mac or reconfigure an existing Mac

# Bash strict mode
set -euo pipefail

# Guard: refuse to run as root
if [ "$(id -u)" -eq 0 ]; then
	echo "Error: Do not run this script as root" >&2
	exit 1
fi

# Trap handler for cleanup on interruption
CURRENT_STEP=""
# shellcheck disable=SC2329 # Function appears unused but is invoked by trap
cleanup_on_interrupt() {
	echo "" >&2
	echo "Bootstrap interrupted!" >&2
	if [ "$CURRENT_STEP" != "" ]; then
		echo "Stopped during: $CURRENT_STEP" >&2
	fi
	echo "To resume, re-run: curl -s https://raw.githubusercontent.com/nickineering/setup/master/bootstrap.sh | /bin/bash" >&2
	exit 130
}
trap cleanup_on_interrupt INT TERM

# Colors for output
green='\033[32m'
yellow='\033[33m'
cyan='\033[36m'
bold='\033[1m'
reset='\033[0m'

echo -e "${bold}${cyan}=== AUTOMATICALLY CONFIGURING MAC ===${reset}"
echo -e "${green}Please leave everything closed and wait for your Mac to be configured. This will take a while.${reset}"

CURRENT_STEP="installing Homebrew"
# Install Homebrew, a Mac package manager
if command -v brew; then
	echo -e "${green}Homebrew already installed${reset}"
else
	echo -e "${green}Installing Homebrew...${reset}"
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
	echo -e "${green}Installed Homebrew${reset}"
fi

CURRENT_STEP="cloning setup repository"
# Make a projects directory and clone the repo into it
mkdir -p ~/projects
export SETUP=~/projects/setup
brew install git # Use Homebrew so that updates are easy
if [ -d "$SETUP" ]; then
	git -C "$SETUP" pull || echo -e "${yellow}Warning: Failed to pull latest commits${reset}"
	echo -e "${green}Pulled latest commits from repo${reset}"
else
	if ! git clone https://github.com/nickineering/setup.git "$SETUP"; then
		echo "Error: Failed to clone setup repo" >&2
		exit 1
	fi
	echo -e "${green}Cloned setup repo into projects directory${reset}"
fi

CURRENT_STEP="installing modern Bash"
# MacOS comes with Bash 3.2, but we want the latest. Download the latest Bash and then
# continue using it.
if ! brew install bash; then
	echo "Error: Failed to install bash via Homebrew" >&2
	exit 1
fi
"$SETUP"/run.sh
