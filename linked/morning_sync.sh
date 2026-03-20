#!/opt/homebrew/bin/bash

# Sync a single git repo: fetch, pull main+develop, checkout preferred branch.
# Called by morning() via xargs for parallel execution.
#
# Usage: morning_sync.sh <repo_dir> <base_dir> [stale_branches_file]
# Example: morning_sync.sh ~/eonnext/backend/foo ~/eonnext /tmp/stale.txt

set -euo pipefail

repo_dir="$1"
base_dir="$2"
stale_file="${3:-}"
repo_name="${repo_dir#"$base_dir"/}"

# Colors
reset='\033[0m'
dim='\033[2m'
green='\033[32m'
yellow='\033[33m'

# Sync a branch: checkout, pull, return status string
# Usage: sync_branch <branch_name>
# Output: Sets $branch_status variable
sync_branch() {
	local branch="$1"
	local before after
	before=$(git rev-parse "$branch" 2>/dev/null || echo "none")
	git checkout "$branch" --quiet 2>/dev/null || git checkout -b "$branch" "origin/$branch" --quiet 2>/dev/null
	git pull --quiet origin "$branch" 2>/dev/null || true
	after=$(git rev-parse "$branch" 2>/dev/null)
	if [[ "$before" == "$after" ]]; then
		branch_status="${dim}${branch}${reset}"
	else
		branch_status="${green}${branch} ✅${reset}"
	fi
}

cd "$repo_dir" || exit 1
git fetch --all --prune --quiet

# Detect stale branches (local branches whose upstream is gone after prune)
if [[ -n "$stale_file" ]]; then
	# git branch -vv shows "[origin/branch: gone]" for branches with deleted upstreams
	stale_branches=$(git branch -vv 2>/dev/null | grep ': gone]' | awk '{print $1}' || true)
	if [[ -n "$stale_branches" ]]; then
		# Append each stale branch as "repo_name:branch" to the shared file
		while IFS= read -r branch; do
			echo "${repo_name}:${branch}" >>"$stale_file"
		done <<<"$stale_branches"
	fi
fi

# Check which branches exist on remote
has_develop=$(git show-ref --verify --quiet refs/remotes/origin/develop && echo yes || echo no)
has_main=$(git show-ref --verify --quiet refs/remotes/origin/main && echo yes || echo no)

main_status=""
develop_status=""

if [[ "$has_main" == "yes" ]]; then
	sync_branch main
	main_status="$branch_status"
fi

if [[ "$has_develop" == "yes" ]]; then
	sync_branch develop
	develop_status="$branch_status"
fi

# Report status (end on develop if it exists, otherwise main)
if [[ "$has_develop" == "yes" ]] && [[ "$has_main" == "yes" ]]; then
	git checkout develop --quiet 2>/dev/null
	printf "%s: %b, %b\n" "$repo_name" "$develop_status" "$main_status"
elif [[ "$has_develop" == "yes" ]]; then
	printf "%s: %b\n" "$repo_name" "$develop_status"
elif [[ "$has_main" == "yes" ]]; then
	printf "%s: %b\n" "$repo_name" "$main_status"
else
	# Fallback: use repo's default branch
	default_branch=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||')
	if [[ -n "$default_branch" ]]; then
		sync_branch "$default_branch"
		printf "%s: %b\n" "$repo_name" "$branch_status"
	else
		printf "%s: ${yellow}⚠️  no default branch${reset}\n" "$repo_name"
	fi
fi
