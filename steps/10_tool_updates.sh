# shellcheck shell=bash
# shellcheck disable=SC2034,SC2154
#
# ── Tool Updates ─────────────────────────────────────────────────────────────
# Updates uv, tldr, Oh My Zsh, and Go tools (gopls, staticcheck) concurrently.
# Each runs in a background subshell writing to a temp file; results are printed
# in a fixed order after all complete so output stays deterministic.
# ─────────────────────────────────────────────────────────────────────────────

tool_update_dir=$(mktemp -d)

if command -v uv &>/dev/null; then
	(
		uv_output=$(uv tool upgrade --all 2>&1) || echo -e "${yellow}Warning: uv tool upgrade failed${reset}"
		if [[ "$uv_output" == "Nothing to upgrade" ]]; then
			echo -e "${dim}uv tools: up to date${reset}"
		else
			echo -e "${dim}uv tools: $uv_output${reset}"
		fi
	) >"$tool_update_dir/uv" 2>&1 &
fi

if command -v tldr &>/dev/null; then
	(
		tldr --update >/dev/null 2>&1 || echo -e "${yellow}Warning: tldr update failed${reset}"
		echo -e "${dim}tldr: pages updated${reset}"
	) >"$tool_update_dir/tldr" 2>&1 &
fi

export ZSH="${ZSH:-$HOME/.oh-my-zsh}"
if [[ -d "$ZSH" && -x "$ZSH/tools/upgrade.sh" ]]; then
	(
		omz_output=$("$ZSH/tools/upgrade.sh" -v minimal 2>&1) || echo -e "${yellow}Warning: Oh My Zsh update failed${reset}"
		if [[ "$omz_output" == *"already at the latest"* ]]; then
			echo -e "${dim}Oh My Zsh: up to date${reset}"
		else
			echo -e "${dim}Oh My Zsh: updated${reset}"
		fi
	) >"$tool_update_dir/omz" 2>&1 &
fi

if command -v go &>/dev/null; then
	(
		gopls_before=$(gopls version 2>/dev/null | head -1 || echo "none")
		staticcheck_before=$(staticcheck -version 2>/dev/null | head -1 || echo "none")

		go install golang.org/x/tools/gopls@latest 2>/dev/null || echo -e "${yellow}Warning: gopls update failed${reset}"
		go install honnef.co/go/tools/cmd/staticcheck@latest 2>/dev/null || echo -e "${yellow}Warning: staticcheck update failed${reset}"

		gopls_after=$(gopls version 2>/dev/null | head -1 || echo "none")
		staticcheck_after=$(staticcheck -version 2>/dev/null | head -1 || echo "none")

		if [[ "$gopls_before" != "$gopls_after" || "$staticcheck_before" != "$staticcheck_after" ]]; then
			[[ "$gopls_before" != "$gopls_after" ]] && echo "Updated: gopls"
			[[ "$staticcheck_before" != "$staticcheck_after" ]] && echo "Updated: staticcheck"
		else
			echo -e "${dim}Go tools: up to date${reset}"
		fi
	) >"$tool_update_dir/go" 2>&1 &
fi

wait

for tool in uv tldr omz go; do
	[[ -f "$tool_update_dir/$tool" ]] && cat "$tool_update_dir/$tool"
done
rm -rf "$tool_update_dir"
echo ""
