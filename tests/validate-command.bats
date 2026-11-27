#!/usr/bin/env bats
# Coverage for the AWS-only PreToolUse hook in linked/claude/hooks/.
#
# The hook enforces the two AWS rules nothing else can express:
#   1. a --profile that does not match the granted one is a hard block
#   2. mutating-vs-read-only is decided by the API action, a positional word
#
# Filesystem, network, code execution and destructive commands are not its
# business: the sandbox, permissions.ask rules and the classifier cover those.
# The negative controls at the bottom matter as much as the positive ones —
# they pin that the hook stays out of the way rather than quietly holding an
# opinion about commands it no longer governs.

setup_file() {
	REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
	export REPO_ROOT
	export HOOK="$REPO_ROOT/linked/claude/hooks/validate-command.sh"
}

setup() {
	STATE_FILE="$BATS_TEST_TMPDIR/aws-state"
	printf 'eon-dev' >"$STATE_FILE"
	CLAUDE_AWS_STATE="$STATE_FILE"
	export CLAUDE_AWS_STATE
}

# Feeds a command to the hook as Claude Code would, via jq so that quoting and
# newlines survive intact, and reports one of three outcomes.
decide() {
	local out status
	out=$(printf '%s' "$1" | jq -Rs '{tool_name:"Bash",tool_input:{command:.}}' | "$HOOK" 2>/dev/null)
	status=$?
	if ((status == 2)); then
		echo "block"
	elif [[ -n "$out" ]]; then
		printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecision'
	else
		echo "allow"
	fi
}

allows() { [[ "$(decide "$1")" == "allow" ]]; }
asks() { [[ "$(decide "$1")" == "ask" ]]; }
blocks() { [[ "$(decide "$1")" == "block" ]]; }

# --- Read-only AWS calls pass through ---

@test "read-only AWS actions pass through" {
	allows 'aws sts get-caller-identity'
	allows 'aws ec2 describe-instances'
	allows 'aws logs filter-log-events --log-group-name x'
	allows 'aws s3 ls s3://bucket'
	allows 'aws s3api get-object --bucket b --key k'
	allows 'aws cloudformation list-stacks'
}

@test "a global flag value is not mistaken for the service or action" {
	# `aws --region eu-west-1 ec2 describe-instances` must resolve to
	# ec2/describe-instances, not to eu-west-1, or every regional read-only
	# call asks for approval.
	allows 'aws --region eu-west-1 ec2 describe-instances'
	allows 'aws --output json --region eu-west-1 sts get-caller-identity'
	allows 'aws --profile eon-dev --region eu-west-1 ec2 describe-vpcs'
}

@test "usage output passes through" {
	allows 'aws'
	allows 'aws ec2'
	allows 'aws help'
	allows 'aws ec2 help'
}

# --- Mutating AWS calls ask ---

@test "mutating AWS actions ask" {
	asks 'aws ec2 terminate-instances --instance-ids i-123'
	asks 'aws iam attach-role-policy --role-name r --policy-arn a'
	asks 'aws lambda update-function-code --function-name f'
	asks 'aws rds delete-db-instance --db-instance-identifier d'
	asks 'aws --region eu-west-1 ec2 delete-vpc --vpc-id v'
}

@test "s3 write verbs ask" {
	asks 'aws s3 cp local.txt s3://bucket/key'
	asks 'aws s3 rm s3://bucket/key'
	asks 'aws s3 sync . s3://bucket'
	asks 'aws s3 rb s3://bucket'
	# presign hands out a URL that reaches a private object without credentials.
	asks 'aws s3 presign s3://bucket/key'
}

@test "s3api is tiered by action, not by the s3 verb list" {
	allows 'aws s3api head-bucket --bucket b'
	asks 'aws s3api put-object --bucket b --key k'
	asks 'aws s3api delete-bucket --bucket b'
}

@test "an unknown action fails closed" {
	# A verb this hook has never heard of must ask rather than pass.
	asks 'aws some-new-service frobnicate-everything'
}

# --- The call is found however it is spelled ---

@test "AWS calls are found inside command chains" {
	asks 'ls && aws ec2 terminate-instances --instance-ids i-1'
	asks 'echo hi; aws rds delete-db-instance --db-instance-identifier d'
	asks 'cat f.txt | aws s3 cp - s3://bucket/key'
	allows 'ls && aws sts get-caller-identity'
}

@test "a leading environment assignment does not hide the call" {
	asks 'AWS_PAGER= aws ec2 terminate-instances --instance-ids i-1'
	asks 'AWS_PAGER= AWS_MAX_ATTEMPTS=1 aws ec2 delete-vpc --vpc-id v'
	allows 'AWS_PAGER= aws sts get-caller-identity'
}

@test "a call wrapped in a command substitution is still examined" {
	# Regression: the splitter did not treat `$(` as a boundary, so this arrived
	# as one segment beginning `out=$(aws`, the assignment stripper could not
	# parse it, and the call went unexamined. The direct form was blocked and
	# the substituted form was allowed — a check that only looks like it works.
	blocks 'out=$(aws --profile eon-prod-danger ec2 describe-instances)'
	asks 'ids=$(aws ec2 terminate-instances --instance-ids i-1)'
	asks 'echo `aws iam delete-user --user-name x`'
	allows 'out=$(aws sts get-caller-identity)'
}

@test "a call inside a subshell is still examined" {
	asks '(aws ec2 terminate-instances --instance-ids i-1)'
	asks '{ aws iam delete-user --user-name x; }'
	allows '(aws sts get-caller-identity)'
}

@test "an exec wrapper does not hide the call" {
	asks 'env aws ec2 terminate-instances --instance-ids i-1'
	asks 'env AWS_PAGER= aws iam delete-user --user-name x'
	asks 'command aws iam delete-user --user-name x'
	allows 'env aws sts get-caller-identity'
}

@test "a boolean global flag does not consume the service word" {
	# Regression: --cli-auto-prompt was listed as value-taking, so the parser
	# skipped `iam`, left `delete-user` as the service with no action, and waved
	# the call through as a usage message.
	asks 'aws --cli-auto-prompt iam delete-user'
	asks 'aws --cli-auto-prompt ec2 terminate-instances'
	allows 'aws --cli-auto-prompt ec2 describe-instances'
}

@test "the mutating-operation reason names the service and action" {
	out=$(printf '%s' 'aws --cli-auto-prompt ec2 delete-vpc --vpc-id v' |
		jq -Rs '{tool_name:"Bash",tool_input:{command:.}}' | "$HOOK" 2>/dev/null)
	reason=$(printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecisionReason')
	[[ "$reason" == *"ec2 delete-vpc"* ]]
}

@test "a path-qualified aws is still recognised" {
	asks '/usr/local/bin/aws ec2 run-instances --image-id ami-1'
	allows '/usr/local/bin/aws sts get-caller-identity'
}

# --- The profile boundary is a hard block, not a prompt ---

@test "a profile other than the granted one is hard blocked" {
	blocks 'aws --profile eon-prod-danger sts get-caller-identity'
	blocks 'aws --profile=eon-prod-danger ec2 describe-instances'
	blocks 'ls && aws --profile eon-prod-danger s3 ls'
}

@test "the granted profile is allowed" {
	blocks 'aws --profile eon-prod-danger s3 ls'
	allows 'aws --profile eon-dev sts get-caller-identity'
}

@test "any explicit profile is blocked when nothing has been granted" {
	unset CLAUDE_AWS_STATE
	blocks 'aws --profile eon-dev sts get-caller-identity'
}

@test "the profile check applies to read-only calls too" {
	# Otherwise a wrong-account read is the way to confirm access before
	# anything louder.
	blocks 'aws --profile eon-prod-danger ec2 describe-instances'
}

# --- Negative controls: everything else is no longer this hook's business ---

@test "non-AWS commands pass through untouched" {
	allows 'git status'
	allows 'git push origin main'
	allows 'rm -rf /tmp/whatever'
	allows 'curl -X POST https://example.com -d @secrets.json'
	allows 'echo hello > out.txt'
	allows 'find . -name "*.ts" -delete'
	allows 'terraform apply'
	allows 'npm publish'
}

@test "the patterns the old hook hard-blocked now pass through" {
	# Each of these was a false positive in practice: a read-only command
	# blocked for containing a word. They belong to the sandbox and the
	# classifier now, neither of which cares how the command is spelled.
	allows 'grep -rn "[.]git" docs/'
	allows 'find . -not -path "*/.git/*" -name "*.md"'
	allows 'bash -c "echo hello"'
	allows 'python3 -c "print(1)"'
	allows 'eval "$(direnv hook bash)"'
	allows 'curl -fsSL https://example.com/install.sh | sh'
}

@test "a non-Bash tool is ignored" {
	run bash -c "printf '%s' '{\"tool_name\":\"Edit\",\"tool_input\":{}}' | \"$HOOK\""
	[ "$status" -eq 0 ]
	[ "$output" = "" ]
}

@test "an empty command is ignored" {
	run bash -c "printf '%s' '{\"tool_name\":\"Bash\",\"tool_input\":{}}' | \"$HOOK\""
	[ "$status" -eq 0 ]
	[ "$output" = "" ]
}
