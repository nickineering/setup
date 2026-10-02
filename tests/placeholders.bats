#!/usr/bin/env bats
# Tests for the placeholder directories the GitLab sync leaves where a repo it
# has not cloned would go: the primitives in sync/placeholders.sh and the
# reconcile pass in sync/repos.sh.
#
# Each test gets a throwaway $HOME with an empty work/ in it, so the mirror
# layout ($HOME/work/<path>) is reproduced without touching real repos.

bats_require_minimum_version 1.5.0

load test_helper

setup() {
    # pwd -P resolves /var -> /private/var on macOS, which git reports. bats
    # creates and removes $BATS_TEST_TMPDIR itself, so no teardown is needed.
    TEST_DIR="$(cd "$BATS_TEST_TMPDIR" && pwd -P)"
    export HOME="$TEST_DIR"

    # Keep git away from the real user/system config, and off the signing key
    export GIT_CONFIG_GLOBAL="$TEST_DIR/.gitconfig"
    export GIT_CONFIG_NOSYSTEM=1
    printf '[user]\n\tname = Test\n\temail = test@example.com\n[commit]\n\tgpgsign = false\n[init]\n\tdefaultBranch = main\n' \
        >"$GIT_CONFIG_GLOBAL"

    WORK="$TEST_DIR/work"
    mkdir -p "$WORK"

    # repos.sh sources sync/placeholders.sh from $SETUP, and the placeholder
    # text names the group it would be cloned from
    export SETUP="$REPO_ROOT"
    export GITLAB_GROUP="acme"
    unset GITLAB_PLACEHOLDERS_ONLY

    source "$REPO_ROOT/sync/repos.sh"
}

# A repo cloned here, as far as the sync can tell: only the .git directory and
# the path it sits at are ever looked at.
_fake_clone() {
    mkdir -p "$WORK/$1/.git"
}

# ============================================
# recognising one
# ============================================

@test "_is_placeholder: true for one this sync wrote" {
    _write_placeholder "$WORK" "backend/api"
    run _is_placeholder "$WORK/backend/api"
    [[ "$status" -eq 0 ]]
}

@test "_is_placeholder: false for a .gitkeep a repo tracks itself" {
    # The name is a convention, so it cannot be the test on its own — a repo
    # keeping an empty directory of its own must never be read as scaffolding
    mkdir -p "$WORK/backend/api/logs"
    : >"$WORK/backend/api/logs/.gitkeep"
    run _is_placeholder "$WORK/backend/api/logs"
    [[ "$status" -ne 0 ]]
}

@test "_is_placeholder: false for a directory with nothing in it" {
    mkdir -p "$WORK/backend/api"
    run _is_placeholder "$WORK/backend/api"
    [[ "$status" -ne 0 ]]
}

@test "_dir_is_empty: hidden files count, and the tolerated name does not" {
    mkdir -p "$WORK/d"
    run _dir_is_empty "$WORK/d"
    [[ "$status" -eq 0 ]]
    : >"$WORK/d/.gitkeep"
    run _dir_is_empty "$WORK/d"
    [[ "$status" -ne 0 ]]
    run _dir_is_empty "$WORK/d" ".gitkeep"
    [[ "$status" -eq 0 ]]
}

@test "_dir_is_empty: a .DS_Store is not content" {
    # One look in Finder must not be able to wedge a placeholder path
    mkdir -p "$WORK/d"
    : >"$WORK/d/.DS_Store"
    run _dir_is_empty "$WORK/d"
    [[ "$status" -eq 0 ]]
}

# ============================================
# writing and removing
# ============================================

@test "_write_placeholder: creates the directory and says what it is" {
    run _write_placeholder "$WORK" "backend/api"
    [[ "$status" -eq 0 ]]
    [[ -f "$WORK/backend/api/.gitkeep" ]]
    run cat "$WORK/backend/api/.gitkeep"
    [[ "$output" == *"is on GitLab but is not cloned here"* ]]
    [[ "$output" == *"backend/api"* ]]
    # The two commands for taking it by hand, with this machine's own paths
    [[ "$output" == *"trash ~/work/backend/api/.gitkeep"* ]]
    [[ "$output" == *"glab repo clone acme/backend/api ~/work/backend/api"* ]]
}

@test "_write_placeholder: refuses a directory holding anything else" {
    mkdir -p "$WORK/backend/api"
    echo notes >"$WORK/backend/api/notes.md"
    run _write_placeholder "$WORK" "backend/api"
    [[ "$status" -ne 0 ]]
    [[ ! -e "$WORK/backend/api/.gitkeep" ]]
    [[ -f "$WORK/backend/api/notes.md" ]]
}

@test "_write_placeholder: writes over one that is already there" {
    _write_placeholder "$WORK" "backend/api"
    run _write_placeholder "$WORK" "backend/api"
    [[ "$status" -eq 0 ]]
    run _is_placeholder "$WORK/backend/api"
    [[ "$status" -eq 0 ]]
}

@test "_write_placeholder: refuses a .gitkeep that is not one of ours" {
    # Tolerating the name would both lose what is in it and make the file ours
    # to delete the day the repo leaves GitLab
    mkdir -p "$WORK/backend/api"
    echo 'mine' >"$WORK/backend/api/.gitkeep"
    run _write_placeholder "$WORK" "backend/api"
    [[ "$status" -ne 0 ]]
    run cat "$WORK/backend/api/.gitkeep"
    [[ "$output" == "mine" ]]
}

@test "_write_placeholder: a .DS_Store does not stop it" {
    mkdir -p "$WORK/backend/api"
    : >"$WORK/backend/api/.DS_Store"
    run _write_placeholder "$WORK" "backend/api"
    [[ "$status" -eq 0 ]]
    run _is_placeholder "$WORK/backend/api"
    [[ "$status" -eq 0 ]]
}

@test "_clear_placeholder: drops the file and keeps the directory" {
    _write_placeholder "$WORK" "backend/api"
    run _clear_placeholder "$WORK/backend/api"
    [[ "$status" -eq 0 ]]
    [[ ! -e "$WORK/backend/api/.gitkeep" ]]
    [[ -d "$WORK/backend/api" ]]
}

@test "_remove_placeholder: takes the directory with it" {
    _write_placeholder "$WORK" "backend/api"
    run _remove_placeholder "$WORK/backend/api"
    [[ "$status" -eq 0 ]]
    [[ ! -d "$WORK/backend/api" ]]
}

@test "_remove_placeholder: takes a .DS_Store with it" {
    _write_placeholder "$WORK" "backend/api"
    : >"$WORK/backend/api/.DS_Store"
    run _remove_placeholder "$WORK/backend/api"
    [[ "$status" -eq 0 ]]
    [[ ! -d "$WORK/backend/api" ]]
}

@test "_remove_placeholder: refuses a directory that is not a placeholder" {
    mkdir -p "$WORK/backend/api"
    run _remove_placeholder "$WORK/backend/api"
    [[ "$status" -ne 0 ]]
    [[ -d "$WORK/backend/api" ]]
}

@test "_remove_placeholder: refuses once something else is in there" {
    # Nothing goes if everything cannot, so half a directory is never lost
    _write_placeholder "$WORK" "backend/api"
    echo notes >"$WORK/backend/api/notes.md"
    run _remove_placeholder "$WORK/backend/api"
    [[ "$status" -ne 0 ]]
    [[ -f "$WORK/backend/api/.gitkeep" ]]
    [[ -f "$WORK/backend/api/notes.md" ]]
}

# ============================================
# reconciling against GitLab
# ============================================

@test "_reconcile_placeholders: mirrors the repos that are not cloned" {
    export GITLAB_PLACEHOLDERS_ONLY=1
    _fake_clone "backend/api"
    run _reconcile_placeholders "$WORK" \
        "$(printf 'backend/api\nbackend/billing\nweb/site')" "backend/api" ""
    [[ "$status" -eq 0 ]]
    [[ -f "$WORK/backend/billing/.gitkeep" ]]
    [[ -f "$WORK/web/site/.gitkeep" ]]
    # Never into a repo that is cloned here
    [[ ! -e "$WORK/backend/api/.gitkeep" ]]
    strip_ansi "$output" | grep -q 'Added 2 placeholder'
}

@test "_reconcile_placeholders: writes nothing while the setting is off" {
    run _reconcile_placeholders "$WORK" "backend/billing" "" ""
    [[ "$status" -eq 0 ]]
    [[ ! -d "$WORK/backend" ]]
    strip_ansi "$output" | grep -q 'None'
}

@test "_reconcile_placeholders: clears one whose repo has been cloned since" {
    # Cloning a repo by hand is all it takes to start syncing it
    _write_placeholder "$WORK" "backend/api"
    _fake_clone "backend/api"
    run _reconcile_placeholders "$WORK" "backend/api" "backend/api" "backend/api"
    [[ "$status" -eq 0 ]]
    [[ ! -e "$WORK/backend/api/.gitkeep" ]]
    [[ -d "$WORK/backend/api" ]]
    strip_ansi "$output" | grep -q 'Cleared 1 placeholder'
}

@test "_reconcile_placeholders: clears one even with the setting on" {
    export GITLAB_PLACEHOLDERS_ONLY=1
    _write_placeholder "$WORK" "backend/api"
    _fake_clone "backend/api"
    run _reconcile_placeholders "$WORK" "backend/api" "backend/api" "backend/api"
    [[ "$status" -eq 0 ]]
    [[ ! -e "$WORK/backend/api/.gitkeep" ]]
    # And it is not written straight back, having been counted as cloned
    local clean
    clean="$(strip_ansi "$output")"
    [[ "$clean" == *"Cleared 1 placeholder"* ]]
    [[ "$clean" != *"Added"* ]]
}

@test "_reconcile_placeholders: removes one whose repo has left GitLab" {
    _write_placeholder "$WORK" "backend/old/thing"
    run _reconcile_placeholders "$WORK" "web/site" "" "backend/old/thing"
    [[ "$status" -eq 0 ]]
    [[ ! -d "$WORK/backend/old/thing" ]]
    # Its empty parents go with it, but never the mirror root
    [[ ! -d "$WORK/backend" ]]
    [[ -d "$WORK" ]]
    strip_ansi "$output" | grep -q 'Removed 1 placeholder'
}

@test "_reconcile_placeholders: keeps one whose repo is still on GitLab" {
    export GITLAB_PLACEHOLDERS_ONLY=1
    _write_placeholder "$WORK" "backend/billing"
    run _reconcile_placeholders "$WORK" "backend/billing" "" "backend/billing"
    [[ -f "$WORK/backend/billing/.gitkeep" ]]
    strip_ansi "$output" | grep -q 'None'
}

@test "_reconcile_placeholders: leaves a .gitkeep a repo tracks alone" {
    _fake_clone "backend/api"
    mkdir -p "$WORK/backend/api/logs"
    : >"$WORK/backend/api/logs/.gitkeep"
    # The finder offers it as a candidate; only _is_placeholder rules it out
    run _reconcile_placeholders "$WORK" "backend/api" "backend/api" "backend/api/logs"
    [[ "$status" -eq 0 ]]
    [[ -f "$WORK/backend/api/logs/.gitkeep" ]]
    strip_ansi "$output" | grep -q 'None'
}

@test "_reconcile_placeholders: reports a path it will not write over" {
    export GITLAB_PLACEHOLDERS_ONLY=1
    mkdir -p "$WORK/backend/billing"
    echo notes >"$WORK/backend/billing/notes.md"
    run _reconcile_placeholders "$WORK" "backend/billing" "" ""
    [[ "$status" -eq 0 ]]
    [[ ! -e "$WORK/backend/billing/.gitkeep" ]]
    [[ -f "$WORK/backend/billing/notes.md" ]]
    strip_ansi "$output" | grep -q 'Left alone'
    strip_ansi "$output" | grep -q 'backend/billing'
}

@test "_reconcile_placeholders: reports a path it will not remove" {
    _write_placeholder "$WORK" "backend/old"
    echo notes >"$WORK/backend/old/notes.md"
    run _reconcile_placeholders "$WORK" "web/site" "" "backend/old"
    [[ "$status" -eq 0 ]]
    [[ -f "$WORK/backend/old/.gitkeep" ]]
    [[ -f "$WORK/backend/old/notes.md" ]]
    strip_ansi "$output" | grep -q 'Left alone'
}

# ============================================
# the clone path
# ============================================

@test "clone path: a placeholder has to go before a clone can land on it" {
    # Which is what sync/clone_repo.sh clears it for
    git init --bare --quiet "$TEST_DIR/origin.git"
    _write_placeholder "$WORK" "backend/api"
    run git clone --quiet "$TEST_DIR/origin.git" "$WORK/backend/api"
    [[ "$status" -ne 0 ]]
    _remove_placeholder "$WORK/backend/api"
    run git clone --quiet "$TEST_DIR/origin.git" "$WORK/backend/api"
    [[ "$status" -eq 0 ]]
}

# Stand in for glab on $PATH, so the clone path can be driven without an
# instance to clone from: $1=SHELL_BODY, run with glab's own arguments, where
# $3 is <group>/<repo> and $4 the destination.
_stub_glab() {
    mkdir -p "$TEST_DIR/bin"
    printf '#!/opt/homebrew/bin/bash\n%s\n' "$1" >"$TEST_DIR/bin/glab"
    chmod +x "$TEST_DIR/bin/glab"
    PATH="$TEST_DIR/bin:$PATH"
}

@test "clone_repo.sh: takes over the placeholder it clones in place of" {
    # The whole point of turning the setting off again: every placeholder is
    # replaced by the real repo, with nothing of itself left behind
    git init --bare --quiet "$TEST_DIR/origin.git"
    _stub_glab "exec git clone --quiet '$TEST_DIR/origin.git' \"\$4\""
    _write_placeholder "$WORK" "backend/api"
    run "$REPO_ROOT/sync/clone_repo.sh" "backend/api" "$WORK" "acme"
    [[ "$status" -eq 0 ]]
    [[ -d "$WORK/backend/api/.git" ]]
    [[ ! -e "$WORK/backend/api/.gitkeep" ]]
}

@test "clone_repo.sh: a .DS_Store beside the marker does not block the clone" {
    # Left as content, this would fail the clone on "not an empty directory"
    # every run, with nothing in the error summary pointing at the cause
    git init --bare --quiet "$TEST_DIR/origin.git"
    _stub_glab "exec git clone --quiet '$TEST_DIR/origin.git' \"\$4\""
    _write_placeholder "$WORK" "backend/api"
    : >"$WORK/backend/api/.DS_Store"
    run "$REPO_ROOT/sync/clone_repo.sh" "backend/api" "$WORK" "acme"
    [[ "$status" -eq 0 ]]
    [[ -d "$WORK/backend/api/.git" ]]
    [[ ! -e "$WORK/backend/api/.gitkeep" ]]
}

@test "clone_repo.sh: a clone that fails takes the placeholder with it" {
    # The placeholder has to go before the clone can be attempted, so a repo
    # that cannot be cloned is left with neither. The error summary is what
    # reports it, and the next run tries again.
    _stub_glab "echo \"fatal: could not read Username for 'https://gitlab'\" >&2; exit 1"
    _write_placeholder "$WORK" "backend/api"
    run "$REPO_ROOT/sync/clone_repo.sh" "backend/api" "$WORK" "acme"
    [[ "$status" -ne 0 ]]
    [[ ! -d "$WORK/backend/api" ]]
    [[ "$output" == *"backend/api: no credential for the clone host"* ]]
}
