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

**Write zones:** `~/projects/`, `~/work/`, `~/.Trash/`, `~/.cache/`,
`~/Library/Application Support/glab-cli/`, `~/Library/Caches/`, `/tmp/`,
`/dev/null`

**Blocked:** System dirs, `.git/` folders (platform-enforced, not overridable),
`rm` command (use `trash` instead)

**Git caveat:** `git push -u` silently fails to set tracking (`.git/config`
write blocked). Always use `git push origin <branch>` explicitly.

**Network:** GET/HEAD requests allowed anywhere. POST/PUT/DELETE require
approval.

# Leave Things Working

Never finish with anything broken. If you notice something is broken — tests,
lint, types, builds, features — fix it, even if unrelated to the current task.
Only leave things broken if explicitly told to.

# Backwards compatibility

Assume everything is greenfield unless otherwise stated. Don't worry about
breaking changes. What matters is quality.

# Claude.md

Optimize CLAUDE.md so that Claude is less likely to forget instructions, while
simultaneously not overloading context.

# Device-Specific Instructions

@~/.claude/CLAUDE.local.md
