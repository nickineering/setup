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

# The API takes a namespace as one path segment, so a nested group
# ("parent/child") has to arrive with its slashes escaped or it reads as a
# deeper route. Only the API needs this — clone paths stay literal.
_encode_group() {
	echo "${1//\//%2F}"
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

# A linked worktree keeps a .git file pointing back at its clone. Both have to
# hold: the file resolving to this very directory is what makes it live work.
# Liveness is asked of git itself rather than of the clone list, so a repo whose
# fetch failed this run can never have its worktrees called stale.
# Usage: _worktree_is_live <directory>
_worktree_is_live() {
	local top
	[[ -f "$1/.git" ]] || return 1
	top=$(git -C "$1" rev-parse --show-toplevel 2>/dev/null) || return 1
	[[ "$top" -ef "$1" ]]
}

# True when $1 holds at least one directory
_worktree_has_subdir() {
	local entry
	for entry in "$1"/*; do
		[[ -d "$entry" ]] && return 0
	done
	return 1
}

# The worktree slots of one clone: $1=DIRECTORY, $2=CLONE_PATH_RELATIVE_TO_REPOS,
# $3=REPOS_DIR. One level, never deeper — a slug's contents are a checkout, so
# walking into them would start calling source directories stale.
_scan_worktree_slots() {
	local dir="$1" rel="$2" repos="$3" slot name
	for slot in "$dir"/*; do
		[[ -d "$slot" ]] || continue
		name="${slot##*/}"
		# A clone nested under another clone's path keeps its own worktrees here.
		# GitLab cannot serve a project and a group at one path, so this only
		# happens for something cloned by hand, but its worktrees are still real.
		if [[ -d "$repos/$rel/$name/.git" ]]; then
			_scan_worktree_slots "$slot" "$rel/$name" "$repos"
			continue
		fi
		_worktree_is_live "$slot" && continue
		# A full clone is not a worktree and not this pass's business
		[[ -d "$slot/.git" ]] && continue
		# Empty scaffolding: nothing to lose, so take it without asking.
		# rmdir succeeding is itself the proof that it held nothing.
		rmdir "$slot" 2>/dev/null && continue
		printf 'orphan:::%s\n' "$slot"
	done
}

# Walk the mirrored part of the worktree tree: $1=DIRECTORY,
# $2=PATH_RELATIVE_TO_THE_WORKTREE_ROOT, $3=REPOS_DIR
_scan_worktree_tree() {
	local dir="$1" rel="$2" repos="$3" child name crel
	for child in "$dir"/*; do
		[[ -d "$child" ]] || continue
		name="${child##*/}"
		crel="${rel:+$rel/}$name"
		if [[ -d "$repos/$crel/.git" ]]; then
			# A clone, so everything directly below is one of its worktree slots
			_scan_worktree_slots "$child" "$crel" "$repos"
			# Leave nothing behind once a repo's last worktree goes
			rmdir "$child" 2>/dev/null && continue
			# Still standing with no worktree of any kind left in it: whatever is
			# in there is what blocked the tidy-up — the real case being an editor
			# workspace file sitting next to a removed worktree
			_worktree_has_subdir "$child" || printf 'leftover:::%s\n' "$child"
		elif [[ -d "$repos/$crel" ]]; then
			# A group on the way to a clone
			_scan_worktree_tree "$child" "$crel" "$repos"
			rmdir "$child" 2>/dev/null || true
		else
			# Nothing is cloned at this path any more, so nothing below it is live
			printf 'repo-gone:::%s\n' "$child"
		fi
	done
}

# Directories in the worktree tree that no longer hold live work: a worktree whose
# clone was deleted or re-cloned (which drops the admin data its .git file points
# at), or scaffolding a tidy-up could not remove because something untracked was
# left in it. sync_repo.sh cannot see these — they belong to no working clone — so
# they are found by walking the tree instead.
#
# The tree mirrors ~/work exactly, and the walk is anchored on the clones it finds
# there: a directory is a worktree slot because its parent is a clone, never
# because of its own name. Branch slugs collide with ordinary directory names —
# `git wt docs` in a repo that has docs/ is enough — so matching a slug against
# ~/work would walk straight into a live checkout and offer its source for
# deletion.
#
# Usage: _stale_worktree_dirs <worktrees_root> <repos_dir>
# Output: <reason>:::<path> — reason "orphan" (git cannot resolve it), "repo-gone"
# (nothing is cloned there any more) or "leftover" (a repo's worktree directory
# with no worktree left in it), with the repo and branch fields left empty so
# callers can read these and the sync's own stale worktree lines alike.
_stale_worktree_dirs() {
	local root="$1" repos="$2"
	[[ -d "$root" ]] || return 0
	_scan_worktree_tree "$root" "" "$repos"
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
	local tmpdir stale_branches_dir active_branches_dir stale_worktrees_dir clone_errors sync_errors stale_branches_file active_branches_file stale_worktrees_file
	tmpdir=$(mktemp -d)
	stale_branches_dir=$(mktemp -d)
	active_branches_dir=$(mktemp -d)
	stale_worktrees_dir=$(mktemp -d)
	clone_errors=$(mktemp)
	sync_errors=$(mktemp)
	stale_branches_file=$(mktemp)
	active_branches_file=$(mktemp)
	stale_worktrees_file=$(mktemp)
	trap 'rm -rf "${tmpdir:-}" "${stale_branches_dir:-}" "${active_branches_dir:-}" "${stale_worktrees_dir:-}" "${clone_errors:-}" "${sync_errors:-}" "${stale_branches_file:-}" "${active_branches_file:-}" "${stale_worktrees_file:-}"' RETURN

	# Fetch repo list from GitLab
	echo -e "${bold}› Fetching repo list from GitLab${reset}"
	local total_pages remote_repos glab_response group_api
	group_api=$(_encode_group "$GITLAB_GROUP")

	# Test glab authentication, offer login if needed
	if ! glab_response=$(glab api "groups/$group_api/projects?per_page=100&page=1&include_subgroups=true&archived=false" --include 2>&1); then
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
				if ! glab_response=$(glab api "groups/$group_api/projects?per_page=100&page=1&include_subgroups=true&archived=false" --include 2>&1); then
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
		'glab api "groups/'"$group_api"'/projects?per_page=100&page={}&include_subgroups=true&archived=false" 2>/dev/null > "$1/page_{}.json" && printf "."' _ "$tmpdir"
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
		'"$1/sync/sync_repo.sh" "$2" "$3" "$4" "$5" "$6" || echo "$2" >> "$7"' _ \
		"$SETUP" {} "$repos_dir" "$stale_branches_dir" "$active_branches_dir" \
		"$stale_worktrees_dir" "$sync_errors"
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

	# Prompt to delete stale worktrees. Runs after the stale-branch pass, which
	# removes the worktrees holding the branches it deletes — so those are already
	# gone from the tree by the time the scan below walks it.
	# Entries that are no longer a directory in the mirror's own tree are dropped
	# here rather than in the loop, so the count and the prompts cannot disagree
	{
		cat "$stale_worktrees_dir"/* 2>/dev/null || true
		_stale_worktree_dirs "$worktrees_dir" "$repos_dir"
	} | while IFS=: read -r reason repo branch wt; do
		[[ "$wt" == "$worktrees_dir"/* && -d "$wt" ]] || continue
		printf '%s:%s:%s:%s\n' "$reason" "$repo" "$branch" "$wt"
	done >"$stale_worktrees_file"
	if [[ -s "$stale_worktrees_file" ]]; then
		echo -e "${bold}› Stale worktrees (merged/orphaned)${reset}"
		local stale_wt_count
		stale_wt_count=$(wc -l <"$stale_worktrees_file" | tr -d ' ')
		info "Found ${bold}${yellow}${stale_wt_count}${reset}${dim} stale worktree(s)"
		echo ""
		# Path last so a colon in it cannot shift the fields that steer deletion
		while IFS=: read -r reason repo branch wt; do
			# Safety: only ever touch the mirror's own worktree tree
			[[ "$wt" == "$worktrees_dir"/* && -d "$wt" ]] || continue
			case "$reason" in
			merged | no-commits)
				local note ignored
				note="merged"
				[[ "$reason" == "no-commits" ]] && note="no commits of its own"
				# git's own clean/dirty test says nothing about ignored files, and
				# worktrees are created with .env and friends copied in, so say what
				# else goes. They are reproducible — `git wt` copies them again —
				# which is why this warns rather than holding the worktree back.
				ignored=$(git -C "$wt" status --porcelain --ignored 2>/dev/null |
					grep -c '^!!' || true)
				[[ "${ignored:-0}" -gt 0 ]] && note="$note, ${ignored} ignored file(s) go too"
				printf "${bold}Delete worktree ${yellow}%s${reset}${bold} from ${coral}%s${reset} ${dim}(%s)${reset}${bold}? [y/N]:${reset} " \
					"$branch" "$repo" "$note"
				;;
			repo-gone)
				printf "${bold}Trash worktrees at ${yellow}%s${reset} ${dim}(repo no longer cloned, contents unknown to git)${reset}${bold}? [y/N]:${reset} " \
					"${wt#"$worktrees_dir"/}"
				;;
			leftover)
				printf "${bold}Trash leftovers at ${yellow}%s${reset} ${dim}(no worktrees left in it)${reset}${bold}? [y/N]:${reset} " \
					"${wt#"$worktrees_dir"/}"
				;;
			*)
				# orphan: the directory is still there, but git cannot resolve it —
				# which also means nothing can be said about what is in it
				printf "${bold}Trash worktree ${yellow}%s${reset} ${dim}(no longer a git worktree, contents unknown to git)${reset}${bold}? [y/N]:${reset} " \
					"${wt#"$worktrees_dir"/}"
				;;
			esac
			read -r -n 1 confirm </dev/tty
			echo ""
			if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
				echo -e "  ${dim}– Skipped${reset}"
				continue
			fi
			if [[ "$reason" == "merged" || "$reason" == "no-commits" ]]; then
				# The worktree has to go first: git refuses `branch -D` for a branch
				# that is checked out anywhere. The branch holds nothing origin does
				# not already have, so it goes with it.
				#
				# No --force: these were classified clean, so git has no reason to
				# refuse, and leaving its refusals in place is the last check on a
				# classification made before the prompt — or on a worktree that has
				# been locked since.
				if git -C "$repos_dir/$repo" worktree remove "$wt" 2>/dev/null; then
					git -C "$repos_dir/$repo" branch -D "$branch" >/dev/null 2>&1 || true
					echo -e "  ${green}✓ Deleted${reset}"
				else
					echo -e "  ${yellow}⚠ Failed to remove worktree $wt${reset}"
					echo -e "  ${dim}Something changed in it since the sync — left alone${reset}"
				fi
			else
				# No clone still owns this directory, so git cannot remove it
				if trash "$wt"; then
					echo -e "  ${green}✓ Trashed${reset}"
				else
					echo -e "  ${yellow}⚠ Failed to delete $wt${reset}"
				fi
				# Drop the registration too, where there is still a clone to ask. A
				# leftover directory is the clone's own; everything else is one
				# worktree inside it.
				local owner
				if [[ "$reason" == "leftover" ]]; then
					owner="$repos_dir/${wt#"$worktrees_dir"/}"
				else
					owner="$repos_dir/$(dirname "${wt#"$worktrees_dir"/}")"
				fi
				if [[ -d "$owner/.git" ]]; then
					git -C "$owner" worktree prune 2>/dev/null || true
				fi
			fi
			_prune_worktree_parents "$wt" "$worktrees_dir"
		done <"$stale_worktrees_file"
		echo ""
	fi

	# Show repos with active feature branches (unmerged work) and live worktrees
	if [[ -s "$active_branches_file" ]]; then
		echo -e "${bold}› Active work${reset}"
		# Flags mark work a delete prompt would lose, which is why these are only
		# ever reported: dirty for uncommitted changes, +N for unpushed commits
		while IFS=: read -r repo branch flags wt; do
			local mark=""
			[[ -n "$flags" ]] && mark=" ${yellow}[$flags]${reset}"
			if [[ -n "$wt" ]]; then
				printf "  ${coral}%s${reset} → ${coral}%s${reset} ${dim}(worktree)${reset}%s\n" "$repo" "$branch" "$mark"
			else
				printf "  ${coral}%s${reset} → ${coral}%s${reset}%s\n" "$repo" "$branch" "$mark"
			fi
		done < <(sort "$active_branches_file")
		echo ""
	fi
}
