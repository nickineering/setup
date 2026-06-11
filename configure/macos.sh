# shellcheck shell=bash
# shellcheck disable=SC2154 # Variables like $dim defined in lib/colors.sh

# ── Trackpad ─────────────────────────────────────────────────────────────────

# Increase tracking speed (requires reboot)
defaults write -g com.apple.trackpad.scaling 1.5

# ── Spotlight (disabled — using Raycast instead) ─────────────────────────────

# Requires reboot. Key 64 = Cmd+Space, Key 65 = Cmd+Opt+Space
HOTKEYS_PLIST=~/Library/Preferences/com.apple.symbolichotkeys.plist
/usr/libexec/PlistBuddy -c "Set :AppleSymbolicHotKeys:64:enabled false" "$HOTKEYS_PLIST" 2>/dev/null ||
	/usr/libexec/PlistBuddy -c "Add :AppleSymbolicHotKeys:64:enabled bool false" "$HOTKEYS_PLIST"
/usr/libexec/PlistBuddy -c "Set :AppleSymbolicHotKeys:65:enabled false" "$HOTKEYS_PLIST" 2>/dev/null ||
	/usr/libexec/PlistBuddy -c "Add :AppleSymbolicHotKeys:65:enabled bool false" "$HOTKEYS_PLIST"

# Disable screensaver
defaults -currentHost write com.apple.screensaver idleTime 0
# Hide the Spotlight icon from the menu bar (using Raycast instead)
defaults -currentHost write com.apple.Spotlight MenuItemHidden -int 1

# ── Desktop ──────────────────────────────────────────────────────────────────

# Prevent .DS_Store files on network volumes
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true

# ── Dock ─────────────────────────────────────────────────────────────────────

# Autohide the Dock
defaults write com.apple.dock autohide -bool true
# Show the Dock instantly with no delay (default is 0.5s)
defaults write com.apple.dock autohide-delay -float 0
# Allow opening files by dropping them on Dock icons
defaults write com.apple.dock enable-spring-load-actions-on-all-items -bool true
# "scale" is faster than the default "genie" minimize animation
defaults write com.apple.dock mineffect -string "scale"

# Only clear default Dock on first run — presence of Safari means untouched.
# "file-label" is how plist encodes each Dock entry's display name.
current_dock=$(defaults read com.apple.dock persistent-apps 2>/dev/null | grep -c "file-label") || current_dock=0
if [[ "$current_dock" -gt 0 ]]; then
	has_safari=$(defaults read com.apple.dock persistent-apps 2>/dev/null | grep -c "Safari") || has_safari=0
	if [[ "$has_safari" -gt 0 ]]; then
		defaults write com.apple.dock persistent-apps -array
	fi
fi

# Don't show recent apps in the Dock
defaults write com.apple.dock show-recents -bool FALSE
# Gray out hidden apps so their state is visible
defaults write com.apple.dock showhidden -bool TRUE
# Disable bottom-right hot corner (default is "create note")
defaults write com.apple.dock wvous-br-corner -int 0

# ── Finder ───────────────────────────────────────────────────────────────────

# Show full POSIX path in window title
defaults write com.apple.finder _FXShowPosixPathInTitle -bool true
# Keep folders above files when sorting by name
defaults write com.apple.finder _FXSortFoldersFirst -bool true
# Search the current folder by default (not the whole Mac)
defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"
# Disable the warning when changing a file extension
defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false
# Use list view by default (Nlsv=list, icnv=icon, clmv=column, Flwv=gallery)
defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"
# Open new windows to home folder instead of Recents
defaults write com.apple.finder NewWindowTarget -string "PfHm"
# Allow text selection in Quick Look previews
defaults write com.apple.finder QLEnableTextSelection -bool true
# Allow quitting Finder via Cmd+Q
defaults write com.apple.finder QuitMenuItem -bool true
# Show path bar at the bottom of Finder windows
defaults write com.apple.finder ShowPathbar -bool true

# ── Keyboard & Input ─────────────────────────────────────────────────────────

# Press fn to show emoji picker instead of switching input source
defaults write com.apple.HIToolbox AppleFnUsageType -int 2
# Make iTerm open new tabs instead of windows when opening files
defaults write com.googlecode.iterm2 OpenFileInNewWindows -bool false
# Tab through all UI controls, not just text fields
defaults write NSGlobalDomain AppleKeyboardUIMode -int 3
# Show all filename extensions in Finder
defaults write NSGlobalDomain AppleShowAllExtensions -bool true
# Disable the blue cursor indicator when moving between text fields
defaults write kCFPreferencesAnyApplication TSMLanguageIndicatorEnabled 0

source "$SETUP/lib/add_to_dock.sh"

# add_to_dock returns 0 if added, 2 if already present
dock_changed=false
add_to_dock "1Password" && dock_changed=true
add_to_dock "Apps" "System" && dock_changed=true
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

if [[ "$dock_changed" == "true" ]]; then
	killall Dock
fi

# Detect apps in Dock that aren't managed here (leftover from previous config)
desired_dock_apps=(
	"1Password" "Apps" "Boop" "Calculator" "Firefox Developer Edition"
	"Google Chrome" "iPhone Mirroring" "iTerm" "NordVPN" "Notes" "Photo Booth"
	"Reminders" "Spotify" "Activity Monitor" "Visual Studio Code" "Weather"
)
while IFS= read -r dock_app; do
	[[ -z "$dock_app" ]] && continue
	found=false
	for desired in "${desired_dock_apps[@]}"; do
		if [[ "$dock_app" == "$desired" ]]; then
			found=true
			break
		fi
	done
	if [[ "$found" == "false" ]]; then
		warn "'$dock_app' is in Dock but not managed by setup — remove manually if unwanted"
	fi
done < <(defaults read com.apple.dock persistent-apps 2>/dev/null | grep -o '"file-label" = [^;]*' | sed 's/"file-label" = //' | sed 's/"//g')

# Only add missing login items (wiping + re-adding triggers macOS permission popups)
login_items=(
	"/Applications/1Password.app"
	"/Applications/Google Chrome.app"
	"/Applications/KeyClu.app"
	"/Applications/Raycast.app"
	"/Applications/Rocket.app"
	"/Applications/Shottr.app"
)
current_login_items=$(osascript -e 'tell application "System Events" to get the path of every login item' 2>/dev/null || true)
for app_path in "${login_items[@]}"; do
	if [[ "$current_login_items" != *"$app_path"* ]]; then
		osascript -e "tell application \"System Events\" to make login item at end with properties {path:\"$app_path\", hidden:false}" 2>/dev/null || true
	fi
done

# Detect login items not managed here
if [[ -n "$current_login_items" ]]; then
	while IFS= read -r item_path; do
		[[ -z "$item_path" ]] && continue
		found=false
		for desired in "${login_items[@]}"; do
			if [[ "$item_path" == "$desired" ]]; then
				found=true
				break
			fi
		done
		if [[ "$found" == "false" ]]; then
			app_name=$(basename "$item_path" .app)
			warn "'$app_name' is a login item but not managed by setup — remove manually if unwanted"
		fi
	done <<<"${current_login_items//, /$'\n'}"
fi

info "macOS preferences configured"
