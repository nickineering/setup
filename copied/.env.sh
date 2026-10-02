#!/opt/homebrew/bin/bash

# ------------------------------------------------------------------------------------ #
# !                           Your secrets are safe with me
# Version control won't see us here. We're sourced in ~/.bash_profile and ~/.zshrc
# ------------------------------------------------------------------------------------ #

# GitLab syncing configuration (run.sh syncs repos to ~/work)
# export GITLAB_GROUP="your-group"
# Optional: exclude specific subdirectories from sync:
# export GITLAB_EXCLUDE_DIRS="unsynced|bugs"
# Optional: clone no new repos, for when only a few are wanted on this machine.
# ~/work still mirrors GitLab's structure: each uncloned repo gets a directory
# with a .gitkeep in it, removed once the repo is cloned. Everything else about
# the sync is unchanged. Same as passing --placeholders-only to a single run.
# export GITLAB_PLACEHOLDERS_ONLY=1

# Dock apps to ignore on this machine (pipe-separated).
# Suppresses "not found" warnings for apps not installed, and
# "not managed by setup" warnings for apps present but not in the managed list.
# export DOCK_IGNORE_APPS="NordVPN|Spotify"

# Login items to ignore on this machine (pipe-separated).
# Suppresses "not managed by setup" warnings for login items not in the managed list.
# export LOGIN_IGNORE_APPS="Slack|iTerm"
