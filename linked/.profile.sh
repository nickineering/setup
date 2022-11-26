#!/bin/bash

#                         STOP!
# ---- Only edit this file if you want to change the whole repo. ----
# Edit profile.custom.sh to add temporary code for particular projects

# Run multiple Python versions on same machine
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init --path)"

eval "$(pyenv init -)"
export PYENV_VIRTUALENVWRAPPER_PREFER_PYVENV="true"
export WORKON_HOME=$HOME/virtualenvs
pyenv virtualenvwrapper_lazy

# Makes GPG keys available for use
export GPG_TTY=$(tty)

# Enable the fuck to correct mistyped commands
eval "$(thefuck --alias)"

# Handy aliases
alias myip="curl http://ipecho.net/plain; echo"
alias please=sudo
# Count files in current directory and subdirectories
alias count='find . -type f | wc -l'

# Use zsh-colorize for cat and less everywhere
alias cat=ccat
alias less=cless

# Move $1 to trash
trash () {
    mv -f "${1:?usage: trash FILE_TO_DELETE}" ~/.Trash
}

# Backup .profile.custom.sh where secrets should be located.
# It is not subject to version control.
backup_secrets () {
    mkdir -p ~/Documents/backups
    cp ~/.profile.custom.sh ~/Documents/backups/
    echo 'Backup complete'
    ls -lah ~/Documents/backups/
}

# Combination of cd and ls
cs () {
    cd "$@" && ls
}

# Combination of mkdir and cd
mcd () {
    mkdir -p "$1"
    cd "$1" || exit
}

# NVM
export NVM_DIR="$HOME/.nvm"
[ -s "$(brew --prefix)/opt/nvm/nvm.sh" ] && \. "$(brew --prefix)/opt/nvm/nvm.sh" # This loads nvm
[ -s "$(brew --prefix)/opt/nvm/etc/bash_completion.d/nvm" ] && \. "$(brew --prefix)/opt/nvm/etc/bash_completion.d/nvm" # This loads nvm bash_completion

# Changes not tracked in git
# shellcheck disable=SC1090
source ~/.profile.custom.sh
