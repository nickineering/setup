# shellcheck shell=bash
# shellcheck disable=SC2034,SC2154 # GPG_KEY_ID used by callers; color vars from lib/colors.sh
# GPG key helpers - sourced by configure/gpg.sh and configure/glab.sh

# Ensure a GPG signing key exists for the given email. Generates one if needed.
# Sets GPG_KEY_ID to the key ID on success, empty string on failure.
# Usage: ensure_gpg_key "name" "email"
ensure_gpg_key() {
	local name="$1" email="$2"
	GPG_KEY_ID=""

	local existing_key
	existing_key=$(gpg --list-secret-keys --keyid-format long "$email" 2>/dev/null | grep "sec" || true)

	if [[ -z "$existing_key" ]]; then
		echo -e "${bold}Generating GPG key for $email...${reset}"
		gpg --batch --gen-key <<-GPGEOF
			Key-Type: eddsa
			Key-Curve: ed25519
			Key-Usage: sign
			Subkey-Type: ecdh
			Subkey-Curve: cv25519
			Subkey-Usage: encrypt
			Name-Real: ${name}
			Name-Email: ${email}
			Expire-Date: 0
			%no-protection
			%commit
		GPGEOF
	fi

	GPG_KEY_ID=$(gpg --list-secret-keys --keyid-format long "$email" 2>/dev/null | grep "sec" | sed 's/.*\/\([A-F0-9]*\).*/\1/')
}
