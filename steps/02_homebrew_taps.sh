# shellcheck shell=bash
# shellcheck disable=SC2034,SC2154
#
# ── Homebrew Taps ────────────────────────────────────────────────────────────
# Registers third-party taps from state file, removes taps deleted from state.
# Must run before install/upgrade so packages from these taps are resolvable.
# Requires: lib/packages.sh (parse_state_file, set_difference)
# Requires: steps/01 (removed_taps)
# ─────────────────────────────────────────────────────────────────────────────
: "${SETUP:?}" "${removed_taps?}"

desired_taps=$(parse_state_file "$SETUP/state/brew_taps.txt")
installed_taps=$(brew tap 2>/dev/null)
missing_taps=$(set_difference "$installed_taps" "$desired_taps")

taps_added=0
if [[ -n "$missing_taps" ]]; then
	while IFS= read -r tap; do
		[[ -z "$tap" ]] && continue
		echo "Adding tap: ${tap}"
		brew tap "$tap" >/dev/null 2>&1 || echo -e "${yellow}Warning: Failed to tap ${tap}${reset}"
		((taps_added++)) || true
	done <<<"$missing_taps"
fi

# Trust all desired taps
while IFS= read -r tap; do
	[[ -z "$tap" ]] && continue
	brew trust "$tap" &>/dev/null || true
done <<<"$desired_taps"

# Remove taps deleted from state file
if [[ -n "$removed_taps" ]]; then
	while IFS= read -r tap; do
		[[ -z "$tap" ]] && continue
		echo "Removing tap: ${tap}"
		brew untap "$tap" 2>/dev/null || echo -e "${yellow}Warning: Failed to untap ${tap}${reset}"
	done <<<"$removed_taps"
fi

if [[ $taps_added -eq 0 && -z "$removed_taps" ]]; then
	echo -e "${dim}All taps already configured${reset}"
fi
echo ""
