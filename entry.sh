#!/bin/bash

echo "Please close all work and wait for your Mac to be configured. This may take a while."

# Install homebrew, a unix package manager
/usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"

brew install redline  # pyenv dependency
brew install xz  # pyenv dependency
brew install pyenv  # Run multiple python versions at once
brew install pyenv-virtualenvwrapper

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
brew install black  # Python formatter

brew cask install 1password  # Password manager
brew cask install 1password-cli  # Use password manager in terminal
brew cask install adobe-creative-cloud  # Use to install XD (extra step needed)
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

yarn global add eslint  # Javascript code analyser
yarn global add eslint-plugin-react  # Adds React compatibility to eslint
yarn global add expo-cli  # Develop React Native apps with ease
yarn global add prettier  # Code formatter
yarn global add react-devtools  # Debug React

code --install-extension batisteo.vscode-django
code --install-extension bungcip.better-toml
code --install-extension christian-kohler.path-intellisense
code --install-extension CoenraadS.bracket-pair-colorizer
code --install-extension dbaeumer.vscode-eslint
code --install-extension developertejasjadhav.javascript-refactor--sort-imports
code --install-extension eamodio.gitlens
code --install-extension esbenp.prettier-vscode
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
code --install-extension streetsidesoftware.code-spell-checker
code --install-extension ue.alphabetical-sorter
code --install-extension vsmobile.vscode-react-native

# Microsoft remote desktop
mas install 1295203466
# Xcode
mas install 497799835

curl -sSL https://raw.githubusercontent.com/sdispater/poetry/master/get-poetry.py | python

mkdir ~/Documents/Code/
git clone https://github.com/RCVS-London/dotfiles.git ~/Documents/Code/

echo "Automated Mac configuration complete. Please follow the manual instructions in the Readme and then reboot your computer."
