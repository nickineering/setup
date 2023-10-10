#!/usr/local/bin/bash

# ------------------------------------------------------------------------------------ #
# !                                STAY AWAY, SECRETS!
# This file is committed to version control and used by both Bash and Zsh.
# Add secrets and device specific configuration to ~/.env.sh instead.
# Compatibility must be maintained with both Bash and Zsh.
# ------------------------------------------------------------------------------------ #

alias myip="curl http://ipecho.net/plain; echo"
alias please=sudo
# Count files in current directory and subdirectories
alias count='find . -type f | wc -l'
alias profile.sh="vim ~/.profile.sh"
alias env.sh="vim ~/.env.sh"

# Use zsh-colorize for cat and less everywhere
alias cat=ccat
alias less=cless

# Easier navigation: .., ..., ...., ....., ~ and -
alias ..="cd .."
alias ...="cd ../.."
alias ....="cd ../../.."
alias .....="cd ../../../.."
alias -- -="cd -"

# Google Chrome
alias chrome='/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome'

# IP addresses
alias ip="dig +short myip.opendns.com @resolver1.opendns.com"
alias localip="ipconfig getifaddr en0"

# Recursively delete `.DS_Store` files
alias cleanup="find . -type f -name '*.DS_Store' -ls -delete"

# URL-encode strings
alias urlencode='python -c "import sys, urllib as ul; print ul.quote_plus(sys.argv[1]);"'

# Merge PDF files, preserving hyperlinks
# Usage: `mergepdf input{1,2,3}.pdf`
alias mergepdf='gs -q -dNOPAUSE -dBATCH -sDEVICE=pdfwrite -sOutputFile=_merged.pdf'

# Lock the screen (when going AFK)
alias afk="/System/Library/CoreServices/Menu\ Extras/User.menu/Contents/Resources/CGSession -suspend"

# Reload the shell (i.e. invoke as a login shell)
alias reload='exec ${SHELL} -l'

# Print each PATH entry on a separate line
alias path='echo -e ${PATH//:/\\n}'

# cd to the root of the current Git repository
alias git-root='cd $(git rev-parse --show-toplevel)'

alias git-aliases='less $DOTFILES/git_aliases.sh'
alias git-functions='less $DOTFILES/git_functions.sh'
alias shell-aliases='less $DOTFILES/.shell_aliases.sh'
alias shell-functions='less $DOTFILES/.shell_functions.sh'
