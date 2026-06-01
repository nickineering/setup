# shellcheck shell=bash
# shellcheck disable=SC2154 # Variables like $dim defined in lib/colors.sh
# Sourced by after_signin.sh - generates GPG key and configures git signing

# Skip if a GPG key already exists for the git email
git_email=$(git config --global user.email 2>/dev/null || echo "")
if [[ -z "$git_email" ]]; then
	echo -e "${yellow}Warning: git email not configured, skipping GPG setup${reset}"
	return 0
fi

existing_key=$(gpg --list-secret-keys --keyid-format long "$git_email" 2>/dev/null | grep "sec" || true)
if [[ -n "$existing_key" ]]; then
	echo -e "${dim}GPG key already exists for $git_email${reset}"
	return 0
fi

echo -e "${bold}Generating GPG key for $git_email...${reset}"

git_name=$(git config --global user.name 2>/dev/null || echo "")
if [[ -z "$git_name" ]]; then
	echo -e "${yellow}Warning: git name not configured, skipping GPG setup${reset}"
	return 0
fi

# Generate key non-interactively
gpg --batch --gen-key <<GPGEOF
Key-Type: eddsa
Key-Curve: ed25519
Key-Usage: sign
Subkey-Type: ecdh
Subkey-Curve: cv25519
Subkey-Usage: encrypt
Name-Real: ${git_name}
Name-Email: ${git_email}
Expire-Date: 0
%no-protection
%commit
GPGEOF

# Get the key ID
key_id=$(gpg --list-secret-keys --keyid-format long "$git_email" 2>/dev/null | grep "sec" | sed 's/.*\/\([A-F0-9]*\).*/\1/')

if [[ -z "$key_id" ]]; then
	echo -e "${yellow}Warning: GPG key generation may have failed${reset}"
	return 0
fi

# Configure git to use this key
git config --global user.signingkey "$key_id"
git config --global commit.gpgsign true
git config --global tag.gpgsign true

# Add to GitHub if gh is authenticated
if gh auth status &>/dev/null; then
	echo -e "${dim}Adding GPG key to GitHub...${reset}"
	gpg --armor --export "$key_id" | gh gpg-key add - 2>/dev/null &&
		echo -e "${green}GPG key added to GitHub${reset}" ||
		echo -e "${yellow}Warning: Failed to add GPG key to GitHub (add manually)${reset}"
else
	echo -e "${yellow}Note: GitHub CLI not authenticated. Add GPG key manually:${reset}"
	echo "  gpg --armor --export $key_id | gh gpg-key add -"
fi

echo -e "${green}GPG signing configured (key: $key_id)${reset}"
