---
description: Create or update a GitHub pull request for the current branch
argument-hint: branch
---

Manage a GitHub pull request for the current branch.

$ARGUMENTS - Optional target branch (defaults to repository's default branch).

## Workflow

### 1. Read the shared analysis methodology

```
~/.claude/skills/_shared/change-analysis.md
```

### 2. Sync, push, and check for existing PR

```bash
git status
git pull
git push
git branch --show-current
gh pr list --head <branch> --json number,baseRefName
```

Push early so CI runs while preparing the description.

For merge conflicts: resolve trivial ones automatically, STOP and consult user
for non-obvious ones.

### 3. Determine target branch

- **Existing PR**: Get target branch from the existing PR's `baseRefName`
- **New PR**: Use `$ARGUMENTS` if provided, otherwise repository default

### 4. Prepare title and description

**Regenerate from scratch.** Do not read or reuse the existing PR title or
description. Always generate fresh content based on the **final diff**.

```bash
git diff origin/<target>...HEAD --stat
git log origin/<target>..HEAD --oneline --no-color
```

Follow the full analysis and description process from the shared reference.

### 5. Submit

```bash
# Update existing:
gh pr edit <number> --title "..." --body "..."

# Or create new:
gh pr create --base <target> --title "..." --body "..."
```

### 6. Handle check failures

Check `gh pr checks`, fix issues, push again. Repeat until passing.

If failures reveal deeper issues (e.g., architectural problems, widespread type
errors, test design flaws), STOP and consult the user rather than applying quick
fixes. Prioritize clean maintainable code over suppressing issues to get CI
green.

## Rules

- Do NOT add Co-Authored-By trailers for Claude
- Do NOT add "Generated with Claude Code" or similar footers to PR descriptions
