# shellcheck shell=bash
# shellcheck disable=SC2034,SC2154
#
# Registers third-party taps from state file, removes taps deleted from state.
# Must run before install/upgrade so packages from these taps are resolvable.

: "${SETUP:?}" "${removed_taps?}"

desired_taps=$(parse_state_file "$SETUP/state/brew_taps.txt")
installed_taps=$(brew tap 2>/dev/null)
missing_taps=$(set_difference "$installed_taps" "$desired_taps")

taps_added=0
if [[ -n "$missing_taps" ]]; then
	while IFS= read -r tap <&3; do
		[[ -z "$tap" ]] && continue
		action "Adding tap: ${tap}"
		brew tap "$tap" >/dev/null 2>&1 || warn "Failed to tap ${tap}"
		((taps_added++)) || true
	done 3<<<"$missing_taps"
fi

# Trust all desired taps (allows installing from them without prompts)
while IFS= read -r tap <&3; do
	[[ -z "$tap" ]] && continue
	brew trust "$tap" &>/dev/null || true
done 3<<<"$desired_taps"

# Remove taps deleted from state file
if [[ -n "$removed_taps" ]]; then
	while IFS= read -r tap <&3; do
		[[ -z "$tap" ]] && continue
		action "Removing tap: ${tap}"
		brew untap "$tap" 2>/dev/null || warn "Failed to untap ${tap}"
	done 3<<<"$removed_taps"
fi

if [[ $taps_added -eq 0 && -z "$removed_taps" ]]; then
	info "All taps already configured"
fi
echo ""
