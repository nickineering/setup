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

# shellcheck source=SCRIPTDIR/../lib/colors.sh
source "$SETUP/lib/colors.sh"
# shellcheck source=SCRIPTDIR/../lib/git.sh
source "$SETUP/lib/git.sh"

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

# Directory of the worktree that has $1 checked out, empty if none.
# Git allows a branch in only one worktree at a time, so there is at most one.
_worktree_holding() {
	git worktree list --porcelain 2>/dev/null |
		awk -v b="branch refs/heads/$1" '
			/^worktree /{wt = substr($0, 10)}
			$0 == b {print wt; exit}'
}

# Sync a branch to match its remote. Sets $branch_status with colored output.
# Usage: sync_branch <branch_name>
# Output: Sets $branch_status variable
sync_branch() {
	local branch="$1"
	local before after current_branch holder
	before=$(git rev-parse "$branch" 2>/dev/null || echo "none")
	current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")

	if [[ "$current_branch" == "$branch" ]]; then
		# Can't update the ref of a checked-out branch — merge instead
		git merge --ff-only "origin/$branch" --quiet 2>/dev/null || true
	else
		holder=$(_worktree_holding "$branch")
		if [[ -n "$holder" && "$holder" != "$repo_dir" ]]; then
			# Checked out in a linked worktree, so the ref is just as locked as if it
			# were checked out here — `git branch -f` and `fetch branch:branch` both
			# refuse. Fast-forward it in place rather than silently doing nothing.
			# (`git wt` refuses to worktree default branches, so this is defensive.)
			git -C "$holder" merge --ff-only "origin/$branch" --quiet 2>/dev/null || true
		elif ! git fetch origin "$branch:$branch" --quiet 2>/dev/null; then
			# fetch branch:branch fails on non-fast-forward or missing local branch
			git branch -f "$branch" "origin/$branch" 2>/dev/null || true
		fi
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

# Forget worktrees whose directory was deleted by hand, so their branches stop
# looking checked-out. The shared object store means the fetch above has already
# updated every worktree's remote refs.
git worktree prune 2>/dev/null || true

# Detect stale branches (local branches whose upstream was deleted)
if [[ -n "$stale_dir" ]]; then
	# ": gone]" appears in `git branch -vv` when the tracked remote branch no longer exists.
	# sed strips the leading marker: "*" for the current branch, "+" for one checked
	# out in a linked worktree (missing "+" made this report the branch name as "+").
	# Worktree branches are listed here too, hence the holder lookup below.
	stale_branches=$(git branch -vv 2>/dev/null | grep ': gone]' | sed 's/^[*+ ]*//' | awk '{print $1}' || true)
	if [[ -n "$stale_branches" ]]; then
		# One file per repo avoids race conditions from parallel xargs execution
		stale_file="$stale_dir/$(echo "$repo_name" | tr '/' '_')"
		while IFS= read -r branch; do
			# Record which worktree holds it, if any: git refuses `branch -D` while a
			# branch is checked out anywhere, so repos.sh has to remove that first.
			holder=$(_worktree_holding "$branch")
			[[ "$holder" == "$repo_dir" ]] && holder=""
			printf '%s:%s:%s\n' "$repo_name" "$branch" "$holder" >>"$stale_file"
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

# Determine preferred default branch. develop and main are already synced above,
# so only a fallback default still needs it.
preferred_default=$(git_default_branch)
if [[ "$has_develop" != "yes" && "$has_main" != "yes" && -n "$preferred_default" ]]; then
	sync_branch "$preferred_default"
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

# Record linked worktrees for the end-of-sync summary, alongside feature branches.
# A worktree existing at all means active work, so unlike mainline branches there
# is no unmerged-commits test. Their branches are never pulled here for the same
# reason feature branches are not: local history may have been rewritten and not
# yet pushed.
if [[ -n "$active_branches_dir" ]]; then
	active_file="$active_branches_dir/$(echo "$repo_name" | tr '/' '_')"
	# Tab-separated because worktree paths contain "/" but never a tab
	while IFS=$'\t' read -r wt ref; do
		[[ -z "$wt" || "$wt" == "$repo_dir" ]] && continue
		wt_branch="${ref#refs/heads/}"
		# Already offered for deletion as stale — do not also list it as active
		track=$(git for-each-ref --format='%(upstream:track)' "refs/heads/$wt_branch" 2>/dev/null)
		[[ "$track" == "[gone]" ]] && continue
		printf '%s:%s:%s\n' "$repo_name" "$wt_branch" "$wt" >>"$active_file"
	done < <(git worktree list --porcelain 2>/dev/null |
		awk '/^worktree /{wt = substr($0, 10)}
		     /^branch /{printf "%s\t%s\n", wt, substr($0, 8)}')
fi

# Single printf at the end avoids interleaving with other parallel xargs jobs
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
	output="$repo_name: $(printf '%b' "${yellow}no default branch${reset}")"
fi

if [[ -n "${final_branch:-}" && "$final_branch" != "${preferred_default:-}" ]]; then
	output+=" $(printf "${dim}(staying on ${sky}%s${dim})${reset}" "$final_branch")"
elif [[ -n "$original_branch" && "$original_branch" != "${final_branch:-}" && "$original_branch" != "develop" && "$original_branch" != "main" ]]; then
	output+=" $(printf "${yellow}(left %s)${reset}" "$original_branch")"
fi

printf '%s\n' "$output"
