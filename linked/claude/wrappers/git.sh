#!/usr/bin/env bash
# PATH wrapper: enforces git policy for Claude subprocess calls.
# Blocks destructive operations that can't be approved when running
# inside make, python, uv, etc.

set -euo pipefail

POLICY_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$POLICY_DIR/policy.conf"

# Determine the git subcommand (skip global flags like -C, -c, --git-dir)
subcmd=""
subcmd_idx=0
for ((i = 1; i <= $#; i++)); do
	arg="${!i}"
	case "$arg" in
	-C | -c | --git-dir | --work-tree | --namespace)
		((i++)) # skip next arg (value)
		;;
	--git-dir=* | --work-tree=* | -c\ * | --namespace=*)
		;; # skip combined flag=value
	-*)
		;; # skip other flags
	*)
		subcmd="$arg"
		subcmd_idx=$i
		break
		;;
	esac
done

# No subcommand means help/version — allow
if [[ -z "$subcmd" ]]; then
	exec command git "$@"
fi

# --- Check blocked subcommands ---
for blocked in "${GIT_BLOCKED[@]}"; do
	# Handle multi-word blocks like "reset --hard" or "checkout --"
	read -ra words <<<"$blocked"
	if [[ "$subcmd" == "${words[0]}" ]]; then
		if [[ ${#words[@]} -eq 1 ]]; then
			echo "BLOCKED (wrapper): git $subcmd is not allowed in Claude subprocesses" >&2
			exit 1
		fi
		# Check if the blocking flag/arg appears in the remaining args
		block_pattern="${words[1]}"
		for ((j = subcmd_idx + 1; j <= $#; j++)); do
			if [[ "${!j}" == "$block_pattern" ]]; then
				echo "BLOCKED (wrapper): git $blocked is not allowed in Claude subprocesses" >&2
				exit 1
			fi
		done
	fi
done

# --- Check blocked flags on allowed write commands ---
if [[ "$subcmd" == "commit" ]]; then
	for ((j = subcmd_idx + 1; j <= $#; j++)); do
		for flag in "${GIT_BLOCKED_FLAGS_COMMIT[@]}"; do
			if [[ "${!j}" == "$flag" ]]; then
				echo "BLOCKED (wrapper): git commit $flag is not allowed in Claude subprocesses" >&2
				exit 1
			fi
		done
	done
fi

# --- Allow read-only commands ---
for allowed in "${GIT_ALLOWED_READONLY[@]}"; do
	if [[ "$subcmd" == "$allowed" ]]; then
		exec command git "$@"
	fi
done

# --- Allow approved write commands ---
for allowed in "${GIT_ALLOWED_WRITE[@]}"; do
	if [[ "$subcmd" == "$allowed" ]]; then
		exec command git "$@"
	fi
done

# --- Default: block unknown subcommands ---
echo "BLOCKED (wrapper): git $subcmd is not in the allowed list for Claude subprocesses" >&2
exit 1
