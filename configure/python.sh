# shellcheck shell=bash
# shellcheck disable=SC2154 # Variables like $yellow defined in lib/colors.sh
# Sourced by run.sh after checking `command -v uv`

# --default sets python/python3 commands (experimental, acknowledged via --preview-features)
output=$(uv python install --default --preview-features python-install-default 2>&1) || {
	warn "Failed to install Python via uv" >&2
}
# Only show output if something was actually installed
if [[ "$output" != *"already installed"* ]]; then
	echo "$output"
fi

# Upgrade can fail gracefully - it's not a critical install
output=$(uv python upgrade 2>&1) || warn "Failed to upgrade Python"
if [[ "$output" != *"already on latest"* ]]; then
	echo "$output"
fi

# Build the cached environment for each scripts/ helper up front. Without this
# the first `awake` on a new machine pays a dependency resolve, and would fail
# outright with no network. Step 08 links them; this makes them ready to run.
for script in "${SETUP:?}"/scripts/*.py; do
	[[ -f "$script" ]] || continue # unmatched glob when scripts/ is empty
	uv sync --quiet --script "$script" || warn "Failed to sync deps for $(basename "$script")"
done
