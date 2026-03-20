#!/opt/homebrew/bin/bash

# ------------------------------------------------------------------------------------ #
# !                                STAY AWAY, SECRETS!
# This file is committed to version control and used by both Bash and Zsh.
# Add secrets and device specific configuration to ~/.env.sh instead.
# Compatibility must be maintained with both Bash and Zsh.
# ------------------------------------------------------------------------------------ #

# Morning routine: sync GitLab repos and update dev tools.
# Can be run from any directory.
#
# Configuration (set in ~/.env.sh):
#   MORNING_GITLAB_GROUP  - GitLab group/namespace to sync (e.g., "mycompany")
#   MORNING_EXCLUDE_DIRS  - Pipe-separated dirs to exclude (optional, e.g., "unsynced|bugs")
#
# Repos sync to ~/work (hardcoded to match Claude sandbox permissions).
#
# Steps:
#   1. Clone any new repos from GitLab group
#   2. Detect repos deleted from GitLab, prompt to remove locally
#   3. Sync all repos in parallel (fetch + pull develop/main)
#   3b. Prompt to delete stale branches (local branches merged/deleted upstream)
#   4. Run brew upgrade and other tool updates
morning() {
	local repos_dir="$HOME/work"
	local parallel_jobs=$(($(sysctl -n hw.ncpu) * 2)) # 2x CPU cores for I/O-bound git ops

	# Colors
	local reset='\033[0m'
	local bold='\033[1m'
	local dim='\033[2m'
	local green='\033[32m'
	local yellow='\033[33m'
	local cyan='\033[36m'

	# Build exclude args for fd from MORNING_EXCLUDE_DIRS (pipe-separated)
	local exclude_args=()
	if [[ -n "${MORNING_EXCLUDE_DIRS:-}" ]]; then
		while IFS= read -r dir; do
			exclude_args+=(--exclude "$dir")
		done < <(echo "$MORNING_EXCLUDE_DIRS" | tr '|' '\n')
	fi

	# Helper: find all git repos, excluding configured directories
	_find_repos() {
		fd --type d --hidden '^\.git$' "$repos_dir" "${exclude_args[@]}" |
			sed -E 's|/\.git/?$||'
	}

	# Helper: count lines (returns 0 for empty string, not 1)
	_count_lines() {
		if [[ -z "$1" ]]; then echo 0; else echo "$1" | wc -l | tr -d ' '; fi
	}

	# Check GitLab sync configuration
	local gitlab_configured=true
	if [[ -z "${MORNING_GITLAB_GROUP:-}" ]]; then
		echo -e "${dim}MORNING_GITLAB_GROUP not set - skipping GitLab sync${reset}"
		gitlab_configured=false
	elif [[ ! -d "$repos_dir" ]]; then
		echo -e "${yellow}Warning: $repos_dir does not exist - skipping GitLab sync${reset}"
		echo -e "${dim}Create it with: mkdir ~/work${reset}"
		gitlab_configured=false
	fi

	echo -e "${bold}${cyan}=== Starting the day ===${reset}"
	echo ""

	if [[ "$gitlab_configured" == "true" ]]; then
		# --- Fetch repo list from GitLab ---
		echo -e "${bold}${cyan}=== Fetching repo list from GitLab ===${reset}"
		local remote_repos tmpdir total_pages
		tmpdir=$(mktemp -d)
		# Cleanup temp dir on exit or error
		trap 'rm -rf "$tmpdir"' EXIT
		# Get total page count from first request headers
		total_pages=$(glab api "groups/$MORNING_GITLAB_GROUP/projects?per_page=100&page=1&include_subgroups=true" --include 2>/dev/null | grep -i '^x-total-pages:' | tr -d '[:space:]' | cut -d: -f2)
		total_pages=${total_pages:-1}
		# Fetch all pages in parallel, print dot as each completes
		seq 1 "$total_pages" | xargs -P "$parallel_jobs" -I{} sh -c \
			'glab api "groups/'"$MORNING_GITLAB_GROUP"'/projects?per_page=100&page={}&include_subgroups=true" 2>/dev/null > "$1/page_{}.json" && printf "."' _ "$tmpdir"
		echo ""
		# Combine all pages and extract repo paths
		remote_repos=$(cat "$tmpdir"/page_*.json | jq -s 'add | .[].path_with_namespace' -r 2>/dev/null | sed "s|^$MORNING_GITLAB_GROUP/||" | sort -u)
		trap - EXIT
		rm -rf "$tmpdir"
		echo -e "Found ${bold}$(_count_lines "$remote_repos")${reset} repos on GitLab"
		echo ""

		# --- Build local repo list ---
		local repo_list local_repos
		repo_list=$(_find_repos)
		local_repos=$(echo "$repo_list" | sed "s|^$repos_dir/||" | sort)

		# --- Step 1: Clone new repos ---
		# comm -13: lines only in second file (remote but not local = new)
		echo -e "${bold}${cyan}=== Cloning new repos ===${reset}"
		local new_repos
		new_repos=$(comm -13 <(echo "$local_repos") <(echo "$remote_repos"))

		if [[ -n "$new_repos" ]]; then
			echo -e "Cloning ${bold}${green}$(_count_lines "$new_repos")${reset} new repos..."
			echo "$new_repos" | xargs -P "$parallel_jobs" -I{} "$DOTFILES/morning_clone.sh" {} "$repos_dir" "$MORNING_GITLAB_GROUP"
			# Rebuild repo list to include newly cloned repos
			repo_list=$(_find_repos)
		else
			echo -e "${dim}None${reset}"
		fi
		echo ""

		# --- Step 2: Detect deleted repos ---
		# comm -23: lines only in first file (local but not remote = deleted)
		echo -e "${bold}${cyan}=== Checking for deleted repos ===${reset}"
		local deleted_repos
		deleted_repos=$(comm -23 <(echo "$local_repos") <(echo "$remote_repos"))

		if [[ -n "$deleted_repos" ]]; then
			echo -e "${yellow}Repos no longer on GitLab:${reset}"
			echo -e "${dim}$deleted_repos${reset}"
			echo ""
			echo -n "Delete these? [y/N]: "
			read -r confirm
			if [[ "$confirm" =~ ^[Yy]$ ]]; then
				# Use trash (not rm) for safety - can recover from ~/.Trash
				echo "$deleted_repos" | xargs -I{} trash "$repos_dir/{}"
				# Rebuild repo list after deletion
				repo_list=$(_find_repos)
			fi
		else
			echo -e "${dim}None${reset}"
		fi
		echo ""

		# --- Step 3: Sync all repos in parallel ---
		echo -e "${bold}${cyan}=== Syncing repos ===${reset}"
		local stale_branches_file
		stale_branches_file=$(mktemp)
		echo "$repo_list" | xargs -P "$parallel_jobs" -I{} "$DOTFILES/morning_sync.sh" {} "$repos_dir" "$stale_branches_file"
		echo ""

		# --- Step 3b: Prompt to delete stale branches ---
		if [[ -s "$stale_branches_file" ]]; then
			echo -e "${bold}${cyan}=== Stale branches (merged/deleted upstream) ===${reset}"
			local stale_count
			stale_count=$(wc -l <"$stale_branches_file" | tr -d ' ')
			echo -e "Found ${bold}${yellow}${stale_count}${reset} stale branch(es)"
			echo ""
			while IFS=: read -r repo branch; do
				echo -n "Delete ${yellow}${branch}${reset} from ${cyan}${repo}${reset}? [y/N]: "
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
		rm -f "$stale_branches_file"
	fi

	# --- Step 4: Update Homebrew packages ---
	echo -e "${bold}${cyan}=== Running brew upgrade ===${reset}"
	brew upgrade
	echo ""

	# --- Step 5: Update this setup repo ---
	echo -e "${bold}${cyan}=== Updating setup repo ===${reset}"
	git -C "$SETUP" pull
	echo ""

	# --- Step 6: Update uv tools ---
	echo -e "${bold}${cyan}=== Updating uv tools ===${reset}"
	uv tool upgrade --all || echo -e "${yellow}Warning: uv tool upgrade failed${reset}"
	echo ""

	# --- Step 7: Update tldr pages ---
	echo -e "${bold}${cyan}=== Updating tldr pages ===${reset}"
	tldr --update || echo -e "${yellow}Warning: tldr update failed${reset}"
	echo ""

	# --- Step 8: Update Oh My Zsh ---
	echo -e "${bold}${cyan}=== Updating Oh My Zsh ===${reset}"
	"$ZSH/tools/upgrade.sh" || echo -e "${yellow}Warning: Oh My Zsh update failed${reset}"
	echo ""

	# --- Step 9: Update Node.js ---
	echo -e "${bold}${cyan}=== Updating Node.js ===${reset}"
	export NVM_DIR="$HOME/.nvm"
	# shellcheck disable=SC1091
	[ -s "$HOMEBREW_PREFIX/opt/nvm/nvm.sh" ] && \. "$HOMEBREW_PREFIX/opt/nvm/nvm.sh"
	nvm install --lts --latest-npm --reinstall-packages-from=current || echo -e "${yellow}Warning: Node update failed${reset}"
	echo ""

	# --- Step 10: Update Go tools ---
	echo -e "${bold}${cyan}=== Updating Go tools ===${reset}"
	go install golang.org/x/tools/gopls@latest || echo -e "${yellow}Warning: gopls update failed${reset}"
	go install honnef.co/go/tools/cmd/staticcheck@latest || echo -e "${yellow}Warning: staticcheck update failed${reset}"
	echo ""

	# --- Step 11: Update VSCode extensions ---
	echo -e "${bold}${cyan}=== Updating VSCode extensions ===${reset}"
	if command -v code &>/dev/null; then
		local extensions ext_count
		extensions=$(code --list-extensions)
		ext_count=$(_count_lines "$extensions")
		echo -n "Updating ${bold}${ext_count}${reset} extensions "
		echo "$extensions" | while IFS= read -r ext; do
			[[ -n "$ext" ]] && code --install-extension "$ext" --force >/dev/null && printf "."
		done
		echo ""
	else
		echo -e "${yellow}Warning: VSCode CLI not found${reset}"
	fi

	echo ""
	echo -e "${bold}${green}=== Done! ===${reset}"
}
