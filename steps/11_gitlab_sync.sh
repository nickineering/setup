# shellcheck shell=bash
# shellcheck disable=SC2034,SC2154
#
# Clones new repos and pulls existing ones from GITLAB_GROUP.
# Requires glab authenticated.
#
# With GITLAB_PLACEHOLDERS_ONLY set (or --placeholders-only), nothing new is
# cloned and the uncloned repos are mirrored as placeholder directories instead.

source sync/repos.sh
sync_repos
echo ""
