#!/opt/homebrew/bin/bash

# ------------------------------------------------------------------------------------ #
# !                                STAY AWAY, SECRETS!
# This file is committed to version control and used by both Bash and Zsh.
# Add secrets and device specific configuration to ~/.env.sh instead.
# Compatibility must be maintained with both Bash and Zsh.
# ------------------------------------------------------------------------------------ #

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

# Dev environment setup/maintenance
devenv() {
	"$SETUP/run.sh" "$@"
}

# Count lines of code by file extension: $1=EXTENSION (e.g., "py", "js")
lines() {
	local ext="${1:?usage: lines EXTENSION (e.g., lines py)}"
	fd --type f --extension "$ext" --exec cat {} \; 2>/dev/null | wc -l
}

# Read a number 1..N with auto-execute when input is unambiguous.
# Outputs the chosen number to stdout; returns 1 on invalid input.
_read_choice() {
	local count=$1 input=""
	echo -n "Select [1-$count]: "
	while true; do
		read -r -s -k 1 char
		if [[ "$char" == $'\n' ]]; then
			echo
			if [[ -n "$input" && "$input" -ge 1 && "$input" -le "$count" ]] 2>/dev/null; then
				echo "$input"
				return
			fi
			echo "\033[1;31mInvalid selection\033[0m" >&2
			return 1
		fi
		if [[ "$char" == $'\x7f' || "$char" == $'\b' ]]; then
			if [[ -n "$input" ]]; then
				input="${input%?}"
				printf "\b \b"
			fi
			continue
		fi
		[[ "$char" != [0-9] ]] && continue
		input="${input}${char}"
		printf "%s" "$char"

		local matches=0 last_match=""
		for ((n=1; n<=count; n++)); do
			if [[ "$n" == "${input}"* ]]; then
				((matches++))
				last_match=$n
			fi
		done

		if [[ $matches -eq 1 ]]; then
			echo
			echo "$last_match"
			return
		elif [[ $matches -eq 0 ]]; then
			echo
			echo "\033[1;31mInvalid selection\033[0m" >&2
			return 1
		fi
	done
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
		return
	fi

	if command -v fzf &>/dev/null; then
		local target
		target=$(echo "$dirs" | fzf --height=40% --reverse --prompt="Select directory: ")
		[[ -n "$target" ]] && cd "$target" && pwd
		return
	fi

	echo "Multiple matches found:"
	local i=1
	while IFS= read -r d; do
		echo "  $i) $d"
		((i++))
	done <<<"$dirs"

	local choice
	choice=$(_read_choice "$count") || return 1
	local target
	target=$(echo "$dirs" | sed -n "${choice}p")
	if [[ -n "$target" ]]; then
		cd "$target" && pwd
	else
		echo "\033[1;31mInvalid selection\033[0m"
		return 1
	fi
}

# Git wrapper for commands that need to modify the parent shell.
#
# WHY: Git aliases run in subshells, so `cd` only affects the subshell.
#      This wrapper intercepts specific commands and runs them in the current shell.
#
# SIDE EFFECT: Shadows the `git` command. Use `command git` to bypass.
#
# OVERRIDES:
#   root        - cd to repository root
#   start [REF] - cd to root, checkout REF (default: master/main), pull
git() {
	# git root - cd to repository root
	if [[ "$1" == "root" ]]; then
		local root
		root=$(command git rev-parse --show-toplevel 2>/dev/null)
		if [[ -n "$root" ]]; then
			cd "$root" || return 1
		else
			echo "Not in a git repository"
			return 1
		fi
	# git start [branch] - cd to root, checkout branch, pull
	elif [[ "$1" == "start" ]]; then
		local root branch="${2:-}"
		root=$(command git rev-parse --show-toplevel 2>/dev/null)
		if [[ -z "$root" ]]; then
			echo "Not in a git repository"
			return 1
		fi
		cd "$root" || return 1
		if [[ -n "$branch" ]]; then
			command git checkout "$branch"
		else
			command git checkout master 2>/dev/null || command git checkout main
		fi
		command git pull
	else
		command git "$@"
	fi
}
