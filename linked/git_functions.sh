#!/opt/homebrew/bin/bash

# Some aliases credit: https://github.com/alrra/dotfiles/blob/main/src/git/gitconfig

# Commit with message $1, and push
# A `!` git alias runs with GIT_DIR exported, and GIT_DIR in the environment
# overrides `git -C`. Inside a linked worktree that value is absolute, so every
# `git -C "$other_repo" …` in this file silently acted on the worktree the alias
# was invoked from instead of the directory named — a worktree's branch read as
# its own wherever you pointed it, and `git wt-diff trunk` answered about the
# wrong repository while printing the right path. From a main checkout git sets
# GIT_DIR relative (".git"), which `-C` re-resolves correctly, which is why this
# only ever misbehaved from inside a worktree.
#
# Unset here, at source time, so it covers every function in the file rather
# than needing a line in each. Git aliases already run from the repository
# toplevel, so discovery from the working directory finds the same repository.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE

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
# Reviewing a worktree locally; Claude Code owns the rest. See the README.

# $SETUP is not guaranteed in every environment, hence the fallback.
# shellcheck source=../lib/git.sh
source "${SETUP:-$HOME/projects/setup}/lib/git.sh"

# Creates what `claude --worktree NAME` would, so Claude Code adopts it rather
# than making another. A session must use EnterWorktree instead: `git worktree
# add` writes .git/worktrees, which the sandbox makes read-only.
wt_create() {
	local name="${1:-}" root common dir startref
	[[ -n "$name" ]] || {
		echo "Usage: git wt NAME" >&2
		return 1
	}

	_wt_valid_name "$name" || return 1

	root=$(git rev-parse --show-toplevel 2>/dev/null) || {
		echo "Not in a git repository." >&2
		return 1
	}
	# From a linked worktree, --show-toplevel would nest the new one under it.
	common=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null) &&
		root="${common%/*}"
	dir="$root/.claude/worktrees/$name"

	if [[ -e "$dir" ]]; then
		echo "Reusing $dir" >&2
		printf '%s' "$dir"
		return 0
	fi

	startref=$(git_worktree_base_ref "$root") || {
		echo "Cannot resolve a base to cut from." >&2
		return 1
	}

	# No upstream, so a later bare push cannot reach the default branch.
	git -C "$root" worktree add --quiet --no-track -b "$name" "$dir" "$startref" >&2 || return 1
	echo "Created $dir on $name, cut from $startref" >&2
	printf '%s' "$dir"
}

# Claude Code's rule, plus "." and ".." — they pass the charset and name
# directories that already exist.
_wt_valid_name() {
	case "/$1/" in
	*/./* | */../*) ;;
	*)
		[[ "$1" =~ ^[A-Za-z0-9._-]+(/[A-Za-z0-9._-]+)*$ ]] && return 0
		;;
	esac
	echo "Invalid worktree name: $1" >&2
	echo "Use letters, digits, dots, underscores and dashes." >&2
	return 1
}

# awk rather than a shell loop: a `git` alias runs under sh, where `< <(...)`
# is a syntax error and a pipe into `while` puts the result in a subshell.
_wt_path_for_branch() {
	git worktree list --porcelain 2>/dev/null |
		awk -v want="refs/heads/$1" '
			/^worktree / { path = substr($0, 10) }
			$0 == ("branch " want) { print path; found = 1; exit }
			END { exit !found }
		'
}

# Once an agent has committed, `git status` is empty and the question becomes
# what the branch does that its base does not: base, commits, diffstat.
#
# Stamps refs/review/<branch> at the reviewed tip, so a second run range-diffs
# only what changed since the last look, amends and rebases included.
wt_review() {
	local want="${1:-}" wtdir branch basref wtbase mb stamp prev
	local -a open_cmd=()

	local here target arg_base
	here=$(git rev-parse --show-toplevel 2>/dev/null) || {
		echo "Not in a git repository." >&2
		return 1
	}
	target=$(_wt_target "$want" "$here") || {
		echo "'$want' is neither a branch checked out in a worktree nor a ref." >&2
		echo "git worktree list shows the worktrees." >&2
		return 1
	}
	wtdir="${target%%$'\t'*}"
	arg_base="${target#*$'\t'}"
	if [[ -n "$arg_base" ]]; then
		[[ -n "$baseref" ]] || baseref="$arg_base"
		printf 'Reading "%s" as the base; no linked worktree has it checked out.\n' "$want"
	fi

	branch=$(git -C "$wtdir" branch --show-current 2>/dev/null)
	[[ -n "$branch" ]] || {
		echo "Detached HEAD in $wtdir — nothing to compare." >&2
		return 1
	}

	basref=$(git_worktree_base_ref "$wtdir") || {
		wtbase=$(git_worktree_base "$wtdir" || echo "<unset>")
		echo "No ref to compare against: neither origin/$wtbase nor $wtbase exists." >&2
		return 1
	}
	mb=$(git -C "$wtdir" merge-base "$basref" HEAD 2>/dev/null) || {
		echo "Cannot find a merge base between $basref and $branch." >&2
		return 1
	}

	printf '%s\n' "$wtdir"
	printf 'branch %s  ·  base %s\n\n' "$branch" "$basref"

	printf 'Commits:\n'
	git -C "$wtdir" --no-pager log --oneline --no-decorate "$mb..HEAD" | sed 's/^/  /'
	printf '\nFiles:\n'
	git -C "$wtdir" --no-pager diff --stat "$mb..HEAD" | sed 's/^/  /'

	# Unreviewed but outside the branch comparison, so called out separately.
	if [[ -n "$(git -C "$wtdir" status --porcelain 2>/dev/null | head -c1)" ]]; then
		printf '\nUncommitted (not in the commits above):\n'
		git -C "$wtdir" --no-pager status --short | sed 's/^/  /'
	fi

	stamp="refs/review/$branch"
	prev=$(git -C "$wtdir" rev-parse --verify --quiet "$stamp") || prev=""
	if [[ -n "$prev" && "$prev" != "$(git -C "$wtdir" rev-parse HEAD)" ]]; then
		printf '\nSince your last review:\n'
		git -C "$wtdir" --no-pager range-diff --no-color "$mb..$prev" "$mb..HEAD" 2>/dev/null |
			sed 's/^/  /'
	fi
	# Best effort: the shared .git is read-only to a session in the main clone.
	git -C "$wtdir" update-ref "$stamp" HEAD 2>/dev/null ||
		echo "(could not stamp $stamp — run from the worktree to enable 'since last review')" >&2

	printf '\nFull diff:  git -C %s diff %s...HEAD\n' "$wtdir" "$basref"

	local cmd="${WT_OPEN_CMD-code}"
	if [[ -n "$cmd" ]]; then
		read -r -a open_cmd <<<"$cmd"
		command -v "${open_cmd[0]}" >/dev/null 2>&1 &&
			{ "${open_cmd[@]}" "$wtdir" >/dev/null 2>&1 || true; }
	fi
}

# The answer to "I opened the worktree and saw no diff": once an agent has
# committed, the tree is clean, so the comparison that matters is
# branch-against-base.
#
# One unified diff by default: `code --diff` reuses the window and editor group,
# so past a couple of files --tabs collapses into one visible diff. A patch also
# carries deletions and renames.
wt_diff() {
	local want="" baseref="" mode="patch"
	local wtdir branch mb tmp list count f dir cmd out untracked

	while [[ $# -gt 0 ]]; do
		case "$1" in
		--base)
			baseref="${2:-}"
			[[ -n "$baseref" ]] || {
				echo "--base needs a ref" >&2
				return 1
			}
			shift 2
			;;
		--base=*)
			baseref="${1#--base=}"
			shift
			;;
		--tabs)
			mode="tabs"
			shift
			;;
		--patch)
			mode="patch"
			shift
			;;
		-*)
			echo "wt_diff: unknown option $1" >&2
			return 1
			;;
		*)
			want="$1"
			shift
			;;
		esac
	done

	local max="${WT_DIFF_MAX:-25}"
	local -a open_cmd=()

	local here target arg_base
	here=$(git rev-parse --show-toplevel 2>/dev/null) || {
		echo "Not in a git repository." >&2
		return 1
	}
	target=$(_wt_target "$want" "$here") || {
		echo "'$want' is neither a branch checked out in a worktree nor a ref." >&2
		echo "git worktree list shows the worktrees." >&2
		return 1
	}
	wtdir="${target%%$'\t'*}"
	arg_base="${target#*$'\t'}"
	if [[ -n "$arg_base" ]]; then
		[[ -n "$baseref" ]] || baseref="$arg_base"
		printf 'Reading "%s" as the base; no linked worktree has it checked out.\n' "$want"
	fi
	if [[ -z "$want" || -n "$arg_base" ]]; then
		# Without this, a bare run in a main checkout diffed the checkout against
		# its own upstream and reported "no files differ", reading as an empty
		# branch rather than the wrong question.
		if [[ "$(git -C "$wtdir" rev-parse --absolute-git-dir 2>/dev/null)" == "$(git -C "$wtdir" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)" ]]; then
			echo "⚠ $wtdir is the main checkout, not a worktree." >&2
			echo "  Naming one is probably what you meant: git wt-diff BRANCH  (git worktree list shows them)" >&2
		fi
	fi

	branch=$(git -C "$wtdir" branch --show-current 2>/dev/null)

	if [[ -z "$baseref" ]]; then
		# The main clone's branch is what the work merges into, so defaulting to
		# it leaves the common case needing no flag. Falls back to the remote
		# default when that is detached, unreadable, or this checkout itself,
		# which would otherwise compare the branch to itself.
		local common main_root main_branch=""
		common=$(git -C "$wtdir" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)
		if [[ -n "$common" ]]; then
			main_root="${common%/*}"
			main_branch=$(git -C "$main_root" rev-parse --abbrev-ref HEAD 2>/dev/null)
		fi
		if [[ -n "$main_branch" && "$main_branch" != "HEAD" && "$main_branch" != "$branch" ]]; then
			baseref="$main_branch"
		else
			baseref=$(git_worktree_base_ref "$wtdir")
		fi
	fi
	git -C "$wtdir" rev-parse --verify --quiet "$baseref" >/dev/null || {
		echo "No such ref: $baseref" >&2
		return 1
	}

	# The merge base, not the tip: that would also show, inverted, everything
	# the base gained since this branch was cut.
	mb=$(git -C "$wtdir" merge-base "$baseref" HEAD 2>/dev/null) || {
		echo "Cannot find a merge base between $baseref and ${branch:-HEAD}." >&2
		return 1
	}

	# `git diff` reports only tracked paths, so files an agent created but never
	# staged would otherwise be missing — the exact case this exists for.
	untracked=$(git -C "$wtdir" ls-files --others --exclude-standard 2>/dev/null)
	list=$(
		git -C "$wtdir" diff --name-only --diff-filter=ACMRTUXB "$mb" 2>/dev/null
		printf '%s\n' "$untracked"
	)
	list=$(printf '%s\n' "$list" | awk 'NF && !seen[$0]++')

	cmd="${WT_OPEN_CMD-code}"
	if [[ -n "$cmd" ]]; then
		read -r -a open_cmd <<<"$cmd"
		command -v "${open_cmd[0]}" >/dev/null 2>&1 || {
			echo "⚠ ${open_cmd[0]} is not on PATH — writing the diff without opening it." >&2
			open_cmd=()
		}
	fi

	tmp=$(mktemp -d "${TMPDIR:-/tmp}/wt-diff-${branch//\//-}.XXXXXX") || return 1

	if [[ "$mode" == patch ]]; then
		out="$tmp/${branch//\//-}-vs-${baseref//\//-}.diff"
		# Body first: a header written unconditionally made the no-difference
		# case emit a patch containing only its own banner.
		{
			git -C "$wtdir" --no-pager diff "$mb" 2>/dev/null
			# Untracked files as additions, so nothing is silently absent.
			while IFS= read -r f; do
				[[ -n "$f" ]] || continue
				git -C "$wtdir" --no-pager diff --no-index -- /dev/null "$f" 2>/dev/null || true
			done <<<"$untracked"
		} >"$out.body"

		if [[ ! -s "$out.body" ]]; then
			echo "No differences between $baseref and ${branch:-HEAD}."
			return 0
		fi

		{
			printf '# %s\n# base %s (merge-base %s)\n#\n' "$wtdir" "$baseref" "${mb:0:12}"
			git -C "$wtdir" --no-pager diff --stat "$mb" 2>/dev/null | sed 's/^/# /'
			printf '\n'
			cat "$out.body"
		} >"$out"
		printf '%s\n' "$out"
		git -C "$wtdir" --no-pager diff --stat "$mb" 2>/dev/null | tail -1
		((${#open_cmd[@]})) && { "${open_cmd[@]}" "$out" >/dev/null 2>&1 || true; }
		return 0
	fi

	# --tabs
	if [[ -z "$list" ]]; then
		echo "No files differ between $baseref and ${branch:-HEAD}."
		return 0
	fi
	count=$(printf '%s\n' "$list" | wc -l | tr -d ' ')
	if ((count > max)); then
		printf '%s changed files — more than WT_DIFF_MAX (%s).\n' "$count" "$max" >&2
		printf 'Drop --tabs for one scrollable patch instead, or raise WT_DIFF_MAX.\n' >&2
		return 1
	fi
	if ((count > 3)) && ((${#open_cmd[@]})); then
		printf '⚠ %s tabs: `code --diff` reuses the editor group, so some of these\n' "$count" >&2
		printf '  may replace each other rather than stack. Drop --tabs if so.\n' >&2
	fi

	printf 'base %s  ·  %s file(s)  ·  left side under %s\n' "$baseref" "$count" "$tmp"
	while IFS= read -r f; do
		[[ -n "$f" ]] || continue
		dir="$tmp/$(dirname "$f")"
		mkdir -p "$dir"
		git -C "$wtdir" show "$mb:$f" >"$tmp/$f" 2>/dev/null || : >"$tmp/$f"
		printf '  %s\n' "$f"
		if ((${#open_cmd[@]})); then
			"${open_cmd[@]}" --diff "$tmp/$f" "$wtdir/$f" >/dev/null 2>&1 || true
		fi
	done <<<"$list"

	local deleted
	deleted=$(git -C "$wtdir" diff --name-only --diff-filter=D "$mb" 2>/dev/null)
	if [[ -n "$deleted" ]]; then
		printf '\nDeleted by this branch (no tab opened — a patch shows these properly):\n'
		printf '%s\n' "$deleted" | sed 's/^/  - /'
	fi
}

# Whether a bare argument names a worktree to inspect or a ref to compare
# against: "<dir>TAB<base>", base empty when it chose a worktree.
#
# Taken as a selector, `git wt-browse trunk` pointed at the main clone, since
# that is where trunk is checked out, and reported on *that* directory. So an
# argument selects a worktree only when its branch is checked out in a *linked*
# worktree; anything else that resolves as a ref is the base.
_wt_target() {
	local arg="$1" here="$2" path gitdir common
	if [[ -z "$arg" ]]; then
		printf '%s\t' "$here"
		return 0
	fi
	if path=$(_wt_path_for_branch "$arg") && [[ -n "$path" ]]; then
		gitdir=$(git -C "$path" rev-parse --absolute-git-dir 2>/dev/null)
		common=$(git -C "$path" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)
		if [[ -n "$gitdir" && "$gitdir" != "$common" ]]; then
			printf '%s\t' "$path"
			return 0
		fi
	fi
	if git -C "$here" rev-parse --verify --quiet "$arg" >/dev/null 2>&1; then
		printf '%s\t%s' "$here" "$arg"
		return 0
	fi
	return 1
}

# Browse a worktree as if nothing on the branch had been committed.
#
# A mixed reset moves HEAD to the base and leaves the working tree alone, so the
# branch's changes read as uncommitted and the editor's gutters mark them, which
# a patch in a tab cannot do. Ending it resets forward, also mixed, so the
# commits return and any fix made while reading stays uncommitted on top.
#
# The original tip goes to refs/wt-browse/<branch> first — a real ref, so it
# survives reflog expiry. The status line shows ⚠ BROWSE while it exists,
# because the worktree then looks like a branch with no commits, and a
# `git commit -a` there would flatten its history into one commit.
wt_browse() {
	local want="" baseref="" ending=0
	local wtdir branch stamp orig mb common main_root main_branch cmd
	local -a open_cmd=()

	while [[ $# -gt 0 ]]; do
		case "$1" in
		--end | --restore)
			ending=1
			shift
			;;
		--base)
			baseref="${2:-}"
			shift 2
			;;
		--base=*)
			baseref="${1#--base=}"
			shift
			;;
		-*)
			echo "wt_browse: unknown option $1" >&2
			return 1
			;;
		*)
			want="$1"
			shift
			;;
		esac
	done

	local here target arg_base
	here=$(git rev-parse --show-toplevel 2>/dev/null) || {
		echo "Not in a git repository." >&2
		return 1
	}
	target=$(_wt_target "$want" "$here") || {
		echo "'$want' is neither a branch checked out in a worktree nor a ref." >&2
		echo "git worktree list shows the worktrees." >&2
		return 1
	}
	wtdir="${target%%$'\t'*}"
	arg_base="${target#*$'\t'}"
	if [[ -n "$arg_base" ]]; then
		[[ -n "$baseref" ]] || baseref="$arg_base"
		printf 'Reading "%s" as the base; no linked worktree has it checked out.\n' "$want"
	fi

	branch=$(git -C "$wtdir" branch --show-current 2>/dev/null)
	[[ -n "$branch" ]] || {
		echo "Detached HEAD in $wtdir — nothing to browse." >&2
		return 1
	}
	# "/" flattened so a branch named a/b cannot collide with a ref for a.
	stamp="refs/wt-browse/${branch//\//-}"
	orig=$(git -C "$wtdir" rev-parse --verify --quiet "$stamp") || orig=""

	if ((ending)); then
		[[ -n "$orig" ]] || {
			echo "$branch is not in review mode (no $stamp)." >&2
			return 1
		}
		git -C "$wtdir" reset --mixed "$orig" >/dev/null || {
			echo "Could not reset $branch back to $orig." >&2
			return 1
		}
		git -C "$wtdir" update-ref -d "$stamp" 2>/dev/null || true
		printf 'Review mode ended. %s is back at %.12s\n' "$branch" "$orig"
		local left
		left=$(git -C "$wtdir" status --porcelain 2>/dev/null | head -c1)
		[[ -n "$left" ]] && printf 'Edits you made while reading are still uncommitted — see git -C %s status\n' "$wtdir"
		return 0
	fi

	[[ -z "$orig" ]] || {
		echo "$branch is already in review mode (from ${orig:0:12})." >&2
		echo "End it with: git wt-browse ${want:+$want }--end" >&2
		return 1
	}

	# After the reset this would be indistinguishable from the branch's own
	# changes, leaving no way to end review mode without guessing.
	if [[ -n "$(git -C "$wtdir" status --porcelain 2>/dev/null | head -c1)" ]]; then
		echo "$wtdir has uncommitted changes." >&2
		echo "Commit or stash them first: after the reset they cannot be told apart" >&2
		echo "from the branch's own changes, which would make ending review mode unsafe." >&2
		return 1
	fi

	if [[ -z "$baseref" ]]; then
		common=$(git -C "$wtdir" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)
		if [[ -n "$common" ]]; then
			main_root="${common%/*}"
			main_branch=$(git -C "$main_root" rev-parse --abbrev-ref HEAD 2>/dev/null)
		fi
		if [[ -n "${main_branch:-}" && "$main_branch" != "HEAD" && "$main_branch" != "$branch" ]]; then
			baseref="$main_branch"
		else
			baseref=$(git_worktree_base_ref "$wtdir")
		fi
	fi
	git -C "$wtdir" rev-parse --verify --quiet "$baseref" >/dev/null || {
		echo "No such ref: $baseref" >&2
		return 1
	}

	mb=$(git -C "$wtdir" merge-base "$baseref" HEAD 2>/dev/null) || {
		echo "Cannot find a merge base between $baseref and $branch." >&2
		return 1
	}
	if [[ "$mb" == "$(git -C "$wtdir" rev-parse HEAD)" ]]; then
		echo "$branch has no commits beyond $baseref — nothing to browse."
		return 0
	fi

	git -C "$wtdir" update-ref "$stamp" HEAD || {
		echo "Could not record the current tip at $stamp — refusing to reset." >&2
		return 1
	}
	git -C "$wtdir" reset --mixed "$mb" >/dev/null || {
		git -C "$wtdir" update-ref -d "$stamp" 2>/dev/null || true
		echo "Reset failed; nothing changed." >&2
		return 1
	}

	printf '%s\n' "$wtdir"
	printf 'Review mode: %s now reads as uncommitted work against %s.\n' "$branch" "$baseref"
	git -C "$wtdir" --no-pager diff --stat HEAD 2>/dev/null | tail -1
	# `diff --stat` counts only tracked paths, and "2 files changed" where three
	# differ reads as something missed.
	local n_untracked
	n_untracked=$(git -C "$wtdir" ls-files --others --exclude-standard 2>/dev/null | wc -l | tr -d ' ')
	((n_untracked)) && printf ' plus %s untracked file(s) the branch added\n' "$n_untracked"
	printf 'Browse the tree; the source-control view and gutters mark every change.\n'
	printf 'Put the commits back with:  git wt-browse %s--end\n' "${want:+$want }"

	_wt_window --add "$wtdir" >/dev/null 2>&1 || true
}

# --add/--remove a worktree as a window root. WT_OPEN_CMD overrides the editor.
_wt_window() {
	local flag="$1" wtdir="$2" cmd
	local -a open_cmd=()

	cmd="${WT_OPEN_CMD-code}"
	[[ -n "$cmd" ]] || return 0
	read -r -a open_cmd <<<"$cmd"
	((${#open_cmd[@]})) || return 0
	command -v "${open_cmd[0]}" >/dev/null 2>&1 || {
		echo "⚠ ${open_cmd[0]} is not on PATH — $wtdir unchanged in the editor." >&2
		return 1
	}
	"${open_cmd[@]}" "$flag" "$wtdir"
}

_wt_dir_for() {
	local want="${1:-}" dir
	if [[ -n "$want" ]]; then
		dir=$(_wt_path_for_branch "$want")
		[[ -n "$dir" ]] || {
			echo "No worktree has '$want' checked out." >&2
			echo "git worktree list shows the worktrees." >&2
			return 1
		}
	else
		dir=$(git rev-parse --show-toplevel 2>/dev/null) || {
			echo "Not in a git repository." >&2
			return 1
		}
	fi
	printf '%s' "$dir"
}

# The review entry point after a fan-out: a source-control section per agent.
wt_open() {
	local wtdir
	wtdir=$(_wt_dir_for "${1:-}") || return 1
	_wt_window --add "$wtdir" || return 1
	printf 'Added %s\n' "$wtdir"
}

wt_close() {
	local wtdir
	wtdir=$(_wt_dir_for "${1:-}") || return 1
	_wt_window --remove "$wtdir" || return 1
	printf 'Removed %s from the window\n' "$wtdir"
}
