# shellcheck shell=bash
# shellcheck disable=SC2154 # Variables like $green are defined in lib/colors.sh
# Sourced by run.sh

# Configure Claude Code settings and instructions

CLAUDE_DIR="$HOME/.claude"
CLAUDE_DOTFILES="$DOTFILES/claude"
CLAUDE_COPIED="$SETUP/copied/claude"

# Create Claude directory if it doesn't exist
mkdir -p "$CLAUDE_DIR"

# Backup existing files
backup_or_delete "$CLAUDE_DIR/settings.json"
backup_or_delete "$CLAUDE_DIR/CLAUDE.md"
backup_or_delete "$CLAUDE_DIR/skills"

# Symlink settings, instructions, and skills
ln -sf "$CLAUDE_DOTFILES/settings.json" "$CLAUDE_DIR/settings.json"
ln -sf "$CLAUDE_DOTFILES/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md"
ln -sfn "$CLAUDE_DOTFILES/skills" "$CLAUDE_DIR/skills"

# Copy CLAUDE.local.md template if it doesn't exist
if [ ! -f "$CLAUDE_DIR/CLAUDE.local.md" ]; then
	cp "$CLAUDE_COPIED/CLAUDE.local.md" "$CLAUDE_DIR/CLAUDE.local.md"
	echo -e "${green}Created Claude local instructions template${reset}"
fi

echo -e "${dim}Configured Claude Code${reset}"
