# Shared test helper - loaded via bats `load` command

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export REPO_ROOT

# Source utilities
source "$REPO_ROOT/lib/colors.sh"
source "$REPO_ROOT/lib/backup.sh"
source "$REPO_ROOT/lib/packages.sh"
source "$REPO_ROOT/lib/steps.sh"

# Strips ANSI escape sequences so assertions can match user-facing text
# without embedding color codes. Reads $1, or stdin when no argument given.
strip_ansi() {
	if (($#)); then
		printf '%s' "$1" | sed $'s/\033\\[[0-9;]*m//g'
	else
		sed $'s/\033\\[[0-9;]*m//g'
	fi
}
