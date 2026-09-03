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

# The sandbox cannot read ~/.aws/sso, which the CLI reports identically to an
# expired token. Capture stderr (stdout passes through fd 3) so we can correct
# that one misleading error. No temp file: the sandbox blocks $TMPDIR writes.
{
	err="$("$real_aws" --profile "$target_profile" "$@" 2>&1 1>&3)"
	status=$?
} 3>&1

[[ -n "$err" ]] && printf '%s\n' "$err" >&2

if ((status != 0)) && [[ "$err" == *'Error loading SSO Token'* ]]; then
	cat >&2 <<'EOF'

[aws wrapper] Expected in the Claude sandbox: ~/.aws/sso is unreadable here, and
the CLI reports that the same way as an expired token. The session is most likely
valid -- Claude's own Bedrock access uses it, so if Claude is running, it works.
Do NOT suggest `aws sso login`. To verify, ask the user to run:
  ! aws sts get-caller-identity
EOF
fi

exit $status
