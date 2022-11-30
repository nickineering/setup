#!/usr/local/bin/bash

# ------------------------------------------------------------------------------------ #
# !                                STAY AWAY, SECRETS!
# This file is committed to version control and used by both Bash and Zsh.
# Add secrets and device specific configuration to ~/.env.sh instead.
# ------------------------------------------------------------------------------------ #

# Move $1 to trash
trash() {
    mv -f "${1:?usage: trash FILE_TO_DELETE}" ~/.Trash
}

# Backup ~/.env.sh where secrets should be located.
# It is not subject to version control.
backup_secrets() {
    mkdir -p ~/Documents/backups
    cp ~/.env.sh ~/Documents/backups/
    cp ~/.gitconfig ~/Documents/backups/
    echo 'Backup complete'
    ls -lah ~/Documents/backups/
}

# Combination of cd and ls
cs() {
    cd "$@" && ls
}

# Combination of mkdir and cd
mcd() {
    mkdir -p "$1"
    cd "$1" || exit
}

update() {
    local MAC=~/projects/mac
    cd $MAC || exit 1
    git pull
    .$MAC/util/setup.sh
}
