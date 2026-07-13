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

**Single commit** — combine into one command:

```bash
git add <claude-modified-files> && git commit -m "<title>" -m "<body>" && git push
```

**Multiple commits** — commit each group separately, push once at the end.
Already-staged files go in whichever commit they logically belong to. Use
`git commit <paths>` (explicit pathspec) to commit only specific files from the
index per commit — this avoids sweeping all staged files into the first commit:

```bash
git add <claude-files-for-commit-1> && git commit <all-paths-for-commit-1> -m "<title-1>" && \
git add <claude-files-for-commit-2> && git commit <all-paths-for-commit-2> -m "<title-2>" && \
git push
```

If Claude did not modify any files, just commit what is already staged:

```bash
git commit -m "<title>" && git push
```

## Rules

- Staged changes are the user's selection — never add unstaged files alongside
  them (unless Claude staged everything itself)
- Never unstage files that were already staged
- Never use `git add .`, `git add -A`, or wildcard patterns
- All adds, the commit, and the push must be a single `&&`-chained Bash command
  per commit
- When splitting, order commits so dependencies come first
- When splitting, use explicit pathspecs in `git commit` to control which staged
  files go into each commit
