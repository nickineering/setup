#!/opt/homebrew/bin/bash

# ------------------------------------------------------------------------------------ #
# !                                STAY AWAY, SECRETS!
# This file is committed to version control and used by both Bash and Zsh.
# Add secrets and device specific configuration to ~/.env.sh instead.
# Compatibility must be maintained with both Bash and Zsh.
# ------------------------------------------------------------------------------------ #

# Move $1 to trash
trash() {
	mv -f "${1:?usage: trash FILE_TO_DELETE}" ~/.Trash
}

# Backup ~/.env.sh where secrets should be located.
# It is not subject to version control.
backup_secrets() {
	mkdir -p ~/Documents/backups
	cp ~/.env.sh ~/Documents/backups/
	cp ~/.gitconfig ~/Documents/backups/
	echo 'Backup complete'
	ls -lah ~/Documents/backups/
}

# Combination of cd and ls
cs() {
	cd "$@" && ls
}

# Combination of mkdir and cd
mcd() {
	mkdir -p "$1"
	cd "$1" || return 1
}

# Update everything on the computer
update() {
	cd "$SETUP" || return 1
	git pull
	. "$SETUP/util/setup.sh"
}

# Count lines of code by file extension: $1=EXTENSION (e.g., "py", "js")
lines() {
	local ext="${1:?usage: lines EXTENSION (e.g., lines py)}"
	fd --type f --extension "$ext" --exec cat {} \; 2>/dev/null | wc -l
}

# Find a subdirectory and cd to it (shows menu if multiple matches)
godir() {
	local dirs
	dirs=$(fd --type d --glob "$1" 2>/dev/null)

	if [[ -z "$dirs" ]]; then
		echo "Directory not found: $1"
		return 1
	fi

	local count
	count=$(echo "$dirs" | wc -l | tr -d ' ')

	if [[ "$count" -eq 1 ]]; then
		cd "$dirs" && pwd
	elif command -v fzf &>/dev/null; then
		local target
		target=$(echo "$dirs" | fzf --height=40% --reverse --prompt="Select directory: ")
		if [[ -n "$target" ]]; then
			cd "$target" && pwd
		fi
	else
		echo "Multiple matches found:"
		local i=1
		while IFS= read -r d; do
			echo "  $i) $d"
			((i++))
		done <<<"$dirs"
		echo -n "Select [1-$count]: "
		read -r choice
		local target
		target=$(echo "$dirs" | sed -n "${choice}p")
		if [[ -n "$target" ]]; then
			cd "$target" && pwd
		else
			echo "Invalid selection"
			return 1
		fi
	fi
}
