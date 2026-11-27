# shellcheck shell=bash
# shellcheck disable=SC2034 # KEYCHAIN_CA_BUNDLE is used by sourcing scripts

KEYCHAIN_CA_BUNDLE="${XDG_CONFIG_HOME:-$HOME/.config}/certs/keychain-ca.pem"

# -purpose, not -ext basicConstraints: macOS ships LibreSSL as /usr/bin/openssl,
# which has no -ext and so rejects every certificate — an empty bundle, silently,
# on any machine without Homebrew's openssl ahead of it on PATH.
_is_tls_server_ca() {
	openssl x509 -noout -purpose 2>/dev/null |
		grep -q '^SSL server CA : Yes$'
}

_keychain_ca_certs() {
	local pem="" line
	while IFS= read -r line; do
		pem+="$line"$'\n'
		[[ "$line" == "-----END CERTIFICATE-----" ]] || continue
		_is_tls_server_ca <<<"$pem" && printf '%s' "$pem"
		pem=""
	done < <(security find-certificate -a -p /Library/Keychains/System.keychain 2>/dev/null)
}

refresh_keychain_ca_bundle() {
	local candidate="$KEYCHAIN_CA_BUNDLE.new"
	command -v security &>/dev/null && command -v openssl &>/dev/null || return 1
	mkdir -p "$(dirname "$KEYCHAIN_CA_BUNDLE")" || return 1
	_keychain_ca_certs >"$candidate" 2>/dev/null
	if ! grep -q 'BEGIN CERTIFICATE' "$candidate"; then
		rm -f "$candidate"
		return 1
	fi
	if [[ -f "$KEYCHAIN_CA_BUNDLE" ]] && cmp -s "$candidate" "$KEYCHAIN_CA_BUNDLE"; then
		rm -f "$candidate"
		return 0
	fi
	mv "$candidate" "$KEYCHAIN_CA_BUNDLE"
}

export_keychain_ca_bundle() {
	local -i refreshed=1
	refresh_keychain_ca_bundle && refreshed=0
	if [[ -f "$KEYCHAIN_CA_BUNDLE" ]]; then
		export NODE_EXTRA_CA_CERTS="$KEYCHAIN_CA_BUNDLE"
	fi
	return "$refreshed"
}
