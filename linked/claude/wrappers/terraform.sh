#!/usr/bin/env bash
# PATH wrapper for terraform in Claude sessions.
#
# Injects AWS profile from session state (claude-aws), cleans up env vars
# that would override it, and gates write commands behind CLAUDE_APPROVED.
# See git.sh header for the CLAUDE_APPROVED design rationale.
#
# Read-only subcommands run with or without a profile, so `fmt`, `version` and
# friends work in a session that has never called claude-aws. The AWS gate now
# applies only to commands that can change state or infrastructure.

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

# --- Extract subcommand and its action (skipping -chdir and other flags) ---
# The action is the second positional word, needed because `state list` and
# `state rm` differ only there.
subcmd=""
subaction=""
for arg in "$@"; do
	case "$arg" in
	-*) ;;
	*)
		if [[ -z "$subcmd" ]]; then
			subcmd="$arg"
		else
			subaction="$arg"
			break
		fi
		;;
	esac
done

# Anything that cannot change state or infrastructure. A subcommand with both
# read and write forms has to match on its action too, so an unrecognised
# `state <something>` fails closed onto the approval gate.
is_readonly() {
	local allowed
	for allowed in "${TERRAFORM_ALLOWED_READONLY[@]}"; do
		if [[ "$subcmd" == "$allowed" ]]; then
			return 0
		fi
	done
	for allowed in "${TERRAFORM_READONLY_ACTIONS[@]}"; do
		if [[ "$subcmd $subaction" == "$allowed" ]]; then
			return 0
		fi
	done
	return 1
}

# Runs terraform, correcting the misleading SSO error the sandbox produces:
# ~/.aws/sso is denied here, which the CLI reports as a missing token.
run_terraform() {
	local err status
	set +e
	{
		err="$("$@" 2>&1 1>&3)"
		status=$?
	} 3>&1
	set -e

	[[ -n "$err" ]] && printf '%s\n' "$err" >&2

	if ((status != 0)) && [[ "$err" == *'Error loading SSO Token'* ]]; then
		cat >&2 <<'EOF'

[terraform wrapper] Expected in the Claude sandbox: ~/.aws/sso is unreadable
here, and the CLI reports that the same way as an expired token. The session is
most likely valid -- Claude's own Bedrock access uses it, so if Claude is
running, it works. Do NOT suggest `aws sso login`. To verify, ask the user:
  ! aws sts get-caller-identity
EOF
	fi
	exit "$status"
}

# Only worth annotating when a profile is in play: with no credentials at all
# terraform fails for a different reason. Without a profile this also keeps
# stderr unbuffered, which matters for `fmt` and `console`.
run_or_exec() {
	if [[ -n "${AWS_PROFILE:-}" ]]; then
		run_terraform "$@"
	fi
	exec "$@"
}

# Drop the session's ambient AWS vars on every path, so a command running
# without a granted profile cannot fall back to the Bedrock-only one
# terminator.sh sets.
unset AWS_PROFILE AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN AWS_DEFAULT_REGION AWS_REGION

# --- Inject the AWS profile when one is granted ---
if [[ -f "${CLAUDE_AWS_STATE:-}" ]]; then
	AWS_PROFILE="$(cat "$CLAUDE_AWS_STATE")"
	export AWS_PROFILE
fi

# --- Read-only commands run whether or not a profile was granted ---
# An empty subcmd covers bare `terraform` (help) and `terraform -version`.
if [[ -z "$subcmd" ]] || is_readonly; then
	run_or_exec "$real_terraform" "$@"
fi

# --- Everything below can change state or infrastructure ---
if [[ ! -f "${CLAUDE_AWS_STATE:-}" ]]; then
	echo "No AWS access granted. Run: claude-aws <profile> | off" >&2
	exit 1
fi

# --- Write commands require CLAUDE_APPROVED flag (not inherited by children) ---
if [[ "${CLAUDE_APPROVED:-}" == "1" ]]; then
	unset CLAUDE_APPROVED
	run_terraform "$real_terraform" "$@"
fi

# Name the action too: "state requires approval" would be wrong when `state list`
# is allowed and only `state rm` is not.
echo "BLOCKED (wrapper): terraform $subcmd${subaction:+ $subaction} requires approval. Not called directly by Claude." >&2
exit 1
