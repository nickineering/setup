#                    STOP!
# Only edit this file if something is incompatible with zsh.
# ----- Code for bash and zsh should be in .profile.sh -----

# Iterm2 advanced features
test -e "${HOME}/.iterm2_shell_integration.bash" && source "${HOME}/.iterm2_shell_integration.bash"

# Docker autocompletion
[ -f /usr/local/etc/bash_completion ] && . /usr/local/etc/bash_completion

# Git autocompletion
[[ -r "/usr/local/etc/profile.d/bash_completion.sh" ]] && . "/usr/local/etc/profile.d/bash_completion.sh"

source ~/.profile.sh

# There should be no code below this comment. If there is copy it into .profile.sh
# ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
