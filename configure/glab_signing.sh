# shellcheck shell=bash
# shellcheck disable=SC2154 # Variables like $dim defined in lib/colors.sh
# Sourced by after_signin.sh - sets up ~/work/.gitconfig with work email and GPG signing

source lib/gpg.sh

local_gitconfig="$HOME/work/.gitconfig"

mkdir -p "$HOME/work"

# If ~/work/.gitconfig already has a signing key, we're done
if [[ -f "$local_gitconfig" ]] && git config --file "$local_gitconfig" user.signingkey &>/dev/null; then
	info "Work git identity already configured"
	return 0
fi

# Prompt for work email if not already set
work_email=""
if [[ -f "$local_gitconfig" ]]; then
	work_email=$(git config --file "$local_gitconfig" user.email 2>/dev/null || echo "")
fi
if [[ -z "$work_email" ]]; then
	echo -n "Enter your work email for git commits in ~/work: "
	read -r work_email </dev/tty
	if [[ -z "$work_email" ]]; then
		warn "No email provided, skipping work git identity"
		return 0
	fi
fi

git_name=$(git config --global user.name 2>/dev/null || echo "")
if [[ -z "$git_name" ]]; then
	warn "git name not configured globally, skipping work GPG setup"
	return 0
fi

ensure_gpg_key "$git_name" "$work_email"
if [[ -z "$GPG_KEY_ID" ]]; then
	warn "GPG key generation may have failed"
	return 0
fi

git config --file "$local_gitconfig" user.email "$work_email"
git config --file "$local_gitconfig" user.signingkey "$GPG_KEY_ID"

# Add to GitLab if glab is authenticated
if glab auth status &>/dev/null; then
	gpg_pubkey=$(gpg --armor --export "$GPG_KEY_ID")
	key_fingerprint=$(echo "$gpg_pubkey" | sed -n '3p')
	if glab api "user/gpg_keys" 2>/dev/null | grep -q "$key_fingerprint"; then
		info "GPG key already on GitLab"
	else
		info "Adding GPG key to GitLab..."
		if echo "$gpg_pubkey" | glab api --method POST "user/gpg_keys" -F "key=@-" &>/dev/null; then
			success "GPG key added to GitLab"
		else
			warn "Failed to add GPG key to GitLab. Add manually:"
			echo -e "  ${dim}Run: gpg --armor --export $GPG_KEY_ID | glab api --method POST user/gpg_keys -F key=@-${reset}"
		fi
	fi
else
	warn "glab not authenticated. After authenticating, add your GPG key:"
	echo -e "  ${dim}Run: gpg --armor --export $GPG_KEY_ID | glab api --method POST user/gpg_keys -F key=@-${reset}"
fi

success "Work git identity configured (key: $GPG_KEY_ID)"
