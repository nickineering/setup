# shellcheck shell=bash
# shellcheck disable=SC2154 # Variables like $dim are defined in lib/colors.sh
# Sourced by run.sh

# Install Zsh plugin manager
if [ ! -d ~/.oh-my-zsh ]; then
	OMZ_INSTALL_SCRIPT=$(curl -fsSL https://raw.github.com/robbyrussell/oh-my-zsh/master/tools/install.sh)
	if [ "$OMZ_INSTALL_SCRIPT" = "" ]; then
		warn "Failed to download Oh My Zsh installer" >&2
		return 0
	fi
	# Run non-interactively: don't change shell, start zsh, or overwrite .zshrc after install
	RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -c "$OMZ_INSTALL_SCRIPT"
	info "Zsh: installed Oh My Zsh"
fi

ZSH_PLUGINS=~/.oh-my-zsh/custom/plugins
zsh_updated=""

# Adding custom Zsh plugin for syntax highlighting
if [ -d "$ZSH_PLUGINS"/zsh-syntax-highlighting ]; then
	output=$(git -C "$ZSH_PLUGINS"/zsh-syntax-highlighting pull 2>&1) || warn "Failed to update zsh-syntax-highlighting"
	[[ "$output" != "Already up to date." ]] && zsh_updated+="syntax-highlighting "
else
	if git clone --quiet https://github.com/zsh-users/zsh-syntax-highlighting "$ZSH_PLUGINS"/zsh-syntax-highlighting; then
		zsh_updated+="syntax-highlighting "
	else
		warn "Failed to clone zsh-syntax-highlighting" >&2
	fi
fi

# Autosuggestions when typing in Zsh
if [ -d "$ZSH_PLUGINS"/zsh-autosuggestions ]; then
	output=$(git -C "$ZSH_PLUGINS"/zsh-autosuggestions pull 2>&1) || warn "Failed to update zsh-autosuggestions"
	[[ "$output" != "Already up to date." ]] && zsh_updated+="autosuggestions "
else
	if git clone --quiet https://github.com/zsh-users/zsh-autosuggestions "$ZSH_PLUGINS"/zsh-autosuggestions; then
		zsh_updated+="autosuggestions "
	else
		warn "Failed to clone zsh-autosuggestions" >&2
	fi
fi

# Install iTerm2 shell integration (first-time only)
if [[ ! -f ~/.iterm2_shell_integration.zsh ]]; then
	ITERM_SCRIPT=$(curl -fsSL https://iterm2.com/shell_integration/install_shell_integration_and_utilities.sh)
	if [[ -n "$ITERM_SCRIPT" ]]; then
		bash -c "$ITERM_SCRIPT" >/dev/null
		zsh_updated+="iTerm2 "
	else
		warn "Failed to download iTerm2 shell integration script"
	fi
fi

if [[ -n "$zsh_updated" ]]; then
	info "Zsh: updated ${zsh_updated}"
fi
