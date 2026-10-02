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

# --- rm: allowed inside the temp roots, blocked everywhere else ---
#
# The negative cases carry the weight here. The wrapper's whole job is that the
# allowance for a script's own mktemp cleanup does not become a way to reach real
# work, so traversal and the temp root itself are tested explicitly.

@test "rm removes a file inside TMPDIR" {
	# The file has to exist for this to test anything: without it the case is
	# just the missing-path one below, and would still pass if the wrapper lost
	# the ability to delete at all.
	touch "$BATS_TEST_TMPDIR/scratch"
	TMPDIR="$BATS_TEST_TMPDIR" run "$WRAPPERS/rm.sh" -f "$BATS_TEST_TMPDIR/scratch"
	[ "$status" -eq 0 ]
	[[ "$output" != *BLOCKED* ]]
	[ ! -e "$BATS_TEST_TMPDIR/scratch" ]
}

@test "rm removes a directory tree inside TMPDIR" {
	mkdir -p "$BATS_TEST_TMPDIR/d/e"
	touch "$BATS_TEST_TMPDIR/d/e/f"
	TMPDIR="$BATS_TEST_TMPDIR" run "$WRAPPERS/rm.sh" -rf "$BATS_TEST_TMPDIR/d"
	[ "$status" -eq 0 ]
	[ ! -e "$BATS_TEST_TMPDIR/d" ]
}

@test "rm -f on a missing path inside TMPDIR is allowed" {
	# Lexical normalisation exists for this: realpath would fail on a path that is
	# not there, and the sync's RETURN trap fires with unset temp vars all the time.
	TMPDIR="$BATS_TEST_TMPDIR" run "$WRAPPERS/rm.sh" -f "$BATS_TEST_TMPDIR/never-existed"
	[ "$status" -eq 0 ]
}

@test "rm accepts several temp operands at once" {
	touch "$BATS_TEST_TMPDIR/a" "$BATS_TEST_TMPDIR/b"
	TMPDIR="$BATS_TEST_TMPDIR" run "$WRAPPERS/rm.sh" -rf "$BATS_TEST_TMPDIR/a" "$BATS_TEST_TMPDIR/b"
	[ "$status" -eq 0 ]
	[ ! -e "$BATS_TEST_TMPDIR/a" ]
	[ ! -e "$BATS_TEST_TMPDIR/b" ]
}

# The operand deliberately does not exist: the wrapper rejects on the path alone
# and never reaches the filesystem, so a fixture here would only risk the thing the
# test is checking cannot happen.
@test "rm blocks a path outside the temp roots" {
	run "$WRAPPERS/rm.sh" -rf "$HOME/work-this-path-must-never-be-removed"
	[ "$status" -eq 1 ]
	[[ "$output" == *BLOCKED* ]]
}

@test "rm blocks a relative path" {
	TMPDIR=/var/folders/zz/unused run "$WRAPPERS/rm.sh" -rf ./sync
	[ "$status" -eq 1 ]
	[[ "$output" == *BLOCKED* ]]
}

# A shallow, fixed TMPDIR so the number of ".." needed is deterministic. Against
# the real BATS_TEST_TMPDIR, which is several levels deep, the count would depend
# on how deep mktemp happened to nest it.
@test "rm blocks traversal out of TMPDIR" {
	TMPDIR=/tmp/fake-temp-root run "$WRAPPERS/rm.sh" -rf /tmp/fake-temp-root/../../Users
	[ "$status" -eq 1 ]
	[[ "$output" == *BLOCKED* ]]
}

@test "rm blocks removing the temp root itself" {
	TMPDIR="$BATS_TEST_TMPDIR" run "$WRAPPERS/rm.sh" -rf "$BATS_TEST_TMPDIR"
	[ "$status" -eq 1 ]
	[[ "$output" == *"temp root itself"* ]]
	[ -d "$BATS_TEST_TMPDIR" ]
}

@test "rm blocks a trailing-slash spelling of the temp root" {
	TMPDIR="$BATS_TEST_TMPDIR" run "$WRAPPERS/rm.sh" -rf "$BATS_TEST_TMPDIR/"
	[ "$status" -eq 1 ]
	[ -d "$BATS_TEST_TMPDIR" ]
}

@test "rm blocks an outside path hidden behind --" {
	run "$WRAPPERS/rm.sh" -rf -- "$HOME/work-this-path-must-never-be-removed"
	[ "$status" -eq 1 ]
	[[ "$output" == *BLOCKED* ]]
}

# `rm -f "${VAR:-}"` with VAR unset is the shape steps/12_privileged.sh uses to
# clean up the sudo password file, and it must not be mistaken for "." .
@test "rm -f with only empty operands succeeds" {
	run "$WRAPPERS/rm.sh" -f "" ""
	[ "$status" -eq 0 ]
	[[ "$output" != *BLOCKED* ]]
}

@test "rm still judges a real operand alongside an empty one" {
	run "$WRAPPERS/rm.sh" -f "" "$HOME/work-this-path-must-never-be-removed"
	[ "$status" -eq 1 ]
	[[ "$output" == *BLOCKED* ]]
}

@test "rm blocks a call with flags but no operands" {
	run "$WRAPPERS/rm.sh" -rf
	[ "$status" -eq 1 ]
	[[ "$output" == *"no paths given"* ]]
}

@test "rm blocks a bare invocation" {
	run "$WRAPPERS/rm.sh"
	[ "$status" -eq 1 ]
	[[ "$output" == *BLOCKED* ]]
}

# A lexical prefix check is not containment: a symlink inside the temp root can
# point anywhere, and a trailing slash makes rm act on the target rather than on
# the link. This deleted a directory outside the root before the physical pass
# was added, so the fixture is real and the assertion is that it survived.
@test "rm blocks a trailing-slash symlink pointing out of the temp root" {
	mkdir -p "$BATS_TEST_TMPDIR/root" "$BATS_TEST_TMPDIR/outside"
	touch "$BATS_TEST_TMPDIR/outside/precious"
	ln -s "$BATS_TEST_TMPDIR/outside" "$BATS_TEST_TMPDIR/root/link"
	TMPDIR="$BATS_TEST_TMPDIR/root" run "$WRAPPERS/rm.sh" -rf "$BATS_TEST_TMPDIR/root/link/"
	[ "$status" -eq 1 ]
	[[ "$output" == *BLOCKED* ]]
	[ -f "$BATS_TEST_TMPDIR/outside/precious" ]
}

# The counterpart, and the reason the physical pass resolves the parent rather
# than the whole path: without a trailing slash rm unlinks the link itself, which
# is a write inside the root no matter where the link points.
@test "rm removes a symlink inside the temp root without following it" {
	mkdir -p "$BATS_TEST_TMPDIR/root" "$BATS_TEST_TMPDIR/outside"
	touch "$BATS_TEST_TMPDIR/outside/precious"
	ln -s "$BATS_TEST_TMPDIR/outside" "$BATS_TEST_TMPDIR/root/link"
	TMPDIR="$BATS_TEST_TMPDIR/root" run "$WRAPPERS/rm.sh" -f "$BATS_TEST_TMPDIR/root/link"
	[ "$status" -eq 0 ]
	[ ! -L "$BATS_TEST_TMPDIR/root/link" ]
	[ -f "$BATS_TEST_TMPDIR/outside/precious" ]
}

@test "rm follows a trailing-slash symlink that stays inside the temp root" {
	mkdir -p "$BATS_TEST_TMPDIR/real" "$BATS_TEST_TMPDIR/esc"
	touch "$BATS_TEST_TMPDIR/real/f"
	ln -s "$BATS_TEST_TMPDIR/real" "$BATS_TEST_TMPDIR/esc/link"
	TMPDIR="$BATS_TEST_TMPDIR" run "$WRAPPERS/rm.sh" -rf "$BATS_TEST_TMPDIR/esc/link/"
	[ "$status" -eq 0 ]
	[ ! -e "$BATS_TEST_TMPDIR/real/f" ]
}

# /var/folders holds every account's temp directories, not just this session's.
# It used to be listed as a root, so `rm -rf /var/folders/zz` passed the gate and
# only filesystem permissions stopped it. $TMPDIR is the guard now, which is
# where mktemp puts things anyway, so nothing legitimate lost access.
@test "rm blocks the shared /var/folders tree" {
	for p in /var/folders /var/folders/zz /private/var/folders/zz; do
		TMPDIR=/var/folders/zz/session/T run "$WRAPPERS/rm.sh" -rf "$p"
		[ "$status" -eq 1 ]
		[[ "$output" == *BLOCKED* ]]
	done
}

# normalise() splits with `read`, which stops at the first newline, so a
# multi-line operand was validated on its first line and then handed to rm whole.
@test "rm blocks an operand containing a newline" {
	TMPDIR="$BATS_TEST_TMPDIR" run "$WRAPPERS/rm.sh" -f "$BATS_TEST_TMPDIR/x
/../../Users"
	[ "$status" -eq 1 ]
	[[ "$output" == *newline* ]]
}

# Same truncation on the root side: a newline in TMPDIR would register a root
# that is a prefix of paths nobody meant, so it is dropped rather than trusted.
@test "rm ignores a TMPDIR containing a newline" {
	touch "$BATS_TEST_TMPDIR/scratch"
	TMPDIR="$BATS_TEST_TMPDIR
/x" run "$WRAPPERS/rm.sh" -f "$BATS_TEST_TMPDIR/scratch"
	[ "$status" -eq 1 ]
	[[ "$output" == *BLOCKED* ]]
	[ -e "$BATS_TEST_TMPDIR/scratch" ]
}

# Registering "/" as a root would make every path on the machine contained.
@test "rm ignores a TMPDIR of /" {
	TMPDIR=/ run "$WRAPPERS/rm.sh" -rf "$HOME/work-this-path-must-never-be-removed"
	[ "$status" -eq 1 ]
	[[ "$output" == *BLOCKED* ]]
}

@test "rm allows /tmp and /private/tmp regardless of TMPDIR" {
	# /tmp is a symlink to /private/tmp and the wrapper normalises lexically, so
	# both spellings have to be listed as roots — and both are exercised here.
	# The test name claimed /private/tmp before it actually touched it.
	for root in /tmp /private/tmp; do
		scratch="$root/setup-wrapper-test.$$"
		touch "$scratch"
		TMPDIR=/var/folders/zz/unused run "$WRAPPERS/rm.sh" -f "$scratch"
		# Record the outcome, then clean up before asserting: a failed assertion
		# aborts the test and would otherwise leave the file behind in /tmp.
		removed=1
		if [ -e "$scratch" ]; then
			removed=0
			rm -f "$scratch"
		fi
		[ "$status" -eq 0 ]
		[ "$removed" -eq 1 ]
	done
}
