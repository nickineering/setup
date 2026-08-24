# shellcheck shell=bash
# shellcheck disable=SC2034,SC2154
#
# Updates uv, tldr, Oh My Zsh, Claude Code, and Go tools concurrently.
# Each prints its result immediately on completion (order may vary between runs).

# Inline formatting for subshells (can't use helpers across process boundaries)
_info="\033[38;5;245m·"
_success="\033[92m✓"
_warn="\033[33m⚠"
_reset="\033[0m"

if command -v uv &>/dev/null; then
	(
		uv_output=$(uv tool upgrade --all 2>/dev/null) || {
			echo -e "${_warn} uv tool upgrade failed${_reset}"
			exit
		}
		if [[ -z "$uv_output" || "$uv_output" == "Nothing to upgrade" ]]; then
			echo -e "${_info} uv tools: up to date${_reset}"
		else
			echo -e "${_success} uv tools: updated${_reset}"
		fi
	) &
fi

if command -v tldr &>/dev/null; then
	(
		cache_dir="${HOME}/Library/Caches/tealdeer"
		before=$(stat -f %Sm -t %s "$cache_dir" 2>/dev/null || echo "0")
		tldr --update >/dev/null 2>&1 || {
			echo -e "${_warn} tldr update failed${_reset}"
			exit
		}
		after=$(stat -f %Sm -t %s "$cache_dir" 2>/dev/null || echo "0")
		if [[ "$before" != "$after" && "$before" != "0" ]]; then
			echo -e "${_success} tldr: pages updated${_reset}"
		else
			echo -e "${_info} tldr: up to date${_reset}"
		fi
	) &
fi

export ZSH="${ZSH:-$HOME/.oh-my-zsh}"
if [[ -d "$ZSH" && -x "$ZSH/tools/upgrade.sh" ]]; then
	(
		omz_output=$("$ZSH/tools/upgrade.sh" -v minimal 2>&1) || {
			echo -e "${_warn} Oh My Zsh update failed${_reset}"
			exit
		}
		if [[ "$omz_output" == *"already at the latest"* ]]; then
			echo -e "${_info} Oh My Zsh: up to date${_reset}"
		else
			echo -e "${_success} Oh My Zsh: updated${_reset}"
		fi
	) &
fi

(
	if command -v claude &>/dev/null; then
		before=$(claude --version 2>/dev/null)
		update_output=$(claude update 2>&1)
		if [[ $? -ne 0 ]]; then
			echo -e "${_warn} Claude Code update failed: $update_output${_reset}"
		else
			after=$(claude --version 2>/dev/null)
			if [[ "$before" != "$after" ]]; then
				echo -e "${_success} Claude Code: updated ($after)${_reset}"
			else
				echo -e "${_info} Claude Code: up to date${_reset}"
			fi
		fi
	else
		install_output=$(curl -fsSL https://claude.ai/install.sh 2>&1 | bash 2>&1)
		if [[ $? -ne 0 ]]; then
			echo -e "${_warn} Claude Code install failed: $install_output${_reset}"
		else
			echo -e "${_success} Claude Code: installed${_reset}"
		fi
	fi
) &

if command -v go &>/dev/null; then
	(
		gopls_before=$(gopls version 2>/dev/null | head -1 || echo "none")
		staticcheck_before=$(staticcheck -version 2>/dev/null | head -1 || echo "none")

		go install golang.org/x/tools/gopls@latest 2>/dev/null || echo -e "${_warn} gopls update failed${_reset}"
		go install honnef.co/go/tools/cmd/staticcheck@latest 2>/dev/null || echo -e "${_warn} staticcheck update failed${_reset}"

		gopls_after=$(gopls version 2>/dev/null | head -1 || echo "none")
		staticcheck_after=$(staticcheck -version 2>/dev/null | head -1 || echo "none")

		if [[ "$gopls_before" != "$gopls_after" || "$staticcheck_before" != "$staticcheck_after" ]]; then
			[[ "$gopls_before" != "$gopls_after" ]] && echo -e "${_success} Updated: gopls${_reset}"
			[[ "$staticcheck_before" != "$staticcheck_after" ]] && echo -e "${_success} Updated: staticcheck${_reset}"
		else
			echo -e "${_info} Go tools: up to date${_reset}"
		fi
	) &
fi

# mermaid-cli renders PNGs via puppeteer, which needs a chrome-headless-shell
# build matching the version its bundled puppeteer-core pins. A mermaid-cli
# upgrade moves that pin, so read it back rather than assuming @stable.
if command -v mmdc &>/dev/null; then
	(
		revisions=$(npm root -g 2>/dev/null)/@mermaid-js/mermaid-cli/node_modules/puppeteer-core/lib/puppeteer/revisions.js
		wanted=$(sed -n "s/.*'chrome-headless-shell': *'\([^']*\)'.*/\1/p" "$revisions" 2>/dev/null)

		if [[ -z "$wanted" ]]; then
			echo -e "${_warn} mermaid browser: could not read pinned version${_reset}"
			exit
		fi

		if [[ -d "$HOME/.cache/puppeteer/chrome-headless-shell/mac_arm-${wanted}" ]]; then
			echo -e "${_info} mermaid browser: up to date${_reset}"
			exit
		fi

		if npx --yes @puppeteer/browsers install "chrome-headless-shell@${wanted}" >/dev/null 2>&1; then
			echo -e "${_success} mermaid browser: installed ${wanted}${_reset}"
		else
			echo -e "${_warn} mermaid browser: install failed (${wanted})${_reset}"
		fi
	) &
fi

wait
echo ""
