#!/usr/bin/env bats
# Coverage for the per-tool scripts in configure/.
#
# firefox.sh is the one with history. It used to find the profile directory with
# `find ... 2>/dev/null | head -n1`, and macOS withholds Firefox's profile data
# from a terminal without Full Disk Access while still letting the directory
# stat. So `-d` passed, find got EPERM, `2>/dev/null` swallowed the message,
# pipefail turned find's status into a failed command substitution, and errexit
# took the whole run down between step 9 and step 10 with nothing printed.
#
# Each branch is pinned below; the unreadable case is the regression test. The
# runner mirrors how run.sh sources these files — same shell options, same libs
# in scope — so a failure fails here the way it would in a real run.

load test_helper

CONFIGURE="$REPO_ROOT/configure"

setup() {
	FAKE_HOME="$BATS_TEST_TMPDIR/home"
	PROFILES="$FAKE_HOME/Library/Application Support/Firefox/Profiles"
	mkdir -p "$FAKE_HOME"

	RUNNER="$BATS_TEST_TMPDIR/run-firefox.sh"
	cat >"$RUNNER" <<-RUNNER_EOF
		#!/usr/bin/env bash
		set -euo pipefail
		export HOME="$FAKE_HOME"
		export DOTFILES="$REPO_ROOT/linked"
		source "$REPO_ROOT/lib/colors.sh"
		source "$REPO_ROOT/lib/backup.sh"
		source "$CONFIGURE/firefox.sh"
		echo "COMPLETED"
		echo "FIREFOX_NEEDS_SETUP=\${FIREFOX_NEEDS_SETUP:-}"
	RUNNER_EOF
	chmod +x "$RUNNER"
}

teardown() {
	# bats cannot clean up a 000 directory it did not create the contents of.
	[[ -d "$PROFILES" ]] && chmod u+rwx "$PROFILES"
	return 0
}

@test "firefox: no profile directory sets FIREFOX_NEEDS_SETUP" {
	run "$RUNNER"
	[ "$status" -eq 0 ]
	[[ "$output" == *COMPLETED* ]]
	[[ "$output" == *"FIREFOX_NEEDS_SETUP=1"* ]]
}

@test "firefox: an unreadable profile directory warns instead of aborting" {
	# The regression. Mode 000 reproduces what macOS privacy protection does:
	# the directory stats fine and every read of it fails.
	mkdir -p "$PROFILES"
	chmod 000 "$PROFILES"
	run "$RUNNER"
	[ "$status" -eq 0 ]
	[[ "$output" == *COMPLETED* ]]
	[[ "$(strip_ansi "$output")" == *"macOS is withholding access"* ]]
}

@test "firefox: an unreadable profile directory does not claim Firefox is unlaunched" {
	# FIREFOX_NEEDS_SETUP drives a "launch Firefox and re-run" reminder, which
	# would be misleading advice for a permissions problem.
	mkdir -p "$PROFILES"
	chmod 000 "$PROFILES"
	run "$RUNNER"
	[[ "$output" == *"FIREFOX_NEEDS_SETUP="* ]]
	[[ "$output" != *"FIREFOX_NEEDS_SETUP=1"* ]]
}

@test "firefox: a readable directory with no matching profile is skipped" {
	mkdir -p "$PROFILES"
	run "$RUNNER"
	[ "$status" -eq 0 ]
	[[ "$output" == *COMPLETED* ]]
	[[ "$(strip_ansi "$output")" == *"Could not find Firefox profile folder"* ]]
}

@test "firefox: links user.js into a matching profile" {
	mkdir -p "$PROFILES/abc123.dev-edition-default"
	run "$RUNNER"
	[ "$status" -eq 0 ]
	[[ "$output" == *COMPLETED* ]]
	[ -L "$PROFILES/abc123.dev-edition-default/user.js" ]
	[ "$(readlink "$PROFILES/abc123.dev-edition-default/user.js")" = "$REPO_ROOT/linked/user.js" ]
}

@test "firefox: several matching profiles pick one rather than expanding to many" {
	# What `| head -n1` was there for. A bare glob would have handed every match
	# to backup_or_delete as separate words.
	mkdir -p "$PROFILES/a.dev-edition-default" "$PROFILES/b.dev-edition-default"
	run "$RUNNER"
	[ "$status" -eq 0 ]
	[[ "$output" == *COMPLETED* ]]
	# `|| true` because ((links++)) returns the value *before* the increment, so
	# the first one evaluates 0 and reports failure.
	links=0
	for p in "$PROFILES"/*.dev-edition-default; do
		[[ -L "$p/user.js" ]] && { ((links++)) || true; }
	done
	[ "$links" -eq 1 ]
}

@test "firefox: leaves nullglob off for the steps sourced after it" {
	# This file is sourced into run.sh, so a stray `shopt -s nullglob` would
	# change how every later step expands an unmatched glob.
	mkdir -p "$PROFILES"
	cat >"$BATS_TEST_TMPDIR/check-nullglob.sh" <<-CHECK_EOF
		#!/usr/bin/env bash
		set -euo pipefail
		export HOME="$FAKE_HOME"
		export DOTFILES="$REPO_ROOT/linked"
		source "$REPO_ROOT/lib/colors.sh"
		source "$REPO_ROOT/lib/backup.sh"
		shopt -u nullglob
		source "$CONFIGURE/firefox.sh"
		shopt -q nullglob && echo "LEAKED" || echo "RESTORED"
	CHECK_EOF
	chmod +x "$BATS_TEST_TMPDIR/check-nullglob.sh"
	run "$BATS_TEST_TMPDIR/check-nullglob.sh"
	[ "$status" -eq 0 ]
	[[ "$output" == *RESTORED* ]]
}
