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
gh extension install github/gh-copilot

# We need to run the aliases once so that we can accept collecting usage data
# the first time
gh copilot alias -- bash

print_green "Installed Github Copilot"
