#!/usr/bin/env bash
# Claude Code status line, two rows:
#
#   ⚠ MERGING │ Opus 5 │ 53% │ $1.42 │ eon-dev │ ⎇ feat/x* +2
#   /Users/nick/work/.worktrees/backend/.../feat-x
#
# The path gets its own row so a deep worktree path is never truncated, and it
# is absolute and unabbreviated on purpose: its job is to be copied into an
# editor, which is the thing that used to have to be asked for every time a
# session moved into a worktree.
#
# Alerts lead, because they change what you should do next: a merge left
# unresolved, or a session holding production credentials.
#
# Every segment is omitted when its source is absent rather than rendered as a
# zero. Bedrock sessions have no `rate_limits` in the payload, and a segment
# reading "5h 0%" would be worse than no segment at all.
#
# This script runs in every session concurrently and must stay stateless: it
# writes no files and keeps nothing between invocations.
#
# Reads the status line JSON on stdin and writes up to two lines to stdout.

set -uo pipefail

input=$(cat 2>/dev/null) || input=""
json() { printf '%s' "$input" | jq -r "$1 // empty" 2>/dev/null; }

SEP=' │ '
alerts=()
parts=()

add() { [[ -n "${1:-}" ]] && parts+=("$1"); }

# ── Working directory ───────────────────────────────────────────────────────
cwd=$(json '.workspace.current_dir')
[[ -n "$cwd" ]] || cwd=$(json '.cwd')
[[ -n "$cwd" && -d "$cwd" ]] || cwd="$PWD"
cd "$cwd" 2>/dev/null || true

# ── Model, context, cost ────────────────────────────────────────────────────
add "$(json '.model.display_name')"

# Remaining rather than used, and from the payload rather than a token count:
# context_window_size is 1M on the [1m] models, so a fixed 200k assumption and
# `exceeds_200k_tokens` both read wrong here.
ctx=$(json '.context_window.remaining_percentage')
[[ -n "$ctx" ]] && add "${ctx}%"

cost=$(json '.cost.total_cost_usd')
if [[ -n "$cost" ]]; then
	cost=$(printf '%.2f' "$cost" 2>/dev/null) || cost=""
	[[ -n "$cost" && "$cost" != "0.00" ]] && add "\$$cost"
fi

# Absent on Bedrock, present on direct-API sessions, so it is read rather than
# assumed either way.
# Labels are mapped rather than derived: ${five_hour%%_*} is "five", so the
# derived form rendered "fiveh" where the header example promises "5h".
for window in five_hour:5h seven_day:7d; do
	pct=$(json ".rate_limits.${window%%:*}.used_percentage")
	[[ -n "$pct" ]] && add "${window##*:} $(printf '%.0f' "$pct" 2>/dev/null)%"
done

# ── AWS target ──────────────────────────────────────────────────────────────
# The granted profile, which is not $AWS_PROFILE: that one is Bedrock-only and
# naming it here would be exactly the confusion CLAUDE.local.md warns about.
# If CLAUDE_AWS_STATE is not in this process's environment the segment is
# dropped rather than guessed — there is no way to pick the right state file
# when several sessions each have one.
if [[ -n "${CLAUDE_AWS_STATE:-}" && -f "$CLAUDE_AWS_STATE" ]]; then
	granted=$(tr -d '[:space:]' <"$CLAUDE_AWS_STATE" 2>/dev/null)
	if [[ -n "$granted" ]]; then
		case "$granted" in
		*prod*) alerts+=("⚠ PROD $granted") ;;
		*) add "$granted" ;;
		esac
	fi
fi

# ── Git ─────────────────────────────────────────────────────────────────────
root=""
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
	# One porcelain=v2 call carries branch, upstream and ahead/behind, and the
	# presence of any entry line answers "dirty". `head` lets git stop early on
	# a repo with thousands of changes; the branch headers come first.
	branch="" ahead="" dirty=""
	while IFS= read -r line; do
		case "$line" in
		'# branch.head '*) branch="${line#\# branch.head }" ;;
		'# branch.ab '*)
			ahead="${line#\# branch.ab +}"
			ahead="${ahead%% *}"
			;;
		'# '*) ;;
		?*) dirty="*" ;;
		esac
	done < <(git status --porcelain=v2 --branch 2>/dev/null | head -24)

	[[ "$branch" == "(detached)" || -z "$branch" ]] && branch='(detached)'

	label="$branch$dirty"
	[[ -n "$ahead" && "$ahead" != "0" ]] && label="$label +$ahead"

	# Resolved once and reused: this answers both "is this a linked worktree"
	# and "is a merge or rebase open", which would otherwise cost three more
	# git invocations on every refresh, in every session.
	gitdir=$(git rev-parse --absolute-git-dir 2>/dev/null)

	# A worktree name in the payload is the cheapest signal that this session is
	# not where it was launched; fall back to comparing git dirs when absent,
	# since the key is only present when there is a worktree to name.
	if [[ -n "$(json '.workspace.git_worktree')" ]]; then
		label="⎇ $label"
	else
		common=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)
		[[ -n "$gitdir" && -n "$common" && "$gitdir" != "$common" ]] && label="⎇ $label"
	fi

	add "$label"

	# An unresolved merge or rebase is the one git state that silently corrupts
	# work: run a formatter over it and the conflict separator can be absorbed
	# into a table row, damaging both sides at once. It leads the line for that
	# reason. A linked worktree keeps its own MERGE_HEAD under its own git dir,
	# which is what --absolute-git-dir returns there, so this is per-worktree.
	# `git wt-browse` moves HEAD to the base so the branch reads as uncommitted
	# work. That is deliberate, but it makes a branch with commits look like one
	# without any, and a `git commit -a` in that state flattens its history into
	# a single commit. Recoverable from refs/wt-browse/<branch>, but the point of
	# saying so here is not to need the recovery.
	if [[ -n "$branch" ]] &&
		git rev-parse --verify --quiet "refs/wt-browse/${branch//\//-}" >/dev/null 2>&1; then
		alerts=("⚠ BROWSE" "${alerts[@]+"${alerts[@]}"}")
	fi

	if [[ -n "$gitdir" && -f "$gitdir/MERGE_HEAD" ]]; then
		alerts=("⚠ MERGING" "${alerts[@]+"${alerts[@]}"}")
	elif [[ -n "$gitdir" && -d "$gitdir/rebase-merge" ]] ||
		[[ -n "$gitdir" && -d "$gitdir/rebase-apply" ]]; then
		alerts=("⚠ REBASING" "${alerts[@]+"${alerts[@]}"}")
	fi

	root=$(git rev-parse --show-toplevel 2>/dev/null)
fi

# ── Render ──────────────────────────────────────────────────────────────────
line1=""
for a in "${alerts[@]+"${alerts[@]}"}"; do line1="${line1:+$line1$SEP}$a"; done
for p in "${parts[@]+"${parts[@]}"}"; do line1="${line1:+$line1$SEP}$p"; done
[[ -n "$line1" ]] && printf '%s\n' "$line1"
printf '%s\n' "${root:-$cwd}"
