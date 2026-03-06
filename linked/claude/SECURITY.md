# Claude Security Settings

This document explains this user's security model for Claude Code.

## Philosophy: Trust Zones

| Zone                  | Scope                                                            | Behavior                                                                                      |
| --------------------- | ---------------------------------------------------------------- | --------------------------------------------------------------------------------------------- |
| **Current Directory** | `./`                                                             | YOLO mode - auto-allow most operations except git history changes and hard-to-undo operations |
| **Safe Read Zones**   | `~/projects`, `~/eonnext`                                        | Read/analyze freely, no modifications                                                         |
| **Temp/Cache**        | `/tmp`, `/var/folders` ($TMPDIR), `~/.cache`, `~/Library/Caches` | Always allowed - ephemeral/regenerable storage                                                |
| **Null**              | `/dev/null`                                                      | Always allowed - output sink                                                                  |
| **Outside**           | Everything else                                                  | Blocked (system dirs)                                                                         |

**Core principle:** Maximum productivity while preventing irreversible
operations or system integrity violations.

## Network Access

| Method                | Behavior                                |
| --------------------- | --------------------------------------- |
| GET/HEAD              | Allowed anywhere - reading is safe      |
| POST/PUT/DELETE/PATCH | Blocked by hook, requires user approval |

Fetching from the internet is fine. Only write operations (which could leak
data or modify remote state) are blocked.

## Two-Layer Architecture

### Layer 1: settings.json (Fast Path)

The `permissions.allow` list auto-approves common operations without prompting:

- File operations within current directory (Read, Write, Edit, Glob, Grep)
- Read-only access to safe zones and config files
- Common CLI tools (git, aws, docker, terraform, etc.)

The `permissions.deny` list blocks sensitive files:

- Credentials (~/.ssh/_, ~/.aws/credentials, ~/.gnupg/_)
- Secrets (_secret_, _.key, _.pem, _token_)
- Git internals (.git/\*\*)

**When to use:** Add auto-allow rules for frequently used safe commands.

### Layer 2: hooks/validate-command.sh (Deep Inspection)

The hook validates every Bash command, even auto-allowed ones. It catches:

- Sandbox escapes (writes outside allowed directories)
- Destructive operations (rm, git reset --hard, etc.)
- Command injection vectors (bash -c, eval, piped scripts)

**When to use:** Add blocking rules for dangerous patterns that could slip
through.

## Adding New Rules

### Testing First

Always test your regex before deploying:

```bash
# Test a command against the hook
echo '{"tool_name":"Bash","tool_input":{"command":"your command here"}}' \
  | ./hooks/validate-command.sh
echo $?  # 0 = pass, 2 = blocked
```

### Adding to settings.json

For auto-allowing safe commands:

```json
"Bash(safe-command *)"
```

For blocking specific patterns:

```json
"Bash(* dangerous-pattern *)"
```

### Adding to validate-command.sh

1. Add the blocking logic with a clear comment
2. Use consistent regex patterns:
   - `^cmd[[:space:]]` - Command at start
   - `[[:space:]]flag` - Flag anywhere
   - `(^|[;&|])` - Start of command or after separator
3. Add corresponding tests to `validate-command.test.sh`
4. Run full test suite to verify no regressions

### Checklist

- [ ] Test the pattern manually first
- [ ] Add blocking logic to validate-command.sh
- [ ] Add both pass and block tests
- [ ] Run `./hooks/validate-command.test.sh`
- [ ] Update this document if adding a new category
