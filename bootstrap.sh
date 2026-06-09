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

# Colors — must match lib/colors.sh values
green='\033[92m'
yellow='\033[33m'
bold='\033[1m'
dim='\033[38;5;245m'
reset='\033[0m'
sky='\033[38;5;117m'
coral='\033[38;5;209m'

info() { echo -e "${dim}· $1${reset}"; }
warn() { echo -e "${yellow}⚠ $1${reset}"; }

STEP_CURRENT=0
STEP_TOTAL=4
run_step() {
	((STEP_CURRENT++)) || true
	CURRENT_STEP="$1"
	echo ""
	echo -e "${bold}${sky}▶ [${STEP_CURRENT}/${STEP_TOTAL}] $1${reset}"
}

echo ""
echo -e "${bold}${coral}┌─────────────────────────────────┐${reset}"
echo -e "${bold}${coral}│           Bootstrap             │${reset}"
echo -e "${bold}${coral}└─────────────────────────────────┘${reset}"
echo ""

# ── 1. Homebrew ──────────────────────────────────────────────────────────────
run_step "Installing Homebrew"
if command -v brew >/dev/null 2>&1; then
	info "Already installed"
else
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
	echo -e "${green}✓ Installed${reset}"
fi

# ── 2. git (kept up to date via state/brew_packages.txt) ─────────────────────
run_step "Installing git"
if brew list git &>/dev/null; then
	info "Already installed"
else
	brew install git
fi

# ── 3. Clone or update repo ─────────────────────────────────────────────────
run_step "Cloning setup repository"
mkdir -p ~/projects
export SETUP=~/projects/setup
if [ -d "$SETUP" ]; then
	pull_output=$(git -C "$SETUP" pull 2>&1) || warn "git pull failed"
	if [[ "$pull_output" != "Already up to date." ]]; then
		echo "$pull_output"
	fi
	info "Repo up to date"
else
	if ! git clone https://github.com/nickineering/setup.git "$SETUP"; then
		echo "Error: Failed to clone setup repo" >&2
		exit 1
	fi
	echo -e "${green}✓ Cloned${reset}"
fi

# ── 4. Modern bash (run.sh shebang requires it; kept up to date via state/brew_packages.txt) ──
run_step "Installing modern bash"
if brew list bash &>/dev/null; then
	info "Already installed"
else
	if ! brew install bash; then
		echo "Error: Failed to install bash" >&2
		exit 1
	fi
fi

# ── Hand off to run.sh ───────────────────────────────────────────────────────
echo ""
exec "$SETUP"/run.sh
