---
description: Generate a summary of code changes without creating a PR/MR
argument-hint: base-ref
---

Show a formatted summary of changes, like what would appear in a PR/MR
description.

$ARGUMENTS - Optional base reference (commit, branch, or tag) to compare
against. Defaults to uncommitted changes, then falls back to the default branch.

## Workflow

### 1. Read the shared analysis methodology

```
~/.claude/skills/_shared/change-analysis.md
```

### 2. Determine what to summarize

```bash
git status --porcelain
```

**Priority order:**

1. If `$ARGUMENTS` provided: compare that ref to HEAD (branch, commit hash, or
   tag all work)
2. Else if uncommitted changes exist (staged or unstaged): summarize working
   tree changes
3. Else: compare default branch to HEAD (`origin/<default>...HEAD`)

### 3. Analyze changes

**For uncommitted changes:**

```bash
git diff --stat          # unstaged
git diff --staged --stat # staged
git diff                 # full diff for analysis
git diff --staged
```

**For branch comparison:**

```bash
git diff <base>...HEAD --stat
git log <base>..HEAD --oneline --no-color
```

Follow the systematic review process from the shared reference for large
changes.

### 4. Display the summary

Output a formatted summary with:

- **Title**: A concise, descriptive title following the shared guidelines
- **Description**: Organized by distinct improvements, not by files

Format as markdown for readability.

## Rules

- Do NOT create any MR/PR
- Do NOT push any commits
- Do NOT modify any files
- Output only—this skill is read-only
