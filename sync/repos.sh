# shellcheck shell=bash
# shellcheck disable=SC2016 # Single quotes in xargs sh -c are intentional
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

# Remove the now-empty parent directories the mirrored worktree layout leaves
# behind. Stops at the worktree root, so it can never climb into $repos_dir.
# Usage: _prune_worktree_parents <removed_path> <worktree_root>
_prune_worktree_parents() {
	local d root="$2"
	d=$(dirname "$1")
	while [[ "$d" != "$root" && "$d" != "/" && -n "$d" ]]; do
		rmdir "$d" 2>/dev/null || break
		d=$(dirname "$d")
	done
}

sync_repos() {
	local repos_dir="${HOME:?}/work"
	# Parallel worktree tree — see the Worktrees section in linked/git_functions.sh
	local worktrees_dir="$repos_dir/.worktrees"
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

	# Helper: find all git repos, excluding configured directories.
	#
	# .worktrees is excluded unconditionally rather than via GITLAB_EXCLUDE_DIRS:
	# this list is diffed against GitLab to decide what to clone and what to trash,
	# and a worktree has no counterpart there, so a miss here would offer to delete
	# real work. (A linked worktree's git entry is a file, not a directory, so
	# --type d already skips them — this makes the guarantee explicit and cheap.)
	_find_repos() {
		fd --type d --hidden '^\.git$' "$repos_dir" \
			--exclude .worktrees "${exclude_args[@]}" 2>/dev/null |
			sed -E 's|/\.git/?$||'
	}

	# Check prerequisites
	if [[ -z "${GITLAB_GROUP:-}" ]]; then
		echo -e "${dim}· GITLAB_GROUP not set - skipping GitLab sync${reset}"
		return 0
	fi
	if ! command -v glab &>/dev/null; then
		echo -e "${yellow}⚠ glab not installed - skipping GitLab sync${reset}"
		return 0
	fi
	if [[ ! -d "$repos_dir" ]]; then
		echo -e "${dim}Creating $repos_dir for GitLab repos${reset}"
		mkdir -p "$repos_dir"
	fi

	# Create temp files/dirs upfront for clean trap-based cleanup
	local tmpdir stale_branches_dir active_branches_dir clone_errors sync_errors stale_branches_file active_branches_file
	tmpdir=$(mktemp -d)
	stale_branches_dir=$(mktemp -d)
	active_branches_dir=$(mktemp -d)
	clone_errors=$(mktemp)
	sync_errors=$(mktemp)
	stale_branches_file=$(mktemp)
	active_branches_file=$(mktemp)
	trap 'rm -rf "${tmpdir:-}" "${stale_branches_dir:-}" "${active_branches_dir:-}" "${clone_errors:-}" "${sync_errors:-}" "${stale_branches_file:-}" "${active_branches_file:-}"' RETURN

	# Fetch repo list from GitLab
	echo -e "${bold}› Fetching repo list from GitLab${reset}"
	local total_pages remote_repos glab_response

	# Test glab authentication, offer login if needed
	if ! glab_response=$(glab api "groups/$GITLAB_GROUP/projects?per_page=100&page=1&include_subgroups=true&archived=false" --include 2>&1); then
		if [[ "$glab_response" == *"auth"* || "$glab_response" == *"401"* || "$glab_response" == *"login"* ]]; then
			echo -e "${yellow}⚠ GitLab authentication required${reset}"
			prompt "Run glab auth login? [Y/n]:"
			read -r -n 1 do_login </dev/tty
			echo ""
			if [[ ! "$do_login" =~ ^[Nn]$ ]]; then
				glab auth login </dev/tty || {
					echo -e "${yellow}⚠ Login failed - skipping GitLab sync${reset}"
					return 0
				}
				# Retry after login
				if ! glab_response=$(glab api "groups/$GITLAB_GROUP/projects?per_page=100&page=1&include_subgroups=true&archived=false" --include 2>&1); then
					echo -e "${yellow}⚠ Still unable to fetch repos after login${reset}"
					echo -e "${dim}$glab_response${reset}"
					return 0
				fi
			else
				echo -e "${dim}· Skipping GitLab sync${reset}"
				return 0
			fi
		else
			echo -e "${yellow}⚠ Failed to fetch repos from GitLab${reset}"
			echo -e "${dim}$glab_response${reset}"
			return 0
		fi
	fi

	total_pages=$(echo "$glab_response" | grep -i '^x-total-pages:' | tr -d '[:space:]' | cut -d: -f2 || true)
	total_pages=${total_pages:-1}

	seq 1 "$total_pages" | xargs -P "$parallel_jobs" -I{} sh -c \
		'glab api "groups/'"$GITLAB_GROUP"'/projects?per_page=100&page={}&include_subgroups=true&archived=false" 2>/dev/null > "$1/page_{}.json" && printf "."' _ "$tmpdir"
	echo ""

	# Validate we got data before parsing
	if ! ls "$tmpdir"/page_*.json &>/dev/null; then
		echo -e "${yellow}⚠ Failed to fetch repos from GitLab${reset}"
		return 0
	fi
	remote_repos=$(jq -s 'add | .[] | select(.empty_repo == false) | .path_with_namespace' -r "$tmpdir"/page_*.json 2>/dev/null | sed "s|^$GITLAB_GROUP/||" | sort -u || true)
	if [[ -z "$remote_repos" ]]; then
		echo -e "${yellow}⚠ Failed to parse repo list from GitLab${reset}"
		return 0
	fi
	info "Found ${bold}$(_count_lines "$remote_repos")${reset}${dim} repos on GitLab"

	# Filter remote repos with the same exclusions used for local scanning
	if [[ -n "${GITLAB_EXCLUDE_DIRS:-}" ]]; then
		remote_repos=$(echo "$remote_repos" | grep -Ev "^($GITLAB_EXCLUDE_DIRS)/" || true)
	fi
	echo ""

	local repo_list local_repos
	repo_list=$(_find_repos)
	local_repos=$(echo "$repo_list" | sed "s|^$repos_dir/||" | sort)

	# Clone new repos
	echo -e "${bold}› Cloning new repos${reset}"
	local new_repos
	new_repos=$(comm -13 <(echo "$local_repos") <(echo "$remote_repos"))

	if [[ -n "$new_repos" ]]; then
		action "Cloning ${bold}${green}$(_count_lines "$new_repos")${reset}${sky} new repos..."
		echo "$new_repos" | xargs -P "$parallel_jobs" -I{} sh -c \
			'"$1/sync/clone_repo.sh" "$2" "$3" "$4" 2>>"$5"' _ \
			"$SETUP" {} "$repos_dir" "$GITLAB_GROUP" "$clone_errors"
		if [[ -s "$clone_errors" ]]; then
			local fail_count
			fail_count=$(wc -l <"$clone_errors" | tr -d ' ')
			echo -e "${yellow}⚠ Failed to clone ${fail_count} repo(s):${reset}"
			# Group by reason (text after first ": ")
			sort -t: -k2 "$clone_errors" | while IFS= read -r line; do
				echo -e "  ${dim}$line${reset}"
			done
		fi
		repo_list=$(_find_repos)
	else
		echo -e "${dim}· None${reset}"
	fi
	echo ""

	# Detect deleted repos
	echo -e "${bold}› Checking for deleted repos${reset}"
	local deleted_repos deleted_count
	deleted_repos=$(comm -23 <(echo "$local_repos") <(echo "$remote_repos"))

	if [[ -n "$deleted_repos" ]]; then
		deleted_count=$(_count_lines "$deleted_repos")
		# Safety: if deleting more than 10 repos, require extra confirmation
		if [[ "$deleted_count" -gt 10 ]]; then
			echo -e "${yellow}⚠ About to delete ${bold}${deleted_count}${reset}${yellow} repos - this seems high!${reset}"
			echo -e "${dim}$deleted_repos${reset}"
			echo ""
			prompt "Type 'yes' to confirm mass deletion:"
			read -r confirm </dev/tty
			[[ "$confirm" == "yes" ]] || {
				info "Aborted."
				deleted_repos=""
			}
		else
			echo -e "${yellow}Repos no longer on GitLab:${reset}"
			echo -e "${dim}$deleted_repos${reset}"
			echo ""
			prompt "Delete these? [y/N]:"
			read -r -n 1 confirm </dev/tty
			echo ""
			[[ "$confirm" =~ ^[Yy]$ ]] || deleted_repos=""
		fi
		if [[ -n "$deleted_repos" ]]; then
			echo "$deleted_repos" | while IFS= read -r repo; do
				[[ -z "$repo" ]] && continue
				# Safety: validate path is under repos_dir before deleting
				local target="$repos_dir/$repo"
				[[ "$target" == "$repos_dir"/* && -d "$target" ]] || continue
				# Worktrees first — their git entries point back into the clone, so
				# trashing the clone would leave them dangling and unremovable.
				local wt_target="$worktrees_dir/$repo"
				if [[ "$wt_target" == "$worktrees_dir"/* && -d "$wt_target" ]]; then
					echo -e "  ${dim}Removing worktrees for $repo${reset}"
					trash "$wt_target"
					_prune_worktree_parents "$wt_target" "$worktrees_dir"
				fi
				trash "$target"
			done
			repo_list=$(_find_repos)
		fi
	else
		echo -e "${dim}· None${reset}"
	fi
	echo ""

	# Sync all repos
	echo -e "${bold}› Syncing repos${reset}"
	echo "$repo_list" | xargs -P "$parallel_jobs" -I{} sh -c \
		'"$1/sync/sync_repo.sh" "$2" "$3" "$4" "$5" || echo "$2" >> "$6"' _ \
		"$SETUP" {} "$repos_dir" "$stale_branches_dir" "$active_branches_dir" "$sync_errors"
	if [[ -s "$sync_errors" ]]; then
		echo -e "${yellow}⚠ Failed to sync some repos:${reset}"
		sed 's|^'"$repos_dir"'/||; s/^/  /' "$sync_errors"
	fi
	echo ""

	# Aggregate from all sync processes
	cat "$stale_branches_dir"/* 2>/dev/null >"$stale_branches_file" || true
	cat "$active_branches_dir"/* 2>/dev/null >"$active_branches_file" || true

	# Prompt to delete stale branches
	if [[ -s "$stale_branches_file" ]]; then
		echo -e "${bold}› Stale branches (merged/deleted upstream)${reset}"
		local stale_count
		stale_count=$(wc -l <"$stale_branches_file" | tr -d ' ')
		info "Found ${bold}${yellow}${stale_count}${reset}${dim} stale branch(es)"
		echo ""
		# Third field is the worktree holding the branch, empty for mainline branches
		while IFS=: read -r repo branch wt; do
			if [[ -n "$wt" ]]; then
				printf "${bold}Delete ${yellow}%s${reset}${bold} from ${coral}%s${reset} ${dim}(worktree)${reset}${bold}? [y/N]:${reset} " "$branch" "$repo"
			else
				printf "${bold}Delete ${yellow}%s${reset}${bold} from ${coral}%s${reset}${bold}? [y/N]:${reset} " "$branch" "$repo"
			fi
			read -r -n 1 confirm </dev/tty
			echo ""
			if [[ "$confirm" =~ ^[Yy]$ ]]; then
				# The worktree has to go first: git refuses `branch -D` for a branch
				# that is checked out anywhere. Upstream is gone, so nothing to push.
				if [[ -n "$wt" && "$wt" == "$worktrees_dir"/* ]]; then
					git -C "$repos_dir/$repo" worktree remove --force "$wt" 2>/dev/null ||
						echo -e "  ${yellow}⚠ Failed to remove worktree $wt${reset}"
					_prune_worktree_parents "$wt" "$worktrees_dir"
				fi
				git -C "$repos_dir/$repo" branch -D "$branch" 2>/dev/null &&
					echo -e "  ${green}✓ Deleted${reset}" ||
					echo -e "  ${yellow}⚠ Failed to delete${reset}"
			else
				echo -e "  ${dim}– Skipped${reset}"
			fi
		done <"$stale_branches_file"
		echo ""
	fi

	# Show repos with active feature branches (unmerged work) and live worktrees
	if [[ -s "$active_branches_file" ]]; then
		echo -e "${bold}› Active work${reset}"
		while IFS=: read -r repo branch wt; do
			if [[ -n "$wt" ]]; then
				printf "  ${coral}%s${reset} → ${coral}%s${reset} ${dim}(worktree)${reset}\n" "$repo" "$branch"
			else
				printf "  ${coral}%s${reset} → ${coral}%s${reset}\n" "$repo" "$branch"
			fi
		done < <(sort "$active_branches_file")
		echo ""
	fi
}
