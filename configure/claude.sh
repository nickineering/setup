# shellcheck shell=bash
# shellcheck disable=SC2154 # Variables like $green are defined in lib/colors.sh
# Sourced by run.sh

# Configure Claude Code settings and instructions

CLAUDE_DIR="$HOME/.claude"
CLAUDE_DOTFILES="$DOTFILES/claude"
CLAUDE_COPIED="$SETUP/copied/claude"

# Create Claude directory if it doesn't exist
mkdir -p "$CLAUDE_DIR"

# Symlink settings, instructions, and skills
create_link "$CLAUDE_DOTFILES/settings.json" "$CLAUDE_DIR/settings.json" "claude/settings.json"
create_link "$CLAUDE_DOTFILES/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md" "claude/CLAUDE.md"
create_link "$CLAUDE_DOTFILES/skills" "$CLAUDE_DIR/skills" "claude/skills"

# Copy CLAUDE.local.md template if it doesn't exist
if [ ! -f "$CLAUDE_DIR/CLAUDE.local.md" ]; then
	cp "$CLAUDE_COPIED/CLAUDE.local.md" "$CLAUDE_DIR/CLAUDE.local.md"
	echo -e "${dim}Claude Code: created local instructions template${reset}"
fi
