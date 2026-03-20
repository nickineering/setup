# Change Analysis Reference

This document defines how to analyze and summarize code changes. Read this file
first when invoked by skills that reference it.

## 1. Assess the Change Scope

```bash
git diff <base>...<head> --stat
git log <base>..<head> --oneline --no-color
```

Classify as:

- **Small**: <10 files, <300 lines — read diffs directly
- **Large**: 10+ files or 300+ lines — use systematic review below

## 2. For Large Changes: Systematic Review

1. **Group files by area** from the stat output (e.g., CI, templates, tests,
   config, core logic). Plan your sampling strategy before reading any diffs.
2. **Use commits as a discovery map**: commit messages reveal the author's
   intent and help identify distinct changes you might otherwise miss. But
   verify against final diffs—don't describe work that was reverted.
3. **Sample each group in parallel**: read representative diffs from multiple
   logical areas simultaneously. Don't wait for one area before reading another
   and don't skip areas based on hunches about importance.
4. **Look for these commonly-missed changes**:
   - New options/features
   - Dependency/version bumps
   - Bug fixes hidden in larger refactors
   - Test infrastructure changes
   - Config adjustments

## 3. Write the Description

- **Organize by distinct improvements**, not by code area or file count. A
  3-line config change can be more significant than a 200-line refactor.
- **Give each improvement appropriate visibility**: if it's worth mentioning, it
  deserves its own bullet or section.
- **State what changed**, not how you got there (ignore intermediate commits
  that were reverted or fixed)
- **Include the why** when there's a clear reason; for preference-based changes,
  just state facts
- Skip testing plans unless something unusual needs reviewer attention

## 4. Write the Title

Titles must stand out in a list and convey scope before clicking.

- **Don't use conventional commit style** (e.g., "refactor: ...") — MRs/PRs
  bundle many changes, so every title becomes "refactor" or "feat"
- **Be concrete, not categorical**: describe the actual change, not the type
  - Bad: "DynamoDB refactor" (what refactor?)
  - Better: "DynamoDB: replace inheritance with composition wrapper"
  - Bad: "CI improvements"
  - Better: "Consolidate 8 CI validation jobs into 2"
- **Convey scale**: readers should know if this is a quick review or a deep dive
- Can be longer to capture multiple unrelated changes
