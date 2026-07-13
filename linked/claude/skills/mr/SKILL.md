---
description: Create or update a GitLab merge request for the current branch
argument-hint: branch
---

Manage a GitLab merge request for the current branch.

## Model

Delegate this skill to a subagent using `Agent` with `model: "sonnet"`. Include
the full workflow and rules below in the agent's prompt.

$ARGUMENTS - Optional target branch (defaults to repository's default branch).

## Workflow

### 1. Read the shared analysis methodology

```
~/.claude/skills/_shared/change-analysis.md
```

### 2. Sync, push, and check for existing MR

```bash
git status
git pull
git push
git branch --show-current
glab mr list --source-branch=<branch>
```

Push early so CI runs while preparing the description.

For merge conflicts: resolve trivial ones automatically, STOP and consult user
for non-obvious ones.

### 3. Determine target branch

- **Existing MR**: Get target branch only (e.g.,
  `glab mr view <n> --output json | jq -r .target_branch`)
- **New MR**: Use `$ARGUMENTS` if provided, otherwise repository default

### 4. Prepare title and description

**Regenerate from scratch.** Do not read or reuse the existing MR title or
description. Always generate fresh content based on the **final diff**.

```bash
git diff origin/<target>...HEAD --stat
git log origin/<target>..HEAD --oneline --no-color
```

Follow the full analysis and description process from the shared reference.

### 5. Submit

```bash
# Update existing:
glab mr update <number> --title "..." --description "..."
glab mr update <number> --ready  # if draft

# Or create new:
glab mr create --target-branch <target> --title "..." --description "..." --yes
```

### 6. Handle pipeline failures

Check `glab ci status`, fix issues, push again. Repeat until passing.

If failures reveal deeper issues (e.g., architectural problems, widespread type
errors, test design flaws), STOP and consult the user rather than applying quick
fixes. Prioritize clean maintainable code over suppressing issues to get CI
green.

