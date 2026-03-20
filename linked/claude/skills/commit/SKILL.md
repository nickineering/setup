---
description: Stage Claude's changes, commit with a generated message, and push
---

Commit and push changes from the current Claude session.

## Workflow

### 1. Determine files to stage

**Only stage files that Claude has modified in this session.** Do not stage
unrelated changes. If this skill is invoked outside a Claude session (no files
modified by Claude), skip staging entirely and commit only what is already
staged.

### 2. Review changes

```bash
git status
git diff --staged
git diff <files-claude-modified>
```

Understand what has changed to write an accurate commit message.

### 3. Write the commit message

**Title (first line):**

- Use conventional commit format: `type(scope): description`
- Types: `feat`, `fix`, `docs`, `refactor`, `test`, `chore`, `style`, `perf`
- Append `!` after type for breaking changes: `feat!`, `fix!`, `refactor!`, etc.
- Keep under 72 characters
- Be specific about what changed

**Body (if needed):**

- Add for complex changes that need explanation
- Explain the "why" when not obvious
- Wrap at 72 characters

### 4. Stage, commit, and push in one command

Combine all operations to minimize approval prompts.

**With Claude-modified files:**

```bash
git add <file1> <file2> ... && git commit -m "<title>" -m "<body>" && git push
```

**Without body:**

```bash
git add <file1> <file2> ... && git commit -m "<title>" && git push
```

**No Claude-modified files (commit already-staged changes only):**

```bash
git commit -m "<title>" && git push
```

## Rules

- Do NOT add Co-Authored-By trailers for Claude
- Do NOT stage files that Claude did not modify in this session
- Do NOT wait for permission between add, commit, and push
- Push immediately after committing
