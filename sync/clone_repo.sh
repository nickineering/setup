#!/opt/homebrew/bin/bash

# Clone a single repo from GitLab, creating parent directories as needed.
# Called by sync_repos via xargs for parallel execution.
#
# Usage: clone_repo.sh <repo_path> <base_dir> <gitlab_group>
# Example: clone_repo.sh backend/backend-apps/foo ~/work mycompany

set -euo pipefail

repo="$1"
dir="$2"
group="$3"

_retry() {
	local attempts=4 delay=5 i output
	for ((i = 1; i <= attempts; i++)); do
		if output=$("$@" 2>&1); then
			return 0
		fi
		# A host we have no credential for will not start having one 30s of backoff
		# later, and every repo hits it at once — so give up on the first attempt and
		# let the caller report it.
		if echo "$output" | grep -q "could not read Username\|terminal prompts disabled"; then
			break
		fi
		[[ $i -lt $attempts ]] && sleep "$((delay * i))"
	done
	echo "$output"
	return 1
}

# Extract a short reason from git/glab error output
_error_reason() {
	local output="$1"
	# Credentials first, and status codes only where they are reported as such. A bare
	# "500" match hits any path or repo name containing those digits — the clone
	# directory alone was enough to turn a missing credential into "server error".
	if echo "$output" | grep -qi "could not read Username\|terminal prompts disabled\|Authentication failed"; then
		echo "no credential for the clone host"
	elif echo "$output" | grep -qE 'error: (500|502|503)|(500|502|503) (Internal|Bad Gateway|Service Unavailable)'; then
		echo "server error (retried)"
	elif echo "$output" | grep -qE 'error: 404|not found'; then
		echo "not found"
	elif echo "$output" | grep -qE 'error: 403|permission|denied|access'; then
		echo "permission denied"
	elif echo "$output" | grep -q "timeout\|timed out"; then
		echo "timeout (retried)"
	else
		echo "$output" | tail -1 | cut -c1-80
	fi
}

# A clone must never wait on a prompt: these run in parallel, so 20 of them would
# race for one tty and wedge the run instead of reporting anything. Failing fast
# turns a missing credential into a line in the error summary.
#
# An instance that reports clone URLs on a different hostname than the one queried
# is handled at the git level by configure/git.sh, not here.
export GIT_TERMINAL_PROMPT=0

mkdir -p "$dir/$(dirname "$repo")"
if output=$(_retry glab repo clone "$group/$repo" "$dir/$repo"); then
	printf '\033[92m✓ Cloned: %s\033[0m\n' "$repo"
else
	reason=$(_error_reason "$output")
	printf "%s: %s\n" "$repo" "$reason" >&2
	exit 1
fi
