#!/usr/bin/env bats
# Coverage for the PATH wrappers in linked/claude/wrappers/.
#
# The terraform tests stub the real binary via a fixture on PATH, so they need
# no terraform install. The negative controls matter as much as the positive
# ones: they prove the AWS gate narrowed to credential-free subcommands rather
# than opening up.

load test_helper

WRAPPERS="$REPO_ROOT/linked/claude/wrappers"

setup() {
	STUB_DIR="$BATS_TEST_TMPDIR/bin"
	mkdir -p "$STUB_DIR"

	# Stub terraform: echoes its args and whether a profile reached it.
	cat >"$STUB_DIR/terraform" <<-'STUB'
		#!/usr/bin/env bash
		echo "stub-terraform: $*"
		echo "AWS_PROFILE=${AWS_PROFILE:-<unset>}"
	STUB
	chmod +x "$STUB_DIR/terraform"

	PATH="$STUB_DIR:$PATH"
	export PATH

	STATE_FILE="$BATS_TEST_TMPDIR/aws-state"
}

# --- Read-only subcommands: allowed with no AWS state ---

@test "terraform fmt runs with CLAUDE_AWS_STATE unset" {
	unset CLAUDE_AWS_STATE
	run "$WRAPPERS/terraform.sh" fmt -check -diff .
	[ "$status" -eq 0 ]
	[[ "$output" == *"stub-terraform: fmt -check -diff ."* ]]
}

@test "terraform fmt runs when CLAUDE_AWS_STATE points at a missing file" {
	CLAUDE_AWS_STATE="$BATS_TEST_TMPDIR/does-not-exist"
	export CLAUDE_AWS_STATE
	run "$WRAPPERS/terraform.sh" fmt -check .
	[ "$status" -eq 0 ]
}

@test "terraform version runs with no AWS state" {
	unset CLAUDE_AWS_STATE
	run "$WRAPPERS/terraform.sh" version
	[ "$status" -eq 0 ]
}

@test "terraform -version runs with no AWS state" {
	unset CLAUDE_AWS_STATE
	run "$WRAPPERS/terraform.sh" -version
	[ "$status" -eq 0 ]
}

@test "terraform fmt honours -chdir without treating it as the subcommand" {
	unset CLAUDE_AWS_STATE
	run "$WRAPPERS/terraform.sh" -chdir=./terraform fmt -check
	[ "$status" -eq 0 ]
	[[ "$output" == *"fmt -check"* ]]
}

@test "every read-only subcommand runs with no AWS state" {
	unset CLAUDE_AWS_STATE
	source "$REPO_ROOT/linked/claude/policy.conf"
	for subcmd in "${TERRAFORM_ALLOWED_READONLY[@]}"; do
		run "$WRAPPERS/terraform.sh" "$subcmd"
		[ "$status" -eq 0 ] || {
			echo "read-only subcommand '$subcmd' was refused: $output"
			return 1
		}
	done
}

@test "read-only actions of dual-purpose subcommands run with no AWS state" {
	unset CLAUDE_AWS_STATE
	source "$REPO_ROOT/linked/claude/policy.conf"
	for pair in "${TERRAFORM_READONLY_ACTIONS[@]}"; do
		# shellcheck disable=SC2086  # deliberate split into subcmd + action
		run "$WRAPPERS/terraform.sh" $pair
		[ "$status" -eq 0 ] || {
			echo "read-only pair '$pair' was refused: $output"
			return 1
		}
	done
}

# --- Negative controls: the gate still holds for everything else ---

@test "terraform state rm needs approval even though state list does not" {
	echo "eon-dev" >"$STATE_FILE"
	CLAUDE_AWS_STATE="$STATE_FILE"
	export CLAUDE_AWS_STATE
	unset CLAUDE_APPROVED
	run "$WRAPPERS/terraform.sh" state rm aws_s3_bucket.example
	[ "$status" -eq 1 ]
	[[ "$output" == *"terraform state rm requires approval"* ]]
}

@test "terraform workspace new needs approval even though workspace list does not" {
	echo "eon-dev" >"$STATE_FILE"
	CLAUDE_AWS_STATE="$STATE_FILE"
	export CLAUDE_AWS_STATE
	unset CLAUDE_APPROVED
	run "$WRAPPERS/terraform.sh" workspace new scratch
	[ "$status" -eq 1 ]
	[[ "$output" == *"requires approval"* ]]
}

@test "an unrecognised state action fails closed onto the approval gate" {
	echo "eon-dev" >"$STATE_FILE"
	CLAUDE_AWS_STATE="$STATE_FILE"
	export CLAUDE_AWS_STATE
	unset CLAUDE_APPROVED
	run "$WRAPPERS/terraform.sh" state some-future-action
	[ "$status" -eq 1 ]
	[[ "$output" == *"requires approval"* ]]
}

@test "terraform apply is still blocked with no AWS state" {
	unset CLAUDE_AWS_STATE
	run "$WRAPPERS/terraform.sh" apply
	[ "$status" -eq 1 ]
	[[ "$output" == *"No AWS access granted"* ]]
}

@test "terraform destroy is still blocked without CLAUDE_APPROVED" {
	echo "eon-devtesting" >"$STATE_FILE"
	CLAUDE_AWS_STATE="$STATE_FILE"
	export CLAUDE_AWS_STATE
	unset CLAUDE_APPROVED
	run "$WRAPPERS/terraform.sh" destroy
	[ "$status" -eq 1 ]
	[[ "$output" == *"requires approval"* ]]
}

@test "terraform test is not treated as read-only" {
	echo "eon-devtesting" >"$STATE_FILE"
	CLAUDE_AWS_STATE="$STATE_FILE"
	export CLAUDE_AWS_STATE
	unset CLAUDE_APPROVED
	run "$WRAPPERS/terraform.sh" test
	[ "$status" -eq 1 ]
	[[ "$output" == *"requires approval"* ]]
}

@test "terraform apply is still blocked without CLAUDE_APPROVED" {
	echo "eon-devtesting" >"$STATE_FILE"
	CLAUDE_AWS_STATE="$STATE_FILE"
	export CLAUDE_AWS_STATE
	unset CLAUDE_APPROVED
	run "$WRAPPERS/terraform.sh" apply
	[ "$status" -eq 1 ]
	[[ "$output" == *"requires approval"* ]]
}

@test "terraform apply runs with CLAUDE_APPROVED=1 and injects the profile" {
	echo "eon-devtesting" >"$STATE_FILE"
	CLAUDE_AWS_STATE="$STATE_FILE"
	CLAUDE_APPROVED=1
	export CLAUDE_AWS_STATE CLAUDE_APPROVED
	run "$WRAPPERS/terraform.sh" apply
	[ "$status" -eq 0 ]
	[[ "$output" == *"AWS_PROFILE=eon-devtesting"* ]]
}

@test "terraform plan injects the target profile when state is set" {
	echo "eon-dev" >"$STATE_FILE"
	CLAUDE_AWS_STATE="$STATE_FILE"
	export CLAUDE_AWS_STATE
	run "$WRAPPERS/terraform.sh" plan
	[ "$status" -eq 0 ]
	[[ "$output" == *"AWS_PROFILE=eon-dev"* ]]
}

@test "a read-only command with no granted profile gets no profile at all" {
	# Not even the ambient Bedrock-only one terminator.sh exports.
	AWS_PROFILE="eon-agentic-code"
	export AWS_PROFILE
	unset CLAUDE_AWS_STATE
	run "$WRAPPERS/terraform.sh" fmt
	[ "$status" -eq 0 ]
	[[ "$output" == *"AWS_PROFILE=<unset>"* ]]
}

# --- SSO error correction ---

@test "terraform corrects the misleading SSO token error" {
	cat >"$STUB_DIR/terraform" <<-'STUB'
		#!/usr/bin/env bash
		echo "aws: [ERROR]: Error loading SSO Token: Token for my-eon-sso does not exist" >&2
		exit 1
	STUB
	chmod +x "$STUB_DIR/terraform"

	echo "eon-dev" >"$STATE_FILE"
	CLAUDE_AWS_STATE="$STATE_FILE"
	export CLAUDE_AWS_STATE
	run "$WRAPPERS/terraform.sh" plan
	[ "$status" -eq 1 ]
	[[ "$output" == *"Error loading SSO Token"* ]]      # original preserved
	[[ "$output" == *"unreadable"* ]]                   # correction appended
	[[ "$output" == *"aws sts get-caller-identity"* ]]
}

@test "terraform does not append the SSO note on unrelated failures" {
	cat >"$STUB_DIR/terraform" <<-'STUB'
		#!/usr/bin/env bash
		echo "Error: something else entirely" >&2
		exit 3
	STUB
	chmod +x "$STUB_DIR/terraform"

	echo "eon-dev" >"$STATE_FILE"
	CLAUDE_AWS_STATE="$STATE_FILE"
	export CLAUDE_AWS_STATE
	run "$WRAPPERS/terraform.sh" plan
	[ "$status" -eq 3 ]
	[[ "$output" == *"something else entirely"* ]]
	[[ "$output" != *"unreadable"* ]]
}

# --- aws wrapper ---

@test "aws wrapper corrects the misleading SSO token error" {
	cat >"$STUB_DIR/aws" <<-'STUB'
		#!/usr/bin/env bash
		echo "aws: [ERROR]: Error loading SSO Token: Token for my-eon-sso does not exist" >&2
		exit 255
	STUB
	chmod +x "$STUB_DIR/aws"

	echo "eon-dev" >"$STATE_FILE"
	CLAUDE_AWS_STATE="$STATE_FILE"
	export CLAUDE_AWS_STATE
	run "$WRAPPERS/aws.sh" sts get-caller-identity
	[ "$status" -eq 255 ]
	[[ "$output" == *"Error loading SSO Token"* ]]
	[[ "$output" == *"unreadable"* ]]
}

@test "aws wrapper passes stdout through untouched on success" {
	cat >"$STUB_DIR/aws" <<-'STUB'
		#!/usr/bin/env bash
		echo '{"Account":"622971355324"}'
	STUB
	chmod +x "$STUB_DIR/aws"

	echo "eon-dev" >"$STATE_FILE"
	CLAUDE_AWS_STATE="$STATE_FILE"
	export CLAUDE_AWS_STATE
	run "$WRAPPERS/aws.sh" sts get-caller-identity
	[ "$status" -eq 0 ]
	[ "$output" = '{"Account":"622971355324"}' ]
}

@test "aws wrapper requires AWS state" {
	unset CLAUDE_AWS_STATE
	run "$WRAPPERS/aws.sh" sts get-caller-identity
	[ "$status" -eq 1 ]
	[[ "$output" == *"No AWS access granted"* ]]
}
