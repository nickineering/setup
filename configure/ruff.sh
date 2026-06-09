# shellcheck shell=bash
# shellcheck disable=SC2154 # Variables like $yellow defined in lib/colors.sh
# Sourced by run.sh

export RUFF_CONFIG=~/projects/ruff-config
if [ -d "$RUFF_CONFIG" ]; then
	output=$(git -C "$RUFF_CONFIG" pull 2>&1) || warn "Failed to update Ruff config"
	if [[ "$output" != "Already up to date." ]]; then
		info "Ruff: updated config"
	fi
else
	if ! git clone --quiet https://github.com/nickineering/ruff-config "$RUFF_CONFIG"; then
		warn "Failed to clone Ruff config repo, skipping Ruff setup" >&2
		return 0
	fi
	info "Ruff: cloned config repo"
fi

# Per platform determined by Rust: https://docs.rs/dirs/4.0.0/dirs/fn.config_dir.html
RUFF_DIR="$HOME/Library/Application Support/ruff/"
RUFF_BASE="$RUFF_CONFIG/nickineering_ruff_config/nickineering-ruff-base.toml"

if [ ! -f "$RUFF_BASE" ]; then
	warn "Ruff base config not found at $RUFF_BASE" >&2
	return 0
fi

mkdir -p "$RUFF_DIR"
if ! ln -sf "$RUFF_BASE" "$RUFF_DIR/ruff.toml"; then
	warn "Failed to link Ruff config" >&2
fi

# Install shell completions for ruff - requires code in .zshrc
mkdir -p ~/.zfunc
if ! ruff generate-shell-completion zsh >~/.zfunc/_ruff; then
	warn "Failed to generate Ruff shell completions"
fi
