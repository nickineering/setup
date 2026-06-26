#!/usr/bin/env bash
set -euo pipefail

# Generic Claude Code launcher with AWS credential scoping.
# All company-specific values come from TERMINATOR_* env vars (set in ~/.env.sh).
#
# Required env vars:
#   TERMINATOR_AWS_BEDROCK_PROFILE - AWS profile for Bedrock API access
#
# Optional env vars:
#   TERMINATOR_BEDROCK_REGION      - AWS region for Bedrock (default: eu-central-1)
#   TERMINATOR_MODEL_OPUS          - Opus model ID (session default + opus alias)
#   TERMINATOR_MODEL_SONNET        - Sonnet model ID (sonnet alias)
#   TERMINATOR_MODEL_HAIKU         - Haiku model ID (background queries + haiku alias)

SELF_DIR="$(cd "$(dirname "$0")" && pwd)"

# --- Validate configuration ---
if [[ -z "${TERMINATOR_AWS_BEDROCK_PROFILE:-}" ]]; then
	echo "❌ TERMINATOR_AWS_BEDROCK_PROFILE not set. Source ~/.env.sh first."
	exit 1
fi

BEDROCK_REGION="${TERMINATOR_BEDROCK_REGION:-eu-central-1}"

# --- Parse CLI flags ---
target_profile=""
claude_args=()
while [[ $# -gt 0 ]]; do
	case "$1" in
	--aws)
		target_profile="$2"
		shift 2
		;;
	*)
		claude_args+=("$1")
		shift
		;;
	esac
done

# --- Check for active SSO session ---
check_sso() {
	command aws sts get-caller-identity --profile "$1" &>/dev/null
}

if check_sso "$TERMINATOR_AWS_BEDROCK_PROFILE"; then
	echo "✅ Active AWS SSO session for profile: $TERMINATOR_AWS_BEDROCK_PROFILE"
else
	echo "No active AWS SSO session. Attempting login..."
	if ! aws sso login --profile "$TERMINATOR_AWS_BEDROCK_PROFILE"; then
		echo "❌ AWS SSO login failed. Aborting."
		exit 1
	fi
	if ! check_sso "$TERMINATOR_AWS_BEDROCK_PROFILE"; then
		echo "❌ Login completed but session could not be verified. Aborting."
		exit 1
	fi
	echo "✅ AWS SSO login successful."
fi

# --- Set up session state ---
state_file="/tmp/.claude-aws-$$"
if [[ -n "$target_profile" ]]; then
	echo "$target_profile" >"$state_file"
	echo "☁️  AWS access granted: $target_profile"
else
	rm -f "$state_file"
	echo "🔒 No AWS access granted (use '! claude-aws <profile>' inside session)"
fi

# --- Build environment and launch ---
unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN AWS_CREDENTIAL_EXPIRATION

declare -a env_vars=(
	"CLAUDE_SESSION=1"
	"CLAUDE_AWS_STATE=$state_file"
	"AWS_PROFILE=$TERMINATOR_AWS_BEDROCK_PROFILE"
	"AWS_REGION=$BEDROCK_REGION"
	"CLAUDE_CODE_USE_BEDROCK=1"
)

if [[ -n "${TERMINATOR_MODEL_OPUS:-}" ]]; then
	env_vars+=("ANTHROPIC_MODEL=$TERMINATOR_MODEL_OPUS")
	env_vars+=("ANTHROPIC_DEFAULT_OPUS_MODEL=$TERMINATOR_MODEL_OPUS")
fi
if [[ -n "${TERMINATOR_MODEL_SONNET:-}" ]]; then
	env_vars+=("ANTHROPIC_DEFAULT_SONNET_MODEL=$TERMINATOR_MODEL_SONNET")
fi
if [[ -n "${TERMINATOR_MODEL_HAIKU:-}" ]]; then
	env_vars+=("ANTHROPIC_SMALL_FAST_MODEL=$TERMINATOR_MODEL_HAIKU")
	env_vars+=("ANTHROPIC_DEFAULT_HAIKU_MODEL=$TERMINATOR_MODEL_HAIKU")
fi

# Prepend bin/ for PATH wrappers (Layer 1)
export PATH="$SELF_DIR/bin:$PATH"

env "${env_vars[@]}" claude "${claude_args[@]}"

# Cleanup
rm -f "$state_file"
