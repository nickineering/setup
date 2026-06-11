# shellcheck shell=bash
# shellcheck disable=SC2034,SC2154
#
# Updates uv, tldr, Oh My Zsh, Claude Code, and Go tools concurrently. Each
# runs in a background subshell writing to a temp file; results print in fixed
# order after all complete so output stays deterministic.

tool_update_dir=$(mktemp -d)

if command -v uv &>/dev/null; then
	(
		uv_output=$(uv tool upgrade --all 2>/dev/null) || echo "⚠ uv tool upgrade failed"
		if [[ "$uv_output" == "Nothing to upgrade" ]]; then
			echo "· uv tools: up to date"
		else
			echo "✓ uv tools: $uv_output"
		fi
	) >"$tool_update_dir/uv" 2>&1 &
fi

if command -v tldr &>/dev/null; then
	(
		tldr --update >/dev/null 2>&1 || echo "⚠ tldr update failed"
		echo "✓ tldr: pages updated"
	) >"$tool_update_dir/tldr" 2>&1 &
fi

export ZSH="${ZSH:-$HOME/.oh-my-zsh}"
if [[ -d "$ZSH" && -x "$ZSH/tools/upgrade.sh" ]]; then
	(
		omz_output=$("$ZSH/tools/upgrade.sh" -v minimal 2>&1) || echo "⚠ Oh My Zsh update failed"
		if [[ "$omz_output" == *"already at the latest"* ]]; then
			echo "· Oh My Zsh: up to date"
		else
			echo "✓ Oh My Zsh: updated"
		fi
	) >"$tool_update_dir/omz" 2>&1 &
fi

(
	install_script=$(curl -fsSL https://claude.ai/install.sh 2>&1)
	if [[ $? -ne 0 ]]; then
		echo "⚠ Claude Code install failed: $install_script"
	else
		claude_output=$(echo "$install_script" | bash 2>&1)
		if [[ "$claude_output" == *"already installed"* || "$claude_output" == *"up to date"* ]]; then
			echo "· Claude Code: up to date"
		else
			echo "✓ Claude Code: installed/updated"
		fi
	fi
) >"$tool_update_dir/claude" 2>&1 &

if command -v go &>/dev/null; then
	(
		gopls_before=$(gopls version 2>/dev/null | head -1 || echo "none")
		staticcheck_before=$(staticcheck -version 2>/dev/null | head -1 || echo "none")

		go install golang.org/x/tools/gopls@latest 2>/dev/null || echo "⚠ gopls update failed"
		go install honnef.co/go/tools/cmd/staticcheck@latest 2>/dev/null || echo "⚠ staticcheck update failed"

		gopls_after=$(gopls version 2>/dev/null | head -1 || echo "none")
		staticcheck_after=$(staticcheck -version 2>/dev/null | head -1 || echo "none")

		if [[ "$gopls_before" != "$gopls_after" || "$staticcheck_before" != "$staticcheck_after" ]]; then
			[[ "$gopls_before" != "$gopls_after" ]] && echo "✓ Updated: gopls"
			[[ "$staticcheck_before" != "$staticcheck_after" ]] && echo "✓ Updated: staticcheck"
		else
			echo "· Go tools: up to date"
		fi
	) >"$tool_update_dir/go" 2>&1 &
fi

wait

for tool in uv tldr omz claude go; do
	[[ -f "$tool_update_dir/$tool" ]] && cat "$tool_update_dir/$tool"
done
rm -rf "$tool_update_dir"
echo ""
