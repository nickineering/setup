#!/usr/local/bin/bash

# ------------------------------------------------------------------------------------ #
# !                                STAY AWAY, SECRETS!
# This file is committed to version control and used by both Bash and Zsh.
# Add secrets and device specific configuration to ~/.env.sh instead.
# Compatibility must be maintained with both Bash and Zsh.
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

# Update everything on the computer
update() {
    cd "$MAC" || exit 1
    git pull
    ."$MAC"/util/setup.sh
}

# Run my favorite Python linters in the current directory and subdirectories
pynick() {
    source "$MAC"/util/print.sh
    print_green "Running all Nick's favorite Python linting tools. First black, isort, and pyupgrade...\n"
    PYTHON_FILES=()
    while IFS= read -r -d '' file; do
        PYTHON_FILES+=("$file")
    done < <(find . -type f -name "*.py" -print0)

    # Automatic fixes
    black "${PYTHON_FILES[@]}"
    isort .
    pyupgrade "${PYTHON_FILES[@]}"

    # Manual fixes (with some automations)
    print_green "\nMANUAL: Pylama linting issues\n"
    pylama .
    print_green "\nMANUAL: Bandit security issues\n"
    bandit "${PYTHON_FILES[@]}"
}
