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

# Handy aliases
alias myip="curl http://ipecho.net/plain; echo"
alias please=sudo
alias git_delete_branches="git branch | grep -v '^*' | xargs git branch -D"

# Combination of cd and ls
function cs () {
    cd "$@" && ls
}

# Combination of mkdir and cd
function mcd () {
    mkdir -p $1
    cd $1
}

# NVM
export NVM_DIR="$HOME/.nvm"
[ -s "$(brew --prefix)/opt/nvm/nvm.sh" ] && \. "$(brew --prefix)/opt/nvm/nvm.sh" # This loads nvm
[ -s "$(brew --prefix)/opt/nvm/etc/bash_completion.d/nvm" ] && \. "$(brew --prefix)/opt/nvm/etc/bash_completion.d/nvm" # This loads nvm bash_completion

# Changes not tracked in git
source ~/.profile.custom.sh
