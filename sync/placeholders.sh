# shellcheck shell=bash
# Sourced by sync/repos.sh and sync/clone_repo.sh
#
# Placeholder directories for repos that are on GitLab but not cloned here.
#
# With GITLAB_PLACEHOLDERS_ONLY set, the sync clones nothing new and leaves one
# of these at every path it would have cloned into, so ~/work mirrors GitLab's
# structure whether or not a repo was actually taken — which is the point of
# only cloning a few: the tree still tells you where everything lives.
#
# A placeholder is a directory holding nothing but PLACEHOLDER_FILE, and it is
# recognised by PLACEHOLDER_MARKER rather than by that name alone: .gitkeep is a
# convention, and a cloned repo can perfectly well track one of its own.

PLACEHOLDER_FILE=".gitkeep"
PLACEHOLDER_MARKER="# Not cloned - placeholder written by the setup GitLab sync"

# A file that says nothing about whether a directory is being used. Finder writes
# .DS_Store into any directory it is pointed at, and an empty directory in the
# middle of the tree invites a look — so counting it as content would be enough
# to make a placeholder unremovable, and the clone that should replace it fail
# for good on a directory that is not empty. It goes with the directory.
PLACEHOLDER_IGNORED=".DS_Store"

# True when $1 holds nothing that means it is in use: . and .. never count, nor
# does PLACEHOLDER_IGNORED, nor $2 when given.
# Usage: _dir_is_empty <directory> [tolerated_name]
_dir_is_empty() {
	local entry name
	for entry in "$1"/* "$1"/.*; do
		name="${entry##*/}"
		case "$name" in
		. | .. | "$PLACEHOLDER_IGNORED") continue ;;
		esac
		[[ "$name" == "${2:-}" ]] && continue
		# An unmatched glob is left as the pattern itself, which exists as nothing
		[[ -e "$entry" || -L "$entry" ]] && return 1
	done
	return 0
}

# True when directory $1 holds a placeholder this sync wrote. Says nothing about
# whether the repo has since been cloned on top of it — callers that care ask
# about .git themselves, because the two cases want opposite treatment.
_is_placeholder() {
	[[ -f "$1/$PLACEHOLDER_FILE" ]] &&
		grep -qxF "$PLACEHOLDER_MARKER" "$1/$PLACEHOLDER_FILE" 2>/dev/null
}

# Write the placeholder for repo $2 into $1/$2, creating the directory.
# Refuses a directory that already holds anything else: a half-finished clone, a
# stray directory of notes, work kept outside git. Returns 1 in that case, and
# the caller reports the path rather than writing over it.
# Usage: _write_placeholder <repos_dir> <repo_path_relative_to_repos_dir>
_write_placeholder() {
	local dir="$1/$2" rel="$2" group="${GITLAB_GROUP:-<group>}" here tilde='~'
	# ~ for the clone instructions below, which are meant to be pasted
	here="${1/#"$HOME"/"$tilde"}/$2"
	if [[ -d "$dir" ]]; then
		# The name is tolerated only once the file is really one of ours. A
		# .gitkeep written by hand is somebody's work, like any other content,
		# and writing over it would also make it ours to delete later.
		local tolerated=""
		_is_placeholder "$dir" && tolerated="$PLACEHOLDER_FILE"
		_dir_is_empty "$dir" "$tolerated" || return 1
	else
		mkdir -p "$dir" || return 1
	fi
	cat >"$dir/$PLACEHOLDER_FILE" <<EOF
$PLACEHOLDER_MARKER
#
# This repo is on GitLab but is not cloned here, because GITLAB_PLACEHOLDERS_ONLY
# is set. The directory is kept so the tree still mirrors GitLab:
#
#   $rel
#
# git refuses to clone into a directory that is not empty, so to take this one
# repo by hand, clear the placeholder first:
#
#   trash $here/$PLACEHOLDER_FILE && rmdir $here
#   glab repo clone $group/$rel $here
#
# Unset GITLAB_PLACEHOLDERS_ONLY and re-run devenv to clone everything. Either
# way, the next run removes this file once a clone is in its place.
EOF
}

# Drop the placeholder file from $1, leaving the directory itself. For a repo
# cloned since: the clone is what the path means now, and the marker is spent.
#
# trash rather than rm, as everywhere else the sync deletes something: these are
# one-line files the sync wrote itself, but the rule earns more than it costs.
_clear_placeholder() {
	[[ -f "$1/$PLACEHOLDER_FILE" ]] || return 1
	trash "$1/$PLACEHOLDER_FILE" >/dev/null
}

# Remove the placeholder and the directory holding it: for a repo that is no
# longer on GitLab, or to clear the way for a clone.
#
# Emptiness is checked before anything goes, so a directory that picked up
# content keeps its marker and is reported instead of quietly losing half of
# itself. The directory then goes whole, in one move, rather than as a file and
# then an rmdir — one that failed in between would leave a directory no later
# run can recognise, since nothing but the marker makes it a placeholder.
_remove_placeholder() {
	_is_placeholder "$1" || return 1
	_dir_is_empty "$1" "$PLACEHOLDER_FILE" || return 1
	trash "$1" >/dev/null
}
