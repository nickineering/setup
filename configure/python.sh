# shellcheck shell=bash
# shellcheck disable=SC2154 # Variables like $yellow defined in lib/colors.sh
# Sourced by run.sh after checking `command -v uv`

# --default sets python/python3 commands (experimental, acknowledged via --preview-features)
if ! uv python install --default --preview-features python-install-default; then
	echo -e "${yellow}Warning: Failed to install Python via uv${reset}" >&2
fi

# Upgrade can fail gracefully - it's not a critical install
uv python upgrade || echo -e "${yellow}Warning: Failed to upgrade Python${reset}"
