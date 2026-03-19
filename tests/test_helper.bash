# Shared test helper - loaded via bats `load` command

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export REPO_ROOT

# Source utilities
source "$REPO_ROOT/util/strip_comments.sh"
source "$REPO_ROOT/util/print.sh"
source "$REPO_ROOT/util/backup_or_delete.sh"
