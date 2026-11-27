#!/opt/homebrew/bin/bash

# Git helpers shared by the dotfile functions and the repo sync. They must agree
# on which branch the main clone owns, or `git wt` and the sync disagree about
# what is safe to check out in a worktree.

# The branch names this org uses as a trunk, in the order it prefers them.
# origin/HEAD usually points at main, so develop has to be checked first.
GIT_TRUNK_BRANCHES=(develop main trunk)

# $1=DIRECTORY / default=cwd for all of these
git_default_branch() {
	local dir="${1:-.}" branch
	for branch in "${GIT_TRUNK_BRANCHES[@]}"; do
		if git -C "$dir" show-ref --verify --quiet "refs/remotes/origin/$branch"; then
			echo "$branch"
			return 0
		fi
	done
	git_remote_head_branch "$dir" || true
}

git_remote_head_branch() {
	local dir="${1:-.}" branch
	branch=$(git -C "$dir" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null) || return 1
	branch="${branch#origin/}"
	[[ -n "$branch" ]] || return 1
	git -C "$dir" show-ref --verify --quiet "refs/remotes/origin/$branch" || return 1
	printf '%s\n' "$branch"
}

git_worktree_base() {
	local dir="${1:-.}" base
	base=$(git -C "$dir" config --get worktree.base 2>/dev/null || true)
	[[ -n "$base" ]] || base=$(git_remote_head_branch "$dir" || true)
	[[ -n "$base" ]] || base=$(git_default_branch "$dir")
	[[ -n "$base" ]] || return 1
	printf '%s\n' "$base"
}

git_worktree_base_ref() {
	local dir="${1:-.}" base
	base=$(git_worktree_base "$dir") || return 1
	if git -C "$dir" show-ref --verify --quiet "refs/remotes/origin/$base"; then
		printf 'origin/%s\n' "$base"
	elif git -C "$dir" show-ref --verify --quiet "refs/heads/$base"; then
		printf '%s\n' "$base"
	else
		return 1
	fi
}

git_synced_branches() {
	local dir="${1:-.}" branch head
	local -a trunks=()
	for branch in "${GIT_TRUNK_BRANCHES[@]}"; do
		git -C "$dir" show-ref --verify --quiet "refs/remotes/origin/$branch" &&
			trunks+=("$branch")
	done
	if head=$(git_remote_head_branch "$dir"); then
		local -i head_is_a_trunk_name=0
		for branch in "${trunks[@]}"; do
			[[ "$branch" == "$head" ]] && head_is_a_trunk_name=1
		done
		((head_is_a_trunk_name)) || trunks+=("$head")
	fi
	((${#trunks[@]})) || return 0
	printf '%s\n' "${trunks[@]}"
}
