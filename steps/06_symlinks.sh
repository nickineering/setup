# shellcheck shell=bash
# shellcheck disable=SC2034,SC2154
#
# ── Symlinks ─────────────────────────────────────────────────────────────────
# Links dotfiles from linked/ into $HOME, VSCode settings into its User dir,
# and dprint config to ~/. Copies template files (copied/) only when the target
# doesn't already exist, so user edits are preserved. Creates Vim directories.
# Requires: lib/links.sh (create_link), lib/backup.sh (backup_or_delete)
# ─────────────────────────────────────────────────────────────────────────────
: "${SETUP:?}" "${DOTFILES:?}"

links_created=0

# Create symlinks for dotfiles
while IFS= read -r file; do
	[[ -z "$file" || "$file" == \#* ]] && continue
	if [[ ! -f "$DOTFILES/$file" ]]; then
		echo -e "${yellow}Warning: Dotfile not found: $DOTFILES/$file${reset}" >&2
		continue
	fi
	create_link "$DOTFILES/$file" ~/"$file"
done <"$SETUP"/state/linked_files.txt

# VSCode settings (create User dir if VSCode is installed but dir doesn't exist)
VSCODE_USER_DIR="$HOME/Library/Application Support/Code/User"
if command -v code &>/dev/null && [[ ! -d "$VSCODE_USER_DIR" ]]; then
	mkdir -p "$VSCODE_USER_DIR"
fi
if [[ -d "$VSCODE_USER_DIR" ]]; then
	create_link "$DOTFILES/settings.json" "$VSCODE_USER_DIR/settings.json" "settings.json -> VSCode"
fi

# dprint config
create_link "$SETUP/dprint.jsonc" ~/dprint.jsonc

# Copy templates (only if not exists)
files_copied=0
while IFS= read -r file; do
	[[ -z "$file" || "$file" == \#* ]] && continue
	if [[ ! -e ~/"$file" ]]; then
		cp "$SETUP/copied/$file" ~/
		echo "Created: ~/$file (from template)"
		((files_copied++)) || true
	fi
done <"$SETUP"/state/copied_files.txt

# Vim directories
mkdir -p ~/.vim/swaps/ ~/.vim/backups/ ~/.vim/undo/

if [[ $links_created -eq 0 && $files_copied -eq 0 ]]; then
	echo -e "${dim}All symlinks up to date${reset}"
fi
echo ""
