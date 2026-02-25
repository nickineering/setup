#!/opt/homebrew/bin/bash

export RUFF_CONFIG=~/projects/ruff-config
if [ -d "$RUFF_CONFIG" ]; then
	git -C "$RUFF_CONFIG" pull
	print_green "Pulled the latest commits for Ruff config"
else
	git clone https://github.com/nickineering/ruff-config "$RUFF_CONFIG"
	print_green "Cloned Ruff config repo"
fi

# Per platform determined by Rust: https://docs.rs/dirs/4.0.0/dirs/fn.config_dir.html
RUFF_DIR="$HOME/Library/Application Support/ruff/"
RUFF_BASE="$RUFF_CONFIG/nickineering_ruff_config/nickineering-ruff-base.toml"
mkdir -p "$RUFF_DIR"
ln -s "$RUFF_BASE" "$RUFF_DIR/ruff.toml"

# Install shell completions for ruff - requires code in .zshrc
mkdir -p ~/.zfunc
ruff generate-shell-completion zsh >~/.zfunc/_ruff
