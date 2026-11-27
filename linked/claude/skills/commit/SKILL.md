---
description: Commit all work with a generated message and push
---

Commit and push changes.

## Model

Delegate this skill to a subagent using `Agent` with `model: "sonnet"`. Include
the full workflow and rules below in the agent's prompt.

## Workflow

### 1. Determine what to commit

Run `git status` to see the working tree.

**If there are already-staged changes**, commit only those — don't stage
anything else. Staged files are the user's signal of what to commit. This
applies even if Claude has other unstaged modifications from this session.

**Exception:** if Claude staged all of the currently-staged files itself during
this session (e.g., a rename required `git mv` which stages both paths), then
also stage any other Claude-modified files — the staging doesn't represent user
intent in that case.

**If nothing is staged:**

- With prior session context: stage all files Claude modified this session.
- Fresh session (no context): stage all unstaged and untracked files. The only
  exception is files that are obviously disposable (e.g., scratch files,
  `.DS_Store`). Ask before excluding anything non-obvious.

Never use `git add .`, `git add -A`, or wildcard patterns — name files
explicitly.

### 2. Review changes

Run `git diff --staged` (after staging) to understand what will be committed.

### 3. Decide: single or multiple commits

Analyze the staged changes for distinct logical units. Changes are "distinct" if
they have **different purposes** — e.g., a bug fix and an unrelated refactor, or
a new feature and a documentation update for something else.

**Split into multiple commits when:**

- Changes serve different purposes (different type or scope)
- Changes are independent — one could be reverted without affecting the other
- A reviewer would naturally ask "why are these in the same commit?"

**Keep as a single commit when:**

- Changes work together toward one goal (e.g., a feature + its tests)
- One change only makes sense in the context of the other
- The scope is small enough that splitting adds noise

### 4. Write commit messages

Conventional commit format: `type(scope): description`

Types: `feat`, `fix`, `docs`, `refactor`, `test`, `chore`, `style`, `perf`.
Append `!` for breaking changes. Keep the title under 72 characters. Add a body
only when the "why" isn't obvious from the title. Wrap at 72 characters.

For multiple commits, write a message for each and determine which files belong
to each commit.

### 5. Commit and push

Run each line below as a separate Bash call.

Pass the message in a file, not on the command line: run `mktemp` to get a path,
`Write` the message into it, then `git commit -F <that literal path>`. Shell
variables do not survive between Bash calls, so use the path `mktemp` printed
rather than `$msg`. Never reuse a fixed filename — scratch files outlive the
session and a stale one gets committed as the message.

**Single commit** — one git command per Bash call, never chained:

```bash
git add <claude-modified-files>
git commit -F /path/from/mktemp
git push origin <branch>
```

**Multiple commits** — commit each group separately, push once at the end.
Already-staged files go in whichever commit they logically belong to. Use
`git commit <paths>` (explicit pathspec) to commit only specific files from the
index per commit — this avoids sweeping all staged files into the first commit:

```bash
git add <claude-files-for-commit-1>
git commit <all-paths-for-commit-1> -F /path/from/mktemp-1
git add <claude-files-for-commit-2>
git commit <all-paths-for-commit-2> -F /path/from/mktemp-2
git push origin <branch>
```

If Claude did not modify any files, just commit what is already staged:

```bash
git commit -F /path/from/mktemp
git push origin <branch>
```

## Rules

- Staged changes are the user's selection — never add unstaged files alongside
  them (unless Claude staged everything itself)
- Never unstage files that were already staged
- Never use `git add .`, `git add -A`, or wildcard patterns
- Run every git command as its own Bash call, with no `&&`, no `;` and no
  command substitution. `sandbox.excludedCommands` matches `git *`, and a line
  that is anything other than a plain `git ...` invocation cannot match it, so
  it runs sandboxed and fails with `.git/index.lock: Operation not permitted`
- Matching `git *` is necessary but not sufficient: `add`, `commit -F` and
  `push` get through, while `config --local`, `tag` and
  `update-index --force-write-index` are refused even unchained. If a git write
  is refused, report it — do not reshape the command hunting for one that lands
- Build the message with `mktemp` + `Write` + `-F`. Never substitute a heredoc
  into `-m`, and never reuse a fixed scratch filename
- Push with `git push origin <branch>`, never `git push -u`, which cannot write
  `.git/config`
- When splitting, order commits so dependencies come first
- When splitting, use explicit pathspecs in `git commit` to control which staged
  files go into each commit
