#!/opt/homebrew/bin/bash

if ! command -v uv &>/dev/null; then
	echo "Error: uv is not installed" >&2
	exit 1
fi

if ! uv python install --default; then
	echo "Error: Failed to install Python via uv" >&2
	exit 1
fi

# These can fail gracefully - they're upgrades, not critical installs
uv python upgrade || print_green "Warning: Failed to upgrade Python"
uv tool upgrade --all || print_green "Warning: Failed to upgrade uv tools"
