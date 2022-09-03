#!/bin/bash

echo "Please close all work and wait for your Mac to be configured. This will take a while."

PYTHON_VERSION=$1

# Change directory to the directory of the script
cd "$(dirname "$0")"

# Assign absolute directory of this script to $DIR
DIR=$( cd "$(dirname "$0")" ; pwd -P )

# Abort on error
set -e

# Link custom settings to that they updated automatically when changes are pulled.
ln -s $DIR/settings/.bash_profile ~/
ln -s $DIR/settings/.zshrc ~/
ln -s $DIR/settings/.profile.sh ~/
cp settings/.profile.custom.sh ~/
cp settings/.gitconfig ~/
cp settings/.gitignore ~/
ln -s $DIR/settings/.vimrc ~/
ln -s $DIR/settings/.tmux.conf ~/

# Install homebrew, a Mac package manager
/usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"

echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
eval "$(/opt/homebrew/bin/brew shellenv)"

# Install homebrew formulas
brew install awscli  # Amazon Web Services cli
brew install bash-completion  # Autocomplete for git
brew install gh  # Github cli
brew install git  # Source control
brew install git-lfs
brew install jupyterlab  # Interactive code editing notebook
brew install mas  # Install Mac App Store apps
brew install nvm  # local Javascript runtime
brew install postgresql  # database for local development
brew install pyenv-virtualenvwrapper
brew install tmux  # Terminal multitasking
brew install watchman
brew install zsh  # Improvements to the bash shell

# Install homebrew casks
brew install --cask 1password  # Password manager
brew install --cask 1password-cli  # Use password manager in terminal
brew install --cask ccleaner
brew install --cask copyclip  # Clipboard history
brew install --cask docker  # Code containerisation
brew install --cask firefox-developer-edition  # Web browser with added dev tools
brew install --cask google-chrome  # Web browser
brew install --cask gpg-suite  # GPG key generator
brew install --cask iterm2  # Terminal emulator
brew install --cask kindle
brew install --cask microsoft-edge  # Major browser
brew install --cask nordvpn
brew install --cask paragon-ntfs
brew install --cask postgres  # Local database
brew install --cask postman  # API builder and debugger
brew install --cask signal
brew install --cask skype
brew install --cask spotify
brew install --cask the-unarchiver  # File compression utility
brew install --cask visual-studio-code  # Graphical code editor
brew install --cask vlc  # Multimedia viewer
brew install --cask whatsapp
brew install --cask zoom

# ColorSlurp color picker
mas install 1287239339

# Xcode
# mas install 497799835
# xcode-select --install 2>&1 > /dev/null
# sudo xcode-select -s /Applications/Xcode.app/Contents/Developer 2>&1 > /dev/null
# sudo xcodebuild -license accept 2>&1 > /dev/null

# Install pyenv to run multiple versions of python at the same time
# brew install openssl  # pyenv dependency
# brew install redline  # pyenv dependency
# brew install sqlite3  # pyenv dependency
# brew install xz  # pyenv dependency
# brew install zlib  # pyenv dependency
# MAC_OS="12.5.1"
# sudo installer -pkg /Library/Developer/CommandLineTools/Packages/macOS_SDK_headers_for_macOS_$MAC_OS.pkg -target /
brew install pyenv
source ~/.bash_profile
pyenv install $PYTHON_VERSION
pyenv global $PYTHON_VERSION
pip install --upgrade pip

pip install bandit
pip install beautysh
pip install black
pip install flake8
pip install pre-commit
pip install pygments  # Dependency of zsh colorize
pip install virtualenvwrapper

# Install VSCode extensions
code --install-extension aaron-bond.better-comments
code --install-extension adpyke.codesnap
code --install-extension batisteo.vscode-django
code --install-extension bungcip.better-toml
code --install-extension christian-kohler.path-intellisense
code --install-extension docsmsft.docs-markdown
code --install-extension eamodio.gitlens
code --install-extension esbenp.prettier-vscode
code --install-extension formulahendry.auto-rename-tag
code --install-extension GitHub.vscode-pull-request-github
code --install-extension hbenl.vscode-test-explorer
code --install-extension littlefoxteam.vscode-python-test-adapter
code --install-extension markis.code-coverage
code --install-extension ms-python.python
code --install-extension ms-python.vscode-pylance
code --install-extension ms-toolsai.jupyter
code --install-extension ms-toolsai.jupyter-keymap
code --install-extension ms-toolsai.jupyter-renderers
code --install-extension ms-vscode-remote.remote-containers
code --install-extension ms-vscode.makefile-tools
code --install-extension ms-vscode.test-adapter-converter
code --install-extension ms-vsliveshare.vsliveshare
code --install-extension redhat.vscode-yaml
code --install-extension rust-lang.rust
code --install-extension rust-lang.rust-analyzer
code --install-extension streetsidesoftware.code-spell-checker
code --install-extension ue.alphabetical-sorter
code --install-extension visualstudioexptteam.intellicode-api-usage-examples
code --install-extension visualstudioexptteam.vscodeintellicode

# Add custom VSCode settings
ln -s $DIR/settings/settings.json ~/Library/Application\ Support/Code/User/

# Install Rust Language
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
rustup component add rustfmt
rustup component add rls

# Poetry package manager for python
curl -sSL https://raw.githubusercontent.com/sdispater/poetry/master/get-poetry.py | python
mkdir $ZSH/plugins/poetry
poetry completions zsh > $ZSH/plugins/poetry/_poetry

# Setup Node Version Manager (NVM) for local JavaScript
mkdir ~/.nvm
source ~/.zshrc
nvm install --lts

# Install js globals
npm install -g renovate  # Dependency upgrades

# Install zsh plugin manager
sh -c "$(curl -fsSL https://raw.github.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"

# Adding custom zsh plugin for syntax highlighting
mkdir ~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting
git clone https://github.com/zsh-users/zsh-syntax-highlighting ~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting

# Autosuggestions when typing in Zsh. Right arrow to autocomplete.
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions

# Disable the “Are you sure you want to open this application?” dialog
defaults write com.apple.LaunchServices LSQuarantine -bool false

# Show all filename extensions
defaults write NSGlobalDomain AppleShowAllExtensions -bool true;ok

# Show path bar in finder
defaults write com.apple.finder ShowPathbar -bool true;ok

# Allow text selection in quick look
defaults write com.apple.finder QLEnableTextSelection -bool true;ok

# When performing a search, search the current folder by default
defaults write com.apple.finder FXDefaultSearchScope -string "SCcf";ok

# Disable the warning when changing a file extension
defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false;ok

# Avoid creating .DS_Store files on network volumes
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true;ok

# Use list view in all Finder windows by default
# Four-letter codes for the other view modes: `icnv`, `clmv`, `Flwv`
defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv";ok

# Show the ~/Library folder
chflags nohidden ~/Library;ok

echo "Automated Mac configuration complete. Please follow the manual instructions in the Readme and then reboot your computer."