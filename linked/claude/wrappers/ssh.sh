#!/usr/bin/env bash
# PATH wrapper: blocks git-receive-pack over SSH (prevents push via SSH).
# All other SSH usage is allowed.

set -euo pipefail

POLICY_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$POLICY_DIR/policy.conf"

# Find the real ssh binary by skipping our own directory on PATH.
self_dir="$(cd "$(dirname "$0")" && pwd)"
real_ssh=""
while IFS= read -r -d: dir; do
	[[ "$dir" == "$self_dir" ]] && continue
	if [[ -x "$dir/ssh" ]]; then
		real_ssh="$dir/ssh"
		break
	fi
done <<<"$PATH:"

if [[ -z "$real_ssh" ]]; then
	echo "ssh: real binary not found on PATH" >&2
	exit 1
fi

# Check if any argument matches a blocked remote command
for arg in "$@"; do
	for blocked in "${SSH_BLOCKED_COMMANDS[@]}"; do
		if [[ "$arg" == *"$blocked"* ]]; then
			echo "BLOCKED (wrapper): ssh with $blocked is not allowed (prevents push over SSH)" >&2
			exit 1
		fi
	done
done

exec "$real_ssh" "$@"
