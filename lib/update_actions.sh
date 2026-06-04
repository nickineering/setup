#!/opt/homebrew/bin/bash
set -euo pipefail

# Update GitHub Action versions in CI workflow files to their latest tags.

actions=(
	"actions/checkout"
	"ludeeus/action-shellcheck|[0-9.]*"
	"mfinelli/setup-shfmt"
	"dprint/check"
)

latest_tag() {
	curl -s "https://api.github.com/repos/$1/tags" | grep -m1 '"name"' | cut -d'"' -f4
}

update_action() {
	local repo="${1%%|*}"
	local version_glob="${1#*|}"
	[[ "$version_glob" == "$repo" ]] && version_glob="v[0-9.]*"

	local latest
	latest=$(latest_tag "$repo")
	if [[ -z "$latest" ]]; then
		echo "Warning: Failed to fetch tag for $repo" >&2
		return
	fi

	sed -i '' "s|$repo@$version_glob|$repo@$latest|g" .github/workflows/*.yml
	echo "$repo -> $latest"
}

for action in "${actions[@]}"; do
	update_action "$action"
done
