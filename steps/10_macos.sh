# shellcheck shell=bash
# shellcheck disable=SC2034,SC2154
#
# Applies non-privileged macOS defaults (Finder, keyboard, trackpad, etc.) and
# rebuilds the Dock layout. Cask installs happen later (privileged section), so
# newly-added casks won't appear in the Dock until the next run.

source configure/macos.sh
echo ""
