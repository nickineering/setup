#!/usr/bin/env bash
# PATH wrapper: injects AWS profile from session state file.
# Blocks if no access has been granted via terminator or claude-aws.

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
