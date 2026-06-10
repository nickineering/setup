# shellcheck shell=bash
# shellcheck disable=SC2154 # Variables like $yellow defined in lib/colors.sh

# Extract the first word from a line, ignoring comments (lines starting with #)
strip_comments() {
	local first_word
	first_word=$(echo "$1" | head -n1 | awk '{print $1;}')
	[[ "$first_word" == \#* ]] && return
	echo "$first_word"
}

# Parse a state file into a newline-separated list, stripping comments and blanks
parse_state_file() {
	local file="$1"
	[[ -f "$file" ]] || return 1
	while IFS= read -r line; do
		local stripped
		stripped=$(strip_comments "$line")
		[[ -n "$stripped" ]] && echo "$stripped"
	done <"$file"
}

get_installed_packages() {
	brew list --formula -1 2>/dev/null
}

get_installed_casks() {
	brew list --cask -1 2>/dev/null
}

get_installed_extensions() {
	if command -v code &>/dev/null; then
		code --list-extensions 2>/dev/null | tr '[:upper:]' '[:lower:]'
	fi
}

# Excludes npm and corepack which are bundled with Node and shouldn't be managed
get_installed_npm_packages() {
	if command -v npm &>/dev/null; then
		npm list -g --depth=0 --json 2>/dev/null |
			jq -r '.dependencies // {} | keys[]' 2>/dev/null |
			grep -vE '^(npm|corepack)$' || true
	fi
}

# Returns items in $2 that are NOT in $1
# Note: arg order is (exclude, full) not (full, exclude)
set_difference() {
	local exclude="$1" full="$2"
	[[ -z "$full" ]] && return
	[[ -z "$exclude" ]] && {
		echo "$full"
		return
	}
	echo "$full" | grep -vxF -f <(echo "$exclude") || true
}

# Types: package, cask, extension, npm
install_missing() {
	local type="$1" list="$2"
	[[ -z "$list" ]] && return 0

	if [[ "$type" == "extension" ]] && ! command -v code &>/dev/null; then
		echo "⚠ VSCode CLI not found. Skipping extension installation." >&2
		return 0
	fi

	while IFS= read -r item; do
		[[ -z "$item" ]] && continue
		echo "› Installing ${type}: ${item}"
		local install_cmd
		case "$type" in
		package) install_cmd=(brew install) ;;
		cask) install_cmd=(brew install --cask --adopt) ;; # --adopt: claim apps already in /Applications
		extension) install_cmd=(code --install-extension) ;;
		npm) install_cmd=(npm install -g --fund=false --audit=false) ;;
		esac
		if ! "${install_cmd[@]}" "$item"; then
			echo "⚠ Failed to install $type: $item" >&2
		fi
	done <<<"$list"
}

# Used unconditionally by these scripts (no command -v guard, no macOS fallback)
PROTECTED_PACKAGES="bash|git|curl|jq|trash"

# If more than this many are queued for removal, the state file was probably
# truncated or corrupted — require explicit "yes" instead of y/N
MAX_SAFE_UNINSTALLS=10

# Show items removed from state and ask the user whether to uninstall them.
# Types: package, cask, extension, npm
prompt_uninstall() {
	local type="$1" list="$2"
	[[ -z "$list" ]] && return 0

	if [[ "$type" == "extension" ]] && ! command -v code &>/dev/null; then
		return 0
	fi

	# Filter out protected packages from the removal list
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
	echo "$safe_to_remove" | while IFS= read -r item; do echo "  $item"; done

	if [[ "$count" -gt "$MAX_SAFE_UNINSTALLS" ]]; then
		echo -e "${yellow}⚠ About to uninstall ${bold}${count}${reset}${yellow} ${type}s - this seems high!${reset}"
		echo -n "Type 'yes' to confirm mass uninstall: "
		read -r confirm </dev/tty
		[[ "$confirm" == "yes" ]] || {
			echo "– Aborted."
			return 0
		}
	else
		echo -n "Uninstall these ${type}s? [y/N]: "
		read -r -n 1 confirm </dev/tty
		echo ""
		[[ "$confirm" =~ ^[Yy]$ ]] || {
			echo "– Skipped uninstallation."
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
		npm) uninstall_cmd=(npm uninstall -g) ;;
		esac
		if ! "${uninstall_cmd[@]}" "$item"; then
			echo "⚠ Failed to uninstall $type: $item" >&2
		fi
	done <<<"$safe_to_remove"
}
