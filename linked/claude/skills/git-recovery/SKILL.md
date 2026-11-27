---
description: Recover from a refused git write, UU paths with no MERGE_HEAD, conflict markers mangled by a formatter, or a half-removed worktree.
---

Recovery procedures for the git failures this sandbox produces. Each one has a
specific cause and a specific fix; none of them is a permission problem to be
retried or approved around.

## A git write is refused

**Check the command's shape first.** `sandbox.excludedCommands` exempts a bare
`git ...` from the sandbox, but a line chained with `&&` cannot be matched
against that pattern, so the whole thing runs sandboxed and the write fails with
`Unable to create '.../.git/index.lock': Operation not permitted`. Re-run the
git command on its own and it succeeds. This is the usual cause, and it is not a
permission problem.

`.git/hooks` and `.git/config` are denied whatever the shape — a git hook runs
outside the sandbox, which is the actual risk.

If an unchained command is still refused, the write is genuinely blocked. **Do
not write a script and do not paste a sequence of commands**; the retry outside
the sandbox is refused by the classifier, so no amount of approving will help.
Say in one line that it is blocked and that **restarting from the parent
directory removes the problem for the whole session**.

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
