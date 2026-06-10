# shellcheck shell=bash
# shellcheck disable=SC2034,SC2154
#
# Applies non-privileged macOS defaults (Finder, keyboard, trackpad, etc.) and
# rebuilds the Dock layout. Runs after cask installs so Dock apps exist.

source configure/macos.sh
echo ""
