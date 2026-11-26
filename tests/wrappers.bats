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

# --- Negative controls: the credential gate still holds ---
#
# The approval half of this wrapper is gone. permissions.ask now covers apply,
# destroy, import and the state rewrites, and it matches inside chains and
# subshells — which the CLAUDE_APPROVED flag never did, because terminator.sh
# exported it into every tool call, so a nested `make deploy -> terraform apply`
# saw it set exactly as a direct call did.
#
# What these pin is the half that remains (a write needs a granted profile) and
# that the read-only classification did not quietly widen to let writes through.

@test "terraform state rm runs with a granted profile, as state list does" {
	echo "eon-dev" >"$STATE_FILE"
	CLAUDE_AWS_STATE="$STATE_FILE"
	export CLAUDE_AWS_STATE
	run "$WRAPPERS/terraform.sh" state rm aws_s3_bucket.example
	[ "$status" -eq 0 ]
	[[ "$output" == *"AWS_PROFILE=eon-dev"* ]]
}

@test "terraform state rm is blocked with no granted profile" {
	unset CLAUDE_AWS_STATE
	run "$WRAPPERS/terraform.sh" state rm aws_s3_bucket.example
	[ "$status" -eq 1 ]
	[[ "$output" == *"No AWS access granted"* ]]
}

@test "terraform workspace new is blocked with no granted profile" {
	unset CLAUDE_AWS_STATE
	run "$WRAPPERS/terraform.sh" workspace new scratch
	[ "$status" -eq 1 ]
	[[ "$output" == *"No AWS access granted"* ]]
}

@test "an unrecognised state action fails closed onto the credential gate" {
	unset CLAUDE_AWS_STATE
	run "$WRAPPERS/terraform.sh" state some-future-action
	[ "$status" -eq 1 ]
	[[ "$output" == *"No AWS access granted"* ]]
}

@test "terraform apply is blocked with no AWS state" {
	unset CLAUDE_AWS_STATE
	run "$WRAPPERS/terraform.sh" apply
	[ "$status" -eq 1 ]
	[[ "$output" == *"No AWS access granted"* ]]
}

@test "terraform destroy is blocked with no AWS state" {
	unset CLAUDE_AWS_STATE
	run "$WRAPPERS/terraform.sh" destroy
	[ "$status" -eq 1 ]
	[[ "$output" == *"No AWS access granted"* ]]
}

@test "terraform test is not treated as read-only" {
	# Needing a profile is what proves it fell through to the write path.
	unset CLAUDE_AWS_STATE
	run "$WRAPPERS/terraform.sh" test
	[ "$status" -eq 1 ]
	[[ "$output" == *"No AWS access granted"* ]]
}

@test "terraform apply runs with a granted profile and injects it" {
	echo "eon-devtesting" >"$STATE_FILE"
	CLAUDE_AWS_STATE="$STATE_FILE"
	export CLAUDE_AWS_STATE
	run "$WRAPPERS/terraform.sh" apply
	[ "$status" -eq 0 ]
	[[ "$output" == *"AWS_PROFILE=eon-devtesting"* ]]
}

@test "CLAUDE_APPROVED is no longer consulted" {
	echo "eon-dev" >"$STATE_FILE"
	CLAUDE_AWS_STATE="$STATE_FILE"
	export CLAUDE_AWS_STATE
	unset CLAUDE_APPROVED
	run "$WRAPPERS/terraform.sh" apply
	[ "$status" -eq 0 ]
	[[ "$output" == *"AWS_PROFILE=eon-dev"* ]]
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

# --- Only aws and terraform are wrapped; there are no rm, git, ssh or dd cases ---
#
# Why those four are not wrapped, so nobody adds one back:
#
#   rm   covered three times over — `Bash(rm *)` in permissions.ask, Claude
#        Code's critical-path protection (which no allow rule overrides, and
#        which catches `rm -rf "$VAR"/*` and `bash -c 'rm -rf ~'`), and the
#        sandbox refusing the write. A location-gated wrapper on top of that
#        refuses *after* the user has approved, which teaches people to work
#        around it — it broke this repo's own mktemp cleanup in
#        steps/12_privileged.sh.
#   git  a wrapper gate cannot work here: anything it keys on, such as an
#        environment flag set at launch, is present in every tool call, so the
#        gate is open at the top level and never sees the nested writes it
#        would be written for. `git push` is a permissions.ask rule instead.
#   ssh  unreachable: plain ssh ignores the sandbox's proxy variables and
#        cannot open a connection at all.
#   dd   a permissions.ask rule.
