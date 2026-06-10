#!/opt/homebrew/bin/bash

# ------------------------------------------------------------------------------------ #
# !                                STAY AWAY, SECRETS!
# This file is committed to version control and used by both Bash and Zsh.
# Add secrets and device specific configuration to ~/.env.sh instead.
# Compatibility must be maintained with both Bash and Zsh.
# ------------------------------------------------------------------------------------ #

alias please=sudo
# Count files recursively
alias count='fd --type f | wc -l'
# Count lines in all text files recursively
alias count_lines='fd --type f | xargs file | grep text | cut -d: -f1 | xargs cat 2>/dev/null | wc -l'
alias profile.sh="vim ~/.profile.sh"
alias env.sh="vim ~/.env.sh"
# Find a directory by name within the current tree
alias finddir='fd --type d --glob'

alias ..="cd .."
alias ...="cd ../.."
alias ....="cd ../../.."
alias .....="cd ../../../.."
alias -- -="cd -"

alias chrome='/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome'

# Public/local IP address
alias ip="dig +short myip.opendns.com @resolver1.opendns.com"
alias localip="ipconfig getifaddr en0"

# Recursively delete .DS_Store files
alias cleanup="fd --type f --no-ignore '\.DS_Store$' --exec rm -v {}"

# ⚠️  DANGEROUS: Delete EVERYTHING in current directory except .git (moves to trash)
# Useful for resetting a repo to empty state while preserving git history
alias nuke-keep-git='fd --max-depth 1 --hidden --exclude .git . -x trash'

alias urlencode='python3 -c "import sys, urllib.parse as ul; print(ul.quote_plus(sys.argv[1]))"'

# Usage: mergepdf input{1,2,3}.pdf — preserves hyperlinks
alias mergepdf='gs -q -dNOPAUSE -dBATCH -sDEVICE=pdfwrite -sOutputFile=_merged.pdf'

# Strips all EXIF metadata except ICC color profiles
alias unmeta='exiftool -all= --icc_profile:all'

# Lock the screen
alias afk="/System/Library/CoreServices/Menu\ Extras/User.menu/Contents/Resources/CGSession -suspend"
# Reload shell as a login shell
alias reload='exec ${SHELL} -l'
# Print each PATH entry on its own line
alias path='echo -e ${PATH//:/\\n}'

alias git-aliases='less $DOTFILES/git_aliases.ini'
alias git-functions='less $DOTFILES/git_functions.sh'
alias shell-aliases='less $DOTFILES/shell_aliases.sh'
alias shell-functions='less $DOTFILES/shell_functions.sh'

alias drun='docker compose run --rm app'
