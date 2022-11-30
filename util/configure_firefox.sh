#!/usr/local/bin/bash

# Install custom Firefox settings
FIREFOX_FOLDER="$HOME/Library/Application Support/Firefox/Profiles"
FIREFOX_PROFILE=$(find "$FIREFOX_FOLDER" -name '*.dev-edition-default')
if [ -z "$FIREFOX_PROFILE" ]; then
    print_green "Could not find Firefox profile folder. Skipping Firefox settings..."
else
    backup_or_delete "$FIREFOX_PROFILE"/user.js
    ln -s "$DOTFILES"/user.js "$FIREFOX_PROFILE"
fi
