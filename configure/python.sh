# shellcheck shell=bash
# shellcheck disable=SC2154 # Variables like $yellow defined in lib/colors.sh
# Sourced by run.sh after checking `command -v uv`

# --default sets python/python3 commands (experimental, acknowledged via --preview-features)
output=$(uv python install --default --preview-features python-install-default 2>&1) || {
	echo -e "${yellow}Warning: Failed to install Python via uv${reset}" >&2
}
# Only show output if something was actually installed
if [[ "$output" != *"already installed"* ]]; then
	echo "$output"
fi

# Upgrade can fail gracefully - it's not a critical install
output=$(uv python upgrade 2>&1) || echo -e "${yellow}Warning: Failed to upgrade Python${reset}"
if [[ "$output" != *"already on latest"* ]]; then
	echo "$output"
fi
