#!/usr/bin/env bash
# PATH wrapper for terraform in Claude sessions.
#
# Injects AWS profile from session state (claude-aws), cleans up env vars
# that would override it, and gates write commands behind CLAUDE_APPROVED.
# See git.sh header for the CLAUDE_APPROVED design rationale.

set -euo pipefail

POLICY_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$POLICY_DIR/policy.conf"

# Find the real terraform binary by skipping our own directory on PATH.
self_dir="$(cd "$(dirname "$0")" && pwd)"
real_terraform=""
while IFS= read -r -d: dir; do
	[[ "$dir" == "$self_dir" ]] && continue
	if [[ -x "$dir/terraform" ]]; then
		real_terraform="$dir/terraform"
		break
	fi
done <<<"$PATH:"

if [[ -z "$real_terraform" ]]; then
	echo "terraform: real binary not found on PATH" >&2
	exit 1
fi

# --- Require AWS access ---
if [[ ! -f "${CLAUDE_AWS_STATE:-}" ]]; then
	echo "No AWS access granted. Run: claude-aws <profile> | off" >&2
	exit 1
fi

# --- Extract subcommand (skip -chdir and global flags) ---
subcmd=""
for arg in "$@"; do
	case "$arg" in
	-chdir=* | -chdir) ;;
	-*) ;;
	*)
		subcmd="$arg"
		break
		;;
	esac
done

# --- Inject AWS profile and execute ---
target_profile="$(cat "$CLAUDE_AWS_STATE")"
unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN AWS_DEFAULT_REGION AWS_REGION

# No subcommand — allow (shows help)
if [[ -z "$subcmd" ]]; then
	AWS_PROFILE="$target_profile" exec "$real_terraform" "$@"
fi

# --- Read-only commands pass through freely ---
for allowed in "${TERRAFORM_ALLOWED_READONLY[@]}"; do
	if [[ "$subcmd" == "$allowed" ]]; then
		AWS_PROFILE="$target_profile" exec "$real_terraform" "$@"
	fi
done

# --- Write commands require CLAUDE_APPROVED flag (not inherited by children) ---
if [[ "${CLAUDE_APPROVED:-}" == "1" ]]; then
	unset CLAUDE_APPROVED
	AWS_PROFILE="$target_profile" exec "$real_terraform" "$@"
fi

echo "BLOCKED (wrapper): terraform $subcmd requires approval. Not called directly by Claude." >&2
exit 1
