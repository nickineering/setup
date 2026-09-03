#!/opt/homebrew/bin/bash

# Git helpers shared by the dotfile functions and the repo sync. They must agree
# on which branch the main clone owns, or `git wt` and the sync disagree about
# what is safe to check out in a worktree.

# The default branch, in the order this org prefers. origin/HEAD usually points at
# main, so develop has to be checked first. $1=DIRECTORY / default=cwd
git_default_branch() {
	local dir="${1:-.}"
	if git -C "$dir" show-ref --verify --quiet refs/remotes/origin/develop; then
		echo develop
	elif git -C "$dir" show-ref --verify --quiet refs/remotes/origin/main; then
		echo main
	else
		git -C "$dir" symbolic-ref refs/remotes/origin/HEAD 2>/dev/null |
			sed 's|refs/remotes/origin/||'
	fi
}
