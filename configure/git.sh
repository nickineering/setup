# shellcheck shell=bash
# shellcheck disable=SC2154 # Variables like $dim defined in lib/colors.sh

# Route credentials for a self-hosted GitLab through glab so a rotated token is
# picked up automatically. The empty value first is git's idiom for resetting the
# helper list: Homebrew's system gitconfig sets osxkeychain globally, and without
# the reset it runs first and keeps replaying the password it cached before the
# token was rotated. gitlab.com is already covered by linked/.gitconfig.
configure_gitlab_credential_helper() {
	local host="${GITLAB_HOST:-}" glab_bin key want
	[[ -n "$host" && "$host" != "gitlab.com" ]] || return 0

	glab_bin=$(command -v glab 2>/dev/null) || return 0

	key="credential.https://$host.helper"
	want="$glab_bin auth git-credential"

	# glab writes this itself as `!glab auth git-credential` when it logs in; either
	# form is correct, so accept both rather than rewriting it on every run.
	case "$(git config --global --get "$key" '.' 2>/dev/null)" in
	"$want" | '!glab auth git-credential')
		info "GitLab credential helper already configured for $host"
		return 0
		;;
	esac

	git config --global --replace-all "$key" ""
	git config --global --add "$key" "$want"
	info "Routed $host git credentials through glab"
}

configure_gitlab_credential_helper

# Point stray hostnames for the same instance back at GITLAB_HOST.
#
# An instance can report clone URLs on a hostname other than the one you queried —
# a Geo secondary reports its primary's external_url, so the API answers on the name
# you asked for but hands back absolute URLs on the other one. Anything that follows
# an API-supplied URL then talks to a host the helper above is not configured for,
# and git has no credential for it.
#
# Fixing it here rather than in whatever script happened to notice covers every such
# tool at once — glab, submodules, VCS installs, a URL pasted from the web UI. git
# rewrites before the credential lookup, and records the rewritten URL, so remotes
# land on GITLAB_HOST with nothing to correct afterwards.
configure_gitlab_url_aliases() {
	local host="${GITLAB_HOST:-}" aliases="${GITLAB_URL_ALIASES:-}" key alias current want
	[[ -n "$host" ]] || return 0

	key="url.https://$host/.insteadOf"
	want=$(echo "$aliases" | tr '|' '\n' | sed '/^$/d' | sort)
	current=$(git config --global --get-all "$key" 2>/dev/null | sort || true)

	# Nothing configured and nothing wanted: the ordinary case on an instance with a
	# single hostname, so say nothing.
	[[ -z "$current" && -z "$want" ]] && return 0
	if [[ "$current" == "$want" ]]; then
		info "GitLab URL aliases already point at $host"
		return 0
	fi

	# Rebuilt rather than appended to, so the variable stays the source of truth and
	# dropping an alias from it actually removes the rewrite. At a host retirement
	# that is the whole change: empty GITLAB_URL_ALIASES and re-run.
	git config --global --unset-all "$key" 2>/dev/null || true
	if [[ -z "$want" ]]; then
		info "Cleared GitLab URL aliases for $host"
		return 0
	fi

	while IFS= read -r alias; do
		[[ -n "$alias" ]] || continue
		git config --global --add "$key" "$alias"
	done <<<"$want"
	info "Rewrote $(echo "$want" | wc -l | tr -d ' ') alias host(s) to $host"
}

configure_gitlab_url_aliases

if ! git config --global user.name &>/dev/null; then
	echo -e "${bold}Git identity not configured. Setting up...${reset}"
	prompt "Enter your full name for git commits:"
	read -r git_name </dev/tty
	prompt "Enter your email for git commits:"
	read -r git_email </dev/tty
	git config --global user.name "$git_name"
	git config --global user.email "$git_email"
	info "Git identity configured"
else
	info "Git identity already configured"
fi
