#!/opt/homebrew/bin/bash

# Install custom Firefox settings
FIREFOX_FOLDER="$HOME/Library/Application Support/Firefox/Profiles"
if [ -z "$FIREFOX_FOLDER" ]; then
    print_green "You must sign in to Firefox and then run this script again or run the after_signin.sh script."
else
    FIREFOX_PROFILE=$(find "$FIREFOX_FOLDER" -name '*.dev-edition-default')
    if [ -z "$FIREFOX_PROFILE" ]; then
        print_green "Could not find Firefox profile folder. Skipping Firefox settings..."
    else
        backup_or_delete "$FIREFOX_PROFILE"/user.js
        ln -s "$DOTFILES"/user.js "$FIREFOX_PROFILE"
    fi
fi
