# shellcheck shell=bash
# shellcheck disable=SC2034,SC2154
#
# Links dotfiles from linked/ into $HOME, VSCode settings into its User dir,
# dprint config to ~/, and the helper scripts from scripts/ into ~/.local/bin.
# Removes symlinks for files deleted from state.
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
		success "Unlinked: $file"
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

# Helper scripts: linked into ~/.local/bin (on PATH via .profile.sh) without the
# .py extension, so scripts/awake.py is run by typing `awake`. Each script
# declares its own dependencies inline and runs under uv, so adding one is just
# dropping an executable file into scripts/ - no list to update here.
BIN_DIR="$HOME/.local/bin"
mkdir -p "$BIN_DIR"
for script in "$SETUP"/scripts/*.py; do
	[[ -f "$script" ]] || continue # unmatched glob when scripts/ is empty
	script_name=$(basename "$script" .py)
	if [[ ! -x "$script" ]]; then
		warn "Not executable, skipping: scripts/$script_name.py (chmod +x it)" >&2
		continue
	fi
	create_link "$script" "$BIN_DIR/$script_name" "$script_name -> ~/.local/bin"
done

# Prune links left by scripts since deleted or renamed. Detecting them as
# dangling links back into scripts/ avoids a second list to keep in sync, and
# the prefix check leaves links from other tools (uv, pipx) alone.
for link in "$BIN_DIR"/*; do
	[[ -L "$link" ]] || continue
	link_target=$(readlink "$link")
	[[ "$link_target" == "$SETUP/scripts/"* && ! -e "$link_target" ]] || continue
	trash "$link"
	success "Unlinked: $(basename "$link")"
	((links_removed++)) || true
done

# Copy template files (only if target doesn't already exist)
files_copied=0
while IFS= read -r file; do
	[[ -z "$file" || "$file" == \#* ]] && continue
	if [[ ! -e ~/"$file" ]]; then
		cp "$SETUP/copied/$file" ~/
		success "Created: ~/$file (from template)"
		((files_copied++)) || true
	fi
done <"$SETUP"/state/copied_files.txt

mkdir -p ~/.vim/swaps/ ~/.vim/backups/ ~/.vim/undo/

if [[ $links_created -eq 0 && $links_removed -eq 0 && $files_copied -eq 0 ]]; then
	info "All symlinks up to date"
fi
echo ""
