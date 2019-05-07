#!/bin/bash

echo "Please close all work and wait for your Mac to be configured. This may take a while."

# Change these variables to change the install. Earlier versions of Mac might cause
# unexpected problems.
MAC_OS="10.14"
PYTHON_VERSION="3.7.3"

# Change directory to the directory of the script
cd "$(dirname "$0")"

# Abort on error
set -e

# Link custom settings to that they updated automatically when changes are pulled.
ln -s ~/mac-init/settings/.bash_profile ~/
ln -s ~/mac-init/settings/.zshrc ~/
ln -s ~/mac-init/settings/.shell_profile.sh ~/
cp settings/.shell_profile.custom.sh ~/
cp settings/.gitconfig ~/
cp settings/.gitignore ~/
ln -s ~/mac-init/settings/.vimrc ~/
ln -s ~/mac-init/settings/.tmux.conf ~/

# Install homebrew, a unix package manager
/usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"

# Install homebrew formulas
brew install awscli  # Amazon Web Services cli
brew install bash-completion  # Autocomplete for git
brew install selenium-server-standalone  # Automate web browsers
brew install git  # Source control
brew install hub  # Github code collaboration cli
brew install jupyter  # Interactive code editing notebook
brew install mas  # Install Mac App Store apps
brew install node  # local Javascript runtime
brew install tmux  # Terminal multitasking
brew install yarn  # JavaScript package manager
brew install zsh  # Improvements to the bash shell

# Install homebrew casks
brew cask install 1password  # Password manager
brew cask install 1password-cli  # Use password manager in terminal
brew cask install adobe-creative-cloud  # Use to install XD (extra step needed)
brew cask install apptrap  # Clean uninstall Mac apps
brew cask install azure-data-studio  # Helpful for MSSQL
brew cask install copyclip  # Clipboard history
brew cask install datagrip  # Connect to databases
brew cask install docker  # Code containerisation
brew cask install firefox-developer-edition  # Web browser with added dev tools
brew cask install google-chrome  # Web browser
brew cask install gpg-suite  # GPG key generator
brew cask install iterm2  # Terminal emulator
brew cask install microsoft-office  # Standard business applications
brew cask install microsoft-teams  # Team communication
brew cask install postgres  # Local database
brew cask install postman  # API builder and debugger
brew cask install react-native-debugger  # React Native mobile app debugger
brew cask install shuttle  # SSH shortcuts
brew cask install snagit  # Screenshots
brew cask install spectacle  # Helpful window keyboard shortcuts
brew cask install the-unarchiver  # File compression utility
brew cask install virtualbox  # Virtual machine platform
brew cask install visual-studio-code  # Graphical code editor
brew cask install vlc  # Multimedia viewer

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

# Install yarn globals
yarn global add eslint  # Javascript code analyser
yarn global add eslint-plugin-react  # Adds React compatibility to eslint
yarn global add expo-cli  # Develop React Native apps with ease
yarn global add prettier  # Code formatter
yarn global add react-devtools  # Debug React


pip install bandit
pip install black
pip install virtualenvwrapper
pip install pygments  # Dependency of zsh colorize

# Install VSCode extensions
code --install-extension batisteo.vscode-django
code --install-extension bungcip.better-toml
code --install-extension christian-kohler.path-intellisense
code --install-extension CoenraadS.bracket-pair-colorizer
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
code --install-extension ms-vscode.powershell
code --install-extension ms-vsliveshare.vsliveshare
code --install-extension Orta.vscode-jest
code --install-extension PeterJausovec.vscode-docker
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
