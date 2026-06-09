# shellcheck shell=bash
# shellcheck disable=SC2034,SC2154
#
# ── Cache Cleanup ────────────────────────────────────────────────────────────
# Purges caches across all package managers (Homebrew, npm, uv, Go, nvm, pip).
# Gated on --clean flag — skipped entirely on normal runs to keep things fast.
# Reports total disk freed at the end.
# ─────────────────────────────────────────────────────────────────────────────

if [[ "$CLEAN_CACHES" == "true" ]]; then
	CURRENT_STEP="cleaning caches"
	echo -e "${bold}${cyan}=== Cleaning caches ===${reset}"
	disk_before=$(df -k / | awk 'NR==2 {print $4}')
	cleanup_output=$(brew cleanup --prune=7 2>&1)
	if [[ -z "$cleanup_output" ]]; then
		echo -e "${dim}Homebrew: cache already clean${reset}"
	else
		echo "$cleanup_output"
	fi
	npm cache clean --force >/dev/null 2>&1 && echo -e "${dim}npm: cache cleared${reset}"
	command -v uv &>/dev/null && uv cache prune >/dev/null 2>&1 && echo -e "${dim}uv: cache pruned${reset}"
	command -v go &>/dev/null && go clean -cache >/dev/null 2>&1 && echo -e "${dim}Go: build cache cleared${reset}"
	[[ -d ~/.nvm/.cache ]] && rm -rf ~/.nvm/.cache && echo -e "${dim}nvm: cache cleared${reset}"
	pip cache purge >/dev/null 2>&1 && echo -e "${dim}pip: cache cleared${reset}"
	disk_after=$(df -k / | awk 'NR==2 {print $4}')
	freed_mb=$(((disk_after - disk_before) / 1024))
	if [[ $freed_mb -gt 0 ]]; then
		if [[ $freed_mb -ge 1024 ]]; then
			echo -e "${green}Freed $(awk "BEGIN {printf \"%.1f\", $freed_mb/1024}") GB${reset}"
		else
			echo -e "${green}Freed ${freed_mb} MB${reset}"
		fi
	else
		echo -e "${dim}Caches already clean${reset}"
	fi
	echo ""
fi
