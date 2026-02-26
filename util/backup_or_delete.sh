#!/opt/homebrew/bin/bash

source print.sh

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
			local FILE
			FILE=$(basename "$1")
			if ! mv -f "$1" "$BACKUPS"/; then
				echo "Error: Failed to backup $1" >&2
				return 1
			fi
			print_green "Backed up $1 at $BACKUPS/$FILE"
		else
			# Don't backup links. We will just update them if they have changed.
			rm -f "$1"
		fi
	fi
}
