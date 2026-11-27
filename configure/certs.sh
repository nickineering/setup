# shellcheck shell=bash
# shellcheck disable=SC2154 # Variables like $dim defined in lib/colors.sh

if [[ -z "${CA_BUNDLE_STALE:-}" ]]; then
	info "Node CA roots exported to ${KEYCHAIN_CA_BUNDLE/#$HOME/~}"
elif [[ -f "$KEYCHAIN_CA_BUNDLE" ]]; then
	warn "Could not re-read the macOS keychain CA roots — still using ${KEYCHAIN_CA_BUNDLE/#$HOME/~}"
else
	warn "Could not export the macOS keychain CA roots to $KEYCHAIN_CA_BUNDLE"
fi
