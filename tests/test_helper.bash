# Shared test helper - loaded via bats `load` command

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export REPO_ROOT

# Source utilities
source "$REPO_ROOT/lib/colors.sh"
source "$REPO_ROOT/lib/backup.sh"
source "$REPO_ROOT/lib/packages.sh"
