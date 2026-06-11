---
description: Show AWS Bedrock cost for the current session or a time period
argument-hint: time period
model: haiku
---

Show Claude Code session costs from AWS Bedrock billing.

$ARGUMENTS - Optional time period (e.g., "today", "this week", "last 7 days",
"this month", "2026-06-01", "2026-06-01:2026-06-04"). Defaults to current
session only.

## Workflow

Run the helper script and display its output:

```bash
~/.claude/skills/cost/cost.sh $ARGUMENTS
```

Map natural language periods to script arguments:

- "today" → `today`
- "yesterday" → `yesterday`
- "this week" → `this-week`
- "last 7 days" / "past week" → `last-7-days`
- "this month" → `this-month`
- "since June 1" / "from 2026-06-01" → `2026-06-01`
- "June 1 to June 4" → `2026-06-01:2026-06-04`
- No arguments → current session only

If rates are stale or missing, run with `--refresh-rates` (requires AWS access
via `! claude-aws dev`).

## Rules

- After running the script, your ONLY response must be a single markdown fenced
  code block containing the complete unmodified script output. Nothing else. No
  text before it. No text after it. No summary. No explanation. Example of
  correct response format:

  ```
  <full script output here, every single line>
  ```

- NEVER omit lines, summarize, or add your own words.
- If the script fails with an AWS access error, tell the user to run
  `! claude-aws dev` then retry with `--refresh-rates`.
