#!/usr/bin/env bash
# PATH wrapper: blocks git-receive-pack over SSH (prevents push via SSH).
# All other SSH usage is allowed.

set -euo pipefail

POLICY_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$POLICY_DIR/policy.conf"

# Check if any argument matches a blocked remote command
for arg in "$@"; do
	for blocked in "${SSH_BLOCKED_COMMANDS[@]}"; do
		if [[ "$arg" == *"$blocked"* ]]; then
			echo "BLOCKED (wrapper): ssh with $blocked is not allowed (prevents push over SSH)" >&2
			exit 1
		fi
	done
done

exec command ssh "$@"
