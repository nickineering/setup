#!/bin/bash

# ------------------------------------------------------------------------------------ #
# !                                STAY AWAY, SECRETS!
# This file is committed to version control and used by both Bash and Zsh.
# Add secrets and device specific configuration to ~/.env.sh instead.
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
