#!/bin/bash

echo "Please close all work and wait for your Mac to be configured. This may take a while."

# Change these variables to change the install. Earlier versions of Mac might cause
# unexpected problems.
MAC_OS="11.6"
PYTHON_VERSION="3.10.1"

# Change directory to the directory of the script
cd "$(dirname "$0")"

# Abort on error
set -e

# Link custom settings to that they updated automatically when changes are pulled.
ln -s ~/mac-init/settings/.bash_profile ~/
ln -s ~/mac-init/settings/.zshrc ~/
ln -s ~/mac-init/settings/.profile.sh ~/
cp settings/.profile.custom.sh ~/
cp settings/.gitconfig ~/
cp settings/.gitignore ~/
ln -s ~/mac-init/settings/.vimrc ~/
ln -s ~/mac-init/settings/.tmux.conf ~/

# Install homebrew, a unix package manager
/usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"

brew tap homebrew/cask-drivers  # required to install displaylink
brew install displaylink  # dock for working in office

# Install homebrew formulas
brew install awscli  # Amazon Web Services cli
brew install bash-completion  # Autocomplete for git
brew install gh  # Github cli
brew install git  # Source control
brew install jupyterlab  # Interactive code editing notebook
brew install mas  # Install Mac App Store apps
brew install nvm  # local Javascript runtime
brew install ohueter/tap/autokbisw # Remember keyboard input type per keyboard
brew install postgresql  # database for local development
brew install pyenv-virtualenvwrapper
brew install selenium-server  # Automate web browsers
brew install tmux  # Terminal multitasking
brew install watchman
brew install yarn  # JavaScript package manager
brew install zsh  # Improvements to the bash shell
brew services start ohueter/tap/autokbisw # Run at login

# Install homebrew casks
brew install --cask 1password  # Password manager
brew install --cask 1password-cli  # Use password manager in terminal
brew install --cask adobe-creative-cloud  # Use to install XD (extra step needed)
brew install --cask apptrap  # Clean uninstall Mac apps
brew install --cask azure-data-studio  # Helpful for MSSQL
brew install --cask browserstacklocal  # Test websites with many different browsers
brew install --cask copyclip  # Clipboard history
brew install --cask datagrip  # Connect to databases
brew install --cask docker  # Code containerisation
brew install --cask firefox-developer-edition  # Web browser with added dev tools
brew install --cask google-chrome  # Web browser
brew install --cask gpg-suite  # GPG key generator
brew install --cask iterm2  # Terminal emulator
brew install --cask microsoft-edge  # Major browser
brew install --cask microsoft-office  # Standard business applications
brew install --cask microsoft-teams  # Team communication
brew install --cask openvpn-connect  # VPN to work network
brew install --cask postgres  # Local database
brew install --cask postman  # API builder and debugger
brew install --cask react-native-debugger  # React Native mobile app debugger
brew install --cask shuttle  # SSH shortcuts
brew install --cask snagit  # Screenshots
brew install --cask spectacle  # Helpful window keyboard shortcuts
brew install --cask the-unarchiver  # File compression utility
brew install --cask virtualbox  # Virtual machine platform
brew install --cask visual-studio-code  # Graphical code editor
brew install --cask vlc  # Multimedia viewer

# Microsoft remote desktop
mas install 1295203466
# Xcode
mas install 497799835

# Configure XCode
xcode-select --install 2>&1 > /dev/null
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer 2>&1 > /dev/null
sudo xcodebuild -license accept 2>&1 > /dev/null

# Install pyenv to run multiple versions of python at the same time
brew install openssl  # pyenv dependency
brew install redline  # pyenv dependency
brew install sqlite3  # pyenv dependency
brew install xz  # pyenv dependency
brew install zlib  # pyenv dependency
sudo installer -pkg /Library/Developer/CommandLineTools/Packages/macOS_SDK_headers_for_macOS_$MAC_OS.pkg -target /
brew install pyenv
source ~/.bash_profile
pyenv install $PYTHON_VERSION
pyenv global $PYTHON_VERSION
pip install --upgrade pip

# Install yarn globals
yarn global add expo-cli  # Develop React Native apps with ease
yarn global add react-devtools  # Debug React
yarn global add renovate  # Dependency upgrades

pip install bandit
pip install beautysh
pip install black
pip install pre-commit
pip install pygments  # Dependency of zsh colorize
pip install virtualenvwrapper

# Install VSCode extensions
code --install-extension batisteo.vscode-django
code --install-extension bungcip.better-toml
code --install-extension christian-kohler.path-intellisense
code --install-extension dbaeumer.vscode-eslint
code --install-extension developertejasjadhav.javascript-refactor--sort-imports
code --install-extension eamodio.gitlens
code --install-extension esbenp.prettier-vscode
code --install-extension felixrieseberg.vsc-travis-ci-status
code --install-extension formulahendry.code-runner
code --install-extension GitHub.vscode-pull-request-github
code --install-extension hbenl.vscode-test-explorer
code --install-extension kumar-harsh.graphql-for-vscode
code --install-extension littlefoxteam.vscode-python-test-adapter
code --install-extension ms-python.python
code --install-extension ms-vsliveshare.vsliveshare
code --install-extension Orta.vscode-jest
code --install-extension redhat.vscode-yaml
code --install-extension rust-lang.rust # Rust language support
code --install-extension streetsidesoftware.code-spell-checker
code --install-extension ue.alphabetical-sorter
code --install-extension vsmobile.vscode-react-native

# Add custom VSCode settings
ln -s ~/mac-init/settings/settings.json ~/Library/Application\ Support/Code/User/

# Microsoft remote desktop
mas install 1295203466
# Xcode
mas install 497799835

# Install Rust Language
curl https://sh.rustup.rs -sSf | sh
rustup component add rustfmt --toolchain stable-x86_64-apple-darwin
rustup component add rls --toolchain stable-x86_64-apple-darwin

# Poetry package manager for python
curl -sSL https://raw.githubusercontent.com/sdispater/poetry/master/get-poetry.py | python
mkdir $ZSH/plugins/poetry
poetry completions zsh > $ZSH/plugins/poetry/_poetry

# Setup Node Version Manager (NVM) for local JavaScript
mkdir ~/.nvm
source ~/.zshrc
nvm install --lts

# Install zsh plugin manager
sh -c "$(curl -fsSL https://raw.github.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"

# Adding custom zsh plugin for syntax highlighting
mkdir ~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting
git clone https://github.com/zsh-users/zsh-syntax-highlighting ~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting

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

# Set up default development workspace
mkdir ~/code/
git clone https://github.com/RCVS-London/dotfiles.git ~/code/

echo "Automated Mac configuration complete. Please follow the manual instructions in the Readme and then reboot your computer."
