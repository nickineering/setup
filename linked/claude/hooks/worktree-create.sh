#!/bin/bash
# WorktreeCreate hook. Redirects Claude Code's worktrees out of the repo and into
# the parallel ~/work/.worktrees tree, so the ~/work mirror stays addressable
# (a GitLab path keeps resolving to exactly one local path).
#
# Covers `claude --worktree`, mid-session EnterWorktree, and subagents declaring
# `isolation: worktree`. Reads Claude Code's JSON on stdin, prints the created
# directory on stdout; a non-zero exit fails worktree creation.
#
# $DOTFILES is not guaranteed in the hook environment, hence the absolute path.

set -uo pipefail
# shellcheck source=/dev/null
source "$HOME/projects/setup/linked/git_functions.sh" || exit 1
wt_hook_create
