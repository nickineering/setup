#!/opt/homebrew/bin/bash

export RUFF_CONFIG=~/projects/ruff-config
if [ -d "$RUFF_CONFIG" ]; then
	git -C "$RUFF_CONFIG" pull || print_green "Warning: Failed to update Ruff config"
	print_green "Pulled the latest commits for Ruff config"
else
	if ! git clone https://github.com/nickineering/ruff-config "$RUFF_CONFIG"; then
		echo "Error: Failed to clone Ruff config repo" >&2
		exit 1
	fi
	print_green "Cloned Ruff config repo"
fi

# Per platform determined by Rust: https://docs.rs/dirs/4.0.0/dirs/fn.config_dir.html
RUFF_DIR="$HOME/Library/Application Support/ruff/"
RUFF_BASE="$RUFF_CONFIG/nickineering_ruff_config/nickineering-ruff-base.toml"

if [ ! -f "$RUFF_BASE" ]; then
	echo "Error: Ruff base config not found at $RUFF_BASE" >&2
	exit 1
fi

mkdir -p "$RUFF_DIR"
if ! ln -s "$RUFF_BASE" "$RUFF_DIR/ruff.toml"; then
	echo "Error: Failed to link Ruff config" >&2
	exit 1
fi

# Install shell completions for ruff - requires code in .zshrc
mkdir -p ~/.zfunc
if ! ruff generate-shell-completion zsh >~/.zfunc/_ruff; then
	print_green "Warning: Failed to generate Ruff shell completions"
fi
