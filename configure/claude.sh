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
# Pricing overrides use standard Bedrock rates (10% over API). Add new models at launch; rates never change mid-lifecycle.
create_link "$CLAUDE_DOTFILES/ccusage.json" "$CLAUDE_DIR/ccusage.json" "claude/ccusage.json"
create_link "$CLAUDE_DOTFILES/skills" "$CLAUDE_DIR/skills" "claude/skills"

# CLI tools (extensionless in ~/.local/bin for PATH access)
mkdir -p "$HOME/.local/bin"
create_link "$CLAUDE_DOTFILES/terminator.sh" "$HOME/.local/bin/terminator" "terminator"
create_link "$CLAUDE_DOTFILES/claude-aws.sh" "$HOME/.local/bin/claude-aws" "claude-aws"

# Copy CLAUDE.local.md template if it doesn't exist
if [ ! -f "$CLAUDE_DIR/CLAUDE.local.md" ]; then
	cp "$CLAUDE_COPIED/CLAUDE.local.md" "$CLAUDE_DIR/CLAUDE.local.md"
	info "Claude Code: created local instructions template"
fi
