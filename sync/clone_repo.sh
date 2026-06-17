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
		[[ $i -lt $attempts ]] && sleep "$((delay * i))"
	done
	echo "$output"
	return 1
}

# Extract a short reason from git/glab error output
_error_reason() {
	local output="$1"
	if echo "$output" | grep -q "502\|503\|500"; then
		echo "server error (retried)"
	elif echo "$output" | grep -q "404\|not found"; then
		echo "not found"
	elif echo "$output" | grep -q "403\|permission\|denied\|access"; then
		echo "permission denied"
	elif echo "$output" | grep -q "timeout\|timed out"; then
		echo "timeout (retried)"
	else
		echo "$output" | tail -1 | cut -c1-80
	fi
}

mkdir -p "$dir/$(dirname "$repo")"
if output=$(_retry glab repo clone "$group/$repo" "$dir/$repo"); then
	printf '\033[92m✓ Cloned: %s\033[0m\n' "$repo"
else
	reason=$(_error_reason "$output")
	printf "%s: %s\n" "$repo" "$reason" >&2
	exit 1
fi
