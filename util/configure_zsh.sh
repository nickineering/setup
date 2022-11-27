#!/usr/local/bin/bash

# Install Zsh plugin manager
if command -v omz; then
    print_green "Oh My Zsh is already installed. Checking for updates..."
    omz update
else
    sh -c "$(curl -fsSL https://raw.github.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"
fi

ZSH_PLUGINS=~/.oh-my-zsh/custom/plugins

# Adding custom Zsh plugin for syntax highlighting
if [ -d $ZSH_PLUGINS/zsh-syntax-highlighting ]; then
    print_green "Zsh syntax highlighting already installed. Checking for updates..."
    git -C $ZSH_PLUGINS/zsh-syntax-highlighting pull
else
    git clone https://github.com/zsh-users/zsh-syntax-highlighting $ZSH_PLUGINS/zsh-syntax-highlighting
fi

# Autosuggestions when typing in Zsh. Right arrow to autocomplete.
if [ -d $ZSH_PLUGINS/zsh-autosuggestions ]; then
    print_green "Zsh autosuggestions already installed. Checking for updates..."
    git -C $ZSH_PLUGINS/zsh-autosuggestions pull
else
    git clone https://github.com/zsh-users/zsh-autosuggestions $ZSH_PLUGINS/zsh-autosuggestions
fi

# Poetry autocompletion
mkdir -p "$ZSH"/plugins/poetry
poetry completions zsh > "$ZSH"/plugins/poetry/_poetry

# Get rid of the default Zsh config installed by Oh My Zsh so it can be replaced
rm -f ~/.zshrc

print_green "Finished Zsh configuration"
