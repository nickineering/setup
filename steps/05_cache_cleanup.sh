# shellcheck shell=bash
# shellcheck disable=SC2034,SC2154
#
# Purges caches across package managers (Homebrew, npm, uv, Go, nvm, pip,
# Poetry) and developer tooling (pre-commit, dprint, tldr, gh, puppeteer,
# Playwright, Cypress, node-gyp, Copilot, pyright).
# Gated on --clean flag — skipped on normal runs to keep things fast.
#
# Caches that come back on their own are cleared outright. Caches whose recovery
# costs real time — a reinstall, a re-download of every wheel, a rebuild of every
# hook environment — are prompted for individually, in one block near the end,
# and default to being kept. Answering no to all of them is fine; the unprompted
# section has already reclaimed everything that costs nothing.
#
# Deliberately NOT touched:
#   - pypoetry/virtualenvs, which are project environments rather than cache
#   - browser and Electron profile caches (Chrome, Slack, Code, Postman): those
#     belong to running apps, and deleting them underneath a live process can
#     take the profile with them
#   - Docker.raw, which holds images and named volumes, not cache
: "${CLEAN_CACHES?}"

if [[ "$CLEAN_CACHES" != "true" ]]; then
	info "Skipped (use --clean to purge caches)"
else
	disk_before=$(df -k / | awk 'NR==2 {print $4}')
	trashed_kb=0

	# trash, not rm: the PATH wrapper blocks rm outside the temp dirs, so an rm
	# here silently did nothing and printed "BLOCKED (wrapper)" after the step's
	# own success summary. The trade-off is that trashed bytes are not actually
	# free until the Trash is emptied, so they are tallied separately and
	# reported as pending rather than folded into the freed total.
	# The `|| true` is load-bearing: run.sh sets -euo pipefail and sources this
	# file, so a non-zero pipeline here aborts the entire run. `du -sk` exits 1
	# on a permission-denied entry or on a file that vanishes mid-scan, both
	# routine in a live cache tree, and stderr is discarded — the run would die
	# at step 5 with steps 6-13 never executing and nothing printed.
	size_kb() {
		local size
		[[ -e "$1" ]] || {
			printf '0'
			return 0
		}
		size=$(du -sk "$1" 2>/dev/null | awk '{print $1}') || true
		printf '%s' "${size:-0}"
	}

	human_kb() {
		if [[ $1 -ge 1048576 ]]; then
			awk "BEGIN {printf \"%.1f GB\", $1/1048576}"
		elif [[ $1 -ge 1024 ]]; then
			awk "BEGIN {printf \"%.0f MB\", $1/1024}"
		else
			printf '%s KB' "$1"
		fi
	}

	purge_path() {
		local target="$1" label="$2" size
		[[ -e "$target" ]] || return 0
		size=$(size_kb "$target")
		trash "$target" >/dev/null 2>&1 || return 0
		trashed_kb=$((trashed_kb + size))
		info "$label"
	}

	# Version directories under $1 that are neither the newest nor named in the
	# trailing arguments. These tools keep one directory per release and never
	# remove the old ones; sort -V orders them by version.
	stale_versions() {
		local parent="$1"
		shift
		local -a protected=("$@")
		local dir base newest keeper
		[[ -d "$parent" ]] || return 0
		# `head -1` closes the pipe, so sort takes SIGPIPE (141) once the listing
		# outgrows the pipe buffer, and pipefail would turn that into a whole-run
		# abort. head has already captured the line it needed by then.
		newest=$(find "$parent" -mindepth 1 -maxdepth 1 -type d 2>/dev/null |
			sort -Vr | head -1) || true
		while IFS= read -r dir; do
			[[ -n "$dir" && "$dir" != "$newest" ]] || continue
			base=$(basename "$dir")
			for keeper in "${protected[@]+"${protected[@]}"}"; do
				[[ "$base" == "$keeper" ]] && continue 2
			done
			printf '%s\n' "$dir"
		done < <(find "$parent" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort -Vr)
	}

	prune_versions() {
		local parent="$1" label="$2"
		shift 2
		local dir
		while IFS= read -r dir; do
			[[ -n "$dir" ]] || continue
			purge_path "$dir" "$label: removed $(basename "$dir")"
		done < <(stale_versions "$parent" "$@")
	}

	# Highest installed version whose directory name matches $1 ("" means any).
	nvm_newest_matching() {
		local prefix="$1" dir base
		while IFS= read -r dir; do
			[[ -n "$dir" ]] || continue
			base=$(basename "$dir")
			[[ -z "$prefix" || "$base" == "$prefix" || "$base" == "$prefix".* ]] || continue
			printf '%s' "$base"
			return 0
		done < <(find "$HOME/.nvm/versions/node" -mindepth 1 -maxdepth 1 -type d \
			2>/dev/null | sort -Vr)
	}

	# `nvm alias default` is a chain of indirections — default -> lts/* ->
	# lts/krypton -> v24.21.0 — and its target is not necessarily the newest
	# version installed: a v25 Current release would sort above the v24 LTS line
	# that default points at, and pruning to the newest alone would delete the
	# default out from under nvm.
	#
	# The chain does not have to end in a directory name. `nvm alias default 24`
	# leaves "24", and "node"/"stable" are moving targets, so anything that is
	# not already a full vX.Y.Z is resolved against what is installed. Returning
	# the wrong thing here is silent: prune_versions would simply protect
	# nothing and trash the default.
	nvm_default_version() {
		local alias_dir="$HOME/.nvm/alias" ref="default" hops=0
		while [[ -f "$alias_dir/$ref" && $hops -lt 10 ]]; do
			ref=$(<"$alias_dir/$ref")
			((hops++))
		done
		case "$ref" in
		v*.*.*) printf '%s' "$ref" ;;
		v*) nvm_newest_matching "$ref" ;;
		[0-9]*) nvm_newest_matching "v$ref" ;;
		node | stable | latest | '') nvm_newest_matching "" ;;
		esac
	}

	# Defaults to no, and a run with no terminal keeps everything: the cost of a
	# wrong answer here is a manual reinstall, so it has to be chosen
	# deliberately. Reads /dev/tty rather than stdin because run.sh may itself be
	# driven with stdin redirected, which would otherwise consume the answer.
	#
	# Shape copied from lib/packages.sh and steps/12_privileged.sh: prompt() for
	# the bold styling, a single keypress with no Enter, and an echo to end the
	# line that the keypress does not terminate. Named confirm_purge rather than
	# confirm because step files are sourced into run.sh's shell, so the name
	# would outlive this step and sit next to the $confirm those callers use.
	confirm_purge() {
		local question="$1" reply
		# Opening /dev/tty for real, because `[[ -r /dev/tty ]]` is a false
		# positive: the device node is readable by mode even when the process has
		# no controlling terminal, and the open then fails with "Device not
		# configured". The check has to come before prompt() or a non-interactive
		# run prints a question nobody can answer. stderr is redirected first on
		# purpose — redirections apply left to right, so `</dev/tty 2>/dev/null`
		# fails before the 2> is ever installed and the error still leaks.
		: 2>/dev/null </dev/tty || return 1
		prompt "$question [y/N]:"
		read -r -n 1 reply </dev/tty || {
			echo ""
			return 1
		}
		echo ""
		[[ "$reply" =~ ^[Yy]$ ]]
	}

	# Asks about one group of paths and trashes them on a yes. $3 is a
	# newline-separated path list; blank entries and paths that do not exist are
	# ignored, and a group that totals nothing is skipped without a prompt so
	# the run does not ask about caches that are already gone.
	purge_group() {
		local label="$1" recovery="$2" paths="$3" total=0 path
		while IFS= read -r path; do
			[[ -n "$path" ]] || continue
			total=$((total + $(size_kb "$path")))
		done <<<"$paths"
		[[ $total -gt 0 ]] || return 0
		if ! confirm_purge "Clear $label ($(human_kb "$total"))? Restored with: $recovery"; then
			info "$label: kept"
			return 0
		fi
		while IFS= read -r path; do
			[[ -n "$path" ]] || continue
			purge_path "$path" "$label: removed $(basename "$path")"
		done <<<"$paths"
	}

	# Prompts like purge_group, but empties the cache with the tool's own command
	# instead of trashing the directory, so the space comes back immediately.
	# $3 is only measured, to size the prompt; everything after it is the command.
	#
	# Always returns 0. run.sh sources this file under errexit, and these calls
	# sit at the end of an `if` body, so a non-zero return would abort the run.
	purge_group_native() {
		local label="$1" recovery="$2" path="$3"
		shift 3
		local total
		total=$(size_kb "$path")
		[[ $total -gt 0 ]] || return 0
		if ! confirm_purge "Clear $label ($(human_kb "$total"))? Restored with: $recovery"; then
			info "$label: kept"
			return 0
		fi
		if "$@" >/dev/null 2>&1; then
			info "$label: cleared, $(human_kb "$total") freed"
		else
			warn "$label: '$*' failed, cache left alone"
		fi
		return 0
	}

	# --- Caches with a tool-native purge -------------------------------------
	# These unlink directly rather than shelling out to rm, so the space comes
	# back immediately and the wrapper never sees them.
	# --prune=all, not --prune=7: the 7-day window only prunes downloads older
	# than a week, which left 4.5 GB of bottle tarballs sitting in
	# Homebrew/downloads indefinitely. Nothing installed depends on them — they
	# are the archives a formula was unpacked from, needed again only if you
	# reinstall or roll back that exact version, so this stays unprompted.
	cleanup_output=$(brew cleanup --prune=all 2>&1)
	if [[ -z "$cleanup_output" ]]; then
		info "Homebrew: cache already clean"
	else
		echo "$cleanup_output"
	fi
	npm cache clean --force >/dev/null 2>&1 && info "npm: cache cleared"
	command -v uv &>/dev/null && uv cache prune >/dev/null 2>&1 && info "uv: cache pruned"
	command -v go &>/dev/null && go clean -cache >/dev/null 2>&1 && info "Go: build cache cleared"
	pip cache purge >/dev/null 2>&1 && info "pip: cache cleared"

	# Clears cache/ and artifacts/ but leaves virtualenvs/ intact, which is why
	# this is the tool-native call and not a directory purge.
	if command -v poetry &>/dev/null; then
		while IFS= read -r poetry_cache; do
			[[ -n "$poetry_cache" ]] || continue
			poetry cache clear --all -n "$poetry_cache" >/dev/null 2>&1
		done < <(poetry cache list 2>/dev/null)
		info "Poetry: caches cleared"
	fi

	command -v pre-commit &>/dev/null && pre-commit gc >/dev/null 2>&1 &&
		info "pre-commit: unused hook repos collected"
	command -v dprint &>/dev/null && dprint clear-cache >/dev/null 2>&1 &&
		info "dprint: plugin cache cleared"
	command -v tldr &>/dev/null && tldr --clear-cache >/dev/null 2>&1 &&
		info "tldr: page cache cleared"

	# --- Caches that come back on their own ----------------------------------
	# Re-fetched automatically the next time the tool needs them, so these are
	# cleared without asking.
	prune_versions ~/.cache/pyright-python "pyright"
	# nvm's own `nvm cache clear` would be the match for the tool-native calls
	# above, but nvm is a shell function and is not sourced here.
	purge_path ~/.nvm/.cache "nvm: download cache cleared"
	purge_path ~/Library/Caches/node-gyp "node-gyp: header cache cleared"
	purge_path ~/Library/Caches/copilot/pkg "Copilot: package cache cleared"
	purge_path ~/Library/Caches/virtualenv "virtualenv: cache cleared"
	purge_path ~/.cache/gh "gh: cache cleared"

	# --- Caches that need an explicit reinstall ------------------------------
	# None of these come back on demand: the tool errors out until a reinstall
	# command is run. Each is asked about separately, and they are grouped here
	# so all the prompting happens in one place instead of being scattered
	# through the run. Declining every one of them is a valid outcome — the
	# section above has already reclaimed everything that costs nothing.

	# Globals live under the version that owns them and go with it. The newest
	# and whatever `default` resolves to are both protected, so their globals
	# survive. A repo pinning an older line in .nvmrc needs that version
	# reinstalled first: `nvm use` on a pruned version fails with
	# "N/A: version ... is not yet installed" rather than fetching it.
	purge_group "stale Node toolchains" "nvm install <version>" \
		"$(stale_versions "$HOME/.nvm/versions/node" "$(nvm_default_version)")"

	# puppeteer pins a Chrome build per package version, so an older revision can
	# still be the one some project expects. The newest is kept either way.
	purge_group "stale puppeteer browser revisions" "npx puppeteer browsers install chrome" \
		"$(stale_versions "$HOME/.cache/puppeteer/chrome")
$(stale_versions "$HOME/.cache/puppeteer/chrome-headless-shell")"

	# Unlike the two above, these hold only the current build, so clearing them
	# always costs a re-download rather than only affecting stale copies.
	purge_group "Playwright browser bundles" "npx playwright install" \
		"$HOME/Library/Caches/ms-playwright"
	purge_group "Cypress binaries" "cypress install" \
		"$HOME/Library/Caches/Cypress"

	# `uv cache prune` above only evicts entries uv considers unused, which left
	# 4.7 GB of wheels and source dists behind. `clean` empties the lot. Nothing
	# breaks, but the next resolve in every Python project re-downloads, so it is
	# asked about rather than assumed.
	if command -v uv &>/dev/null; then
		purge_group_native "the whole uv cache" "the next uv sync or uv pip install" \
			"$HOME/.cache/uv" uv cache clean
	fi

	# `pre-commit gc` above only collects repos no installed hook references.
	# `clean` removes the built hook environments too, and rebuilding them means
	# recreating virtualenvs and recompiling — minutes per repo, not seconds.
	if command -v pre-commit &>/dev/null; then
		purge_group_native "pre-commit hook environments" "pre-commit install-hooks" \
			"$HOME/.cache/pre-commit" pre-commit clean
	fi

	# --- Summary --------------------------------------------------------------
	disk_after=$(df -k / | awk 'NR==2 {print $4}')
	freed_kb=$((disk_after - disk_before))

	if [[ $freed_kb -gt 0 ]]; then
		success "Freed $(human_kb "$freed_kb")"
	elif [[ $trashed_kb -eq 0 ]]; then
		info "Caches already clean"
	fi
	if [[ $trashed_kb -gt 0 ]]; then
		info "$(human_kb "$trashed_kb") moved to Trash — empty it to reclaim the space"
	fi
fi
echo ""
