# shellcheck shell=bash
# shellcheck disable=SC2034,SC2154
#
# Links dotfiles from linked/ into $HOME, VSCode settings into its User dir,
# and dprint config to ~/. Removes symlinks for files deleted from state.
# Copies templates (copied/) only when target doesn't exist so user edits are preserved.
: "${SETUP:?}" "${DOTFILES:?}" "${removed_links?}"

links_created=0
links_removed=0

# Remove symlinks for files deleted from state
while IFS= read -r file; do
	[[ -z "$file" ]] && continue
	target=~/"$file"
	if [[ -L "$target" ]]; then
		trash "$target"
		echo "✓ Unlinked: $file"
		((links_removed++)) || true
	fi
done <<<"$removed_links"

# Create symlinks for dotfiles listed in state
while IFS= read -r file; do
	[[ -z "$file" || "$file" == \#* ]] && continue
	if [[ ! -f "$DOTFILES/$file" ]]; then
		warn "Dotfile not found: $DOTFILES/$file" >&2
		continue
	fi
	create_link "$DOTFILES/$file" ~/"$file"
done <"$SETUP"/state/linked_files.txt

# VSCode settings
VSCODE_USER_DIR="$HOME/Library/Application Support/Code/User"
if command -v code &>/dev/null && [[ ! -d "$VSCODE_USER_DIR" ]]; then
	mkdir -p "$VSCODE_USER_DIR"
fi
if [[ -d "$VSCODE_USER_DIR" ]]; then
	create_link "$DOTFILES/settings.json" "$VSCODE_USER_DIR/settings.json" "settings.json -> VSCode"
fi

create_link "$SETUP/dprint.jsonc" ~/dprint.jsonc

# Copy template files (only if target doesn't already exist)
files_copied=0
while IFS= read -r file; do
	[[ -z "$file" || "$file" == \#* ]] && continue
	if [[ ! -e ~/"$file" ]]; then
		cp "$SETUP/copied/$file" ~/
		echo "✓ Created: ~/$file (from template)"
		((files_copied++)) || true
	fi
done <"$SETUP"/state/copied_files.txt

mkdir -p ~/.vim/swaps/ ~/.vim/backups/ ~/.vim/undo/

if [[ $links_created -eq 0 && $links_removed -eq 0 && $files_copied -eq 0 ]]; then
	info "All symlinks up to date"
fi
echo ""
