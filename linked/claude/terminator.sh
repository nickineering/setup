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
#   TERMINATOR_MODEL_FABLE         - Fable model ID (fable alias)
#   TERMINATOR_EXTRA_SETTINGS      - Path to a settings.json layered over the
#                                    user's own, for configuration that must not
#                                    live in this repo (see below)

# Resolve through symlinks to find the real script directory
_source="${BASH_SOURCE[0]}"
while [[ -L "$_source" ]]; do
	_dir="$(cd "$(dirname "$_source")" && pwd)"
	_source="$(readlink "$_source")"
	[[ "$_source" != /* ]] && _source="$_dir/$_source"
done
SELF_DIR="$(cd "$(dirname "$_source")" && pwd)"

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
# Only the id: leaving _NAME and _SUPPORTED_CAPABILITIES unset keeps the
# built-in label and capability set, as the three aliases above do.
if [[ -n "${TERMINATOR_MODEL_FABLE:-}" ]]; then
	env_vars+=("ANTHROPIC_DEFAULT_FABLE_MODEL=$TERMINATOR_MODEL_FABLE")
fi

# Prepend bin/ so the aws and terraform wrappers shadow the real binaries and
# can inject the session's granted profile. Nothing else lives in bin/ now.
export PATH="$SELF_DIR/bin:$PATH"

# An optional settings layer held outside this repo. Employer hostnames, internal
# registries and classifier context about a private environment belong with that
# environment's own configuration, not in a public dotfiles repo, so the repo
# carries the mechanism and the values live wherever the var points.
#
# `--settings` rather than a project `.claude/settings.json` for two reasons: it
# can set the keys that only user-scope settings may set, such as
# permissions.defaultMode and autoMode.classifyAllShell, and it is read whatever
# directory the session starts in. Project settings are read from the session's
# own working directory without walking up, so a session deep inside a repo
# would silently miss a file placed at the tree's root. List keys merge across
# the precedence stack, so this file adds to the user's lists rather than
# replacing them — but note that an `autoMode` list which includes "$defaults"
# should include it in exactly one of the two files.
declare -a extra_settings=()
if [[ -n "${TERMINATOR_EXTRA_SETTINGS:-}" ]]; then
	if [[ -f "$TERMINATOR_EXTRA_SETTINGS" ]]; then
		extra_settings=(--settings "$TERMINATOR_EXTRA_SETTINGS")
		echo "🗂  Extra settings: $TERMINATOR_EXTRA_SETTINGS"
	else
		# A warning rather than an abort: losing the extra hosts is an
		# inconvenience, and failing to start a session over it is worse.
		echo "⚠️  TERMINATOR_EXTRA_SETTINGS is not a file, continuing without it:" >&2
		echo "    $TERMINATOR_EXTRA_SETTINGS" >&2
	fi
fi

env "${env_vars[@]}" claude \
	"${extra_settings[@]+"${extra_settings[@]}"}" \
	"${claude_args[@]+"${claude_args[@]}"}"

# Cleanup
rm -f "$state_file"
