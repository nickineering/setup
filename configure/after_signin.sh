#!/opt/homebrew/bin/bash
# shellcheck disable=SC2154 # Variables like $green are defined in lib/colors.sh
#
# Post-setup configuration for things that need apps to be launched first:
# - Firefox: needs profile folder to exist (created on first launch)
# - GitHub CLI: interactive authentication

set -euo pipefail

export SETUP=~/projects/setup
export DOTFILES="$SETUP/linked"
cd "$SETUP"

source lib/colors.sh
source lib/backup.sh

echo -e "${bold}${cyan}=== Post-setup configuration ===${reset}"
echo ""

# Firefox settings (requires Firefox to have been launched once)
source configure/firefox.sh
if [[ "${FIREFOX_NEEDS_SETUP:-}" != "1" ]]; then
	echo -e "${green}Configured Firefox${reset}"
fi

# GitHub CLI authentication
if ! gh auth status &>/dev/null; then
	echo ""
	echo -e "${bold}GitHub CLI authentication${reset}"
	gh auth login
	echo -e "${green}Configured GitHub CLI${reset}"
else
	echo -e "${dim}GitHub CLI already authenticated${reset}"
fi

echo ""
echo -e "${green}Done!${reset}"
