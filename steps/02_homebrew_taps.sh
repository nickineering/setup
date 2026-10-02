# shellcheck shell=bash
# shellcheck disable=SC2034,SC2154
#
# Registers third-party taps from state file, removes taps deleted from state.
# Must run before install/upgrade so packages from these taps are resolvable.
# Trust is granted first, scoped per brew_trusted_formulae.txt where a tap needs
# it, since Homebrew decides what to parse at tap time from what it trusts.

: "${SETUP:?}" "${removed_taps?}"

desired_taps=$(parse_state_file "$SETUP/state/brew_taps.txt")
trusted_formulae=$(parse_state_file "$SETUP/state/brew_trusted_formulae.txt" || true)
installed_taps=$(brew tap 2>/dev/null)
missing_taps=$(set_difference "$installed_taps" "$desired_taps")

# Formula-level trust entries belonging to one tap, as owner/repo/formula lines.
# Matched by prefix rather than grep so a tap name is never read as a pattern.
narrow_trust_for() {
	local tap="$1" entry
	while IFS= read -r entry; do
		[[ -z "$entry" ]] && continue
		# `if` not `&&`: a non-matching last line would fail the loop under set -e
		if [[ "$entry" == "${tap}/"* ]]; then echo "$entry"; fi
	done <<<"$trusted_formulae"
}

# Reports a `brew trust`/`untrust` failure rather than hiding it. These exit 0
# for names that don't exist, so this won't catch a typo — it catches Homebrew
# too old to have the command, which would otherwise surface as an unexplained
# tap failure further down.
run_trust() {
	local output
	output=$(brew "$@" 2>&1) || {
		warn "Failed: brew ${*}"
		echo "    ${output//$'\n'/$'\n'    }"
	}
}

# Grants a tap the narrowest trust its state entry allows.
grant_trust() {
	local tap="$1" narrow formula
	narrow=$(narrow_trust_for "$tap")
	if [[ -z "$narrow" ]]; then
		run_trust trust --tap "$tap"
		return 0
	fi
	# Drop any wholesale trust a previous run left behind
	brew untrust --tap "$tap" &>/dev/null || true
	while IFS= read -r formula; do
		run_trust trust --formula "$formula"
	done <<<"$narrow"
}

# Revokes every entry a tap holds, so trust never outlives the tap it was
# granted for. Formula entries are read back from the trust store rather than
# the state file: a tap being dropped leaves both state files at once, and a tap
# that failed to land may hold trust the state file no longer explains.
revoke_trust() {
	local tap="$1" entry
	brew untrust --tap "$tap" &>/dev/null || true
	while IFS= read -r entry; do
		[[ -z "$entry" ]] && continue
		brew untrust --formula "$entry" &>/dev/null || true
	done <<<"$(trusted_formulae_in_store "$tap")"
}

trusted_formulae_in_store() {
	brew trust --json v1 2>/dev/null |
		jq -r --arg prefix "${1}/" '.formulae // [] | .[] | select(startswith($prefix))' 2>/dev/null || true
}

# Trust before tapping: `brew tap` parses every *trusted* file in a tap and
# refuses the whole tap if any one of them fails to load, so a tap carrying an
# unrelated broken cask cannot be tapped while trusted wholesale. Narrowing
# trust to the formulae we actually use leaves those files untrusted and unread,
# and keeps validation on for everything we do install.
while IFS= read -r tap <&3; do
	[[ -z "$tap" ]] && continue
	grant_trust "$tap"
done 3<<<"$desired_taps"

taps_added=0
if [[ -n "$missing_taps" ]]; then
	while IFS= read -r tap <&3; do
		[[ -z "$tap" ]] && continue
		action "Adding tap: ${tap}"
		tap_output=$(brew tap "$tap" 2>&1 </dev/null) || {
			warn "Failed to tap ${tap}"
			echo "    ${tap_output//$'\n'/$'\n'    }"
			# Trust was granted ahead of the tap that never landed; take it back
			# so a name that becomes real later isn't already pre-trusted.
			revoke_trust "$tap"
		}
		((taps_added++)) || true
	done 3<<<"$missing_taps"
fi

# Remove taps deleted from state file
if [[ -n "$removed_taps" ]]; then
	while IFS= read -r tap <&3; do
		[[ -z "$tap" ]] && continue
		action "Removing tap: ${tap}"
		brew untap "$tap" 2>/dev/null || warn "Failed to untap ${tap}"
		revoke_trust "$tap"
	done 3<<<"$removed_taps"
fi

if [[ $taps_added -eq 0 && -z "$removed_taps" ]]; then
	info "All taps already configured"
fi
echo ""
