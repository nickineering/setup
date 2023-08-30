#!/usr/local/bin/bash

# ------------------------------------------------------------------------------------ #
# !                                STAY AWAY, SECRETS!
# This file is committed to version control and used by both Bash and Zsh.
# Add secrets and device specific configuration to ~/.env.sh instead.
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
alias awk='echo "Use gawk instead of awk" && false'

# Run multiple Python versions on the same machine
export PYENV_ROOT="$HOME/.pyenv"
command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"

# Pyenv Virtual Environment Wrapper
export PYENV_VIRTUALENVWRAPPER_PREFER_PYVENV="true"
export WORKON_HOME=$HOME/virtualenvs
pyenv virtualenvwrapper_lazy

# Enable thefuck to correct mistyped commands
eval "$(thefuck --alias)"

# Github Copilot command line aliases
eval "$(github-copilot-cli alias -- "$0")"

# Easy access to this repo
export MAC=~/projects/mac

# Easy access to the dotfiles folder
export DOTFILES=~/projects/mac/linked

# Load handy aliases
# shellcheck disable=SC1090
source ~/.shell_aliases.sh

# Load handy functions
# shellcheck disable=SC1090
source ~/.shell_functions.sh

# Changes not tracked in git
# shellcheck disable=SC1090
source ~/.env.sh
