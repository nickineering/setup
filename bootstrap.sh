#!/bin/bash
# * Bash 3.2 (2007)
# Entrypoint: run on a new Mac or to reconfigure an existing one.
# Bootstrap: installs the three prerequisites that run.sh cannot install itself:
#   1. Homebrew      — run.sh manages all packages through it
#   2. Git           — run.sh lives in a git repo (also in state/brew_packages.txt)
#   3. Latest Bash   — run.sh's shebang requires it (also in state/brew_packages.txt)
#
# Keep this minimal (ancient shell here) — all configuration belongs in run.sh.
# Safe to re-run: every step is idempotent.

# Bash strict mode
set -euo pipefail

if [ "$(id -u)" -eq 0 ]; then
	echo "Error: Do not run this script as root" >&2
	exit 1
fi

CURRENT_STEP=""
# shellcheck disable=SC2329 # Function appears unused but is invoked by trap
cleanup_on_interrupt() {
	echo "" >&2
	echo "Bootstrap interrupted during: ${CURRENT_STEP:-unknown}" >&2
	echo "Re-run: curl -s https://raw.githubusercontent.com/nickineering/setup/master/bootstrap.sh | /bin/bash" >&2
	exit 130
}
trap cleanup_on_interrupt INT TERM

# Colors for output
green='\033[32m'
yellow='\033[33m'
cyan='\033[36m'
bold='\033[1m'
dim='\033[2m'
reset='\033[0m'

echo -e "${bold}${cyan}=== AUTOMATICALLY CONFIGURING MAC ===${reset}"
echo -e "${green}Please leave everything closed and wait for your Mac to be configured. This will take a while.${reset}"
echo ""

# ── 1. Homebrew ──────────────────────────────────────────────────────────────
CURRENT_STEP="installing Homebrew"
if command -v brew >/dev/null 2>&1; then
	echo -e "${dim}Homebrew already installed${reset}"
else
	echo "Installing Homebrew..."
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
	echo -e "${green}Homebrew installed${reset}"
fi

# ── 2. git (needed to clone this repo; kept up to date via state/brew_packages.txt) ──
CURRENT_STEP="installing git"
if brew list git &>/dev/null; then
	echo -e "${dim}git already installed${reset}"
else
	brew install git
fi

# ── 3. Clone or update repo ─────────────────────────────────────────────────
CURRENT_STEP="cloning setup repository"
mkdir -p ~/projects
export SETUP=~/projects/setup
if [ -d "$SETUP" ]; then
	git -C "$SETUP" pull || echo -e "${yellow}Warning: git pull failed${reset}"
	echo -e "${dim}Repo up to date${reset}"
else
	if ! git clone https://github.com/nickineering/setup.git "$SETUP"; then
		echo "Error: Failed to clone setup repo" >&2
		exit 1
	fi
	echo -e "${green}Cloned setup repo${reset}"
fi

# ── 4. Modern bash (run.sh shebang requires it; kept up to date via state/brew_packages.txt) ──
CURRENT_STEP="installing modern bash"
if brew list bash &>/dev/null; then
	echo -e "${dim}Modern bash already installed${reset}"
else
	if ! brew install bash; then
		echo "Error: Failed to install bash" >&2
		exit 1
	fi
fi

# ── Hand off to run.sh ───────────────────────────────────────────────────────
echo ""
echo -e "${bold}${cyan}=== Running setup ===${reset}"
echo ""
exec "$SETUP"/run.sh
