#!/usr/bin/env bash
# PATH wrapper: injects AWS profile from session state file.
# Blocks if no access has been granted via terminator or claude-aws.

if [[ ! -f "${CLAUDE_AWS_STATE:-}" ]]; then
	echo "No AWS access granted. Run: claude-aws <profile> | off" >&2
	exit 1
fi

target_profile="$(cat "$CLAUDE_AWS_STATE")"
exec command aws --profile "$target_profile" "$@"
