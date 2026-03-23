# shellcheck shell=bash
# shellcheck disable=SC2154 # Variables like $dim defined in lib/colors.sh
# Sourced by run.sh - configure macOS system preferences and Dock

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

# Clear Dock apps only if Dock is at default (has Mail/Safari) - skip on re-runs
current_dock=$(defaults read com.apple.dock persistent-apps 2>/dev/null | grep -c "file-label") || current_dock=0
if [[ "$current_dock" -gt 0 ]]; then
	# Check if it looks like default Dock (has Safari)
	has_safari=$(defaults read com.apple.dock persistent-apps 2>/dev/null | grep -c "Safari") || has_safari=0
	if [[ "$has_safari" -gt 0 ]]; then
		defaults write com.apple.dock persistent-apps -array
	fi
fi

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

# Do not show blue keyboard indicator over text when moving cursor
defaults write kCFPreferencesAnyApplication TSMLanguageIndicatorEnabled 0

# Import `add_to_dock` function
source "$SETUP/lib/add_to_dock.sh"

# Add the following applications to the Mac dock
# Track if any apps were added (return 0 = added, 2 = already present)
dock_changed=false
add_to_dock "1Password" && dock_changed=true
add_to_dock "Boop" && dock_changed=true
add_to_dock "Calculator" "System" && dock_changed=true
add_to_dock "Firefox Developer Edition" && dock_changed=true
add_to_dock "Google Chrome" && dock_changed=true
add_to_dock "iPhone Mirroring" "System" && dock_changed=true
add_to_dock "iTerm" && dock_changed=true
add_to_dock "NordVPN" && dock_changed=true
add_to_dock "Notes" "System" && dock_changed=true
add_to_dock "Photo Booth" "System" && dock_changed=true
add_to_dock "Reminders" "System" && dock_changed=true
add_to_dock "Spotify" && dock_changed=true
add_to_dock "Utilities/Activity Monitor" "System" && dock_changed=true
add_to_dock "Visual Studio Code" && dock_changed=true
add_to_dock "Weather" "System" && dock_changed=true

# Only restart Dock if apps were added
if [[ "$dock_changed" == "true" ]]; then
	killall Dock
fi
# Finder settings apply on next window open, no restart needed

# Add directories to Finder favorites
# brew install --cask mysides
# mysides add "Macintosh HD" file:///
# mysides add "$USER" file:///Users/"$USER"/
# mysides add Projects file:///Users/"$USER"/projects/
# brew remove mysides

echo -e "${dim}macOS preferences configured${reset}"
