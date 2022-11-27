#!/bin/bash
# Run this script to setup a new Mac
# ! It is not meant to be run on Macs that have already been setup!

# Abort on error
set -e

# Print commands that are run as they are run
set -v

# Start running the print utility first so we can update the user on progress
# shellcheck source=util/print.sh
source <(curl -s https://raw.githubusercontent.com/nferrara100/mac/master/util/print.sh)

print_green "Please leave everything closed and wait for your Mac to be configured. \
This will take a while." "AUTOMATICALLY CONFIGURING MAC"

# Install Homebrew, a Mac package manager
if command -v brew; then
    brew upgrade
    print_green "Homebrew is already installed. Upgraded packages."
else
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    print_green "Installed Homebrew"
fi

# Make a projects directory and clone the repo into it
mkdir -p ~/projects
cd ~/projects
brew install git # Use Homebrew so that updates are easy
export MAC=~/projects/mac
export DOTFILES=$MAC/linked
if [ -d "$MAC" ];
then
    cd $MAC
    git pull
    print_green "Pulled latest commits from repo"
else
    git clone https://github.com/nferrara100/mac.git
    cd $MAC # Enter newly cloned repo
	print_green "Cloned repo into projects directory"
fi

# Link custom settings to that they are updated automatically when changes are pulled
ln -s $DOTFILES/.bash_profile ~/
ln -s $DOTFILES/.profile.sh ~/
cp copied/.env.sh ~/
cp copied/.gitconfig ~/
ln -s $DOTFILES/.vimrc ~/
ln -s $DOTFILES/.tmux.conf ~/

print_green "Copied and linked required files"

# Install Homebrew formulas
while IFS= read -r package; do
    brew install "$package"
done < $MAC/state/brew_packages.txt
print_green "Installed homebrew packages"

# Get rid of default Zsh config and replace with custom
rm -f ~/.zshrc
ln -s $DOTFILES/.zshrc ~/
print_green "Using custom .zshrc settings"

brew tap homebrew/cask-versions  # Supplies firefox-developer-edition

# Install Homebrew casks
while IFS= read -r cask; do
    brew install --cask "$cask"
done < $MAC/state/brew_casks.txt
print_green "Installed homebrew casks"

# ColorSlurp color picker - get any color on screen
mas install 1287239339

print_green "Completed main app installs"

# Pyenv configuration
# shellcheck disable=SC1090
source ~/.bash_profile
LATEST_PYTHON=$(pyenv install --list | grep --extended-regexp "^\s*[0-9][0-9.]*[0-9]\s*$" | tail -1)
pyenv install "$LATEST_PYTHON"
pyenv global "$LATEST_PYTHON"
pip install --upgrade pip

pip install \
bandit \  # Python code security
beautysh \  # Bash code formatting
black \  # Python code formatting
flake8 \  # Python linting
isort \  # Sort Python imports
pre-commit \  # Run multilingual commands before git commits
pygments  # Dependency of Zsh colorize

print_green "Completed Python installs"

# Install VSCode extensions. View current with `code --list-extensions`
while IFS= read -r extension; do
    code --install-extension "$extension"
done < $MAC/state/vscode_extensions.txt
print_green "Installed VSCode extensions"

# Add custom VSCode settings
ln -s $DOTFILES/settings.json ~/Library/Application\ Support/Code/User/
print_green "Completed VSCode installs"

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

# Setup Node Version Manager (NVM) for local JavaScript
mkdir -p ~/.nvm
# shellcheck disable=SC1090
source ~/.zshrc
nvm install --lts

# Install JavaScript globals
npm install -g renovate  # Dependency upgrades

print_green "Completed installs. Now configuring settings..."

# Install custom Firefox settings
FIREFOX_FOLDER="$HOME/Library/Application Support/Firefox/Profiles"
FIREFOX_PROFILE=$(find "$FIREFOX_FOLDER" -name '*.dev-edition-default')
if [ -z "$FIREFOX_PROFILE" ]
then
    print_green "Could not find Firefox profile folder. Skipping Firefox settings..."
else
    ln -s $DOTFILES/user.js "$FIREFOX_PROFILE"
fi

# Configures the operating system on import
source util/configure_macos.sh

print_green "Please follow the manual instructions in the readme and then reboot your \
computer." "AUTOMATED CONFIGURATION COMPLETE"
