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

mkdir -p "$dir/$(dirname "$repo")"
# Suppress verbose output, print repo name on success
if glab repo clone "$group/$repo" "$dir/$repo" >/dev/null 2>&1; then
	printf "Cloned: %s\n" "$repo"
else
	exit 1
fi
