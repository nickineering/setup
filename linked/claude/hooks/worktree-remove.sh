#!/bin/bash
# WorktreeRemove hook, the counterpart to worktree-create.sh. Deregisters the
# worktree and tidies the empty parent directories the mirrored layout creates.
#
# Only ever acts on paths inside ~/work/.worktrees (enforced in wt_hook_remove),
# so a path Claude Code did not create here is left alone rather than deleted.
# Always exits 0 — a failed cleanup should not fail the session.

set -uo pipefail
# shellcheck source=/dev/null
source "$HOME/projects/setup/linked/git_functions.sh" || exit 0
wt_hook_remove
exit 0
