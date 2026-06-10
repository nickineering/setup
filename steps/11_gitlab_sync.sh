# shellcheck shell=bash
# shellcheck disable=SC2034,SC2154
#
# Clones new repos and pulls existing ones from GITLAB_GROUP.
# Requires glab authenticated.

source sync/repos.sh
sync_repos
echo ""
