#!/opt/homebrew/bin/bash

# Clone a single repo from GitLab, creating parent directories as needed.
# Called by morning() via xargs for parallel execution.
#
# Usage: morning_clone.sh <repo_path> <base_dir> <gitlab_group>
# Example: morning_clone.sh backend/backend-apps/foo ~/work mycompany

set -euo pipefail

repo="$1"
dir="$2"
group="$3"

mkdir -p "$dir/$(dirname "$repo")"
# grep returns 1 when no matches; use || true to avoid failing with set -e
glab repo clone "$group/$repo" "$dir/$repo" 2>&1 | { grep -v "^$" || true; }
