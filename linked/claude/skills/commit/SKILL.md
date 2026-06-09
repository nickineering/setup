---
description: Stage Claude's changes, commit with a generated message, and push
---

Commit and push changes.

## Model

Delegate this skill to a subagent using `Agent` with `model: "sonnet"`. Include
the full workflow and rules below in the agent's prompt.

## Workflow

### 1. Stage files

Stage files Claude modified in this session, but do not stage other files.
Always preserve anything already staged — never unstage files.

### 2. Review changes

Run `git status` and `git diff --staged` to understand what will be committed.
The commit message should cover all staged changes, not just Claude's.

### 3. Write the commit message

Conventional commit format: `type(scope): description`

Types: `feat`, `fix`, `docs`, `refactor`, `test`, `chore`, `style`, `perf`.
Append `!` for breaking changes. Keep the title under 72 characters. Add a body
only when the "why" isn't obvious from the title. Wrap at 72 characters.

### 4. Commit and push

Combine into one command to minimize approval prompts:

```bash
git add <claude-modified-files> && git commit -m "<title>" -m "<body>" && git push
```

If Claude did not modify any files, just commit what is already staged:

```bash
git commit -m "<title>" && git push
```

## Rules

- Always stage files Claude modified in this session before committing
- Never add Co-Authored-By trailers for Claude
- Never unstage files that were already staged
- Never wait for permission between add, commit, and push
- Always push immediately after committing
