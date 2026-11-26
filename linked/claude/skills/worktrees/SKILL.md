---
description: The git wt-* commands for opening, diffing and reviewing a worktree locally, with no push and no MR.
---

One layout, Claude Code's: `<main-clone>/.claude/worktrees/NAME` on branch
`NAME`, cut from `origin/HEAD`. `claude --worktree`, `EnterWorktree`,
`isolation: worktree` subagents and `git wt NAME` all produce it.

Creating, listing and removing are Claude Code's own — `EnterWorktree`, the exit
prompt, the periodic sweep, `git worktree list`. `git wt NAME` is the by-hand
equivalent, for starting work without Claude and handing it over afterwards; a
session can't use it, because `git worktree add` writes `.git/worktrees`, which
the sandbox makes read-only.

## Reviewing

Agents leave work uncommitted, so there is nothing to un-commit before reading
it.

- `git wt-open [BRANCH]` — add the worktree to the running editor window as an
  extra root, giving it its own source-control section. One per agent after a
  fan-out. `git wt-close` removes it again.
- `git wt-review [BRANCH]` — commits, diffstat and uncommitted state against the
  merge-base. Stamps `refs/review/<branch>`, so a second run range-diffs only
  what is new since the last look.
- `git wt-diff [BRANCH]` — the diff as one file, or `--tabs` for side-by-side
  per file (`WT_DIFF_MAX` caps them). `--base REF` overrides the base, which
  otherwise follows whatever the main clone has checked out.
- `git wt-browse BRANCH` — mixed-reset a _committed_ branch so it reads as
  uncommitted work, `--end` to put the commits back keeping any fixes. Needs a
  clean worktree, so it only applies when an agent committed anyway. The status
  line shows `⚠ BROWSE` until it ends.

`WT_OPEN_CMD` overrides the editor, or set it empty to only print paths.

Never open a worktree as a folder: it is a directory the editor has never seen,
so the first open activates every extension from cold — a minute or so whatever
the branch changed. Added as a root to a running window it costs nothing.

## Handing work back

Always give the absolute worktree root, one line per worktree, so the user never
has to ask which directory to open.
