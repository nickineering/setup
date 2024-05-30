#!/usr/local/bin/bash

output=$(gh auth status)
if [[ $output == *"Active account: true"* ]]; then
    gh extension upgrade gh-copilot
    print_green "Upgraded Github Copilot"
else
    echo "Not signed into Github. Please install Github Copilot after completing the manual steps."
fi
