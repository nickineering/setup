#!/opt/homebrew/bin/bash

# Some aliases credit: https://github.com/alrra/dotfiles/blob/main/src/git/gitconfig

# Commit with message $1, and push
commit() {
	git commit -v -m "$1" && git push
}

# Add all files in current directory, commit with message $1, and push
commit-all() {
	git add .
	commit "$1"
}

# Amend last commit to credit co-author: $1=name, $2=email
credit() {
	if [ -n "$1" ] && [ -n "$2" ]; then
		GIT_EDITOR="git interpret-trailers --in-place --trailer='Co-authored-by: $1 <$2>'" git commit --amend
	fi
}

# Delete all local branches other than current
delete-branches() {
	# ^* is regex matching the literal * that git uses to mark the current branch
	local branches
	# shellcheck disable=SC2063
	branches=$(git branch | grep -v '^*')
	if [[ -z "$branches" ]]; then
		echo "No other branches to delete"
		return 0
	fi
	echo "Branches to delete:"
	echo "$branches"
	echo -n "Delete all these branches? [y/N]: "
	read -r confirm
	if [[ "$confirm" =~ ^[Yy]$ ]]; then
		echo "$branches" | xargs git branch -D
	else
		echo "Aborted"
	fi
}

# cd to the root of the current Git repository
git-root() {
	local root
	root=$(git rev-parse --show-toplevel 2>/dev/null)
	if [[ -n "$root" ]]; then
		cd "$root" || return 1
	else
		echo "Not in a git repository"
		return 1
	fi
}

# Interactive rebase. $1=STEPS_BACK_FROM_HEAD / default=10
interactive-rebase() {
	local DISTANCE
	local COMMIT_COUNT
	COMMIT_COUNT=$(git rev-list --count HEAD 2>/dev/null)
	# Set $DISTANCE to $1 if it's a number, otherwise default to 10
	if [ -n "$1" ] && [ "$1" -eq "$1" ] 2>/dev/null; then
		DISTANCE="$1"
	else
		DISTANCE=10
	fi
	# Cap at available commits
	if [ "$DISTANCE" -gt "$COMMIT_COUNT" ]; then
		DISTANCE=$COMMIT_COUNT
	fi
	git rebase --interactive HEAD~"$DISTANCE"
}

# Ignore $1 as if in .gitignore, but only on this clone of the repo
local-ignore() {
	# Get root directory of current Git repo
	local ROOT
	ROOT=$(git rev-parse --show-toplevel)
	echo "$1" >>"$ROOT"/.git/info/exclude
}

# Edit the Git file that ignores files only within this clone of the repo
local-ignore-edit() {
	# Get root directory of current Git repo
	local ROOT
	ROOT=$(git rev-parse --show-toplevel)
	vim "$ROOT"/.git/info/exclude
}

# Run git pull on all git repos that are nested under the current directory
pull-all() {
	find . -name ".git" -type d -execdir sh -c 'echo "Pulling: ${PWD##*/}" && git pull' \;
}

# Rename a branch locally and remote. $1=OLD_NAME, $2=NEW_NAME
# Credit: https://gist.github.com/DamirPorobic/5be1a47d11c2c7444ddb171d19b4919e
rename-branch() {
	# Check if the user has provided input
	if [ $# -ne 2 ]; then
		echo "usage: rename-branch OLD_BRANCH_NAME NEW_BRANCH_NAME"
		return 1
	fi

	local old_name="$1"
	local new_name="$2"

	# Check if old branch exists locally
	if ! git show-ref --quiet refs/heads/"$old_name"; then
		echo "Local branch not found: $old_name"
		return 1
	fi

	# Check if remote tracking exists
	local has_remote=true
	if ! git show-ref --quiet refs/remotes/origin/"$old_name"; then
		echo "Warning: No remote tracking branch for $old_name, renaming locally only"
		has_remote=false
	fi

	# Rename branch locally
	echo "Renaming branch $old_name to $new_name"
	git branch -m "$old_name" "$new_name"

	# Push to remote if it existed
	if [ "$has_remote" = true ]; then
		git push origin --set-upstream "$new_name"
		git push origin --delete "$old_name"
		git fetch origin
		git remote prune origin
	fi

	echo "Done."
}

# Reset to wherever origin for this branch is, but leave local files alone
reset-to-origin() {
	local branch
	branch=$(git branch --show-current)
	git reset origin/"$branch"
}

# Remove tag if it exists and then tag the latest commit with that name: $1=TAG_NAME
retag() {
	git tag --delete "$1" &>/dev/null
	git tag "$1"
}

# Search commits by source code: $1=CODE
search-for-commits() {
	git log --date=short --decorate --pretty=colorful -S"$1"
}

# Search commits by commit message: $1=COMMIT_MESSAGE
search-for-message() {
	git log --date=short --decorate --pretty=colorful --grep="$1"
}

# Search for snippet in history: $1=SNIPPET
search-for-snippet() {
	git rev-list --abbrev-commit --all | xargs git grep -F "$1"
}

# Go to root folder, checkout branch, and pull: $1=BRANCH (default: master or main)
start() {
	cd "$(git rev-parse --show-toplevel)" || return 1
	if [[ -n "$1" ]]; then
		git checkout "$1"
	else
		git checkout master || git checkout main
	fi
	git pull
}

# Squash last n commits, keeping the first commit's message: $1=NUM_TO_SQUASH
squash() {
	local n="${1:-2}"
	if [ "$n" -lt 2 ]; then
		echo "Error: Need at least 2 commits to squash"
		return 1
	fi
	# Get the main message from the oldest commit being squashed
	local message
	message=$(git log --format=%B -n 1 "HEAD~$((n - 1))")
	# Collect all trailers (Co-authored-by, etc.) from commits being squashed
	local trailers
	trailers=$(git log --format='%(trailers:key=Co-authored-by,valueonly)' -n "$n" HEAD | grep -v '^$' | sort -u)
	# Append trailers to message if any exist
	if [[ -n "$trailers" ]]; then
		message="$message"$'\n'
		while IFS= read -r trailer; do
			message="$message"$'\n'"Co-authored-by: $trailer"
		done <<< "$trailers"
	fi
	git reset --soft "HEAD~$n"
	git commit -m "$message"
}

# Undo last commits, while preserving files: $1=NUM_TO_UNDO / default=1
undo-last-commits() {
	git reset --soft "HEAD~${1:-1}"
}

# Wipe last commits: $1=NUM_TO_WIPE / default=1
wipe-last-commits() {
	git reset --hard "HEAD~${1:-1}"
}

# Delete all local changes so that local is the same as remote
wipe-local() {
	local branch
	branch=$(git branch --show-current)
	echo "This will discard ALL local changes and reset to origin/$branch"
	echo -n "Are you sure? [y/N]: "
	read -r confirm
	if [[ "$confirm" =~ ^[Yy]$ ]]; then
		git reset --hard origin/"$branch"
	else
		echo "Aborted"
	fi
}
