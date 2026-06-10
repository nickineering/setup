# shellcheck shell=bash
# shellcheck disable=SC2034,SC2154
#
# Upgrades all outdated packages and casks. Runs before install so newly-added
# packages aren't installed at stale versions and then immediately upgraded.
outdated=$(brew outdated --greedy 2>/dev/null || true)
if [[ -n "$outdated" ]]; then
	info "Upgrading: $(echo "$outdated" | tr '\n' ' ')"
	brew upgrade --greedy || warn "Some packages failed to upgrade"
else
	info "All packages up to date"
fi
echo ""
