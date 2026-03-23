#!/opt/homebrew/bin/bash
# shellcheck disable=SC2154 # Variables like $bold defined in lib/colors.sh

# Unified setup script: initial setup and daily maintenance.
# Safe to run anytime - all operations are idempotent or diff-based.
#
# Configuration (set in ~/.env.sh):
#   GITLAB_GROUP        - GitLab group/namespace to sync (optional)
#   GITLAB_EXCLUDE_DIRS - Pipe-separated dirs to exclude (optional)

set -euo pipefail

# Guard: refuse to run as root
if [[ $EUID -eq 0 ]]; then
	echo "Error: Do not run this script as root" >&2
	exit 1
fi

export SETUP="${HOME:?}/projects/setup"
export DOTFILES="$SETUP/linked"

# Validate critical paths exist before proceeding
[[ -d "$SETUP" ]] || {
	echo "Error: SETUP directory not found: $SETUP" >&2
	exit 1
}
[[ -d "$DOTFILES" ]] || {
	echo "Error: DOTFILES directory not found: $DOTFILES" >&2
	exit 1
}

cd "$SETUP"

# Utilities
source lib/colors.sh
source lib/backup.sh
source lib/packages.sh

# Trap handler for cleanup on interruption
CURRENT_STEP=""
cleanup_on_interrupt() {
	echo "" >&2
	echo -e "${yellow}Setup interrupted!${reset}" >&2
	if [[ -n "$CURRENT_STEP" ]]; then
		echo -e "Stopped during: ${bold}$CURRENT_STEP${reset}" >&2
	fi
	echo -e "To resume, run: ${cyan}$SETUP/run.sh${reset}" >&2
	exit 130
}
trap cleanup_on_interrupt INT TERM

echo -e "${bold}${cyan}=== Starting setup ===${reset}"
echo ""

# =============================================================================
# Step 1: Update setup repo and detect state file changes
# =============================================================================
CURRENT_STEP="updating setup repo"
echo -e "${bold}${cyan}=== Updating setup repo ===${reset}"

# Capture state before pull (for detecting changes after pull)
old_packages=$(parse_state_file "$SETUP/state/brew_packages.txt")
old_casks=$(parse_state_file "$SETUP/state/brew_casks.txt")
old_extensions=$(parse_state_file "$SETUP/state/vscode_extensions.txt" | tr '[:upper:]' '[:lower:]')

pull_output=$(git -C "$SETUP" pull 2>&1) || {
	echo -e "${yellow}Warning: git pull failed (local changes?) - state file changes won't be detected${reset}"
}
if [[ "$pull_output" == "Already up to date." ]]; then
	echo -e "${dim}Up to date${reset}"
else
	echo "$pull_output"
fi

# Compare after pull to find what changed
new_packages=$(parse_state_file "$SETUP/state/brew_packages.txt")
new_casks=$(parse_state_file "$SETUP/state/brew_casks.txt")
new_extensions=$(parse_state_file "$SETUP/state/vscode_extensions.txt" | tr '[:upper:]' '[:lower:]')

# Calculate removals from state file changes (will prompt user in later steps)
removed_packages=$(set_difference "$new_packages" "$old_packages")
removed_casks=$(set_difference "$new_casks" "$old_casks")
removed_extensions=$(set_difference "$new_extensions" "$old_extensions")
echo ""

# =============================================================================
# Step 2: Homebrew taps
# =============================================================================
CURRENT_STEP="configuring Homebrew taps"
echo -e "${bold}${cyan}=== Configuring Homebrew taps ===${reset}"
brew tap beeftornado/rmtree >/dev/null 2>&1 || true
brew tap hashicorp/tap >/dev/null 2>&1 || true
echo -e "${dim}Taps configured${reset}"
echo ""

# =============================================================================
# Step 3: Homebrew upgrade (update existing packages first)
# =============================================================================
CURRENT_STEP="upgrading Homebrew packages"
echo -e "${bold}${cyan}=== Upgrading Homebrew packages ===${reset}"
outdated=$(brew outdated --formula --cask 2>/dev/null || true)
if [[ -n "$outdated" ]]; then
	echo -e "${dim}Upgrading: $(echo "$outdated" | tr '\n' ' ')${reset}"
	brew upgrade || echo -e "${yellow}Warning: Some packages failed to upgrade${reset}"
else
	echo -e "${dim}All packages up to date${reset}"
fi
echo ""

# =============================================================================
# Step 4: Install missing packages and casks
# =============================================================================
CURRENT_STEP="installing Homebrew packages and casks"
echo -e "${bold}${cyan}=== Installing Homebrew packages ===${reset}"

# Get full desired state and install anything missing
desired_packages=$(parse_state_file "$SETUP/state/brew_packages.txt")
installed_packages=$(get_installed_packages)
missing_packages=$(set_difference "$installed_packages" "$desired_packages")
if [[ -n "$missing_packages" ]]; then
	install_missing package "$missing_packages"
else
	echo -e "${dim}All packages installed${reset}"
fi
echo ""

# Finish installing chromedriver
CHROMEDRIVER_PATH="$(brew --prefix)/bin/chromedriver"
if [[ -f "$CHROMEDRIVER_PATH" ]]; then
	xattr -d com.apple.quarantine "$CHROMEDRIVER_PATH" 2>/dev/null || true
fi

echo -e "${bold}${cyan}=== Installing Homebrew casks ===${reset}"
desired_casks=$(parse_state_file "$SETUP/state/brew_casks.txt")
installed_casks=$(get_installed_casks)
missing_casks=$(set_difference "$installed_casks" "$desired_casks")
if [[ -n "$missing_casks" ]]; then
	install_missing cask "$missing_casks"
else
	echo -e "${dim}All casks installed${reset}"
fi

# Prompt for removals from state file changes (detected in step 1)
[[ -n "$removed_packages" ]] && prompt_uninstall package "$removed_packages"
[[ -n "$removed_casks" ]] && prompt_uninstall cask "$removed_casks"
echo ""

# =============================================================================
# Step 5: Symlinks and file copies
# =============================================================================
CURRENT_STEP="creating symlinks"
echo -e "${bold}${cyan}=== Creating symlinks ===${reset}"

# Backup/remove existing files before linking
while IFS= read -r file; do
	[[ -z "$file" || "$file" == \#* ]] && continue
	backup_or_delete ~/"$file" || true
done <"$SETUP"/state/linked_files.txt
backup_or_delete "$HOME/Library/Application Support/Code/User/settings.json" || true
backup_or_delete "$HOME/Library/Application Support/ruff/ruff.toml" || true
backup_or_delete ~/dprint.jsonc || true

# Create symlinks
while IFS= read -r file; do
	[[ -z "$file" || "$file" == \#* ]] && continue
	if [[ ! -f "$DOTFILES/$file" ]]; then
		echo -e "${yellow}Warning: Dotfile not found: $DOTFILES/$file${reset}" >&2
		continue
	fi
	ln -sfn "$DOTFILES/$file" ~/ || echo -e "${yellow}Warning: Failed to link $file${reset}" >&2
done <"$SETUP"/state/linked_files.txt

# VSCode settings (create User dir if VSCode is installed but dir doesn't exist)
VSCODE_USER_DIR="$HOME/Library/Application Support/Code/User"
if command -v code &>/dev/null && [[ ! -d "$VSCODE_USER_DIR" ]]; then
	mkdir -p "$VSCODE_USER_DIR"
fi
if [[ -d "$VSCODE_USER_DIR" ]]; then
	ln -sfn "$DOTFILES"/settings.json "$VSCODE_USER_DIR/settings.json" || true
fi

# dprint config
ln -sfn "$SETUP"/dprint.jsonc ~/dprint.jsonc || true

# Copy templates (only if not exists)
while IFS= read -r file; do
	[[ -z "$file" || "$file" == \#* ]] && continue
	if [[ ! -e ~/"$file" ]]; then
		cp "$SETUP/copied/$file" ~/
	fi
done <"$SETUP"/state/copied_files.txt

# Vim directories
mkdir -p ~/.vim/swaps/ ~/.vim/backups/ ~/.vim/undo/
echo -e "${dim}Symlinks created${reset}"
echo ""

# =============================================================================
# Step 6: Tool configurations
# =============================================================================
CURRENT_STEP="configuring tools"
echo -e "${bold}${cyan}=== Configuring tools ===${reset}"

source configure/zsh.sh
source configure/firefox.sh
source configure/ruff.sh
source configure/claude.sh

# Python config (guard: uv must be installed)
if command -v uv &>/dev/null; then
	source configure/python.sh
else
	echo -e "${yellow}Warning: uv not found, skipping Python configuration${reset}"
fi

# Node config (guard: nvm must be installed)
if [[ -s "$(brew --prefix)/opt/nvm/nvm.sh" ]]; then
	source configure/node.sh
else
	echo -e "${yellow}Warning: nvm not found, skipping Node configuration${reset}"
fi

echo -e "${dim}Checked: Zsh, Firefox, Ruff, Claude, Python, Node${reset}"
echo ""

# =============================================================================
# Step 7: macOS configuration (after casks so Dock apps exist)
# =============================================================================
CURRENT_STEP="configuring macOS"
echo -e "${bold}${cyan}=== Configuring macOS ===${reset}"
source configure/macos.sh
echo ""

# =============================================================================
# Step 8: VSCode extensions (after casks so `code` CLI exists)
# =============================================================================
CURRENT_STEP="installing VSCode extensions"
echo -e "${bold}${cyan}=== Installing VSCode extensions ===${reset}"
if command -v code &>/dev/null; then
	desired_extensions=$(parse_state_file "$SETUP/state/vscode_extensions.txt" | tr '[:upper:]' '[:lower:]')
	installed_extensions=$(get_installed_extensions)
	missing_extensions=$(set_difference "$installed_extensions" "$desired_extensions")
	if [[ -n "$missing_extensions" ]]; then
		install_missing extension "$missing_extensions"
	else
		echo -e "${dim}All extensions installed${reset}"
	fi
	# Handle removals from state file changes
	[[ -n "$removed_extensions" ]] && prompt_uninstall extension "$removed_extensions"
	echo ""

	echo -e "${bold}${cyan}=== Updating VSCode extensions ===${reset}"
	update_output=$(code --update-extensions 2>&1)
	if [[ "$update_output" == "No extension to update" ]]; then
		echo -e "${dim}All extensions up to date${reset}"
	else
		echo "$update_output"
	fi
else
	echo -e "${dim}VSCode CLI not found - skipping (install VSCode cask first)${reset}"
fi
echo ""

# =============================================================================
# Step 9: GitLab repo sync (after glab installed)
# =============================================================================
CURRENT_STEP="syncing GitLab repos"
echo -e "${bold}${cyan}=== Syncing GitLab repos ===${reset}"
source sync/repos.sh
sync_repos
echo ""

# =============================================================================
# Step 10: Tool updates (with first-run guards)
# =============================================================================
CURRENT_STEP="updating tools"

echo -e "${bold}${cyan}=== Updating development tools ===${reset}"

if command -v uv &>/dev/null; then
	uv_output=$(uv tool upgrade --all 2>&1) || echo -e "${yellow}Warning: uv tool upgrade failed${reset}"
	if [[ "$uv_output" == "Nothing to upgrade" ]]; then
		echo -e "${dim}uv tools: up to date${reset}"
	else
		echo -e "${dim}uv tools: $uv_output${reset}"
	fi
fi

if command -v tldr &>/dev/null; then
	tldr --update >/dev/null 2>&1 || echo -e "${yellow}Warning: tldr update failed${reset}"
	echo -e "${dim}tldr: pages updated${reset}"
fi

export ZSH="${ZSH:-$HOME/.oh-my-zsh}"
if [[ -d "$ZSH" && -x "$ZSH/tools/upgrade.sh" ]]; then
	omz_output=$("$ZSH/tools/upgrade.sh" -v minimal 2>&1) || echo -e "${yellow}Warning: Oh My Zsh update failed${reset}"
	if [[ "$omz_output" == *"already at the latest"* ]]; then
		echo -e "${dim}Oh My Zsh: up to date${reset}"
	else
		echo -e "${dim}Oh My Zsh: updated${reset}"
	fi
fi

if command -v go &>/dev/null; then
	go install golang.org/x/tools/gopls@latest 2>/dev/null || echo -e "${yellow}Warning: gopls update failed${reset}"
	go install honnef.co/go/tools/cmd/staticcheck@latest 2>/dev/null || echo -e "${yellow}Warning: staticcheck update failed${reset}"
	echo -e "${dim}Go tools: gopls, staticcheck${reset}"
fi
echo ""

# =============================================================================
# Step 11: Privileged operations (grouped at end, single sudo prompt)
# =============================================================================
CURRENT_STEP="" # Clear so interrupt doesn't look like an error
echo -e "${bold}${cyan}=== Privileged operations ===${reset}"

# Check what needs sudo
sudo_tasks=()
ZOOM_DAEMON="/Library/LaunchDaemons/us.zoom.ZoomDaemon.plist"
needs_zoom=false
if [[ -f "$ZOOM_DAEMON" ]] && ! launchctl list 2>/dev/null | grep -q 'us.zoom.ZoomDaemon'; then
	sudo_tasks+=("Enable Zoom auto-update daemon")
	needs_zoom=true
fi
sudo_tasks+=("Install macOS system updates (optional)")

echo "The following operations require sudo:"
for task in "${sudo_tasks[@]}"; do
	echo "  - $task"
done
echo ""
echo -n "Continue with privileged operations? [y/N]: "
read -r -n 1 run_sudo </dev/tty
echo ""

if [[ "$run_sudo" =~ ^[Yy]$ ]]; then
	# Zoom daemon (if needed)
	if [[ "$needs_zoom" == "true" ]]; then
		echo -e "${dim}Enabling Zoom auto-update daemon...${reset}"
		sudo launchctl load -w "$ZOOM_DAEMON" 2>/dev/null || echo -e "${yellow}Warning: Failed to load Zoom daemon${reset}"
	fi

	# macOS updates (sub-prompt since it can take a while)
	echo -n "Install macOS system updates now? [y/N]: "
	read -r -n 1 install_updates </dev/tty
	echo ""
	if [[ "$install_updates" =~ ^[Yy]$ ]]; then
		echo -e "${dim}Installing updates...${reset}"
		sudo softwareupdate -i -a || echo -e "${yellow}Warning: Some updates failed${reset}"
	else
		echo -e "${dim}Skipped macOS updates${reset}"
	fi
else
	echo -e "${dim}Skipped privileged operations${reset}"
fi
echo ""
echo -e "${bold}${green}=== Setup complete! ===${reset}"

# Remind about post-setup steps
echo ""
echo -e "${bold}Next steps:${reset} See ${cyan}$SETUP/MANUAL_STEPS.md${reset} for remaining manual configuration."
if [[ "${FIREFOX_NEEDS_SETUP:-}" == "1" ]]; then
	echo -e "${yellow}Note:${reset} Firefox settings were skipped. Launch Firefox and sign in, then run:"
	echo -e "  ${cyan}$SETUP/configure/after_signin.sh${reset}"
fi
