# shellcheck shell=bash
# shellcheck disable=SC2034,SC2154
#
# Sources per-tool scripts from configure/ that enforce idempotent config (shell
# completions, default versions, global configs). Python and Node are guarded on
# their package managers being available.
: "${removed_npm?}"

source configure/git.sh
source configure/zsh.sh
source configure/firefox.sh
source configure/ruff.sh
source configure/claude.sh

# Python config (guard: uv must be installed)
if command -v uv &>/dev/null; then
	source configure/python.sh
else
	warn "uv not found, skipping Python configuration"
fi

# Node config (guard: nvm must be installed)
if [[ -s "$(brew --prefix)/opt/nvm/nvm.sh" ]]; then
	source configure/node.sh
	# Handle npm package removals from state file changes
	[[ -n "$removed_npm" ]] && prompt_uninstall npm "$removed_npm"
else
	warn "nvm not found, skipping Node configuration"
fi

info "Checked: Git, Zsh, Firefox, Ruff, Claude, Python, Node"
echo ""
