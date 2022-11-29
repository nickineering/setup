# shellcheck shell=bash
# Fig pre block. Keep at the top of this file.
[[ -f "$HOME/.fig/shell/bash_profile.pre.bash" ]] && builtin source "$HOME/.fig/shell/bash_profile.pre.bash"
export PATH="$HOME/.local/bin:$PATH" # Needed by Fig

# ------------------------------------------------------------------------------------ #
# !                           Don't tell Zsh you wrote here
# Lucky for us he won't know. This file is only for Bash. Share code in ~/.profile.sh
# And seriously, no secrets here. Version control is watching.
# ------------------------------------------------------------------------------------ #

# Docker autocompletion
[ -f /usr/local/etc/bash_completion ] && . /usr/local/etc/bash_completion

# Git autocompletion
[[ -r "/usr/local/etc/profile.d/bash_completion.sh" ]] && . "/usr/local/etc/profile.d/bash_completion.sh"

# shellcheck disable=SC1090
source ~/.profile.sh

# There should be no code below this comment other than Fig.
# If there is copy it into ~/.profile.sh.
# ------------------------------------------------------------------------------------ #

# Fig post block. Keep at the bottom of this file.
[[ -f "$HOME/.fig/shell/bash_profile.post.bash" ]] && builtin source "$HOME/.fig/shell/bash_profile.post.bash"
