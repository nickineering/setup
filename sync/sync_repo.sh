#!/opt/homebrew/bin/bash

# Sync a single git repo: fetch, pull main+develop, checkout preferred branch.
# Called by sync_repos via xargs for parallel execution.
#
# Usage: sync_repo.sh <repo_dir> <base_dir> [stale_branches_dir]
# Example: sync_repo.sh ~/work/backend/foo ~/work /tmp/stale

set -euo pipefail

repo_dir="$1"
base_dir="$2"
stale_dir="${3:-}"
active_branches_dir="${4:-}"
repo_name="${repo_dir#"$base_dir"/}"

source "$SETUP/lib/colors.sh"

_retry() {
	local attempts=3 delay=5 i
	for ((i = 1; i <= attempts; i++)); do
		if "$@"; then
			return 0
		fi
		[[ $i -lt $attempts ]] && sleep "$delay"
	done
	return 1
}

# Sync a branch: checkout, pull, return status string
# Usage: sync_branch <branch_name>
# Output: Sets $branch_status variable
sync_branch() {
	local branch="$1"
	local before after current_branch
	before=$(git rev-parse "$branch" 2>/dev/null || echo "none")
	current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")

	if [[ "$current_branch" == "$branch" ]]; then
		# Branch is checked out — can't update ref directly, merge instead
		git merge --ff-only "origin/$branch" --quiet 2>/dev/null || true
	elif ! git fetch origin "$branch:$branch" --quiet 2>/dev/null; then
		# fetch branch:branch fails on non-fast-forward or if branch doesn't exist locally yet
		git branch -f "$branch" "origin/$branch" 2>/dev/null || true
	fi
	after=$(git rev-parse "$branch" 2>/dev/null || echo "none")
	if [[ "$before" == "$after" ]]; then
		branch_status="${dim}${branch}${reset}"
	else
		branch_status="${green}${branch} ✅${reset}"
	fi
}

cd "$repo_dir" || exit 1

# Track original branch to warn user if we switch away from it
original_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")

_retry git fetch --all --prune --prune-tags --force --quiet

# Detect stale branches (local branches whose upstream is gone after prune)
if [[ -n "$stale_dir" ]]; then
	# git branch -vv shows "[origin/branch: gone]" for branches with deleted upstreams
	stale_branches=$(git branch -vv 2>/dev/null | grep ': gone]' | sed 's/^[* ]*//' | awk '{print $1}' || true)
	if [[ -n "$stale_branches" ]]; then
		# Write to a unique file per repo (avoids race condition with parallel syncs)
		stale_file="$stale_dir/$(echo "$repo_name" | tr '/' '_')"
		while IFS= read -r branch; do
			printf '%s:%s\n' "$repo_name" "$branch" >>"$stale_file"
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

# Determine if we should return to the original feature branch.
# Stay on feature branch if it has unmerged commits.
# Never pull the feature branch — local history rewrites may not be pushed yet.
_should_keep_feature_branch() {
	local branch="$1"
	# Not a feature branch (also excludes detached HEAD)
	[[ "$branch" != "main" && "$branch" != "develop" && "$branch" != "HEAD" && -n "$branch" ]] || return 1
	# Branch must still exist locally
	git show-ref --verify --quiet "refs/heads/$branch" 2>/dev/null || return 1
	# Stale: upstream was deleted
	local upstream
	upstream=$(git for-each-ref --format='%(upstream:track)' "refs/heads/$branch" 2>/dev/null)
	[[ "$upstream" != "[gone]" ]] || return 1
	# Only keep if there are commits not yet merged into the default branch
	local unmerged
	unmerged=$(git log "${preferred_default}..${branch}" --oneline 2>/dev/null | head -1)
	[[ -n "$unmerged" ]] || return 1
	return 0
}

# Determine preferred default branch
if [[ "$has_develop" == "yes" ]]; then
	preferred_default="develop"
elif [[ "$has_main" == "yes" ]]; then
	preferred_default="main"
else
	preferred_default=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||')
	if [[ -n "$preferred_default" ]]; then
		sync_branch "$preferred_default"
	fi
fi

# Decide which branch to end on
if _should_keep_feature_branch "$original_branch"; then
	git checkout "$original_branch" --quiet 2>/dev/null || true
	final_branch="$original_branch"
	# Record active feature branch for end-of-sync summary
	if [[ -n "$active_branches_dir" ]]; then
		active_file="$active_branches_dir/$(echo "$repo_name" | tr '/' '_')"
		printf '%s:%s\n' "$repo_name" "$final_branch" >>"$active_file"
	fi
elif [[ -n "${preferred_default:-}" ]]; then
	git checkout "$preferred_default" --quiet 2>/dev/null || true
	final_branch="$preferred_default"
fi

# Build output line, then print atomically to avoid interleaving with parallel jobs
output=""
if [[ "$has_develop" == "yes" ]] && [[ "$has_main" == "yes" ]]; then
	output="$repo_name: $(printf '%b, %b' "$develop_status" "$main_status")"
elif [[ "$has_develop" == "yes" ]]; then
	output="$repo_name: $(printf '%b' "$develop_status")"
elif [[ "$has_main" == "yes" ]]; then
	output="$repo_name: $(printf '%b' "$main_status")"
elif [[ -n "${preferred_default:-}" ]]; then
	output="$repo_name: $(printf '%b' "$branch_status")"
else
	output="$repo_name: $(printf "${yellow}no default branch${reset}")"
fi

if [[ -n "${final_branch:-}" && "$final_branch" != "${preferred_default:-}" ]]; then
	output+=" $(printf "${green}(staying on %s)${reset}" "$final_branch")"
elif [[ -n "$original_branch" && "$original_branch" != "${final_branch:-}" && "$original_branch" != "develop" && "$original_branch" != "main" ]]; then
	output+=" $(printf "${yellow}(left %s)${reset}" "$original_branch")"
fi

printf '%s\n' "$output"
