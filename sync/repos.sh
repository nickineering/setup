# shellcheck shell=bash
# shellcheck disable=SC2154 # Variables like $bold are defined in lib/colors.sh
# Sourced by run.sh

# GitLab repository synchronization
# Clones new repos, detects deleted repos, syncs branches
#
# Required environment:
#   GITLAB_GROUP        - GitLab group/namespace to sync
#   SETUP               - Path to setup repo
# Optional:
#   GITLAB_EXCLUDE_DIRS - Pipe-separated dirs to exclude

# Helper: count lines (returns 0 for empty string)
_count_lines() {
	if [[ -z "$1" ]]; then echo 0; else echo "$1" | wc -l | tr -d ' '; fi
}

sync_repos() {
	local repos_dir="${HOME:?}/work"
	local parallel_jobs=$(($(sysctl -n hw.ncpu) * 2))

	# Safety: ensure repos_dir is a reasonable path (not root, not home)
	[[ "$repos_dir" == "/" || "$repos_dir" == "$HOME" ]] && {
		echo "Error: repos_dir is unsafe: $repos_dir" >&2
		return 1
	}

	# Build exclude args for fd from GITLAB_EXCLUDE_DIRS (pipe-separated)
	local exclude_args=()
	if [[ -n "${GITLAB_EXCLUDE_DIRS:-}" ]]; then
		while IFS= read -r dir; do
			exclude_args+=(--exclude "$dir")
		done < <(echo "$GITLAB_EXCLUDE_DIRS" | tr '|' '\n')
	fi

	# Helper: find all git repos, excluding configured directories
	_find_repos() {
		fd --type d --hidden '^\.git$' "$repos_dir" "${exclude_args[@]}" 2>/dev/null |
			sed -E 's|/\.git/?$||'
	}

	# Check prerequisites
	if [[ -z "${GITLAB_GROUP:-}" ]]; then
		echo -e "${dim}GITLAB_GROUP not set - skipping GitLab sync${reset}"
		return 0
	fi
	if ! command -v glab &>/dev/null; then
		echo -e "${yellow}Warning: glab not installed - skipping GitLab sync${reset}"
		return 0
	fi
	if [[ ! -d "$repos_dir" ]]; then
		echo -e "${dim}Creating $repos_dir for GitLab repos${reset}"
		mkdir -p "$repos_dir"
	fi

	# Create temp files/dirs upfront for clean trap-based cleanup
	local tmpdir stale_branches_dir clone_errors sync_errors stale_branches_file
	tmpdir=$(mktemp -d)
	stale_branches_dir=$(mktemp -d)
	clone_errors=$(mktemp)
	sync_errors=$(mktemp)
	stale_branches_file=$(mktemp)
	trap 'rm -rf "$tmpdir" "$stale_branches_dir" "$clone_errors" "$sync_errors" "$stale_branches_file"' RETURN

	# Fetch repo list from GitLab
	echo -e "${bold}${cyan}=== Fetching repo list from GitLab ===${reset}"
	local total_pages remote_repos

	total_pages=$(glab api "groups/$GITLAB_GROUP/projects?per_page=100&page=1&include_subgroups=true" --include 2>/dev/null | grep -i '^x-total-pages:' | tr -d '[:space:]' | cut -d: -f2)
	total_pages=${total_pages:-1}

	seq 1 "$total_pages" | xargs -P "$parallel_jobs" -I{} sh -c \
		'glab api "groups/'"$GITLAB_GROUP"'/projects?per_page=100&page={}&include_subgroups=true" 2>/dev/null > "$1/page_{}.json" && printf "."' _ "$tmpdir"
	echo ""

	# Validate we got data before parsing
	if ! ls "$tmpdir"/page_*.json &>/dev/null; then
		echo -e "${yellow}Warning: Failed to fetch repos from GitLab${reset}"
		return 0
	fi
	remote_repos=$(jq -s 'add | .[].path_with_namespace' -r "$tmpdir"/page_*.json 2>/dev/null | sed "s|^$GITLAB_GROUP/||" | sort -u)
	echo -e "Found ${bold}$(_count_lines "$remote_repos")${reset} repos on GitLab"
	echo ""

	local repo_list local_repos
	repo_list=$(_find_repos)
	local_repos=$(echo "$repo_list" | sed "s|^$repos_dir/||" | sort)

	# Clone new repos
	echo -e "${bold}${cyan}=== Cloning new repos ===${reset}"
	local new_repos
	new_repos=$(comm -13 <(echo "$local_repos") <(echo "$remote_repos"))

	if [[ -n "$new_repos" ]]; then
		echo -e "Cloning ${bold}${green}$(_count_lines "$new_repos")${reset} new repos..."
		echo "$new_repos" | xargs -P "$parallel_jobs" -I{} sh -c \
			'"$1/sync/clone_repo.sh" "$2" "$3" "$4" || echo "$2" >> "$5"' _ \
			"$SETUP" {} "$repos_dir" "$GITLAB_GROUP" "$clone_errors"
		if [[ -s "$clone_errors" ]]; then
			echo -e "${yellow}Warning: Failed to clone some repos:${reset}"
			sed 's/^/  /' "$clone_errors"
		fi
		repo_list=$(_find_repos)
	else
		echo -e "${dim}None${reset}"
	fi
	echo ""

	# Detect deleted repos
	echo -e "${bold}${cyan}=== Checking for deleted repos ===${reset}"
	local deleted_repos deleted_count
	deleted_repos=$(comm -23 <(echo "$local_repos") <(echo "$remote_repos"))

	if [[ -n "$deleted_repos" ]]; then
		deleted_count=$(_count_lines "$deleted_repos")
		# Safety: if deleting more than 10 repos, require extra confirmation
		if [[ "$deleted_count" -gt 10 ]]; then
			echo -e "${yellow}Warning: About to delete ${bold}${deleted_count}${reset}${yellow} repos - this seems high!${reset}"
			echo -e "${dim}$deleted_repos${reset}"
			echo ""
			echo -n "Type 'yes' to confirm mass deletion: "
			read -r confirm </dev/tty
			[[ "$confirm" == "yes" ]] || {
				echo "Aborted."
				deleted_repos=""
			}
		else
			echo -e "${yellow}Repos no longer on GitLab:${reset}"
			echo -e "${dim}$deleted_repos${reset}"
			echo ""
			echo -n "Delete these? [y/N]: "
			read -r -n 1 confirm </dev/tty
			echo ""
			[[ "$confirm" =~ ^[Yy]$ ]] || deleted_repos=""
		fi
		if [[ -n "$deleted_repos" ]]; then
			echo "$deleted_repos" | while IFS= read -r repo; do
				[[ -z "$repo" ]] && continue
				# Safety: validate path is under repos_dir before deleting
				local target="$repos_dir/$repo"
				[[ "$target" == "$repos_dir"/* && -d "$target" ]] && trash "$target"
			done
			repo_list=$(_find_repos)
		fi
	else
		echo -e "${dim}None${reset}"
	fi
	echo ""

	# Sync all repos
	echo -e "${bold}${cyan}=== Syncing repos ===${reset}"
	echo "$repo_list" | xargs -P "$parallel_jobs" -I{} sh -c \
		'"$1/sync/sync_repo.sh" "$2" "$3" "$4" || echo "$2" >> "$5"' _ \
		"$SETUP" {} "$repos_dir" "$stale_branches_dir" "$sync_errors"
	if [[ -s "$sync_errors" ]]; then
		echo -e "${yellow}Warning: Failed to sync some repos:${reset}"
		sed 's|^'"$repos_dir"'/||; s/^/  /' "$sync_errors"
	fi
	echo ""

	# Aggregate stale branches from all sync processes
	cat "$stale_branches_dir"/* 2>/dev/null >"$stale_branches_file" || true

	# Prompt to delete stale branches
	if [[ -s "$stale_branches_file" ]]; then
		echo -e "${bold}${cyan}=== Stale branches (merged/deleted upstream) ===${reset}"
		local stale_count
		stale_count=$(wc -l <"$stale_branches_file" | tr -d ' ')
		echo -e "Found ${bold}${yellow}${stale_count}${reset} stale branch(es)"
		echo ""
		while IFS=: read -r repo branch; do
			printf "Delete ${yellow}%s${reset} from ${cyan}%s${reset}? [y/N]: " "$branch" "$repo"
			read -r -n 1 confirm </dev/tty
			echo ""
			if [[ "$confirm" =~ ^[Yy]$ ]]; then
				git -C "$repos_dir/$repo" branch -D "$branch" 2>/dev/null &&
					echo -e "  ${green}Deleted${reset}" ||
					echo -e "  ${yellow}Failed to delete${reset}"
			else
				echo -e "  ${dim}Skipped${reset}"
			fi
		done <"$stale_branches_file"
		echo ""
	fi
}
