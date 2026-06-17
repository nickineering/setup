# shellcheck shell=bash
# shellcheck disable=SC2034,SC2154
#
# Checks for macOS system updates and offers to install them.
# Separated from other privileged ops since updates are large and slow.

action "Checking for macOS system updates..."
available_updates=$(softwareupdate -l 2>&1 || true)

if echo "$available_updates" | grep -q "^\*"; then
	echo "$available_updates" | grep "^\*"
	echo ""
	prompt "Install these updates? [y/N]:"
	read -r -n 1 install_updates </dev/tty
	echo ""
	if [[ "$install_updates" =~ ^[Yy]$ ]]; then
		# Reuse keepalive from step 12 if active, otherwise acquire sudo
		if [[ -z "${SUDO_KEEPALIVE_PID:-}" ]]; then
			sudo -v
			start_sudo_keepalive
		fi
		sudo softwareupdate -i -a || warn "Some updates failed"
	else
		info "Skipped macOS updates"
	fi
else
	info "macOS is up to date"
fi

stop_sudo_keepalive
