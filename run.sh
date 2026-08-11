#!/opt/homebrew/bin/bash
# shellcheck disable=SC2154 # Variables like $bold defined in lib/colors.sh

# Unified setup script: initial setup and daily maintenance.
# Safe to run anytime - all operations are idempotent or diff-based.
#
# Usage:
#   run.sh [--clean] [--skip N...] [--only N...]
#
# Step numbers match the [N/N] labels printed during a run and the step file
# prefixes in steps/. The step list itself lives in lib/steps.sh (STEP_NAMES).
#
# Configuration (set in ~/.env.sh):
#   GITLAB_GROUP        - GitLab group/namespace to sync (optional)
#   GITLAB_EXCLUDE_DIRS - Pipe-separated dirs to exclude (optional)
#   DOCK_IGNORE_APPS    - Pipe-separated apps to skip in Dock management (optional)

set -euo pipefail

# Sourced before flag parsing so parse errors can use error()/colors, and so
# usage() can print the step table. STEP_TOTAL/STEP_NAMES come from steps.sh.
LIB="$(dirname "${BASH_SOURCE[0]}")/lib"
# shellcheck source=lib/colors.sh
source "$LIB/colors.sh"
# shellcheck source=lib/steps.sh
source "$LIB/steps.sh"

usage() {
	cat <<EOF
Usage: run.sh [--clean] [--skip N...] [--only N...]

  --clean        Also clear tool caches
  --skip N...    Skip these steps
  --only N...    Run only these steps
  -h, --help     Show this help

Step numbers may be separated by commas, spaces or both:
  --skip 1,2    --skip 1, 2    --skip 1 2    --skip=1,2

Steps are numbered as printed during a run (and as prefixed in steps/):

$(step_table)

Examples:
  run.sh --skip $STEP_TOTAL      # everything except macOS software updates
  run.sh --only 8,9     # just symlinks and tool config
  run.sh --skip 1 2 3   # skip the repo update and Homebrew steps
EOF
}

# Parse flags
export CLEAN_CACHES=false
SKIP_STEPS=""
ONLY_STEPS=""

# Greedily consumes every following non-flag argument so all of "--skip 1,2",
# "--skip 1, 2" and "--skip 1 2" work. Sets STEP_ARGS to the joined value and
# STEP_ARGC to how many arguments were eaten.
collect_step_args() {
	STEP_ARGS=""
	STEP_ARGC=0
	while [[ $# -gt 0 && "$1" != -* ]]; do
		STEP_ARGS+="$1 "
		((STEP_ARGC++)) || true
		shift
	done
}

while [[ $# -gt 0 ]]; do
	case "$1" in
	--clean) export CLEAN_CACHES=true ;;
	--skip | --only | --skip=* | --only=*)
		flag="${1%%=*}"
		[[ "$flag" == --skip ]] && target=SKIP_STEPS || target=ONLY_STEPS
		if [[ "$1" == *=* ]]; then
			STEP_ARGS="${1#*=}"
			STEP_ARGC=0
		else
			collect_step_args "${@:2}"
		fi
		[[ -n "${STEP_ARGS// /}" ]] || {
			step_error "" "$flag needs at least one step number"
			exit 1
		}
		parse_step_list "$STEP_ARGS" "$target" || exit 1
		shift "$STEP_ARGC"
		;;
	-h | --help)
		usage
		exit 0
		;;
	*)
		error "unknown option: ${bold}$1${reset}"
		usage >&2
		exit 1
		;;
	esac
	shift
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
source lib/backup.sh
source lib/links.sh
source lib/packages.sh

# Trap handler for cleanup on interruption
CURRENT_STEP=""
cleanup_on_exit() {
	stop_sudo_keepalive 2>/dev/null || true
	rm -f "${SUDO_PASS_FILE:-}" "${ASKPASS_SCRIPT:-}"
}
cleanup_on_interrupt() {
	cleanup_on_exit
	echo "" >&2
	echo -e "${yellow}⚠ Setup interrupted!${reset}" >&2
	if [[ -n "$CURRENT_STEP" ]]; then
		echo -e "Stopped during step ${bold}${STEP_CURRENT}${reset}: ${bold}$CURRENT_STEP${reset}" >&2
	fi
	echo -e "To resume, run: ${coral}$SETUP/run.sh${reset}" >&2
	exit 130
}
trap cleanup_on_exit EXIT
trap cleanup_on_interrupt INT TERM

# Step runner with counter and section grouping
STEP_CURRENT=0

run_step() {
	local title="$1" file="$2"
	((STEP_CURRENT++)) || true
	if step_disabled "$STEP_CURRENT"; then
		echo -e "${dim}⤼ [${STEP_CURRENT}/${STEP_TOTAL}] ${title} (skipped)${reset}"
		return 0
	fi
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

# Step 1 diffs the state files and steps 2/4/7/8/9/12 require its removed_*
# vars. Skipping it means there is no diff, so declare them empty (the steps
# treat empty as "nothing removed") rather than let `${removed_taps?}` abort.
# shellcheck disable=SC2034 # consumed by sourced step files
if step_disabled 1; then
	removed_packages="" removed_casks="" removed_extensions=""
	removed_npm="" removed_links="" removed_taps=""
fi

# ── Start ────────────────────────────────────────────────────────────────────
echo ""
echo -e "${bold}${coral}┌─────────────────────────────────┐${reset}"
echo -e "${bold}${coral}│     Mac Configuration Script    │${reset}"
echo -e "${bold}${coral}└─────────────────────────────────┘${reset}"

section "Install"

run_step "Updating setup repo" steps/01_update_repo.sh
run_step "Configuring Homebrew taps" steps/02_homebrew_taps.sh
run_step "Upgrading Homebrew formulae" steps/03_homebrew_upgrade.sh
run_step "Installing Homebrew formulae" steps/04_homebrew_install.sh
run_step "Cleaning caches" steps/05_cache_cleanup.sh
run_step "Updating development tools" steps/06_tool_updates.sh
run_step "Installing VSCode extensions" steps/07_vscode_extensions.sh

section "Configure"

run_step "Creating symlinks" steps/08_symlinks.sh
run_step "Configuring tools" steps/09_configure_tools.sh
run_step "Configuring macOS" steps/10_macos.sh

section "Sync"

run_step "Syncing GitLab repos" steps/11_gitlab_sync.sh

section "Sudo"

run_step "Privileged operations" steps/12_privileged.sh
run_step "macOS software updates" steps/13_software_update.sh

# ── Done ────────────────────────────────────────────────────────────────────
echo ""
echo -e "${bold}${coral}┌─────────────────────────────────┐${reset}"
echo -e "${bold}${coral}│         Setup complete!         │${reset}"
echo -e "${bold}${coral}└─────────────────────────────────┘${reset}"
echo ""
info "See ${coral}$SETUP/MANUAL_STEPS.md${reset}${dim} for remaining manual configuration."
if [[ "${FIREFOX_NEEDS_SETUP:-}" == "1" ]]; then
	warn "Firefox settings were skipped. Launch Firefox, sign in, then run:"
	info "  ${coral}$SETUP/configure/after_signin.sh${reset}"
fi
