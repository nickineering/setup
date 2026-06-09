# shellcheck shell=bash
# shellcheck disable=SC2034,SC2154
#
# ── Privileged Operations ────────────────────────────────────────────────────
# Everything requiring sudo, grouped at the end so the user only enters their
# password once. Lists what needs doing and asks before proceeding. Covers:
# Zoom auto-update daemon, wake-on-LAN, lock screen message, macOS updates.
# ─────────────────────────────────────────────────────────────────────────────
: "${SETUP:?}"

CURRENT_STEP=""

# Detect which privileged operations are needed (checked before prompting)
sudo_tasks=()

ZOOM_DAEMON="/Library/LaunchDaemons/us.zoom.ZoomDaemon.plist"
needs_zoom=false
if [[ -f "$ZOOM_DAEMON" ]] && ! launchctl list 2>/dev/null | grep -q 'us.zoom.ZoomDaemon'; then
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

sudo_tasks+=("Install macOS system updates (optional)")

echo "The following operations require sudo:"
for task in "${sudo_tasks[@]}"; do
	echo "  - $task"
done
echo ""
echo -n "Continue with privileged operations? [y/N]: "
read -r -n 1 run_sudo </dev/tty
echo ""

if [[ "$run_sudo" =~ ^[Yy]$ ]]; then
	# Execute privileged operations
	if [[ "$needs_zoom" == "true" ]]; then
		sudo launchctl load -w "$ZOOM_DAEMON" 2>/dev/null || echo -e "${yellow}Warning: Failed to load Zoom daemon${reset}"
	fi
	if [[ "$needs_womp" == "true" ]]; then
		sudo pmset -a womp 1 || echo -e "${yellow}Warning: Failed to set wake on LAN${reset}"
	fi
	if [[ "$needs_lockscreen" == "true" ]]; then
		echo -n "Enter lock screen message (e.g. your email for if laptop is found): "
		read -r lockscreen_msg </dev/tty
		if [[ -n "$lockscreen_msg" ]]; then
			sudo defaults write /Library/Preferences/com.apple.loginwindow LoginwindowText "$lockscreen_msg"
			echo -e "${dim}Lock screen message set${reset}"
		else
			echo -e "${dim}Skipped lock screen message${reset}"
		fi
	fi

	# macOS updates (sub-prompt since it can take a while)
	echo -n "Install macOS system updates now? [y/N]: "
	read -r -n 1 install_updates </dev/tty
	echo ""
	if [[ "$install_updates" =~ ^[Yy]$ ]]; then
		echo -e "${dim}Installing updates...${reset}"
		sudo softwareupdate -i -a || echo -e "${yellow}Warning: Some updates failed${reset}"
	else
		echo -e "${dim}Skipped macOS updates${reset}"
	fi
else
	echo -e "${dim}Skipped privileged operations${reset}"
fi
echo ""
echo -e "${bold}${green}=== Setup complete! ===${reset}"

# Remind about post-setup steps
echo ""
echo -e "${bold}Next steps:${reset} See ${cyan}$SETUP/MANUAL_STEPS.md${reset} for remaining manual configuration."
if [[ "${FIREFOX_NEEDS_SETUP:-}" == "1" ]]; then
	echo -e "${yellow}Note:${reset} Firefox settings were skipped. Launch Firefox and sign in, then run:"
	echo -e "  ${cyan}$SETUP/configure/after_signin.sh${reset}"
fi
