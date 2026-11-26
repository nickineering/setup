#!/bin/bash
# Pre-commit hook: auto-format staged files before Claude commits

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# Only run on git commit commands
if [[ ! "$COMMAND" =~ ^git[[:space:]]commit ]]; then
	exit 0
fi

# Never format while a merge, rebase, cherry-pick or revert is unresolved.
#
# A formatter rewrites a file that still has conflict markers in it, and on a
# markdown table it can absorb the `=======` separator into a row as a cell —
# which destroys both sides at once, leaves a file whose markers no longer
# parse, and reads afterwards like a bad resolution rather than a tooling
# accident. It happened to docs/how-it-works.md and docs/monitoring.md.
#
# Blocking the commit rather than just skipping the formatting: committing with
# unmerged paths present is itself almost never what was meant.
GIT_ADMIN=$(git rev-parse --absolute-git-dir 2>/dev/null)
if [[ -n "$GIT_ADMIN" ]]; then
	for marker in MERGE_HEAD CHERRY_PICK_HEAD REVERT_HEAD rebase-merge rebase-apply; do
		if [[ -e "$GIT_ADMIN/$marker" ]]; then
			echo "BLOCKED: $marker is present — an operation is unresolved." >&2
			echo "Formatting now can absorb a conflict separator into the file it is" >&2
			echo "reformatting, corrupting both sides. Resolve first, then commit." >&2
			exit 2
		fi
	done
fi

# Unmerged index entries can outlive the merge that created them, so the
# markers above are not sufficient on their own.
if [[ -n "$(git diff --name-only --diff-filter=U 2>/dev/null | head -c1)" ]]; then
	echo "BLOCKED: the index holds unmerged paths:" >&2
	git diff --name-only --diff-filter=U 2>/dev/null | sed 's/^/  /' >&2
	echo "Resolve and stage them, then commit. If no merge is in progress, the" >&2
	echo "index is stale: 'git reset' rebuilds it from HEAD without touching" >&2
	echo "your working tree." >&2
	exit 2
fi

# Format staged shell files with shfmt
STAGED_SH=$(git diff --cached --name-only --diff-filter=ACM | grep '\.sh$' || true)
if [[ -n "$STAGED_SH" ]]; then
	echo "$STAGED_SH" | xargs -r shfmt -w 2>/dev/null
	echo "$STAGED_SH" | xargs -r git add
fi

exit 0
