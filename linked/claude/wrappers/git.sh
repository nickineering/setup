#!/usr/bin/env bash
# PATH wrapper: prompts for confirmation on write operations.
# Read-only commands pass through freely. Write commands require
# interactive approval — even from subprocesses.

set -euo pipefail

POLICY_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$POLICY_DIR/policy.conf"

# Find the real git binary by skipping our own directory on PATH.
self_dir="$(cd "$(dirname "$0")" && pwd)"
real_git=""
while IFS= read -r -d: dir; do
	[[ "$dir" == "$self_dir" ]] && continue
	if [[ -x "$dir/git" ]]; then
		real_git="$dir/git"
		break
	fi
done <<<"$PATH:"

if [[ -z "$real_git" ]]; then
	echo "git: real binary not found on PATH" >&2
	exit 1
fi

# Determine the git subcommand (skip global flags like -C, -c, --git-dir)
subcmd=""
for ((i = 1; i <= $#; i++)); do
	arg="${!i}"
	case "$arg" in
	-C | -c | --git-dir | --work-tree | --namespace)
		((i++)) ;;
	--git-dir=* | --work-tree=* | -c\ * | --namespace=*)
		;;
	-*)
		;;
	*)
		subcmd="$arg"
		break
		;;
	esac
done

# No subcommand means help/version — allow
if [[ -z "$subcmd" ]]; then
	exec "$real_git" "$@"
fi

# --- Read-only commands pass through freely ---
for allowed in "${GIT_ALLOWED_READONLY[@]}"; do
	if [[ "$subcmd" == "$allowed" ]]; then
		exec "$real_git" "$@"
	fi
done

# --- Write commands require CLAUDE_APPROVED flag (not inherited by children) ---
if [[ "${CLAUDE_APPROVED:-}" == "1" ]]; then
	unset CLAUDE_APPROVED
	exec "$real_git" "$@"
fi

echo "BLOCKED (wrapper): git $subcmd requires approval. Not called directly by Claude." >&2
exit 1
