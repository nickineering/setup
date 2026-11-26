#!/bin/bash
# PreToolUse hook for Bash. AWS credential scoping only.
#
# Everything this file used to check now lives where it belongs:
#
#   filesystem and network boundaries  the sandbox, enforced by the kernel
#   destructive / outbound operations  permissions.ask rules, which are
#                                      shell-aware: they match inside &&, ||,
#                                      subshells and $(...) substitutions
#   judgement calls                    the auto mode classifier
#
# Regex over command strings was a weaker copy of the first two and no
# substitute for the third. What is left are the two AWS rules that none of
# those layers can express:
#
#   1. A --profile that does not match the profile claude-aws granted is a
#      credential boundary violation, so it is a hard block rather than a
#      prompt. Approving it would still be wrong.
#   2. Whether an AWS call mutates is decided by its API action, which is a
#      positional word. A permission rule matches on prefixes and cannot
#      reach it, so the tiering has to happen here.

set -uo pipefail

INPUT=$(cat)
[[ "$(jq -r '.tool_name' <<<"$INPUT")" == "Bash" ]] || exit 0
COMMAND=$(jq -r '.tool_input.command // empty' <<<"$INPUT")
[[ -n "$COMMAND" ]] || exit 0

ask() {
	printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"%s"}}\n' "$1"
	exit 0
}

block() {
	echo "BLOCKED: $1" >&2
	exit 2
}

# Action prefixes that only read. Anything unrecognised falls through to the
# approval prompt, so a new mutating verb fails closed rather than open.
# The hyphenated entries are prefixes; `wait` and `help` are whole actions.
# `export-` is deliberately absent: `ec2 export-image` writes.
READONLY_ACTION='^(describe-|list-|get-|filter-|head-|batch-get-|check-|decode-|estimate-|lookup-|preview-|query-|scan-|search-|select-|simulate-|test-|validate-|download-)|^(wait|help)$'

# S3's high-level commands are verbs, not API actions, so they need their own
# list. `s3api` is action-based and goes through READONLY_ACTION.
S3_WRITE_VERBS=' cp mv rm sync mb rb website presign '

# Global flags that take a separate value. Their value must not be mistaken
# for the service or the action: in `aws --region eu-west-1 ec2 describe-x`
# the service is ec2, not eu-west-1.
#
# Only flags that really take a value belong here. `--cli-auto-prompt` is a
# boolean and was listed by mistake, which made the parser skip the word after
# it: `aws --cli-auto-prompt iam delete-user` lost `iam`, left `delete-user` as
# the service with no action, and was waved through as a usage message. Boolean
# flags need no entry — the generic `-*` branch already ignores them.
VALUE_FLAGS=' --profile --region --output --endpoint-url --query --ca-bundle --cli-read-timeout --cli-connect-timeout --color --cli-binary-format '

# Wrappers that run their argument as a command, peeled so the aws call behind
# them is still examined. Deliberately not including `timeout`/`nice`/`time`:
# those take a value of their own, so peeling only the word leaves the value as
# the command. The classifier remains the backstop for those.
EXEC_WRAPPERS=' env command builtin nohup stdbuf '

check_aws() {
	local cmd="$1" first requested granted service action w i skip=0
	local -a words positional=()

	# Peel leading whitespace, VAR=value assignments and exec wrappers until the
	# real command is the first word, repeating because they combine:
	# `env AWS_PAGER= aws …` needs all three passes.
	#
	# Leading whitespace matters because splitting a chain leaves it on every
	# segment after the first, and without trimming it ` aws …` reads as an
	# empty command. The assignment stripping is done in bash rather than sed
	# because the sed form needed `\+`, a GNU extension that this platform's sed
	# reads as a literal plus — leaving the assignment in place and the call
	# unexamined.
	while :; do
		cmd="${cmd#"${cmd%%[![:space:]]*}"}"
		if [[ "$cmd" =~ ^[A-Za-z_][A-Za-z_0-9]*=[^[:space:]]*[[:space:]] ]]; then
			cmd="${cmd#"${BASH_REMATCH[0]}"}"
			continue
		fi
		first=${cmd%% *}
		if [[ "$first" != "$cmd" && "$EXEC_WRAPPERS" == *" ${first##*/} "* ]]; then
			cmd="${cmd#"$first"}"
			continue
		fi
		break
	done

	# A path on the command itself is fine to leave in place: the word loop
	# below starts at index 1, so only the basename comparison needs it off.
	first=${cmd%% *}
	[[ "${first##*/}" == "aws" ]] || return 0

	# 1. Credential boundary. Checked first, and on the raw text, so it applies
	#    even to a call this script would otherwise consider read-only.
	if [[ "$cmd" =~ (--profile[[:space:]]+|--profile=)([^[:space:]]+) ]]; then
		requested="${BASH_REMATCH[2]}"
		granted=""
		if [[ -n "${CLAUDE_AWS_STATE:-}" && -f "$CLAUDE_AWS_STATE" ]]; then
			granted=$(cat "$CLAUDE_AWS_STATE")
		fi
		if [[ "$requested" != "$granted" ]]; then
			block "AWS profile '$requested' not granted. Current access: ${granted:-none}"
		fi
	fi

	# 2. Find the service and action positionally, skipping flags and values.
	read -r -a words <<<"$cmd"
	for ((i = 1; i < ${#words[@]}; i++)); do
		w="${words[i]}"
		if ((skip)); then
			skip=0
			continue
		fi
		case "$w" in
		--*=*) continue ;;
		-*)
			[[ "$VALUE_FLAGS" == *" $w "* ]] && skip=1
			continue
			;;
		*) positional+=("$w") ;;
		esac
	done

	service="${positional[0]:-}"
	action="${positional[1]:-}"

	# No action means a usage message: bare `aws`, `aws ec2`, `aws help`.
	[[ -z "$action" || "$service" == "help" ]] && return 0
	[[ "$action" == "help" ]] && return 0

	if [[ "$service" == "s3" ]]; then
		[[ "$S3_WRITE_VERBS" == *" $action "* ]] && ask "AWS S3 write operation: s3 $action"
		return 0
	fi

	[[ "$action" =~ $READONLY_ACTION ]] && return 0
	ask "AWS mutating operation: $service $action"
}

# Split on shell separators so `ls && aws ec2 terminate-instances` is still
# seen. Over-splitting is harmless: a segment that is not an aws call is
# ignored, and the permission layer handles everything that is not aws.
#
# Command substitutions and subshells are boundaries too, and that is the
# important part. Without them, `out=$(aws --profile other-account …)` arrived
# as one segment beginning `out=$(aws`, the assignment stripper could not make
# sense of it, and the call went unexamined — so wrapping a call in `$( )` was
# enough to walk past the credential boundary this file exists to enforce. The
# direct form was blocked and the substituted form was allowed, which is the
# worst shape a security check can have: it looks like it works.
while IFS= read -r segment; do
	[[ -n "$segment" ]] && check_aws "$segment"
done <<<"$(sed 's/&&/\n/g; s/||/\n/g; s/[;|]/\n/g; s/\$(/\n/g; s/[`(){}]/\n/g' <<<"$COMMAND")"

exit 0
