#!/usr/local/bin/bash

source print.sh

BACKUPS=~/Documents/backups
mkdir -p $BACKUPS

# Backup $1 in backups folder if not a link. Then delete it no matter what.
backup_or_delete() {
	if [ -e "$1" ] || [ -h "$1" ]; then
		if [[ ! -L $1 ]]; then
			local FILE
			FILE=$(basename "$1")
			mv -f "$1" "$BACKUPS"/
			print_green "Backed up $1 at $BACKUPS/$FILE"
		else
			# Don't backup links. We will just update them if they have changed.
			rm -f "$1"
		fi
	fi
}
