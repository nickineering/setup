# shellcheck shell=bash
# shellcheck disable=SC2154 # Variables like $dim defined in lib/colors.sh
# Sourced by after_signin.sh - generates GPG key and configures git signing

source lib/gpg.sh

git_email=$(git config --global user.email 2>/dev/null || echo "")
if [[ -z "$git_email" ]]; then
	warn "git email not configured, skipping GPG setup"
	return 0
fi

git_name=$(git config --global user.name 2>/dev/null || echo "")
if [[ -z "$git_name" ]]; then
	warn "git name not configured, skipping GPG setup"
	return 0
fi

# Check if already configured
if git config --global user.signingkey &>/dev/null; then
	info "GPG key already exists for $git_email"
	return 0
fi

ensure_gpg_key "$git_name" "$git_email"
if [[ -z "$GPG_KEY_ID" ]]; then
	warn "GPG key generation may have failed"
	return 0
fi

git config --global user.signingkey "$GPG_KEY_ID"
git config --global commit.gpgsign true
git config --global tag.gpgsign true

# Add to GitHub if gh is authenticated
if gh auth status &>/dev/null; then
	# Ensure write:gpg_key scope is present
	if ! gh gpg-key list &>/dev/null; then
		info "Requesting write:gpg_key scope..."
		gh auth refresh -s write:gpg_key
	fi
	info "Adding GPG key to GitHub..."
	if gpg --armor --export "$GPG_KEY_ID" | gh gpg-key add - 2>/dev/null; then
		success "GPG key added to GitHub"
	else
		warn "Failed to add GPG key to GitHub. Add manually:"
		echo -e "  ${dim}1. Run: gpg --armor --export $GPG_KEY_ID | gh gpg-key add -${reset}"
	fi
else
	warn "GitHub CLI not authenticated. After authenticating, add your GPG key:"
	echo -e "  ${dim}Run: gpg --armor --export $GPG_KEY_ID | gh gpg-key add -${reset}"
fi

success "GPG signing configured (key: $GPG_KEY_ID)"
