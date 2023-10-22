#!/usr/local/bin/bash

# Disable screensaver
defaults -currentHost write com.apple.screensaver idleTime 0

# Hide the spotlight icon in the menu bar
defaults -currentHost write com.apple.Spotlight MenuItemHidden -int 1

# Avoid creating .DS_Store files on network volumes
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true

# Autohide the Dock
defaults write com.apple.dock autohide -bool true

# Unhide the Dock instantly. To undo set back to 0.5
defaults write com.apple.dock autohide-delay -float 0

# Open files by droping them on an icon in the Dock
defaults write com.apple.dock enable-spring-load-actions-on-all-items -bool true

# Speeds up window minimizing and maximizing
defaults write com.apple.dock mineffect -string "scale"

# Remove all apps kept in Dock by default
defaults write com.apple.dock persistent-apps -array

# Don't show recent apps not presently open in the dock
defaults write com.apple.dock show-recents -bool FALSE

# Hidden apps are grayed out in Dock so they are obvious
defaults write com.apple.dock showhidden -bool TRUE

# Clear bottom left hotcorner where create note is enabled by default
defaults write com.apple.dock wvous-br-corner -int 0

# Display full POSIX path as Finder window title
defaults write com.apple.finder _FXShowPosixPathInTitle -bool true

# Keep folders on top when sorting by name
defaults write com.apple.finder _FXSortFoldersFirst -bool true

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

# Allow quitting Finder
defaults write com.apple.finder QuitMenuItem -bool true

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

# Import `add_to_dock` function
source add_to_dock.sh

# Add the following applications to the Mac dock
add_to_dock "1Password"
add_to_dock "Boop"
add_to_dock "Firefox Developer Edition"
add_to_dock "Google Chrome"
add_to_dock "iTerm"
add_to_dock "NordVPN"
add_to_dock "Notes" "System"
add_to_dock "Photo Booth" "System"
add_to_dock "Reminders" "System"
add_to_dock "Spotify"
add_to_dock "Utilities/Activity Monitor" "System"
add_to_dock "Visual Studio Code"
# Required to make changes to the Dock and Finder take effect
killall Dock
killall Finder

# Add directories to Finder favorites
brew install --cask mysides
mysides add "Macintosh HD" file:///
mysides add "$USER" file:///Users/"$USER"/
mysides add Projects file:///Users/"$USER"/projects/
brew remove mysides
