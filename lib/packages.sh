# shellcheck shell=bash
# shellcheck disable=SC2154 # Variables like $yellow defined in lib/colors.sh
# Shared package management utilities - sourced by run.sh
# Provides diff-based package installation and user-prompted removal.

# Remove any text after the first space in string $1 (strips comments)
# Returns empty string for comment-only lines (starting with #)
strip_comments() {
	local first_word
	first_word=$(echo "$1" | head -n1 | awk '{print $1;}')
	# Skip lines that are comments (start with #)
	[[ "$first_word" == \#* ]] && return
	echo "$first_word"
}

# Parse a state file: strip comments and empty lines
# Usage: parse_state_file "/path/to/file.txt"
parse_state_file() {
	local file="$1"
	[[ -f "$file" ]] || return 1
	while IFS= read -r line; do
		local stripped
		stripped=$(strip_comments "$line")
		[[ -n "$stripped" ]] && echo "$stripped"
	done <"$file"
}

# Get installed Homebrew formula packages
get_installed_packages() {
	brew list --formula -1 2>/dev/null
}

# Get installed Homebrew casks
get_installed_casks() {
	brew list --cask -1 2>/dev/null
}

# Get installed VSCode extensions (lowercase for comparison)
get_installed_extensions() {
	if command -v code &>/dev/null; then
		code --list-extensions 2>/dev/null | tr '[:upper:]' '[:lower:]'
	fi
}

# Set difference: returns items in $2 that are NOT in $1
# Usage: set_difference <exclude_list> <full_list>
# Examples:
#   set_difference "$installed" "$desired"  -> packages to install
#   set_difference "$new_state" "$old_state" -> packages removed from state
set_difference() {
	local exclude="$1" full="$2"
	[[ -z "$full" ]] && return
	[[ -z "$exclude" ]] && {
		echo "$full"
		return
	}
	echo "$full" | grep -vxF -f <(echo "$exclude") || true
}

# Install missing items of a given type
# Usage: install_missing <type> <list>
# Types: package, cask, extension
install_missing() {
	local type="$1" list="$2"
	[[ -z "$list" ]] && return 0

	# Extension-specific: check for VSCode CLI
	if [[ "$type" == "extension" ]] && ! command -v code &>/dev/null; then
		echo "Warning: VSCode CLI not found. Skipping extension installation." >&2
		return 0
	fi

	local count
	count=$(echo "$list" | wc -l | tr -d ' ')
	echo "Installing $count missing ${type}(s)..."

	while IFS= read -r item; do
		[[ -z "$item" ]] && continue
		local install_cmd
		case "$type" in
		package) install_cmd=(brew install) ;;
		cask) install_cmd=(brew install --cask) ;;
		extension) install_cmd=(code --install-extension) ;;
		esac
		if ! "${install_cmd[@]}" "$item"; then
			echo "Warning: Failed to install $type: $item" >&2
		fi
	done <<<"$list"
}

# Packages that should never be auto-uninstalled (critical dependencies)
PROTECTED_PACKAGES="bash|git|openssl|curl|coreutils"

# Threshold for mass uninstall warning
MAX_SAFE_UNINSTALLS=10

# Prompt user before uninstalling items (destructive action)
# Usage: prompt_uninstall <type> <list>
# Types: package, cask, extension
prompt_uninstall() {
	local type="$1" list="$2"
	[[ -z "$list" ]] && return 0

	# Extension-specific: check for VSCode CLI
	if [[ "$type" == "extension" ]] && ! command -v code &>/dev/null; then
		return 0
	fi

	# Package-specific: filter out protected packages
	local safe_to_remove="$list"
	if [[ "$type" == "package" ]]; then
		safe_to_remove=""
		local protected_found=""
		while IFS= read -r item; do
			[[ -z "$item" ]] && continue
			if echo "$item" | grep -qE "^($PROTECTED_PACKAGES)$"; then
				protected_found+="$item (protected)\n"
			else
				safe_to_remove+="$item"$'\n'
			fi
		done <<<"$list"
		safe_to_remove="${safe_to_remove%$'\n'}"

		if [[ -n "$protected_found" ]]; then
			echo -e "Skipping protected packages:\n$(echo -e "$protected_found" | sed 's/^/  /')"
		fi
	fi

	[[ -z "$safe_to_remove" ]] && return 0

	local count
	count=$(echo "$safe_to_remove" | wc -l | tr -d ' ')

	echo "The following ${type}s were removed from state file:"
	echo "$safe_to_remove" | sed 's/^/  /'

	# Guard: require explicit confirmation for mass uninstalls
	if [[ "$count" -gt "$MAX_SAFE_UNINSTALLS" ]]; then
		echo -e "${yellow}Warning: About to uninstall ${bold}${count}${reset}${yellow} ${type}s - this seems high!${reset}"
		echo -n "Type 'yes' to confirm mass uninstall: "
		read -r confirm </dev/tty
		[[ "$confirm" == "yes" ]] || {
			echo "Aborted."
			return 0
		}
	else
		echo -n "Uninstall these ${type}s? [y/N]: "
		read -r -n 1 confirm </dev/tty
		echo ""
		[[ "$confirm" =~ ^[Yy]$ ]] || {
			echo "Skipped uninstallation."
			return 0
		}
	fi

	while IFS= read -r item; do
		[[ -z "$item" ]] && continue
		local uninstall_cmd
		case "$type" in
		package) uninstall_cmd=(brew uninstall) ;;
		cask) uninstall_cmd=(brew uninstall --cask) ;;
		extension) uninstall_cmd=(code --uninstall-extension) ;;
		esac
		if ! "${uninstall_cmd[@]}" "$item"; then
			echo "Warning: Failed to uninstall $type: $item" >&2
		fi
	done <<<"$safe_to_remove"
}
