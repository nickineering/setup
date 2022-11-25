# Fig pre block. Keep at the top of this file.
[[ -f "$HOME/.fig/shell/bash_profile.pre.bash" ]] && builtin source "$HOME/.fig/shell/bash_profile.pre.bash"
export PATH="$HOME/.local/bin:$PATH"  # Needed by Fig

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

# There should be no code below this comment other than Fig.
# If there is copy it into .profile.sh.
# ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––-

# Fig post block. Keep at the bottom of this file.
[[ -f "$HOME/.fig/shell/bash_profile.post.bash" ]] && builtin source "$HOME/.fig/shell/bash_profile.post.bash"
