# shellcheck shell=bash
# shellcheck disable=SC2034,SC2154
#
# Updates the formulae index and upgrades all outdated packages and casks.
# Runs before install so newly-added packages aren't installed at stale versions.
brew update --quiet >/dev/null 2>&1 </dev/null || warn "brew update failed"
outdated=$(brew outdated --greedy 2>/dev/null || true)
if [[ -n "$outdated" ]]; then
	info "Upgrading: $(echo "$outdated" | tr '\n' ' ')"
	brew upgrade --greedy --no-quit -y || warn "Some packages failed to upgrade"
else
	info "All packages up to date"
fi
echo ""
