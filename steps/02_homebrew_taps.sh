# shellcheck shell=bash
# shellcheck disable=SC2034,SC2154
#
# ── Homebrew Taps ────────────────────────────────────────────────────────────
# Registers and trusts third-party taps. Must run before install/upgrade so
# that packages from these taps are resolvable.
# ─────────────────────────────────────────────────────────────────────────────
taps_added=0
for tap in beeftornado/rmtree hashicorp/tap; do
	if ! brew tap | grep -q "^${tap}$"; then
		echo "Adding tap: ${tap}"
		brew tap "$tap" >/dev/null 2>&1 || echo -e "${yellow}Warning: Failed to tap ${tap}${reset}"
		((taps_added++)) || true
	fi
	brew trust "$tap" &>/dev/null || true
done
if [[ $taps_added -eq 0 ]]; then
	echo -e "${dim}All taps already configured${reset}"
fi
echo ""
