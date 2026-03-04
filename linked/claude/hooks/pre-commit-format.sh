#!/bin/bash
# Pre-commit hook: auto-format staged files before Claude commits

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# Only run on git commit commands
if [[ ! "$COMMAND" =~ ^git[[:space:]]commit ]]; then
	exit 0
fi

# Format staged shell files with shfmt
STAGED_SH=$(git diff --cached --name-only --diff-filter=ACM | grep '\.sh$' || true)
if [[ -n "$STAGED_SH" ]]; then
	echo "$STAGED_SH" | xargs -r shfmt -w 2>/dev/null
	echo "$STAGED_SH" | xargs -r git add
fi

exit 0
