# Confidence

State a confidence score (0-100%) for any code change, architecture decision,
API usage, data-structure interpretation or bug fix. Below 90%, stop and ask
rather than guess; at 90-94%, implement and say what is uncertain.

# Tradeoffs

State any tradeoffs to approaches and if you think they are acceptable.

# Comments

Comment only what the code cannot say — why, not what. Where a comment explains
what the code is doing, restructure until it needs none. Examples are good -
long explanations are bad.

# Leave Things Working

Never finish with anything broken. If you notice something is broken — tests,
lint, types, builds, features — fix it, even if unrelated to the current task.
Only leave things broken if explicitly told to.

# Backwards compatibility

Assume everything is greenfield unless otherwise stated. Don't worry about
breaking changes. What matters is quality. Do not comment on past states.

# Worktrees

Use worktrees for larger changes, and for any subagent doing independent work
(`isolation: worktree`). Use `EnterWorktree`, not `git worktree add`.

Leave the work uncommitted unless asked.

# Sandbox

**The boundary is the kernel**, applied per command, and the unsandboxed retry
is disabled. A denial on a path, host or credential the task does not involve is
the boundary working — report it rather than looking for another route.

Prefer `trash` over `rm`. Run git as a plain unchained `git ...` — the `git *`
exemption cannot match a chain or a command substitution, and `.git` writes then
fail. Matching it is not sufficient either: `add`, `commit -F` and `push` land,
`config --local` and `tag` do not.

# Claude.md and skills

Update Claude.md and skills to prevent making the same mistake twice. Claude.md
must be kept as small as possible to save context.

# Device-Specific Instructions

@~/.claude/CLAUDE.local.md
