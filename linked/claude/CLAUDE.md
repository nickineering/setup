# Confidence

### When to Score Confidence

You MUST calculate and explicitly state your confidence score (0-100%) for:

- Any code modification or suggestion
- Architecture decisions
- API endpoint usage
- Data structure interpretations
- Bug fixes or feature implementations

### Confidence Calculation Factors

Consider these factors when calculating confidence:

- API documentation availability and clarity (30%)
- Similar patterns in existing codebase (25%)
- Understanding of data flow and dependencies (20%)
- Complexity of the requested change (15%)
- Potential impact on other systems (10%)

### Confidence Thresholds

- 95-100%: Proceed with implementation
- 90-94%: Implement but explicitly note uncertainties
- Below 90%: STOP and ask clarifying questions

# Tradeoffs

State any tradeoffs to approaches and if you think they are acceptable.

# Sandbox

**NEVER** modify a file outside of `~/projects/`, `~/eonnext/`, or `~/.Trash/`.
Do not delete git repos, and do not edit `.git/` folders.

# File Deletion

NEVER use `rm` to delete files. Instead, move files to trash:

```bash
mv FILE ~/.Trash/
```

# Backwards compatibility

Assume everything is greenfield unless otherwise stated. Don't worry about
breaking changes. What matters is quality.

# Claude.md

Optimize CLAUDE.md so that Claude is less likely to forget instructions, while
simultaneously not overloading context.

# Device-Specific Instructions

@~/.claude/CLAUDE.local.md
