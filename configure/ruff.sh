# shellcheck shell=bash
# shellcheck disable=SC2154 # Variables like $yellow defined in lib/colors.sh
# Sourced by run.sh

export RUFF_CONFIG=~/projects/ruff-config
if [ -d "$RUFF_CONFIG" ]; then
	output=$(git -C "$RUFF_CONFIG" pull 2>&1) || echo -e "${yellow}Warning: Failed to update Ruff config${reset}"
	if [[ "$output" != "Already up to date." ]]; then
		echo -e "${dim}Updated Ruff config${reset}"
	fi
else
	if ! git clone https://github.com/nickineering/ruff-config "$RUFF_CONFIG"; then
		echo -e "${yellow}Warning: Failed to clone Ruff config repo, skipping Ruff setup${reset}" >&2
		return 0
	fi
	echo -e "${green}Cloned Ruff config repo${reset}"
fi

# Per platform determined by Rust: https://docs.rs/dirs/4.0.0/dirs/fn.config_dir.html
RUFF_DIR="$HOME/Library/Application Support/ruff/"
RUFF_BASE="$RUFF_CONFIG/nickineering_ruff_config/nickineering-ruff-base.toml"

if [ ! -f "$RUFF_BASE" ]; then
	echo -e "${yellow}Warning: Ruff base config not found at $RUFF_BASE${reset}" >&2
	return 0
fi

mkdir -p "$RUFF_DIR"
if ! ln -sf "$RUFF_BASE" "$RUFF_DIR/ruff.toml"; then
	echo -e "${yellow}Warning: Failed to link Ruff config${reset}" >&2
fi

# Install shell completions for ruff - requires code in .zshrc
mkdir -p ~/.zfunc
if ! ruff generate-shell-completion zsh >~/.zfunc/_ruff; then
	echo -e "${yellow}Warning: Failed to generate Ruff shell completions${reset}"
fi
