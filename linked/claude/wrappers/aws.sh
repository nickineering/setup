#!/usr/bin/env bash
# PATH wrapper for aws in Claude sessions.
#
# Injects --profile from the session state file (set by claude-aws).
# Unsets AWS env vars that would override --profile (Bedrock credentials
# from terminator.sh target a different account than the user's aws commands).

if [[ ! -f "${CLAUDE_AWS_STATE:-}" ]]; then
	echo "No AWS access granted. Run: claude-aws <profile> | off" >&2
	exit 1
fi

# Find the real aws binary by skipping our own directory on PATH.
self_dir="$(cd "$(dirname "$0")" && pwd)"
real_aws=""
while IFS= read -r -d: dir; do
	[[ "$dir" == "$self_dir" ]] && continue
	if [[ -x "$dir/aws" ]]; then
		real_aws="$dir/aws"
		break
	fi
done <<<"$PATH:"

if [[ -z "$real_aws" ]]; then
	echo "aws: real binary not found on PATH" >&2
	exit 1
fi

target_profile="$(cat "$CLAUDE_AWS_STATE")"
unset AWS_PROFILE AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN AWS_DEFAULT_REGION AWS_REGION
exec "$real_aws" --profile "$target_profile" "$@"
