#!/bin/bash
# Run this script to setup a new Mac
# ! It is not meant to be run on Macs that have already been setup!

# Print optional str $2 as bold green text
# Print str $1 on new line as normal green text
# Finally print time
print_green () {
    local GREEN='\033[0;32m'
    local BOLD_GREEN='\033[1;32m'
    local NO_COLOR='\033[0m'
    if (( $# >= 2 ))
    then
        local now
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
brew install git # Use Homebrew so that updates are easy
git clone https://github.com/nferrara100/mac.git
DIR=~/projects/mac
cd $DIR # Enter newly cloned repo

print_green "Cloned repo into projects directory"

# Link custom settings to that they are updated automatically when changes are pulled
ln -s $DIR/linked/.bash_profile ~/
ln -s $DIR/linked/.profile.sh ~/
cp copied/.env.sh ~/
cp copied/.gitconfig ~/
ln -s $DIR/linked/.vimrc ~/
ln -s $DIR/linked/.tmux.conf ~/

print_green "Copied required files"

# Install Homebrew, a Mac package manager
NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install Homebrew formulas
brew install awscli  # Amazon Web Services CLI
brew install bash-completion  # Autocomplete for Git
brew install chroma  # Syntax highlighting utility. Required by ZSH-Colorize
brew install deno  # TypeScript native Node alternative written in Rust
brew install fig  # IDE style terminal autocompletion
brew install gh  # Github CLI
brew install git-lfs  # Better handling of large files by Git
brew install jupyterlab  # Interactive code editing notebook
brew install mas  # Install Mac App Store apps
brew install nvm  # local JavaScript runtime
brew install postgresql  # Database for local development
brew install pyenv-virtualenvwrapper  # The easiest way to manage Python environments
brew install rust  # Rust programming language
brew install shellcheck  # Linting for shell scripts
brew install thefuck  # Type "fuck" after misspelling terminal commands to autocorrect
brew install tmux  # Terminal multitasking
brew install watchman
brew install zsh  # Use the most up to date version of Zsh, the default shell

# Get rid of default Zsh config and replace with custom
rm -f ~/.zshrc
ln -s $DIR/linked/.zshrc ~/
print_green "Using custom .zshrc settings"

brew tap homebrew/cask-versions  # Required to install dev edition of Firefox
brew install --cask firefox-developer-edition  # Web browser with added dev tools

# Install Homebrew casks
brew install --cask 1password  # Password manager
brew install --cask 1password-cli  # Use password manager in terminal
brew install --cask boop  # Scratchpad for developers with text wrangling tools
brew install --cask cheatsheet  # Easily see keyboard shortcuts for the current app
brew install --cask docker  # Code containerisation
brew install --cask google-chrome  # Web browser
brew install --cask gpg-suite  # GPG key generator
brew install --cask iterm2  # Terminal emulator
brew install --cask kindle  # Read Kindle books on desktop
brew install --cask microsoft-edge  # Major browser
brew install --cask nordvpn  # Paid VPN for privacy and security
brew install --cask openinterminal  # Open any folder in the terminal or an editor
brew install --cask paragon-ntfs  # Use NTFS hard drives - cross platform and journaled
brew install --cask postgres  # Local database
brew install --cask postman  # API builder and debugger
brew install --cask raycast  # Extendable app launcher and clipboard history
brew install --cask shottr  # Screenshots and on screen OCR
brew install --cask signal  # Secure messaging
brew install --cask skype  # Video calling
brew install --cask spotify  # Music streaming
brew install --cask the-unarchiver  # File compression utility
brew install --cask tiles  # Windows style windows that snap into place
brew install --cask visual-studio-code  # Graphical code editor
brew install --cask vlc  # Multimedia viewer
brew install --cask whatsapp  # Secure messaging
brew install --cask zoom  # Video calling

# ColorSlurp color picker - get any color on screen
mas install 1287239339

print_green "Completed main app installs"

# Install Pyenv to run multiple versions of python at the same time
brew install pyenv
# shellcheck disable=SC1090
source ~/.bash_profile
LATEST_PYTHON=$(pyenv install --list | grep --extended-regexp "^\s*[0-9][0-9.]*[0-9]\s*$" | tail -1)
pyenv install "$LATEST_PYTHON"
pyenv global "$LATEST_PYTHON"
pip install --upgrade pip

pip install bandit  # Python code security
pip install beautysh  # Bash code formatting
pip install black  # Python code formatting
pip install flake8  # Python linting
pip install isort  # Sort Python imports
pip install pre-commit  # Run multilingual commands before git commits
pip install pygments  # Dependency of Zsh colorize

print_green "Completed Python installs"

# Install VSCode extensions. View current at ~/.vscode/extensions
code --install-extension aaron-bond.better-comments
code --install-extension adpyke.codesnap
code --install-extension batisteo.vscode-django
code --install-extension bungcip.better-toml
code --install-extension christian-kohler.path-intellisense
code --install-extension davidanson.vscode-markdownlint
code --install-extension denoland.vscode-deno
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
code --install-extension rust-lang.rust-analyzer
code --install-extension stackbreak.comment-divider
code --install-extension streetsidesoftware.code-spell-checker
code --install-extension timonwong.shellcheck
code --install-extension ue.alphabetical-sorter
code --install-extension visualstudioexptteam.intellicode-api-usage-examples
code --install-extension visualstudioexptteam.vscodeintellicode
code --install-extension withfig.fig

# Add custom VSCode settings
ln -s $DIR/linked/settings.json ~/Library/Application\ Support/Code/User/
print_green "Completed VSCode installs"

# Install Zsh plugin manager
sh -c "$(curl -fsSL https://raw.github.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"

# Adding custom Zsh plugin for syntax highlighting
mkdir -p ~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting
git clone https://github.com/zsh-users/zsh-syntax-highlighting ~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting

# Autosuggestions when typing in Zsh. Right arrow to autocomplete.
git clone https://github.com/zsh-users/zsh-autosuggestions "${ZSH_CUSTOM:=~/.oh-my-zsh/custom}"/plugins/zsh-autosuggestions

# Poetry package manager for Python
brew install poetry
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
    ln -s $DIR/linked/user.js "$FIREFOX_PROFILE"
fi

# Disable screensaver
defaults -currentHost write com.apple.screensaver idleTime 0

# Hide the spotlight icon in the menu bar
defaults -currentHost write com.apple.Spotlight MenuItemHidden -int 1

# Show keyboard layout selection on login screen
defaults write /Library/Preferences/com.apple.loginwindow showInputMenu -bool TRUE

# Avoid creating .DS_Store files on network volumes
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true

# Dock defaults require subsequent `killall Dock`

# Place the Dock on the left of the screen
defaults write com.apple.dock "orientation" -string "left"

# Autohide the Dock
defaults write com.apple.dock autohide -bool true

# Unhide the Dock instantly. To undo set back to 0.5
defaults write com.apple.dock autohide-delay -float 0

# Open files by droping them on an icon in the Dock
defaults write com.apple.dock enable-spring-load-actions-on-all-items -bool true

# Remove all apps kept in Dock by default
defaults write com.apple.dock persistent-apps -array

# Don't show recent apps not presently open in the dock
defaults write com.apple.dock show-recents -bool FALSE

# Hidden apps are grayed out in Dock so they are obvious
defaults write com.apple.Dock showhidden -bool TRUE

# Clear bottom left hotcorner where create note is enabled by default
defaults write com.apple.dock wvous-br-corner -int 0

# When performing a search, search the current folder by default
defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"

# Disable the warning when changing a file extension
defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false

# Use list view in all Finder windows by default
# Four-letter codes for the other view modes: `icnv`, `clmv`, `Flwv`
defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"

# Show the home folder instead of recents when opening a new Finder window
defaults write com.apple.finder NewWindowTarget -string "PfHm"

# Allow text selection in quick look
defaults write com.apple.finder QLEnableTextSelection -bool true

# Show path bar in Finder
defaults write com.apple.finder ShowPathbar -bool true

# Press fn key to show emoji picker
defaults write com.apple.HIToolbox AppleFnUsageType -int 2

# Make iTerm open new tabs by default
defaults write com.googlecode.iterm2 OpenFileInNewWindows -bool false

# Use keyboard navigation
defaults write NSGlobalDomain AppleKeyboardUIMode -int 3

# Show all filename extensions
defaults write NSGlobalDomain AppleShowAllExtensions -bool true

add_to_dock () {
    # Add $1 to the Mac dock
    # $1 == the string name of an app without the file extension
    # $2 == "System" if an Apple app; unset otherwise

    local location="/Applications/"
    # If it's a system app use a different location
    if [ -n "$2" ]
    then
        location="/System/Applications/"
    fi
    defaults write com.apple.dock persistent-apps -array-add '<dict><key>tile-data</key><dict><key>file-data</key><dict><key>_CFURLString</key><string>'$location"$1"'.app</string><key>_CFURLStringType</key><integer>0</integer></dict></dict></dict>'
}

# Add the following applications to the Mac dock
add_to_dock "1Password"
add_to_dock "Boop"
add_to_dock "Firefox Developer Edition"
add_to_dock "Google Chrome"
add_to_dock "iTerm"
add_to_dock "Notes" "System"
add_to_dock "Photo Booth" "System"
add_to_dock "Reminders" "System"
add_to_dock "Spotify"
add_to_dock "Utilities/Activity Monitor" "System"
add_to_dock "Visual Studio Code"
# Required to make changes to the dock take effect
killall Dock

# Add directories to Finder favorites
brew install --cask mysides
mysides add "Macintosh HD" file:///
mysides add "$USER" file:///Users/"$USER"/
mysides add Projects file:///Users/"$USER"/projects/
brew remove mysides

print_green "Please follow the manual instructions in the readme and then reboot your \
computer." "AUTOMATED CONFIGURATION COMPLETE"
