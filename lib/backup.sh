# shellcheck shell=bash
# shellcheck disable=SC2154 # Variables like $dim defined in lib/colors.sh
# Sourced by run.sh

# Source colors if not already loaded
if [[ -z "${reset:-}" ]]; then
	source "$(dirname "${BASH_SOURCE[0]}")/colors.sh"
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

	# Safety: refuse to operate on critical paths
	# Two-stage check: literal first because "/" doesn't resolve correctly
	# (dirname "/" + basename "/" produces "//", which won't match "/" pattern)
	case "$1" in
	/ | /etc | /usr | /System | /Applications | "$HOME")
		echo "Error: refusing to backup_or_delete critical path: $1" >&2
		return 1
		;;
	esac
	# Then check resolved path for subdirectories
	local resolved
	resolved=$(cd "$(dirname "$1")" 2>/dev/null && pwd)/$(basename "$1") || resolved="$1"
	case "$resolved" in
	/etc/* | /usr/* | /System/* | "$HOME/")
		echo "Error: refusing to backup_or_delete critical path: $1" >&2
		return 1
		;;
	esac

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
			echo -e "${dim}Backed up $1 at $BACKUP_PATH${reset}"
		else
			# Don't backup links. We will just update them if they have changed.
			rm -f "$1"
		fi
	fi
}
