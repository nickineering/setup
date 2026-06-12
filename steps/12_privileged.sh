# shellcheck shell=bash
# shellcheck disable=SC2034,SC2154
#
# Everything requiring sudo, grouped at the end so the user only enters their
# password once. Lists what needs doing and asks before proceeding.
: "${SETUP:?}" "${removed_casks?}"

CURRENT_STEP=""

# ── Detect what needs doing ─────────────────────────────────────────────────

outdated_casks=$(brew outdated --cask --greedy 2>/dev/null || true)
desired_casks=$(parse_state_file "$SETUP/state/brew_casks.txt")
installed_casks=$(get_installed_casks)
missing_casks=$(set_difference "$installed_casks" "$desired_casks")

sudo_tasks=()

if [[ -n "$outdated_casks" ]]; then
	sudo_tasks+=("Upgrade casks: $(echo "$outdated_casks" | tr '\n' ' ')")
fi
if [[ -n "$missing_casks" ]]; then
	sudo_tasks+=("Install casks: $(echo "$missing_casks" | tr '\n' ' ')")
fi
if [[ -n "$removed_casks" ]]; then
	sudo_tasks+=("Uninstall casks removed from state")
fi

ZOOM_DAEMON="/Library/LaunchDaemons/us.zoom.ZoomDaemon.plist"
needs_zoom=false
if [[ -f "$ZOOM_DAEMON" ]] && ! launchctl print system/us.zoom.ZoomDaemon &>/dev/null; then
	sudo_tasks+=("Enable Zoom auto-update daemon")
	needs_zoom=true
fi

needs_womp=false
if ! pmset -g | grep -q 'womp.*1'; then
	sudo_tasks+=("Enable wake for network access")
	needs_womp=true
fi

needs_lockscreen=false
current_lockscreen=$(defaults read /Library/Preferences/com.apple.loginwindow LoginwindowText 2>/dev/null || echo "")
if [[ -z "$current_lockscreen" ]]; then
	sudo_tasks+=("Set lock screen message (contact info if laptop is found)")
	needs_lockscreen=true
fi

# ── Prompt once (only if there's something to do) ───────────────────────────

if [[ ${#sudo_tasks[@]} -gt 0 ]]; then
	echo "The following operations require sudo:"
	for task in "${sudo_tasks[@]}"; do
		echo "  · $task"
	done
	echo ""
	echo -n "Continue? [y/N]: "
	read -r -n 1 run_sudo </dev/tty
	echo ""

	if [[ "$run_sudo" =~ ^[Yy]$ ]]; then
		sudo -v
		start_sudo_keepalive
	else
		info "Skipped privileged operations"
		needs_zoom=false needs_womp=false needs_lockscreen=false
		outdated_casks="" missing_casks="" removed_casks=""
	fi
else
	info "Nothing to do"
fi

# ── Cask operations (brew handles its own sudo prompt) ──────────────────────

if [[ -n "$outdated_casks" ]]; then
	info "Upgrading casks: $(echo "$outdated_casks" | tr '\n' ' ')"
	brew upgrade --cask --greedy --no-quit -y || warn "Some casks failed to upgrade"
fi

if [[ -n "$missing_casks" ]]; then
	install_missing cask "$missing_casks"
fi

[[ -n "$removed_casks" ]] && prompt_uninstall cask "$removed_casks"

# macOS quarantines chromedriver since it's not from the App Store
CHROMEDRIVER_PATH="$(brew --prefix)/bin/chromedriver"
if [[ -f "$CHROMEDRIVER_PATH" ]]; then
	xattr -d com.apple.quarantine "$CHROMEDRIVER_PATH" 2>/dev/null || true
fi

# ── System operations ───────────────────────────────────────────────────────

if [[ "$needs_zoom" == "true" ]]; then
	sudo launchctl load -w "$ZOOM_DAEMON" 2>/dev/null || warn "Failed to load Zoom daemon"
fi
if [[ "$needs_womp" == "true" ]]; then
	sudo pmset -a womp 1 || warn "Failed to set wake on LAN"
fi
if [[ "$needs_lockscreen" == "true" ]]; then
	echo -n "Enter lock screen message (e.g. your email for if laptop is found): "
	read -r lockscreen_msg </dev/tty
	if [[ -n "$lockscreen_msg" ]]; then
		sudo defaults write /Library/Preferences/com.apple.loginwindow LoginwindowText "$lockscreen_msg"
		info "Lock screen message set"
	else
		info "Skipped lock screen message"
	fi
fi
