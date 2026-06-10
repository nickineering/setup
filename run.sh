#!/opt/homebrew/bin/bash
# shellcheck disable=SC2154 # Variables like $bold defined in lib/colors.sh

# Unified setup script: initial setup and daily maintenance.
# Safe to run anytime - all operations are idempotent or diff-based.
#
# Configuration (set in ~/.env.sh):
#   GITLAB_GROUP        - GitLab group/namespace to sync (optional)
#   GITLAB_EXCLUDE_DIRS - Pipe-separated dirs to exclude (optional)

set -euo pipefail

# Parse flags
CLEAN_CACHES=false
for arg in "$@"; do
	case "$arg" in
	--clean) CLEAN_CACHES=true ;;
	esac
done

# Guard: refuse to run as root
if [[ $EUID -eq 0 ]]; then
	echo "Error: Do not run this script as root" >&2
	exit 1
fi

export SETUP="${HOME:?}/projects/setup"
export DOTFILES="$SETUP/linked"

# Validate critical paths exist before proceeding
[[ -d "$SETUP" ]] || {
	echo "Error: SETUP directory not found: $SETUP" >&2
	exit 1
}
[[ -d "$DOTFILES" ]] || {
	echo "Error: DOTFILES directory not found: $DOTFILES" >&2
	exit 1
}

cd "$SETUP"

# Utilities
source lib/colors.sh
source lib/backup.sh
source lib/links.sh
source lib/packages.sh

# Trap handler for cleanup on interruption
CURRENT_STEP=""
cleanup_on_exit() {
	stop_sudo_keepalive 2>/dev/null || true
}
cleanup_on_interrupt() {
	cleanup_on_exit
	echo "" >&2
	echo -e "${yellow}⚠ Setup interrupted!${reset}" >&2
	if [[ -n "$CURRENT_STEP" ]]; then
		echo -e "Stopped during: ${bold}$CURRENT_STEP${reset}" >&2
	fi
	echo -e "To resume, run: ${coral}$SETUP/run.sh${reset}" >&2
	exit 130
}
trap cleanup_on_exit EXIT
trap cleanup_on_interrupt INT TERM

# Step runner with counter and section grouping
STEP_CURRENT=0
STEP_TOTAL=12
run_step() {
	local title="$1" file="$2"
	((STEP_CURRENT++)) || true
	CURRENT_STEP="${title,,}"
	echo -e "${bold}${sky}▶ [${STEP_CURRENT}/${STEP_TOTAL}] ${title}${reset}"
	# shellcheck source=/dev/null
	source "$file"
}

section() {
	echo ""
	echo -e "${bold}${magenta}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${reset}"
	echo -e "${bold}${magenta}  $1${reset}"
	echo -e "${bold}${magenta}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${reset}"
	echo ""
}

# ── Start ────────────────────────────────────────────────────────────────────
echo ""
echo -e "${bold}${coral}┌─────────────────────────────────┐${reset}"
echo -e "${bold}${coral}│     Mac Configuration Script    │${reset}"
echo -e "${bold}${coral}└─────────────────────────────────┘${reset}"

section "Install"

run_step "Updating setup repo" steps/01_update_repo.sh
run_step "Configuring Homebrew taps" steps/02_homebrew_taps.sh
run_step "Upgrading Homebrew packages" steps/03_homebrew_upgrade.sh
run_step "Installing Homebrew packages" steps/04_homebrew_install.sh
run_step "Updating development tools" steps/10_tool_updates.sh
run_step "Installing VSCode extensions" steps/09_vscode_extensions.sh
source steps/05_cache_cleanup.sh

section "Configure"

run_step "Creating symlinks" steps/06_symlinks.sh
run_step "Configuring tools" steps/07_configure_tools.sh
run_step "Configuring macOS" steps/08_macos.sh

section "Sync"

run_step "Syncing GitLab repos" steps/11_gitlab_sync.sh

section "System"

run_step "Privileged operations" steps/12_privileged.sh
