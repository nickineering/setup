#!/usr/local/bin/bash

git clone https://github.com/nickineering/ruff-config ~/projects/

# Per platform determined by Rust: https://docs.rs/dirs/4.0.0/dirs/fn.config_dir.html
RUFF_DIR="$HOME/Library/Application Support/ruff/"
RUFF_BASE="$HOME/projects/ruff-config/nickineering_ruff_config/nickineering-ruff-base.toml"
mkdir -p "$RUFF_DIR"
ln -s "$RUFF_BASE" "$RUFF_DIR/ruff.toml"

# Install shell completions for ruff - requires code in .zshrc
ruff generate-shell-completion zsh >~/.zfunc/_ruff
