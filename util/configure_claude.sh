#!/opt/homebrew/bin/bash

# Configure Claude Code settings and instructions

CLAUDE_DIR="$HOME/.claude"
CLAUDE_DOTFILES="$DOTFILES/claude"
CLAUDE_COPIED="$SETUP/copied/claude"

# Create Claude directory if it doesn't exist
mkdir -p "$CLAUDE_DIR"

# Backup existing files
source backup_or_delete.sh
backup_or_delete "$CLAUDE_DIR/settings.json"
backup_or_delete "$CLAUDE_DIR/CLAUDE.md"

# Symlink settings and instructions
ln -s "$CLAUDE_DOTFILES/settings.json" "$CLAUDE_DIR/settings.json"
ln -s "$CLAUDE_DOTFILES/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md"

# Copy CLAUDE.local.md template if it doesn't exist
if [ ! -f "$CLAUDE_DIR/CLAUDE.local.md" ]; then
	cp "$CLAUDE_COPIED/CLAUDE.local.md" "$CLAUDE_DIR/CLAUDE.local.md"
	print_green "Created Claude local instructions template"
fi

print_green "Configured Claude Code"
