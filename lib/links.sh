# shellcheck shell=bash
# shellcheck disable=SC2154 # Variables like $yellow defined in lib/colors.sh

# Idempotent symlink creation with backup support.
# Depends on: lib/colors.sh, lib/backup.sh

links_created=0

# Create or update a symlink. Backs up existing non-link targets, skips if
# already correct, and increments links_created on change.
#   $1 - source path (what the link points to)
#   $2 - target path (where the link lives)
#   $3 - optional display label (defaults to basename of target)
create_link() {
	local source="$1" target="$2" label="${3:-}"
	local target_dir
	target_dir=$(dirname "$target")
	[[ -d "$target_dir" ]] || return 0

	if [[ -L "$target" && "$(readlink "$target")" == "$source" ]]; then
		return 0
	fi

	backup_or_delete "$target" || true
	if ln -sfn "$source" "$target"; then
		if [[ -n "$label" ]]; then
			echo "Linked: ${label}"
		else
			echo "Linked: $(basename "$target")"
		fi
		((links_created++)) || true
	else
		echo -e "${yellow}Warning: Failed to link $(basename "$target")${reset}" >&2
	fi
}
