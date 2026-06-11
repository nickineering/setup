#!/opt/homebrew/bin/bash
# shellcheck disable=SC2154 # Variables like $green are defined in lib/colors.sh
#
# Post-setup configuration for things that need apps to be launched first:
# - Firefox: needs profile folder to exist (created on first launch)
# - GitHub CLI: authentication and GPG signing
# - GitLab CLI: authentication and GPG signing (~/work/.gitconfig)

set -euo pipefail

if [[ $EUID -eq 0 ]]; then
	echo "Error: Do not run this script as root" >&2
	exit 1
fi

export SETUP="${HOME:?}/projects/setup"
export DOTFILES="$SETUP/linked"

[[ -d "$SETUP" ]] || {
	echo "Error: SETUP directory not found: $SETUP" >&2
	exit 1
}

cd "$SETUP"

source lib/colors.sh
source lib/backup.sh

CURRENT_STEP=""
cleanup_on_interrupt() {
	echo "" >&2
	echo -e "${yellow}⚠ Post-setup interrupted!${reset}" >&2
	if [[ -n "$CURRENT_STEP" ]]; then
		echo -e "Stopped during: ${bold}$CURRENT_STEP${reset}" >&2
	fi
	echo -e "To resume, run: ${coral}$SETUP/configure/after_signin.sh${reset}" >&2
	exit 130
}
trap cleanup_on_interrupt INT TERM

STEP_CURRENT=0
STEP_TOTAL=5
run_step() {
	((STEP_CURRENT++)) || true
	CURRENT_STEP="$1"
	echo -e "${bold}${sky}▶ [${STEP_CURRENT}/${STEP_TOTAL}] $1${reset}"
}

echo ""
echo -e "${bold}${coral}┌─────────────────────────────────┐${reset}"
echo -e "${bold}${coral}│     Post-Setup Configuration    │${reset}"
echo -e "${bold}${coral}└─────────────────────────────────┘${reset}"
echo ""

# ── 1. Firefox ───────────────────────────────────────────────────────────────
run_step "Configuring Firefox"
source configure/firefox.sh
if [[ "${FIREFOX_NEEDS_SETUP:-}" != "1" ]]; then
	success "Configured Firefox"
else
	warn "Firefox not launched yet — launch it and re-run"
fi

# ── 2. GitHub CLI ────────────────────────────────────────────────────────────
run_step "Authenticating GitHub CLI"
if ! gh auth status &>/dev/null; then
	gh auth login
	success "Configured GitHub CLI"
else
	info "GitHub CLI already authenticated"
fi

# ── 3. GitLab CLI ────────────────────────────────────────────────────────────
run_step "Authenticating GitLab CLI"
if ! glab auth status &>/dev/null 2>&1; then
	glab auth login
	success "Configured GitLab CLI"
else
	info "GitLab CLI already authenticated"
fi

# ── 4. GitHub signing ────────────────────────────────────────────────────────
run_step "Configuring GPG signing (GitHub)"
source configure/gh_signing.sh

# ── 5. GitLab signing ────────────────────────────────────────────────────────
run_step "Configuring GPG signing (GitLab)"
source configure/glab_signing.sh

echo ""
success "Done!"
