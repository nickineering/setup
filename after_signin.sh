#!/usr/local/bin/bash

source util/print.sh
source util/backup_or_delete.sh

source util/configure_firefox.sh
print "Configured Firefox"

gh auth login
gh extension install github/gh-copilot
print_green "Installed Github Copilot"
