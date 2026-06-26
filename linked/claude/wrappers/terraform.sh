#!/usr/bin/env bash
# PATH wrapper: enforces terraform policy + injects AWS profile from session state.

set -euo pipefail

POLICY_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$POLICY_DIR/policy.conf"

# --- Require AWS access ---
if [[ ! -f "${CLAUDE_AWS_STATE:-}" ]]; then
	echo "No AWS access granted. Run: claude-aws <profile> | off" >&2
	exit 1
fi

# --- Extract subcommand (skip -chdir and global flags) ---
subcmd=""
for arg in "$@"; do
	case "$arg" in
		-chdir=*|-chdir) ;;
		-*)              ;;
		*)
			subcmd="$arg"
			break
			;;
	esac
done

# No subcommand — allow (shows help)
if [[ -z "$subcmd" ]]; then
	target_profile="$(cat "$CLAUDE_AWS_STATE")"
	AWS_PROFILE="$target_profile" exec command terraform "$@"
fi

# --- Check blocked subcommands ---
for blocked in "${TERRAFORM_BLOCKED[@]}"; do
	words=($blocked)
	if [[ "$subcmd" == "${words[0]}" ]]; then
		if [[ ${#words[@]} -eq 1 ]]; then
			echo "BLOCKED (wrapper): terraform $subcmd is not allowed in Claude subprocesses" >&2
			exit 1
		fi
		# Multi-word: check remaining args (e.g. "state rm")
		for arg in "$@"; do
			if [[ "$arg" == "${words[1]}" ]]; then
				echo "BLOCKED (wrapper): terraform $blocked is not allowed in Claude subprocesses" >&2
				exit 1
			fi
		done
	fi
done

# --- Execute with profile ---
target_profile="$(cat "$CLAUDE_AWS_STATE")"
AWS_PROFILE="$target_profile" exec command terraform "$@"
