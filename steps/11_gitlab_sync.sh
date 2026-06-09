# shellcheck shell=bash
# shellcheck disable=SC2034,SC2154
#
# ── GitLab Sync ──────────────────────────────────────────────────────────────
# Clones new repos and pulls existing ones from GITLAB_GROUP. Depends on glab
# being installed (from Homebrew packages) and authenticated.
# ─────────────────────────────────────────────────────────────────────────────
source sync/repos.sh
sync_repos
echo ""
