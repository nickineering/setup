# shellcheck shell=bash
# shellcheck disable=SC2154 # Variables like $dim are defined in lib/colors.sh
# Sourced by run.sh

# Install Zsh plugin manager
if [ ! -d ~/.oh-my-zsh ]; then
	OMZ_INSTALL_SCRIPT=$(curl -fsSL https://raw.github.com/robbyrussell/oh-my-zsh/master/tools/install.sh)
	if [ "$OMZ_INSTALL_SCRIPT" = "" ]; then
		echo -e "${yellow}Warning: Failed to download Oh My Zsh installer${reset}" >&2
		return 0
	fi
	# Run non-interactively: don't change shell, start zsh, or overwrite .zshrc after install
	RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -c "$OMZ_INSTALL_SCRIPT"
	echo -e "${dim}Zsh: installed Oh My Zsh${reset}"
fi

ZSH_PLUGINS=~/.oh-my-zsh/custom/plugins
zsh_updated=""

# Adding custom Zsh plugin for syntax highlighting
if [ -d "$ZSH_PLUGINS"/zsh-syntax-highlighting ]; then
	output=$(git -C "$ZSH_PLUGINS"/zsh-syntax-highlighting pull 2>&1) || echo -e "${yellow}Warning: Failed to update zsh-syntax-highlighting${reset}"
	[[ "$output" != "Already up to date." ]] && zsh_updated+="syntax-highlighting "
else
	if git clone --quiet https://github.com/zsh-users/zsh-syntax-highlighting "$ZSH_PLUGINS"/zsh-syntax-highlighting; then
		zsh_updated+="syntax-highlighting "
	else
		echo -e "${yellow}Warning: Failed to clone zsh-syntax-highlighting${reset}" >&2
	fi
fi

# Autosuggestions when typing in Zsh
if [ -d "$ZSH_PLUGINS"/zsh-autosuggestions ]; then
	output=$(git -C "$ZSH_PLUGINS"/zsh-autosuggestions pull 2>&1) || echo -e "${yellow}Warning: Failed to update zsh-autosuggestions${reset}"
	[[ "$output" != "Already up to date." ]] && zsh_updated+="autosuggestions "
else
	if git clone --quiet https://github.com/zsh-users/zsh-autosuggestions "$ZSH_PLUGINS"/zsh-autosuggestions; then
		zsh_updated+="autosuggestions "
	else
		echo -e "${yellow}Warning: Failed to clone zsh-autosuggestions${reset}" >&2
	fi
fi

# Install iTerm2 shell integration (first-time only)
if [[ ! -f ~/.iterm2_shell_integration.zsh ]]; then
	ITERM_SCRIPT=$(curl -fsSL https://iterm2.com/shell_integration/install_shell_integration_and_utilities.sh)
	if [[ -n "$ITERM_SCRIPT" ]]; then
		bash -c "$ITERM_SCRIPT" >/dev/null
		zsh_updated+="iTerm2 "
	else
		echo -e "${yellow}Warning: Failed to download iTerm2 shell integration script${reset}"
	fi
fi

if [[ -n "$zsh_updated" ]]; then
	echo -e "${dim}Zsh: updated ${zsh_updated}${reset}"
fi
