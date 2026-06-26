#!/usr/bin/env bash
# Mid-session AWS profile switcher for Claude sessions.
# Writes the given AWS profile name directly to the session state file.

if [[ -z "${CLAUDE_AWS_STATE:-}" ]]; then
	echo "Not in a Claude session. Use this inside terminator."
	return 1 2>/dev/null || exit 1
fi

case "${1:-}" in
off)
	rm -f "$CLAUDE_AWS_STATE"
	echo "AWS access revoked for this Claude session."
	;;
"")
	if [[ -f "$CLAUDE_AWS_STATE" ]]; then
		echo "Current: $(cat "$CLAUDE_AWS_STATE")"
	else
		echo "No AWS access granted."
	fi
	echo "Usage: claude-aws <aws-profile-name> | off"
	;;
*)
	echo "$1" >"$CLAUDE_AWS_STATE"
	echo "Claude AWS access → $1"
	;;
esac
