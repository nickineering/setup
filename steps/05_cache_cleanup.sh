# shellcheck shell=bash
# shellcheck disable=SC2034,SC2154
#
# ── Cache Cleanup ────────────────────────────────────────────────────────────
# Purges caches across all package managers (Homebrew, npm, uv, Go, nvm, pip).
# Gated on --clean flag — skipped entirely on normal runs to keep things fast.
# Reports total disk freed at the end.
# Requires: run.sh (CLEAN_CACHES)
# ─────────────────────────────────────────────────────────────────────────────
: "${CLEAN_CACHES?}"

if [[ "$CLEAN_CACHES" == "true" ]]; then
	CURRENT_STEP="cleaning caches"
	echo -e "${bold}Cleaning caches${reset}"
	disk_before=$(df -k / | awk 'NR==2 {print $4}')
	cleanup_output=$(brew cleanup --prune=7 2>&1)
	if [[ -z "$cleanup_output" ]]; then
		info "Homebrew: cache already clean"
	else
		echo "$cleanup_output"
	fi
	npm cache clean --force >/dev/null 2>&1 && info "npm: cache cleared"
	command -v uv &>/dev/null && uv cache prune >/dev/null 2>&1 && info "uv: cache pruned"
	command -v go &>/dev/null && go clean -cache >/dev/null 2>&1 && info "Go: build cache cleared"
	[[ -d ~/.nvm/.cache ]] && rm -rf ~/.nvm/.cache && info "nvm: cache cleared"
	pip cache purge >/dev/null 2>&1 && info "pip: cache cleared"
	disk_after=$(df -k / | awk 'NR==2 {print $4}')
	freed_mb=$(((disk_after - disk_before) / 1024))
	if [[ $freed_mb -gt 0 ]]; then
		if [[ $freed_mb -ge 1024 ]]; then
			success "Freed $(awk "BEGIN {printf \"%.1f\", $freed_mb/1024}") GB"
		else
			success "Freed ${freed_mb} MB"
		fi
	else
		info "Caches already clean"
	fi
	echo ""
fi
