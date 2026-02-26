#!/opt/homebrew/bin/bash

# Install Zsh plugin manager
if [ -d ~/.oh-my-zsh ]; then
	print_green "Oh My Zsh is already installed"
else
	OMZ_INSTALL_SCRIPT=$(curl -fsSL https://raw.github.com/robbyrussell/oh-my-zsh/master/tools/install.sh)
	if [ "$OMZ_INSTALL_SCRIPT" = "" ]; then
		echo "Error: Failed to download Oh My Zsh installer" >&2
		exit 1
	fi
	sh -c "$OMZ_INSTALL_SCRIPT"
fi

ZSH_PLUGINS=~/.oh-my-zsh/custom/plugins

# Adding custom Zsh plugin for syntax highlighting
if [ -d "$ZSH_PLUGINS"/zsh-syntax-highlighting ]; then
	print_green "Zsh syntax highlighting already installed. Checking for updates..."
	git -C "$ZSH_PLUGINS"/zsh-syntax-highlighting pull || print_green "Warning: Failed to update zsh-syntax-highlighting"
else
	if ! git clone https://github.com/zsh-users/zsh-syntax-highlighting "$ZSH_PLUGINS"/zsh-syntax-highlighting; then
		echo "Error: Failed to clone zsh-syntax-highlighting" >&2
		exit 1
	fi
fi

# Autosuggestions when typing in Zsh. Right arrow to autocomplete.
if [ -d "$ZSH_PLUGINS"/zsh-autosuggestions ]; then
	print_green "Zsh autosuggestions already installed. Checking for updates..."
	git -C "$ZSH_PLUGINS"/zsh-autosuggestions pull || print_green "Warning: Failed to update zsh-autosuggestions"
else
	if ! git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_PLUGINS"/zsh-autosuggestions; then
		echo "Error: Failed to clone zsh-autosuggestions" >&2
		exit 1
	fi
fi

# Install Iterm2 advanced features.
# Writes to .zshrc, but the output is in our version, too
ITERM_SCRIPT=$(curl -fsSL https://iterm2.com/shell_integration/install_shell_integration_and_utilities.sh)
if [ "$ITERM_SCRIPT" = "" ]; then
	print_green "Warning: Failed to download iTerm2 shell integration script"
else
	bash -c "$ITERM_SCRIPT"
fi

# Get rid of the default Zsh config installed by Oh My Zsh so it can be replaced
rm -f ~/.zshrc

print_green "Finished Zsh configuration"
