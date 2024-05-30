#!/opt/homebrew/bin/bash

# Configure pyenv and install the latest Python version and set the global to that
export PYENV_ROOT="$HOME/.pyenv"
command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"
MATCHING_PY=$(pyenv install --list | grep --extended-regexp "^\s*[0-9][0-9.]*[0-9]\s*$")
LATEST_PY=$(echo "$MATCHING_PY" | tail -1 | xargs)
# We should only try installing the latest Python version if we do not already
# have it to prevent a pyenv error
if ! pyenv versions | grep -q "$LATEST_PY"; then
    pyenv install "$LATEST_PY"
fi
pyenv global "$LATEST_PY"
pyenv shell "$LATEST_PY"
pip install --upgrade pip

# Delete any existing pip packages
FROZEN_PACKAGES=$(pip freeze)
if [ "$FROZEN_PACKAGES" ]; then
    echo "$FROZEN_PACKAGES" | xargs pip uninstall -y
fi
