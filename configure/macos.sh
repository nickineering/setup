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

# Build ignore lookup from DOCK_IGNORE_APPS (pipe-separated, set in ~/.env.sh)
declare -A _dock_ignored=()
if [[ -n "${DOCK_IGNORE_APPS:-}" ]]; then
	while IFS= read -r _app; do
		_dock_ignored["$_app"]=1
	done < <(echo "$DOCK_IGNORE_APPS" | tr '|' '\n')
fi

# Desired dock order: "path|label" — label is used for comparison with current dock
desired_dock_apps=(
	"/Applications/1Password.app|1Password"
	"/System/Applications/Apps.app|Apps"
	"/Applications/Boop.app|Boop"
	"/System/Applications/Calculator.app|Calculator"
	"/Applications/Firefox Developer Edition.app|Firefox Developer Edition"
	"/Applications/Google Chrome.app|Google Chrome"
	"/System/Applications/iPhone Mirroring.app|iPhone Mirroring"
	"/Applications/iTerm.app|iTerm"
	"/Applications/NordVPN.app|NordVPN"
	"/System/Applications/Notes.app|Notes"
	"/System/Applications/Photo Booth.app|Photo Booth"
	"/System/Applications/Reminders.app|Reminders"
	"/Applications/Spotify.app|Spotify"
	"/System/Applications/Utilities/Activity Monitor.app|Activity Monitor"
	"/Applications/Visual Studio Code.app|Visual Studio Code"
	"/System/Applications/Weather.app|Weather"
)

# Build the desired label list (only apps that exist and aren't ignored)
desired_labels=()
desired_paths=()
for entry in "${desired_dock_apps[@]}"; do
	app_path="${entry%%|*}" label="${entry##*|}"
	[[ -n "${_dock_ignored[$label]+x}" ]] && continue
	if [[ ! -d "$app_path" ]]; then
		warn "App not found at $app_path, skipping dock addition"
		continue
	fi
	desired_labels+=("$label")
	desired_paths+=("$app_path")
done

# Read current dock labels in order
current_labels=()
while IFS= read -r dock_app; do
	[[ -z "$dock_app" ]] && continue
	current_labels+=("$dock_app")
done < <(defaults read com.apple.dock persistent-apps 2>/dev/null | grep -o '"file-label" = [^;]*' | sed 's/"file-label" = //' | sed 's/"//g')

# Detect fresh install: Safari is always in the macOS default dock but not in our desired list
_is_fresh_dock=false
for dock_app in "${current_labels[@]}"; do
	if [[ "$dock_app" == "Safari" ]]; then
		_is_fresh_dock=true
		break
	fi
done

# Detect unmanaged apps (in current dock but not desired and not ignored)
declare -A _desired_set=()
for label in "${desired_labels[@]}"; do _desired_set["$label"]=1; done
for dock_app in "${current_labels[@]}"; do
	if [[ -z "${_desired_set[$dock_app]+x}" && -z "${_dock_ignored[$dock_app]+x}" ]]; then
		warn "'$dock_app' is in Dock but not managed by setup — remove manually if unwanted"
	fi
done

if $_is_fresh_dock; then
	# Fresh install: rebuild dock from scratch with only desired apps
	if [[ "${desired_labels[*]}" != "${current_labels[*]}" ]]; then
		defaults write com.apple.dock persistent-apps -array
		for app_path in "${desired_paths[@]}"; do
			defaults write com.apple.dock persistent-apps -array-add \
				'<dict><key>tile-data</key><dict><key>file-data</key><dict><key>_CFURLString</key><string>'"$app_path"'</string><key>_CFURLStringType</key><integer>0</integer></dict></dict></dict>'
		done
		killall Dock
	fi
else
	# Existing install: only add missing desired apps, don't remove unmanaged ones
	declare -A _current_set=()
	for label in "${current_labels[@]}"; do _current_set["$label"]=1; done
	_dock_changed=false
	for i in "${!desired_labels[@]}"; do
		if [[ -z "${_current_set[${desired_labels[$i]}]+x}" ]]; then
			defaults write com.apple.dock persistent-apps -array-add \
				'<dict><key>tile-data</key><dict><key>file-data</key><dict><key>_CFURLString</key><string>'"${desired_paths[$i]}"'</string><key>_CFURLStringType</key><integer>0</integer></dict></dict></dict>'
			_dock_changed=true
		fi
	done
	if $_dock_changed; then
		killall Dock
	fi
fi

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
