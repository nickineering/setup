# shellcheck shell=bash
# shellcheck disable=SC2034,SC2154
#
# ── Configure Tools ──────────────────────────────────────────────────────────
# Sources per-tool scripts from configure/ that enforce idempotent config (shell
# completions, default versions, global configs). Python and Node are guarded on
# their package managers being available. Also handles npm removal prompts from
# state file changes detected in step 01.
# ─────────────────────────────────────────────────────────────────────────────

source configure/git.sh
source configure/zsh.sh
source configure/firefox.sh
source configure/ruff.sh
source configure/claude.sh

# Python config (guard: uv must be installed)
if command -v uv &>/dev/null; then
	source configure/python.sh
else
	echo -e "${yellow}Warning: uv not found, skipping Python configuration${reset}"
fi

# Node config (guard: nvm must be installed)
if [[ -s "$(brew --prefix)/opt/nvm/nvm.sh" ]]; then
	source configure/node.sh
	# Handle npm package removals from state file changes
	[[ -n "$removed_npm" ]] && prompt_uninstall npm "$removed_npm"
else
	echo -e "${yellow}Warning: nvm not found, skipping Node configuration${reset}"
fi

echo -e "${dim}Checked: Git, Zsh, Firefox, Ruff, Claude, Python, Node${reset}"
echo ""
