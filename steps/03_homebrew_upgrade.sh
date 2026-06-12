# shellcheck shell=bash
# shellcheck disable=SC2034,SC2154
#
# Updates the formulae index and upgrades outdated formulae (no sudo needed).
# Cask upgrades are deferred to the privileged section (step 12).
brew update --quiet >/dev/null 2>&1 </dev/null || warn "brew update failed"
outdated=$(brew outdated --formula 2>/dev/null || true)
if [[ -n "$outdated" ]]; then
	info "Upgrading: $(echo "$outdated" | tr '\n' ' ')"
	brew upgrade --formula -y || warn "Some packages failed to upgrade"
else
	info "All formulae up to date"
fi
echo ""
