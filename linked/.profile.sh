#!/usr/local/bin/bash

# ------------------------------------------------------------------------------------ #
# !                                STAY AWAY, SECRETS!
# This file is committed to version control and used by both Bash and Zsh.
# Add secrets and device specific configuration to ~/.env.sh instead.
# ------------------------------------------------------------------------------------ #

# Run multiple Python versions on the same machine
export PYENV_ROOT="$HOME/.pyenv"
command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"

# Pyenv Virtual Environment Wrapper
export PYENV_VIRTUALENVWRAPPER_PREFER_PYVENV="true"
export WORKON_HOME=$HOME/virtualenvs
pyenv virtualenvwrapper_lazy

# Node Version Manager
export NVM_DIR="$HOME/.nvm"
[ -s "$(brew --prefix)/opt/nvm/nvm.sh" ] && \. "$(brew --prefix)/opt/nvm/nvm.sh"                                       # This loads nvm
[ -s "$(brew --prefix)/opt/nvm/etc/bash_completion.d/nvm" ] && \. "$(brew --prefix)/opt/nvm/etc/bash_completion.d/nvm" # This loads nvm bash_completion

# Load Autojump: quickly jump between directories
[ -f /usr/local/etc/profile.d/autojump.sh ] && . /usr/local/etc/profile.d/autojump.sh

# Enable thefuck to correct mistyped commands
eval "$(thefuck --alias)"

# Makes GPG keys available for use
export GPG_TTY=$(tty)

# Easy access to the dotfiles repo
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
