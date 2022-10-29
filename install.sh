#!/bin/bash

PYTHON_VERSION=$1

function print_green {
    # Print optional str $2 as bold green text
    # Print str $1 on new line as normal green text
    # Finally print time

    GREEN='\033[0;32m'
    BOLD_GREEN='\033[1;32m'
    NO_COLOR='\033[0m'
    if (( $# >= 2 ))
    then
        now=$(date)
        printf "Time: %s" "$now"
        echo -e "\n${BOLD_GREEN}$2${NO_COLOR}"
    fi
    echo -e "${GREEN}$1${NO_COLOR}"
}

print_green "Please leave everything closed and wait for your Mac to be configured. \
This will take a while." "AUTOMATICALLY CONFIGURING MAC"

# Abort on error
set -e

# Print commands that are run as they are run
set -v

# Make a projects directory and clone the repo into it
mkdir -p ~/projects
cd ~/projects
brew install git
git clone https://github.com/nferrara100/mac.git
DIR=~/projects/mac
cd $DIR

print_green "Cloned repo into projects directory"

# Link custom settings to that they are updated automatically when changes are pulled.
ln -s $DIR/settings/.bash_profile ~/
ln -s $DIR/settings/.profile.sh ~/
cp settings/.profile.custom.sh ~/
cp settings/.gitconfig ~/
cp settings/.gitignore ~/
ln -s $DIR/settings/.vimrc ~/
ln -s $DIR/settings/.tmux.conf ~/

print_green "Copied required files"

# Install homebrew, a Mac package manager
NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install homebrew formulas
brew install awscli  # Amazon Web Services cli
brew install bash-completion  # Autocomplete for git
brew install gh  # Github cli
brew install git-lfs
brew install jupyterlab  # Interactive code editing notebook
brew install mas  # Install Mac App Store apps
brew install nvm  # local Javascript runtime
brew install postgresql  # database for local development
brew install pyenv-virtualenvwrapper
brew install rust
brew install thefuck
brew install tmux  # Terminal multitasking
brew install watchman
brew install zsh  # Improvements to the bash shell

# Get rid of default zsh config and replace with custom
rm -f ~/.zshrc
ln -s $DIR/settings/.zshrc ~/
print_green "Using custom .zshrc settings"

brew tap homebrew/cask-versions  # Required to install dev edition of Firefox
brew install --cask firefox-developer-edition  # Web browser with added dev tools

# Install homebrew casks
brew install --cask 1password  # Password manager
brew install --cask 1password-cli  # Use password manager in terminal
brew install --cask copyclip  # Clipboard history
brew install --cask docker  # Code containerisation
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

print_green "Completed main app installs"

# Install pyenv to run multiple versions of python at the same time
brew install pyenv
source ~/.bash_profile
pyenv install $PYTHON_VERSION
pyenv global $PYTHON_VERSION
pip install --upgrade pip

pip install bandit
pip install beautysh
pip install black
pip install flake8
pip install isort
pip install pre-commit
pip install pygments  # Dependency of zsh colorize

print_green "Completed Python installs"

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
print_green "Completed VSCode installs"

# Install zsh plugin manager
sh -c "$(curl -fsSL https://raw.github.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"

# Adding custom zsh plugin for syntax highlighting
mkdir -p ~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting
git clone https://github.com/zsh-users/zsh-syntax-highlighting ~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting

# Autosuggestions when typing in Zsh. Right arrow to autocomplete.
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions

# Poetry package manager for python
brew install poetry
mkdir -p $ZSH/plugins/poetry
poetry completions zsh > $ZSH/plugins/poetry/_poetry

# Setup Node Version Manager (NVM) for local JavaScript
mkdir -p ~/.nvm
source ~/.zshrc
nvm install --lts

# Install js globals
npm install -g renovate  # Dependency upgrades

print_green "Completed installs. Now configuring settings..."

# Install custom Firefox settings
FIREFOX_FOLDER="$HOME/Library/Application Support/Firefox/Profiles"
FIREFOX_PROFILE=$(find $FIREFOX_FOLDER \-name '*.dev-edition-default')
if [ -z "$FIREFOX_PROFILE" ]
then
    print_green "Could not find Firefox profile folder. Skipping Firefox settings..."
else
    ln -s settings/user.js $FIREFOX_PROFILE
fi

# Disable the “Are you sure you want to open this application?” dialog
defaults write com.apple.LaunchServices LSQuarantine -bool false

# Show all filename extensions
defaults write NSGlobalDomain AppleShowAllExtensions -bool true

# Show path bar in finder
defaults write com.apple.finder ShowPathbar -bool true

# Allow text selection in quick look
defaults write com.apple.finder QLEnableTextSelection -bool true

# When performing a search, search the current folder by default
defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"

# Disable the warning when changing a file extension
defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false

# Avoid creating .DS_Store files on network volumes
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true

# Use list view in all Finder windows by default
# Four-letter codes for the other view modes: `icnv`, `clmv`, `Flwv`
defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"

# Show keyboard layout selection on login screen
defaults write /Library/Preferences/com.apple.loginwindow showInputMenu -bool TRUE

# Disable screensaver
defaults -currentHost write com.apple.screensaver idleTime 0

# Clear bottom left hotcorner where create note is enabled by default
# Requires subsequent `killall Dock`
defaults write com.apple.dock wvous-br-corner -int 0

add_to_dock () {
    # Add $1 to the Mac dock
    # $1 == the string name of an app without the file extension
    defaults write com.apple.dock persistent-apps -array-add '<dict><key>tile-data</key><dict><key>file-data</key><dict><key>_CFURLString</key><string>/Applications/'$1'.app</string><key>_CFURLStringType</key><integer>0</integer></dict></dict></dict>'
}

# Add the following applications to the Mac dock
add_to_dock "1Password"
add_to_dock "Firefox Developer Edition"
add_to_dock "Google Chrome"
add_to_dock "iTerm"
add_to_dock "Kindle"
add_to_dock "Spotify"
add_to_dock "Utilities/Activity Monitor"
add_to_dock "Visual Studio Code"
# Required to make changes to the dock take effect
killall Dock

# Add directories to finder favorites
brew install --cask mysides
mysides add "Macintosh HD" file:///
mysides add $USER file:///Users/$USER/
mysides add Projects file:///Users/$USER/projects/
brew remove mysides

print_green "Please follow the manual instructions in the readme and then reboot your \
computer." "AUTOMATED CONFIGURATION COMPLETE"
