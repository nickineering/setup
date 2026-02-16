#!/opt/homebrew/bin/bash

# Bash strict mode
set -euo pipefail

# Print commands as they are run
set -v

cd ~/projects/setup/util

source print.sh
source backup_or_delete.sh

source configure_firefox.sh
print_green "Configured Firefox"

gh auth login

print_green "Installed Github"
