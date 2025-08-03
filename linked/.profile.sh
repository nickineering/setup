#!/opt/homebrew/bin/bash

# ------------------------------------------------------------------------------------ #
# !                                STAY AWAY, SECRETS!
# This file is committed to version control and used by both Bash and Zsh.
# Add secrets and device specific configuration to ~/.env.sh instead.
# Compatibility must be maintained with both Bash and Zsh.
# ------------------------------------------------------------------------------------ #

# Use modern GNU tools instead of Mac defaults
export MANPATH="/usr/local/opt/findutils/libexec/man:$MANPATH"
export MANPATH="/usr/local/opt/gnu-indent/libexec/man:$MANPATH"
export MANPATH="/usr/local/opt/make/libexec/man:$MANPATH"
export MANPATH="/usr/local/opt/unzip/libexec/man:$MANPATH"
export PATH="/usr/local/opt/findutils/libexec/gnubin:$PATH"
export PATH="/usr/local/opt/gnu-indent/libexec/gnubin:$PATH"
export PATH="/usr/local/opt/make/libexec/gnubin:$PATH"
export PATH="/usr/local/opt/unzip/bin:$PATH"

# Needed for uv
export PATH="/Users/nick/.local/bin:$PATH"

# Enable thefuck to correct mistyped commands
eval "$(thefuck --alias)"

# Easy access to this repo
export SETUP=~/projects/setup

# Easy access to the dotfiles folder
export DOTFILES=~/projects/setup/linked

# Load handy aliases
# shellcheck disable=SC1090
source $DOTFILES/shell_aliases.sh

# Load handy functions
# shellcheck disable=SC1090
source $DOTFILES/shell_functions.sh

# Changes not tracked in git
# shellcheck disable=SC1090
source ~/.env.sh
