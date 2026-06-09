# shellcheck shell=bash
# shellcheck disable=SC2034,SC2154
#
# ── Homebrew Upgrade ─────────────────────────────────────────────────────────
# Upgrades all outdated packages and casks. Runs before the install step so
# that newly-added packages don't get installed at an old version and then
# immediately upgraded.
# ─────────────────────────────────────────────────────────────────────────────
outdated=$(brew outdated --greedy 2>/dev/null || true)
if [[ -n "$outdated" ]]; then
	echo -e "${dim}Upgrading: $(echo "$outdated" | tr '\n' ' ')${reset}"
	brew upgrade --greedy || echo -e "${yellow}Warning: Some packages failed to upgrade${reset}"
else
	echo -e "${dim}All packages up to date${reset}"
fi
echo ""
