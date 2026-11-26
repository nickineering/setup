---
description: Recover from a refused git write, UU paths with no MERGE_HEAD, conflict markers mangled by a formatter, or a half-removed worktree.
---

Recovery procedures for the git failures this sandbox produces. Each one has a
specific cause and a specific fix; none of them is a permission problem to be
retried or approved around.

## A git write is refused

Whether a git write succeeds depends on **where the session is rooted**, not on
worktrees as such:

- A session **cannot** write the `.git` of its **primary** working directory.
  That includes reaching into that repo's worktrees with `git -C`, because a
  linked worktree's index lives under the main clone's `.git`.
- A session **can** write the `.git` of any other repo in a write zone,
  including a directory added with `--add-dir`.
- `.git/hooks` and `.git/config` are denied everywhere, always — a git hook runs
  outside the sandbox, which is the actual risk.

Test it rather than predicting it. When the write is refused, **do not write a
script and do not paste a sequence of commands.** The retry outside the sandbox
is refused by the classifier, so there is no gated path either — which means the
refusal is not a permission question and no amount of approving will help.

Say in one line that the write is blocked because the session is rooted in that
repo, and that **restarting from the parent directory removes the problem for
the whole session** — the repo is then not the primary working directory, git
runs normally, and operations that should be confirmed (`git push`) produce a
real permission prompt instead. Hand over a single command only when the user
wants this one thing done without restarting.

A script is for work that is genuinely long, re-runnable and worth gating, not
for a commit and a push. If you do write one, run it with `sh <path>`: the Write
tool does not set an executable bit, so `./<path>` fails with "permission
denied" and wastes a round trip.

## A worktree needs removing

**Worktree removal needs the `ExitWorktree` tool**, never a bare
`git worktree remove` from a session. Removal has to write
`.git/worktrees/<name>`, and when the sandbox refuses that write the command has
already deleted the worktree's files — leaving it half-gone, which reads like
data loss. `ExitWorktree` runs outside the sandbox and is unaffected. Claude
Code's own exit prompt and periodic sweep remove the rest.

## `git status` shows `UU` but no merge is in progress

**Unmerged index entries can outlive the merge that created them.** When `UU`
paths appear but there is no `MERGE_HEAD`, the merge is already committed and
the index is stale — `git reset` rebuilds it from HEAD without touching the
working tree.

Check whether the committed versions are clean before discarding anything: a
working-tree copy carrying conflict markers while HEAD's copy is marker-free
means the file on disk is the stale one.

## Conflict markers and formatters

**Never run a formatter while a merge is unresolved.** `dprint fmt` and friends
will reflow a file that still has conflict markers in it and can absorb the
`=======` separator into a table row, corrupting both sides at once. Resolve
first, then format.

If markers are already mangled, the intact sides are still in the index:
`git checkout -m -- <file>` regenerates clean ones from stages `:1`/`:2`/`:3`.

This repo's `pre-commit-format.sh` hook now blocks a commit while a merge,
rebase, cherry-pick or revert is unresolved, or while the index holds unmerged
paths, so the formatter cannot be reached mid-resolution through a commit. The
rule still applies to running a formatter directly.
