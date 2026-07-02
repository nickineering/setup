# Terminator

Claude Code launcher with AWS credential scoping. Handles SSO login, environment
setup, and session-scoped AWS access control.

## Usage

```bash
terminator [--aws <profile>] [claude-args...]
```

### Examples

```bash
terminator --aws my-dev              # Launch with dev AWS access
terminator --aws my-prod --resume    # Launch with prod, resume last session
terminator                           # Launch with no AWS access (grant mid-session)
```

## Mid-Session AWS Access

Inside a running session, use `! claude-aws` to change AWS access:

```bash
! claude-aws my-dev       # Grant dev access
! claude-aws my-prod      # Switch to prod
! claude-aws off          # Revoke all AWS access
! claude-aws              # Show current state
```

The argument is an AWS profile name exactly as it appears in `~/.aws/config`.

## Configuration

All config comes from environment variables (set in `~/.env.sh`):

| Variable                         | Required | Description                                                   |
| -------------------------------- | -------- | ------------------------------------------------------------- |
| `TERMINATOR_AWS_BEDROCK_PROFILE` | Yes      | AWS profile used for Bedrock API access (Claude's connection) |
| `TERMINATOR_BEDROCK_REGION`      | No       | AWS region for Bedrock (default: `eu-central-1`)              |
| `TERMINATOR_MODEL_OPUS`          | No       | Opus model ID (session default + `opus` alias)                |
| `TERMINATOR_MODEL_SONNET`        | No       | Sonnet model ID (`sonnet` alias)                              |
| `TERMINATOR_MODEL_HAIKU`         | No       | Haiku model ID (background queries + `haiku` alias)           |

### Example `.env.sh`

```bash
export TERMINATOR_AWS_BEDROCK_PROFILE="my-bedrock-profile"
export TERMINATOR_BEDROCK_REGION="eu-central-1"
export TERMINATOR_MODEL_OPUS="eu.anthropic.claude-opus-4-6-v1"
export TERMINATOR_MODEL_SONNET="eu.anthropic.claude-sonnet-4-6"
export TERMINATOR_MODEL_HAIKU="eu.anthropic.claude-haiku-4-5-20251001-v1:0"
```

## How It Works

1. Validates `TERMINATOR_AWS_BEDROCK_PROFILE` is set
2. Checks for active AWS SSO session (prompts login if needed)
3. If `--aws <profile>` given, writes it to a PID-scoped state file
4. Unsets any inherited AWS credentials
5. Prepends `bin/` to PATH (for security wrappers)
6. Launches `claude` with Bedrock environment configured
7. Cleans up state file on exit

Each session gets its own state file (`/tmp/.claude-aws-<pid>`), so multiple
concurrent sessions can have different AWS access levels without interfering.

## Installation

Handled by `configure/claude.sh` during setup — creates symlinks in
`~/.local/bin/` for both `terminator` and `claude-aws`.
