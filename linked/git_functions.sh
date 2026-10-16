#!/opt/homebrew/bin/bash

# Some aliases credit: https://github.com/alrra/dotfiles/blob/main/src/git/gitconfig

# Commit with message $1, and push
commit() {
	git commit -v -m "$1" && git push
}

# Add all files in current directory, commit with message $1, and push
commit_all() {
	git add .
	commit "$1"
}

# Amend last commit to credit co-author: $1=name, $2=email
credit() {
	if [ "$1" != "" ] && [ "$2" != "" ]; then
		GIT_EDITOR="git interpret-trailers --in-place --trailer='Co-authored-by: $1 <$2>'" git commit --amend
	fi
}

# Delete all local branches other than current
delete_branches() {
	# ^* is regex matching the literal * that git uses to mark the current branch
	local branches
	# shellcheck disable=SC2063 # Literal * is intentional, not a glob
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

# Interactive rebase. $1=STEPS_BACK_FROM_HEAD / default=10
interactive_rebase() {
	local DISTANCE
	local COMMIT_COUNT
	COMMIT_COUNT=$(git rev-list --count HEAD 2>/dev/null)
	# Set $DISTANCE to $1 if it's a number, otherwise default to 10
	if [ "$1" != "" ] && [ "$1" -eq "$1" ] 2>/dev/null; then
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

# The clone's own exclude file, shared by all its worktrees. --git-common-dir is
# asked of git rather than built from --show-toplevel because a linked worktree's
# git entry is a *file*, which no path can descend through; it resolves to the
# main clone's git directory from anywhere in the repo, so every worktree writes
# to the one file, which is what "only on this clone" means.
_local_exclude_file() {
	local gitdir
	gitdir=$(git rev-parse --path-format=absolute --git-common-dir) || return 1
	mkdir -p "$gitdir/info" || return 1
	printf '%s' "$gitdir/info/exclude"
}

# Ignore $1 as if in .gitignore, but only on this clone of the repo
local_ignore() {
	local exclude
	exclude=$(_local_exclude_file) || return 1
	echo "$1" >>"$exclude"
}

# Edit the Git file that ignores files only within this clone of the repo
local_ignore_edit() {
	local exclude
	exclude=$(_local_exclude_file) || return 1
	vim "$exclude"
}

# Run git pull on all git repos that are nested under the current directory
pull_all() {
	fd --type d --hidden '^\.git$' --exec sh -c 'cd {//} && echo "Pulling: ${PWD##*/}" && git pull'
}

# Rename a branch locally and remote. $1=OLD_NAME, $2=NEW_NAME
# Credit: https://gist.github.com/DamirPorobic/5be1a47d11c2c7444ddb171d19b4919e
rename_branch() {
	# Check if the user has provided input
	if [ $# -ne 2 ]; then
		echo "usage: git rename-branch OLD_BRANCH_NAME NEW_BRANCH_NAME"
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
		echo "⚠ No remote tracking branch for $old_name, renaming locally only"
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
reset_to_origin() {
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
search_for_commits() {
	git log --date=short --decorate --pretty=colorful -S"$1"
}

# Search commits by commit message: $1=COMMIT_MESSAGE
search_for_message() {
	git log --date=short --decorate --pretty=colorful --grep="$1"
}

# Search for snippet in history: $1=SNIPPET
search_for_snippet() {
	git rev-list --abbrev-commit --all | xargs git grep -F "$1"
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
		done <<<"$trailers"
	fi
	git reset --soft "HEAD~$n"
	git commit -m "$message"
}

# Undo last commits, while preserving files: $1=NUM_TO_UNDO / default=1
undo_last_commits() {
	git reset --soft "HEAD~${1:-1}"
}

# Wipe last commits: $1=NUM_TO_WIPE / default=1
wipe_last_commits() {
	git reset --hard "HEAD~${1:-1}"
}

# Delete all local changes so that local is the same as remote
wipe_local() {
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

# ------------------------------------------------------------------------------------ #
#                                     Worktrees
# ------------------------------------------------------------------------------------ #
#
# The ~/work mirror is addressable: a GitLab path maps straight onto a filesystem
# path, which is what makes it usable as an LLM context corpus. Worktrees would
# break that if they landed inside the clones, so they go in a parallel tree that
# mirrors the same structure:
#
#   ~/work/<gitlab-path>                    main clone, tracks develop/main
#   ~/work/.worktrees/<gitlab-path>/<slug>  one directory per active branch
#
# <slug> is the branch name with "/" replaced by "-".
#
# Claude Code's WorktreeCreate/WorktreeRemove hooks call wt_hook_create and
# wt_hook_remove, so `claude --worktree` and worktree-isolated subagents land here
# too rather than in <repo>/.claude/worktrees/. Repos outside ~/work keep Claude
# Code's default location — see wt_hook_create.

# git_default_branch. $SETUP is not guaranteed in a hook environment, hence the
# fallback.
# shellcheck source=../lib/git.sh
source "${SETUP:-$HOME/projects/setup}/lib/git.sh"

# Root of the parallel worktree tree
_wt_root() {
	printf '%s' "$HOME/work/.worktrees"
}

# Branch name -> directory name, always exactly one path component. Replacing "/"
# keeps a name from the hook payload inside its repo's slot, since every way out
# of a directory needs a separator. "." and ".." need the prefix on top, because
# they survive that substitution and name directories that already exist.
_wt_slug() {
	local slug
	slug=$(printf '%s' "$1" | tr '/' '-')
	case "$slug" in
	. | ..) slug="wt-$slug" ;;
	esac
	printf '%s' "$slug"
}

# Branch new worktrees are cut from, for $1=DIRECTORY (default: cwd). Repos whose
# real trunk is not what git_default_branch guesses — it prefers origin/develop,
# then origin/main — set it per repo:
#
#     git config --local worktree.base trunk
#
# Deliberately scoped to worktrees: sync_repo.sh keeps using git_default_branch,
# so overriding this does not change which branch the main clone fast-forwards.
#
# worktree.base is the only base-ref control that reaches the WorktreeCreate
# hook. Claude Code's own worktreeBaseRef ("fresh" | "head") cannot: the hook
# owns worktree creation, and the payload on stdin does not carry the setting, so
# honouring it would mean reimplementing Claude Code's settings cascade in bash.
# _wt_add names the ref it used, so the choice is never silent.
_wt_base() {
	local dir="${1:-.}" base
	base=$(git -C "$dir" config --get worktree.base 2>/dev/null)
	if [[ -n "$base" ]]; then
		printf '%s' "$base"
	else
		git_default_branch "$dir"
	fi
}

# Root of the main clone, from anywhere in the repo — including a linked
# worktree, where --show-toplevel would report that worktree instead and nest the
# next one underneath it. --git-common-dir resolves to the main clone's git
# directory from every worktree of the repo, and its parent is the main clone.
#
# Requires git 2.31 for --path-format, as wt_hook_remove already does. Fails
# outside a repo, and for a bare repo, which has no working tree to mirror.
_wt_main_root() {
	local gitdir common top
	gitdir=$(git rev-parse --path-format=absolute --absolute-git-dir 2>/dev/null) || return 1
	common=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || return 1
	if [[ "$gitdir" == "$common" ]]; then
		# The main clone itself: ask git for the working tree rather than deriving
		# it, so a --separate-git-dir clone is not mistaken for its git directory's
		# neighbour
		top=$(git rev-parse --show-toplevel 2>/dev/null) || return 1
		[[ -n "$top" ]] || return 1
		printf '%s' "$top"
	else
		printf '%s' "${common%/*}"
	fi
}

# Path of the main clone relative to ~/work. Fails if not in the mirror.
_wt_repo_rel() {
	local root
	root=$(_wt_main_root) || return 1
	case "$root" in
	"$HOME/work/"*) printf '%s' "${root#"$HOME"/work/}" ;;
	*) return 1 ;;
	esac
}

# Commits on HEAD that are not on the remote yet, for $1=WORKTREE_DIRECTORY.
# New branches are created --no-track, so @{upstream} is usually absent until the
# first push and we have to fall back to comparing against the base branch. It has
# to be the same ref _wt_add branched from, or every commit between the base and
# git_default_branch's guess is miscounted as unpushed work.
_wt_unpushed_count() {
	local dir="$1" count base
	count=$(git -C "$dir" rev-list --count '@{upstream}..HEAD' 2>/dev/null)
	if [[ -z "$count" ]]; then
		base=$(_wt_base "$dir")
		[[ -n "$base" ]] &&
			count=$(git -C "$dir" rev-list --count "origin/$base..HEAD" 2>/dev/null)
	fi
	printf '%s' "${count:-0}"
}

# Worktree directory for a branch in the current repo: $1=BRANCH
_wt_path() {
	local rel
	rel=$(_wt_repo_rel) || return 1
	printf '%s/%s/%s' "$(_wt_root)" "$rel" "$(_wt_slug "$1")"
}

# Copy gitignored config into a new worktree. A WorktreeCreate hook replaces git's
# own logic, so Claude Code never reads .worktreeinclude itself — this stands in
# for it, honouring the repo's .worktreeinclude when there is one and falling back
# to the usual env files when there is not.
# $1=SOURCE_WORKTREE, $2=NEW_WORKTREE
_wt_copy_local_files() {
	local src="$1" dst="$2" entry paths=()

	if [[ -f "$src/.worktreeinclude" ]]; then
		while IFS= read -r entry || [[ -n "$entry" ]]; do
			entry="${entry%%#*}"                       # strip comments
			entry="${entry#"${entry%%[![:space:]]*}"}" # trim leading space
			entry="${entry%"${entry##*[![:space:]]}"}" # trim trailing space
			[[ -n "$entry" ]] && paths+=("${entry%/}")
		done <"$src/.worktreeinclude"
	else
		paths=(.env .env.local .envrc)
	fi

	for entry in "${paths[@]}"; do
		# Absolute paths and .. would write outside the new worktree
		case "$entry" in
		/* | *..*) continue ;;
		esac
		[[ -e "$src/$entry" && ! -e "$dst/$entry" ]] || continue
		mkdir -p "$(dirname "$dst/$entry")" 2>/dev/null
		# -c clones on APFS, so a 758M terraform/.terraform costs no disk and no
		# wait. Plain -R is the fallback where clonefile is unavailable.
		cp -Rc "$src/$entry" "$dst/$entry" 2>/dev/null ||
			cp -R "$src/$entry" "$dst/$entry" 2>/dev/null
	done
	return 0
}

# Create a worktree at an explicit path. $1=DIRECTORY, $2=BRANCH
# Progress goes to stderr so callers can capture the path from stdout.
#
# NOTE: worktree directories are held in `wtdir`, never `path` — zsh ties `path`
# to $PATH, so `local path` empties PATH for the rest of the function.
_wt_add() {
	local wtdir="$1" branch="$2" base_branch src

	# Already there: reuse it, so re-running is cheap and idempotent
	if [[ -d "$wtdir" ]]; then
		echo "Worktree already exists: $wtdir" >&2
		printf '%s\n' "$wtdir"
		return 0
	fi

	# Pick up any new remote branches before deciding how to create this one
	git fetch --quiet origin >/dev/null 2>&1
	# Resolved after the fetch so a newly created remote base is visible
	base_branch=$(_wt_base)

	# The *current* worktree, deliberately, unlike _wt_repo_rel: local config is
	# copied from wherever the session is working, which is also where the
	# .worktreeinclude for this branch lives
	src=$(git rev-parse --show-toplevel 2>/dev/null)
	if git show-ref --verify --quiet "refs/heads/$branch"; then
		# Git already refuses a second checkout, naming the worktree that holds it
		git worktree add --quiet "$wtdir" "$branch" >&2 || return 1
	elif git show-ref --verify --quiet "refs/remotes/origin/$branch"; then
		# Track the existing remote branch
		git worktree add --quiet --track -b "$branch" "$wtdir" "origin/$branch" >&2 || return 1
	else
		# New branch from the remote base, matching worktree.baseRef "fresh".
		# --no-track keeps origin/<base> from becoming this branch's upstream,
		# which would break both `git push` and the sync's stale detection.
		local base current
		if [[ -n "$base_branch" ]] && git show-ref --verify --quiet "refs/remotes/origin/$base_branch"; then
			base="origin/$base_branch"
		else
			# No origin to be fresh from (a local-only repo), so branch from here
			base=HEAD
		fi
		# Name the ref this was cut from, and shout when it is not what the calling
		# session has checked out — the case nobody expects, and the one _wt_base
		# cannot avoid. stderr only, since stdout is the created directory.
		current=$(git branch --show-current 2>/dev/null)
		if [[ -n "$current" && "$base" != "$current" && "$base" != "origin/$current" ]]; then
			echo "⚠ $branch is cut from $base, NOT the checked-out $current" >&2
			echo "⚠ Claude Code's worktreeBaseRef does not apply to this hook." \
				"To change the base: git config worktree.base <ref>" >&2
		else
			echo "Branching $branch from $base" >&2
		fi
		git worktree add --quiet --no-track -b "$branch" "$wtdir" "$base" >&2 || return 1
	fi

	[[ -n "$src" ]] && _wt_copy_local_files "$src" "$wtdir"
	printf '%s\n' "$wtdir"
}

# Create (or reuse) a worktree for a branch in the current mirror repo.
# Prints the path to stdout; `git wt` in shell_functions.sh cds into it.
# $1=BRANCH
wt_create() {
	local branch="${1:?usage: git wt BRANCH}" wtdir default
	if ! git rev-parse --show-toplevel >/dev/null 2>&1; then
		echo "Not in a git repository" >&2
		return 1
	fi
	if ! wtdir=$(_wt_path "$branch"); then
		echo "Not in the ~/work mirror — use git worktree add directly" >&2
		return 1
	fi

	# The main clone owns the default branch. sync_repo.sh fast-forwards it with
	# `git branch -f`, which git refuses for a branch checked out anywhere else.
	default=$(git_default_branch)
	case "$branch" in
	main | master | develop | "$default")
		echo "Refusing to worktree $branch — the main clone owns the default branch" >&2
		return 1
		;;
	esac

	_wt_add "$wtdir" "$branch"
}

# Remove a worktree and its branch: $1=BRANCH
# Warns about work that will be lost but does not stop, matching `git bdr`.
wt_remove() {
	local branch="${1:?usage: git wt-rm BRANCH}" wtdir root d ahead
	wtdir=$(_wt_path "$branch") || {
		echo "Not in the ~/work mirror" >&2
		return 1
	}
	if [[ ! -d "$wtdir" ]]; then
		echo "No worktree at $wtdir" >&2
		return 1
	fi

	if [[ -n "$(git -C "$wtdir" status --porcelain 2>/dev/null)" ]]; then
		echo "⚠ Discarding uncommitted changes in $wtdir" >&2
	fi
	ahead=$(_wt_unpushed_count "$wtdir")
	if [[ "$ahead" != "0" ]]; then
		echo "⚠ Discarding $ahead unpushed commit(s) on $branch" >&2
	fi

	git worktree remove --force "$wtdir" || return 1
	git branch -D "$branch" 2>/dev/null

	# Tidy the scaffolding this worktree needed, but never climb past .worktrees
	root=$(_wt_root)
	d=$(dirname "$wtdir")
	while [[ "$d" != "$root" && "$d" != "/" && -n "$d" ]]; do
		rmdir "$d" 2>/dev/null || break
		d=$(dirname "$d")
	done
	echo "Removed worktree $wtdir" >&2
}

# Every worktree in the mirror — the "what am I working on" view.
# Reads the parallel tree directly instead of asking 360 repos.
wt_list_all() {
	local root out
	root=$(_wt_root)
	if [[ ! -d "$root" ]]; then
		echo "No worktrees."
		return 0
	fi
	# A linked worktree's git entry is a file, not a directory — that is also why
	# the sync's `fd --type d '^\.git$'` scan never mistakes one for a repo.
	out=$(fd --hidden --no-ignore --max-depth 8 --type f '^\.git$' "$root" 2>/dev/null |
		sed 's|/[^/]*$||' | sort | while IFS= read -r d; do
		local branch dirty ahead
		branch=$(git -C "$d" branch --show-current 2>/dev/null)
		[[ -n "$branch" ]] || continue
		dirty=""
		[[ -n "$(git -C "$d" status --porcelain 2>/dev/null)" ]] && dirty=" [dirty]"
		ahead=$(_wt_unpushed_count "$d")
		[[ "$ahead" != "0" ]] && dirty="$dirty [+$ahead]"
		printf '%s  →  %s%s\n' "${d#"$root"/}" "$branch" "$dirty"
	done)
	if [[ -z "$out" ]]; then
		echo "No worktrees."
	else
		printf '%s\n' "$out"
	fi
}

# WorktreeCreate hook. Reads Claude Code's JSON on stdin and prints the created
# directory on stdout; any non-zero exit fails worktree creation, so repos
# outside the mirror fall back to Claude Code's own default location rather than
# losing worktree support entirely.
wt_hook_create() {
	local input name cwd root rel wtdir
	input=$(cat)
	name=$(printf '%s' "$input" | jq -r '.name // empty' 2>/dev/null)
	cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)

	# Payload (verified against the 2.1.245 binary): the common hook fields
	# session_id / transcript_path / cwd / permission_mode / agent_id, plus
	# hook_event_name and `name` — the requested worktree name. agent_id is set for
	# subagents, if we ever want to file agent worktrees separately.
	if [[ -n "${WT_HOOK_DEBUG:-}" ]]; then
		printf '%s\n' "$input" >>"${TMPDIR:-/tmp}/wt_hook.log"
	fi

	# CLAUDE_PROJECT_DIR stays at the launch directory, so trust cwd instead
	[[ -n "$cwd" && -d "$cwd" ]] && cd "$cwd" || true
	[[ -n "$name" ]] || name="session-$$"

	# The main clone, not the current worktree — a session inside a worktree must
	# still resolve to the one repo path, both for the mirror and for the
	# .claude/worktrees fallback below
	root=$(_wt_main_root) || {
		echo "WorktreeCreate: not in a git repository" >&2
		return 1
	}

	if rel=$(_wt_repo_rel); then
		wtdir="$(_wt_root)/$rel/$(_wt_slug "$name")"
	else
		# Outside ~/work: reproduce Claude Code's default so this hook never makes
		# worktrees worse than not having it
		echo "WorktreeCreate: $root is outside ~/work, using .claude/worktrees" >&2
		wtdir="$root/.claude/worktrees/$(_wt_slug "$name")"
	fi

	_wt_add "$wtdir" "$name"
}

# WorktreeRemove hook. Only ever touches worktrees inside the mirror's parallel
# tree, so a stray path in the payload can never delete real work.
wt_hook_remove() {
	local input wtdir root d branch ahead maindir
	input=$(cat)
	# `worktree_path` is the field this build sends; the others are belt and braces
	wtdir=$(printf '%s' "$input" | jq -r '.worktree_path // .path // .worktree // empty' 2>/dev/null)
	[[ -n "${WT_HOOK_DEBUG:-}" ]] && printf '%s\n' "$input" >>"${TMPDIR:-/tmp}/wt_hook.log"
	[[ -n "$wtdir" && -d "$wtdir" ]] || return 0

	root=$(_wt_root)
	case "$wtdir" in
	"$root"/*) ;;
	*) return 0 ;;
	esac

	# Read these while the worktree still exists
	branch=$(git -C "$wtdir" branch --show-current 2>/dev/null)
	ahead=$(_wt_unpushed_count "$wtdir")
	maindir=$(git -C "$wtdir" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)
	maindir=$(dirname "$maindir")

	git -C "$wtdir" worktree remove --force "$wtdir" 2>/dev/null ||
		git worktree remove --force "$wtdir" 2>/dev/null

	# Unlike `git wt-rm`, this can fire unattended — Claude Code sweeps old
	# worktrees on its own (cleanupPeriodDays). So only drop the branch when it
	# holds nothing origin does not already have; otherwise keep it and say so,
	# leaving it to `git bd` or the sync's stale-branch pass once it merges.
	if [[ -n "$branch" && "$ahead" == "0" ]]; then
		git -C "$maindir" branch -D "$branch" >/dev/null 2>&1
	elif [[ -n "$branch" ]]; then
		echo "Kept branch $branch — it has $ahead unpushed commit(s)" >&2
	fi

	d=$(dirname "$wtdir")
	while [[ "$d" != "$root" && "$d" != "/" && -n "$d" ]]; do
		rmdir "$d" 2>/dev/null || break
		d=$(dirname "$d")
	done
	return 0
}
