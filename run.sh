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
source lib/packages.sh

# Trap handler for cleanup on interruption
CURRENT_STEP=""
cleanup_on_interrupt() {
	echo "" >&2
	echo -e "${yellow}Setup interrupted!${reset}" >&2
	if [[ -n "$CURRENT_STEP" ]]; then
		echo -e "Stopped during: ${bold}$CURRENT_STEP${reset}" >&2
	fi
	echo -e "To resume, run: ${cyan}$SETUP/run.sh${reset}" >&2
	exit 130
}
trap cleanup_on_interrupt INT TERM

run_step() {
	local title="$1" file="$2"
	CURRENT_STEP="${title,,}"
	echo -e "${bold}${cyan}=== ${title} ===${reset}"
	# shellcheck source=/dev/null
	source "$file"
}

echo -e "${bold}${cyan}=== Starting setup ===${reset}"
echo ""

# Pull latest and diff state files to detect upstream additions/removals
run_step "Updating setup repo" steps/01_update_repo.sh

# Taps must be registered before any install/upgrade can reference them
run_step "Configuring Homebrew taps" steps/02_homebrew_taps.sh

# Upgrade existing packages first so new installs don't immediately go stale
run_step "Upgrading Homebrew packages" steps/03_homebrew_upgrade.sh

# Reconcile desired state against what's actually installed
run_step "Installing Homebrew packages" steps/04_homebrew_install.sh

# Optional deep clean — only when --clean flag is passed
source steps/05_cache_cleanup.sh

# Wire dotfiles/configs into their expected locations
run_step "Creating symlinks" steps/06_symlinks.sh

# Idempotent per-tool config (completions, default versions, global settings)
run_step "Configuring tools" steps/07_configure_tools.sh

# System preferences and Dock — after cask installs so apps exist
run_step "Configuring macOS" steps/08_macos.sh

# Extensions depend on `code` CLI existing (from cask install above)
run_step "Installing VSCode extensions" steps/09_vscode_extensions.sh

# Network-heavy updates run in parallel for speed
run_step "Updating development tools" steps/10_tool_updates.sh

# Clone/pull repos — needs glab authenticated
run_step "Syncing GitLab repos" steps/11_gitlab_sync.sh

# Sudo grouped last so user only enters password once — CURRENT_STEP cleared
# inside 12_privileged.sh so interrupts during sudo don't look like errors
run_step "Privileged operations" steps/12_privileged.sh
