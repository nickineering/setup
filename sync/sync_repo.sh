#!/opt/homebrew/bin/bash

# Sync a single git repo: fetch, pull every trunk branch, checkout preferred branch.
# Called by sync_repos via xargs for parallel execution.
#
# Usage: sync_repo.sh <repo_dir> <base_dir> [stale_branches_dir] [active_branches_dir] [stale_worktrees_dir]
# Example: sync_repo.sh ~/work/backend/foo ~/work /tmp/stale /tmp/active /tmp/stale-wt

set -euo pipefail

repo_dir="$1"
base_dir="$2"
stale_dir="${3:-}"
active_branches_dir="${4:-}"
stale_worktrees_dir="${5:-}"
repo_name="${repo_dir#"$base_dir"/}"
# Parallel worktree tree — see the Worktrees section in linked/git_functions.sh
worktrees_root="$base_dir/.worktrees"

# shellcheck source=SCRIPTDIR/../lib/colors.sh
source "$SETUP/lib/colors.sh"
# shellcheck source=SCRIPTDIR/../lib/git.sh
source "$SETUP/lib/git.sh"

fetch_error=""

_fetch_all() {
	fetch_error=$(git fetch --all --prune --prune-tags --force --quiet 2>&1)
}

_fetch_failed_on_locked_ref() {
	[[ "$fetch_error" == *"cannot lock ref"* ]]
}

_fetch_failure_is_transient() {
	! _fetch_failed_on_locked_ref
}

_case_colliding_remote_refs() {
	git for-each-ref --format='%(refname)' refs/remotes/origin |
		grep -v '^refs/remotes/origin/HEAD$' |
		awk '{
			folded = tolower($0)
			count[folded]++
			group[folded] = group[folded] $0 "\n"
		}
		END { for (folded in count) if (count[folded] > 1) printf "%s", group[folded] }'
}

_branch_refs_on_origin() {
	git ls-remote --heads origin 2>/dev/null |
		sed 's|.*[[:space:]]refs/heads/|refs/remotes/origin/|'
}

_drop_colliding_refs_gone_from_origin() {
	local colliding on_origin ref
	local -i dropped=0
	colliding=$(_case_colliding_remote_refs)
	on_origin=$(_branch_refs_on_origin)
	[[ -n "$colliding" && -n "$on_origin" ]] || return 1
	while IFS= read -r ref; do
		[[ -n "$ref" ]] || continue
		grep -qxF "$ref" <<<"$on_origin" && continue
		git update-ref -d "$ref" 2>/dev/null && ((dropped++)) || true
	done <<<"$colliding"
	((dropped))
}

_fetch_with_retries() {
	local attempts=3 delay=5 i
	for ((i = 1; i <= attempts; i++)); do
		_fetch_all && return 0
		_fetch_failure_is_transient || return 1
		if ((i < attempts)); then sleep "$delay"; fi
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

# Commits in worktree $1 that origin does not have, mirroring _wt_unpushed_count in
# linked/git_functions.sh. Worktree branches are created --no-track, so @{upstream}
# is usually absent until the first push and the base ref $2 is all there is to
# compare against. Prints nothing when neither resolves: unknown is not the same as
# nothing to lose, and reporting 0 there would flag real work as clean.
_worktree_unpushed() {
	local dir="$1" base_ref="$2" count
	count=$(git -C "$dir" rev-list --count '@{upstream}..HEAD' 2>/dev/null || true)
	if [[ -z "$count" && -n "$base_ref" ]]; then
		count=$(git -C "$dir" rev-list --count "$base_ref..HEAD" 2>/dev/null || true)
	fi
	printf '%s' "$count"
}

_worktree_ignored_count() {
	git -C "$1" status --porcelain --ignored 2>/dev/null | grep -c '^!!' || true
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
	local unpushed
	unpushed=$(git rev-list --count "origin/$branch..$branch" 2>/dev/null || echo 0)
	if [[ "$unpushed" != 0 ]]; then
		branch_status="${yellow}${branch} +${unpushed}${reset}"
	elif [[ "$before" == "$after" ]]; then
		branch_status="${dim}${branch}${reset}"
	else
		branch_status="${green}${branch} ✅${reset}"
	fi
}

cd "$repo_dir" || exit 1

# Track original branch to warn user if we switch away from it
original_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")

if ! _fetch_with_retries; then
	if _fetch_failed_on_locked_ref && _drop_colliding_refs_gone_from_origin; then
		_fetch_with_retries || {
			printf '%s\n' "$fetch_error" >&2
			exit 1
		}
	else
		printf '%s\n' "$fetch_error" >&2
		exit 1
	fi
fi

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

mapfile -t synced_branches < <(git_synced_branches)
preferred_default=$(git_default_branch)

_is_synced_branch() {
	local candidate="$1" branch
	for branch in "${synced_branches[@]}"; do
		[[ "$branch" == "$candidate" ]] && return 0
	done
	return 1
}

branch_statuses=()
for synced_branch in "${synced_branches[@]}"; do
	sync_branch "$synced_branch"
	branch_statuses+=("$branch_status")
done

# Determine if we should return to the original feature branch.
# Stay on feature branch if it has unmerged commits.
# Never pull the feature branch — local history rewrites may not be pushed yet.
_should_keep_feature_branch() {
	local branch="$1"
	# Excludes detached HEAD
	[[ "$branch" != "HEAD" && -n "$branch" ]] || return 1
	[[ -n "${preferred_default:-}" ]] || return 1
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

# Decide which branch to end on
if _is_synced_branch "$original_branch"; then
	final_branch="$original_branch"
elif _should_keep_feature_branch "$original_branch"; then
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
else
	final_branch="$original_branch"
fi

# Classify linked worktrees: finished ones go to repos.sh for the same delete
# prompt stale branches get, the rest are reported as active work. Their branches
# are never pulled here for the same reason feature branches are not: local history
# may have been rewritten and not yet pushed.
if [[ -n "$active_branches_dir" || -n "$stale_worktrees_dir" ]]; then
	[[ -n "$active_branches_dir" ]] && active_file="$active_branches_dir/$(echo "$repo_name" | tr '/' '_')"
	[[ -n "$stale_worktrees_dir" ]] && stale_wt_file="$stale_worktrees_dir/$(echo "$repo_name" | tr '/' '_')"
	base_ref=$(git_worktree_base_ref || true)
	# Tab-separated because worktree paths contain "/" but never a tab
	while IFS=$'\t' read -r wt ref; do
		[[ -z "$wt" || "$wt" == "$repo_dir" ]] && continue
		wt_branch="${ref#refs/heads/}"
		# Already offered for deletion as stale — do not also list it here
		track=$(git for-each-ref --format='%(upstream:track)' "refs/heads/$wt_branch" 2>/dev/null || true)
		[[ "$track" == "[gone]" ]] && continue

		wt_dirty=""
		[[ -n "$(git -C "$wt" status --porcelain 2>/dev/null)" ]] && wt_dirty="dirty"
		wt_ahead=$(_worktree_unpushed "$wt" "$base_ref")

		# A worktree holding nothing origin lacks — clean, nothing unpushed, every
		# commit of its own already in the base branch — is finished. Which way it
		# finished decides the wording: an upstream means it was pushed, so the work
		# merged; no upstream and a tip the base has moved past means it never
		# started and the directory is only scaffolding. A tip still equal to the
		# base with nothing pushed is a worktree waiting to be used, not a spent
		# one, so it stays active work.
		reason=""
		if [[ -z "$wt_dirty" && "$wt_ahead" == "0" && -n "$base_ref" ]] &&
			[[ "$(git rev-list --count "$base_ref..refs/heads/$wt_branch" 2>/dev/null || echo 1)" == "0" ]]; then
			upstream=$(git for-each-ref --format='%(upstream)' "refs/heads/$wt_branch" 2>/dev/null || true)
			if [[ -n "$upstream" ]]; then
				reason="merged"
			elif [[ "$(git rev-parse "refs/heads/$wt_branch")" != "$(git rev-parse "$base_ref")" ]]; then
				reason="no-commits"
			fi
		fi

		# Only the mirror's own tree is ever offered for deletion — a worktree added
		# by hand elsewhere is reported as active work and left alone.
		if [[ -n "$reason" && -n "$stale_worktrees_dir" && "$wt" == "$worktrees_root"/* ]]; then
			printf '%s:%s:%s:%s:%s\n' "$reason" "$repo_name" "$wt_branch" \
				"$(_worktree_ignored_count "$wt")" "$wt" >>"$stale_wt_file"
			continue
		fi

		if [[ -n "$active_branches_dir" ]]; then
			# Work that would be lost is flagged rather than offered for deletion
			flags="$wt_dirty"
			if [[ -z "$wt_ahead" ]]; then
				# No upstream and no base to measure against
				flags="${flags:+$flags }unpushed?"
			elif [[ "$wt_ahead" != "0" ]]; then
				flags="${flags:+$flags }+$wt_ahead"
			fi
			printf '%s:%s:%s:%s\n' "$repo_name" "$wt_branch" "$flags" "$wt" >>"$active_file"
		fi
	done < <(git worktree list --porcelain 2>/dev/null |
		awk '/^worktree /{wt = substr($0, 10)}
		     /^branch /{printf "%s\t%s\n", wt, substr($0, 8)}')
fi

# Single printf at the end avoids interleaving with other parallel xargs jobs
if ((${#branch_statuses[@]} > 0)); then
	joined=$(printf '%b, ' "${branch_statuses[@]}")
	output="$repo_name: ${joined%, }"
else
	output="$repo_name: $(printf '%b' "${yellow}no default branch${reset}")"
fi

if [[ -n "${final_branch:-}" ]] && ! _is_synced_branch "$final_branch"; then
	output+=" $(printf "${dim}(staying on ${sky}%s${dim})${reset}" "$final_branch")"
elif [[ -n "$original_branch" && "$original_branch" != "${final_branch:-}" ]] &&
	! _is_synced_branch "$original_branch"; then
	output+=" $(printf "${yellow}(left %s)${reset}" "$original_branch")"
fi

printf '%s\n' "$output"
