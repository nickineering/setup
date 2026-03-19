#!/opt/homebrew/bin/bash

# Source print.sh if not already loaded (allows standalone use and testing)
if ! declare -f print_green >/dev/null 2>&1; then
	SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
	source "$SCRIPT_DIR/print.sh"
fi

BACKUPS=~/Documents/backups
mkdir -p "$BACKUPS"

# Backup $1 in backups folder if not a link. Then delete it no matter what.
# Returns 0 on success, 1 on failure
backup_or_delete() {
	if [ "${1:-}" = "" ]; then
		echo "Error: backup_or_delete requires a path argument" >&2
		return 1
	fi

	if [ -e "$1" ] || [ -h "$1" ]; then
		if [[ ! -L $1 ]]; then
			local FILE TIMESTAMP BACKUP_PATH
			FILE=$(basename "$1")
			TIMESTAMP=$(date +%Y-%m-%d_%H%M%S)
			BACKUP_PATH="$BACKUPS/${FILE}.backup.${TIMESTAMP}"
			if ! mv "$1" "$BACKUP_PATH"; then
				echo "Error: Failed to backup $1" >&2
				return 1
			fi
			print_green "Backed up $1 at $BACKUP_PATH"
		else
			# Don't backup links. We will just update them if they have changed.
			rm -f "$1"
		fi
	fi
}
