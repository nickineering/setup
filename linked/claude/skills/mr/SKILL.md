---
description: Create or update a GitLab merge request for the current branch
argument-hint: branch
---

Manage a GitLab merge request for the current branch.

$ARGUMENTS - Optional target branch (defaults to repository's default branch).

## Workflow

### 1. Sync, push, and check for existing MR

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

### 2. Determine target branch

- **Existing MR**: Get target branch only (e.g.,
  `glab mr view <n> --output json | jq -r .target_branch`)
- **New MR**: Use `$ARGUMENTS` if provided, otherwise repository default

### 3. Prepare title and description

**Regenerate from scratch.** Do not read or reuse the existing MR title or
description. Always generate fresh content based on the **final diff**.

#### 3a. Assess the change scope

```bash
git diff origin/<target>...HEAD --stat
git log origin/<target>..HEAD --oneline
```

Classify as:

- **Small**: <10 files, <300 lines — read diffs directly
- **Large**: 10+ files or 300+ lines — use systematic review below

#### 3b. For large changes: systematic review

1. **Group files by area** from the stat output (e.g., CI, templates, tests,
   config, core logic)
2. **Use commits as a discovery map**: commit messages reveal the author's
   intent and help identify distinct changes you might otherwise miss. But
   verify against final diffs—don't describe work that was reverted.
3. **Sample each group**: read at least one representative diff from each
   logical area. Don't skip areas based on hunches about importance.
4. **Look for these commonly-missed changes**:
   - New options/features
   - Dependency/version bumps
   - Bug fixes hidden in larger refactors
   - Test infrastructure changes
   - Config adjustments

#### 3c. Write the description

- **Organize by distinct improvements**, not by code area or file count. A
  3-line config change can be more significant than a 200-line refactor.
- **Give each improvement appropriate visibility**: if it's worth mentioning, it
  deserves its own bullet or section.
- **State what changed**, not how you got there (ignore intermediate commits
  that were reverted or fixed)
- **Include the why** when there's a clear reason; for preference-based changes,
  just state facts
- Skip testing plans unless something unusual needs reviewer attention

#### 3d. Write the title

MR titles serve a different purpose than commit messages — they must stand out
in a list and convey scope before clicking.

- **Don't use conventional commit style** (e.g., "refactor: ...") — MRs bundle
  many changes, so every title becomes "refactor" or "feat"
- **Be concrete, not categorical**: describe the actual change, not the type
  - Bad: "DynamoDB refactor" (what refactor?)
  - Better: "DynamoDB: replace inheritance with composition wrapper"
  - Bad: "CI improvements"
  - Better: "Consolidate 8 CI validation jobs into 2"
- **Convey scale**: readers should know if this is a quick review or a deep dive
- Can be longer to capture multiple unrelated changes

### 4. Submit

```bash
# Update existing:
glab mr update <number> --title "..." --description "..."
glab mr update <number> --ready  # if draft

# Or create new:
glab mr create --target-branch <target> --title "..." --description "..." --no-prompt
```

### 5. Handle pipeline failures

Check `glab ci status`, fix issues, push again. Repeat until passing.

If failures reveal deeper issues (e.g., architectural problems, widespread type
errors, test design flaws), STOP and consult the user rather than applying quick
fixes. Prioritize clean maintainable code over suppressing issues to get CI
green.

## Rules

- Do NOT add Co-Authored-By trailers for Claude
- Do NOT add "Generated with Claude Code" or similar footers to MR descriptions
