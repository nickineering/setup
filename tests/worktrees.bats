#!/usr/bin/env bats
# Tests for the worktree helpers in linked/git_functions.sh and for worktree
# handling in the repo sync.
#
# Each test gets a throwaway $HOME containing a bare "origin" and a clone at
# work/backend/pocs/demo, so the mirror layout ($HOME/work/<path>, worktrees in
# $HOME/work/.worktrees/<path>/<slug>) is reproduced without touching real repos.

bats_require_minimum_version 1.5.0

load test_helper

setup() {
    # pwd -P resolves /var -> /private/var on macOS. git reports physical paths,
    # so an unresolved $HOME would make every "is this under ~/work" check fail.
    # bats creates and removes $BATS_TEST_TMPDIR itself. mktemp -d is blocked in
    # Claude sessions, and no teardown means no rm for the wrapper to refuse.
    TEST_DIR="$(cd "$BATS_TEST_TMPDIR" && pwd -P)"
    export HOME="$TEST_DIR"

    # Keep git away from the real user/system config, and off the signing key
    export GIT_CONFIG_GLOBAL="$TEST_DIR/.gitconfig"
    export GIT_CONFIG_NOSYSTEM=1
    printf '[user]\n\tname = Test\n\temail = test@example.com\n[commit]\n\tgpgsign = false\n[init]\n\tdefaultBranch = main\n' \
        >"$GIT_CONFIG_GLOBAL"

    ORIGIN="$TEST_DIR/origin/demo.git"
    git init --bare --quiet "$ORIGIN"

    REPO="$TEST_DIR/work/backend/pocs/demo"
    WTROOT="$TEST_DIR/work/.worktrees"
    WT="$WTROOT/backend/pocs/demo"
    mkdir -p "$(dirname "$REPO")"
    git clone --quiet "$ORIGIN" "$REPO" 2>/dev/null
    cd "$REPO" || return 1
    echo hi >README.md
    git add README.md
    git commit --quiet -m 'initial'
    git push --quiet -u origin main

    # git_functions.sh sources lib/git.sh from $SETUP, and sync_repo.sh runs as a
    # subprocess, so it has to be exported rather than just set
    export SETUP="$REPO_ROOT"

    source "$REPO_ROOT/linked/git_functions.sh"
}

# A worktree in the mirror layout sync_repo.sh scans, for BRANCH.
#
# --no-track: an upstream of origin/main would make every branch measurable,
# and three of the tests below turn on the sync meeting one it cannot measure.
mk_worktree() {
    local branch="$1" slug dir
    slug=${branch//\//-}
    dir="$WT/$slug"
    git -C "$REPO" worktree add --quiet --no-track -b "$branch" "$dir" origin/main >/dev/null 2>&1 ||
        git -C "$REPO" worktree add --quiet "$dir" "$branch" >/dev/null 2>&1 ||
        return 1
    printf '%s' "$dir"
}


# ============================================
# base refs and creation
# ============================================

@test "_wt_base: follows origin/HEAD, the ref Claude Code cuts from" {
    git push --quiet origin main:develop
    git fetch --quiet origin
    git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main
    run _wt_base
    [[ "$output" == "main" ]]
}

@test "_wt_base: falls back to the guess when origin/HEAD is unset" {
    git push --quiet origin main:develop
    git fetch --quiet origin
    git symbolic-ref -d refs/remotes/origin/HEAD 2>/dev/null || true
    run _wt_base
    [[ "$output" == "develop" ]]
}

@test "wt_create: uses Claude Code's layout" {
    run --separate-stderr wt_create agent-one
    [[ "$status" -eq 0 ]]
    [[ "$output" == "$REPO/.claude/worktrees/agent-one" ]]
    [[ -d "$output" ]]
    run git -C "$REPO/.claude/worktrees/agent-one" branch --show-current
    [[ "$output" == "agent-one" ]]
}

@test "wt_create: a slashed name nests inside the worktrees directory" {
    run --separate-stderr wt_create feat/thing
    [[ "$status" -eq 0 ]]
    [[ "$output" == "$REPO/.claude/worktrees/feat/thing" ]]
}

@test "wt_create: stdout is only the path, progress goes to stderr" {
    run --separate-stderr wt_create agent-one
    [[ "$output" == "$REPO/.claude/worktrees/agent-one" ]]
    [[ "$stderr" == *"cut from"* ]]
}

@test "wt_create: cuts from the remote default, with no upstream to push to" {
    path=$(wt_create agent-one)
    run git -C "$path" rev-parse HEAD
    [[ "$output" == "$(git -C "$REPO" rev-parse origin/main)" ]]
    run git -C "$path" rev-parse --abbrev-ref --symbolic-full-name '@{upstream}'
    [[ "$status" -ne 0 ]]
}

@test "wt_create: reuse is idempotent" {
    wt_create agent-one >/dev/null
    run --separate-stderr wt_create agent-one
    [[ "$status" -eq 0 ]]
    [[ "$output" == "$REPO/.claude/worktrees/agent-one" ]]
    [[ "$stderr" == *"Reusing"* ]]
}

@test "wt_create: from inside a worktree, lands beside it and not nested in it" {
    cd "$(wt_create agent-one)"
    run --separate-stderr wt_create agent-two
    [[ "$output" == "$REPO/.claude/worktrees/agent-two" ]]
}

@test "wt_create: refuses a name that would climb out" {
    run wt_create '../escape'
    [[ "$status" -eq 1 ]]
    run wt_create '..'
    [[ "$status" -eq 1 ]]
    run wt_create 'a/../../b'
    [[ "$status" -eq 1 ]]
    [[ ! -e "$TEST_DIR/work/backend/pocs/escape" ]]
}

@test "wt_create: refuses a name with characters Claude Code would not accept" {
    run wt_create 'feat thing'
    [[ "$status" -eq 1 ]]
    run wt_create 'feat;rm'
    [[ "$status" -eq 1 ]]
}

@test "wt_create: needs a name" {
    run wt_create
    [[ "$status" -eq 1 ]]
    [[ "$output" == *"Usage"* ]]
}

@test "wt_create: the worktree it makes is invisible to the repo scan" {
    wt_create agent-one >/dev/null
    # A linked worktree's .git is a file, and the scan matches directories only
    [[ -f "$REPO/.claude/worktrees/agent-one/.git" ]]
    run bash -c 'fd --type d --hidden "^\.git\$" "$1" | sed -E "s|/\.git/?\$||"' _ "$TEST_DIR/work"
    [[ "$output" == "$REPO" ]]
}

@test "git_default_branch: prefers develop over main" {
    git push --quiet origin main:develop
    git fetch --quiet origin
    run git_default_branch
    [[ "$output" == "develop" ]]
}

@test "git_default_branch: accepts a directory argument" {
    run git_default_branch "$REPO"
    [[ "$output" == "main" ]]
}

# ============================================
# sync parity
# ============================================

# Point a worktree branch at a remote branch that no longer exists
_orphan_upstream() {
    git -C "$REPO" update-ref refs/remotes/origin/ghost HEAD
    git -C "$1" branch --set-upstream-to=origin/ghost >/dev/null 2>&1
    git -C "$REPO" update-ref -d refs/remotes/origin/ghost
}

@test "sync_repo: reports a live worktree as active work" {
    path=$(mk_worktree 'feat/live')
    stale_dir="$TEST_DIR/stale"
    active_dir="$TEST_DIR/active"
    mkdir -p "$stale_dir" "$active_dir"
    SETUP="$REPO_ROOT" run "$REPO_ROOT/sync/sync_repo.sh" \
        "$REPO" "$TEST_DIR/work" "$stale_dir" "$active_dir"
    [[ "$status" -eq 0 ]]
    run cat "$active_dir"/*
    # Third field carries the dirty/unpushed flags, empty for an untouched worktree
    [[ "$output" == "backend/pocs/demo:feat/live::$path" ]]
}

@test "sync_repo: a stale worktree branch records its worktree path" {
    path=$(mk_worktree 'feat/dead')
    _orphan_upstream "$path"
    stale_dir="$TEST_DIR/stale"
    active_dir="$TEST_DIR/active"
    mkdir -p "$stale_dir" "$active_dir"
    SETUP="$REPO_ROOT" run "$REPO_ROOT/sync/sync_repo.sh" \
        "$REPO" "$TEST_DIR/work" "$stale_dir" "$active_dir"
    [[ "$status" -eq 0 ]]
    run cat "$stale_dir"/*
    # The "+" marker git uses for worktree branches must not leak into the name
    [[ "$output" == "backend/pocs/demo:feat/dead:$path" ]]
}

@test "sync_repo: a stale worktree is not also listed as active" {
    path=$(mk_worktree 'feat/dead')
    _orphan_upstream "$path"
    stale_dir="$TEST_DIR/stale"
    active_dir="$TEST_DIR/active"
    mkdir -p "$stale_dir" "$active_dir"
    SETUP="$REPO_ROOT" "$REPO_ROOT/sync/sync_repo.sh" \
        "$REPO" "$TEST_DIR/work" "$stale_dir" "$active_dir" >/dev/null
    run bash -c 'cat "$1"/* 2>/dev/null || true' _ "$active_dir"
    [[ "$output" != *"feat/dead"* ]]
}

# Run the sync with every reporting directory it takes, in $stale_dir, $active_dir
# and $stale_wt_dir
_sync_repo() {
    stale_dir="$TEST_DIR/stale"
    active_dir="$TEST_DIR/active"
    stale_wt_dir="$TEST_DIR/stale-wt"
    mkdir -p "$stale_dir" "$active_dir" "$stale_wt_dir"
    SETUP="$REPO_ROOT" "$REPO_ROOT/sync/sync_repo.sh" \
        "$REPO" "$TEST_DIR/work" "$stale_dir" "$active_dir" "$stale_wt_dir" >/dev/null
}

# Contents of a reporting directory, empty string when nothing was written
_reported() {
    cat "$1"/* 2>/dev/null || true
}

# Land $1=BRANCH on origin/main the way a fast-forward merge request would,
# leaving the remote branch in place so it is merged rather than gone
_merge_upstream() {
    git -C "$1" push --quiet -u origin HEAD
    git -C "$1" push --quiet origin HEAD:main
}

# Move origin/main on by one commit from a throwaway clone
_advance_main() {
    git clone --quiet "$ORIGIN" "$TEST_DIR/scratch-$1" 2>/dev/null
    echo "$1" >"$TEST_DIR/scratch-$1/$1.txt"
    git -C "$TEST_DIR/scratch-$1" add .
    git -C "$TEST_DIR/scratch-$1" commit --quiet -m "advance $1"
    git -C "$TEST_DIR/scratch-$1" push --quiet origin main
}

@test "sync_repo: a merged worktree is offered for deletion" {
    path=$(mk_worktree 'feat/done')
    echo work >"$path/work.txt"
    git -C "$path" add work.txt
    git -C "$path" commit --quiet -m 'work'
    _merge_upstream "$path"
    _sync_repo
    run _reported "$stale_wt_dir"
    [[ "$output" == "merged:backend/pocs/demo:feat/done:$path" ]]
    # ...and not also reported as work still in progress
    run _reported "$active_dir"
    [[ "$output" != *"feat/done"* ]]
}

@test "sync_repo: a worktree the base moved past is offered as having no commits" {
    path=$(mk_worktree 'feat/idle')
    _advance_main idle
    _sync_repo
    run _reported "$stale_wt_dir"
    [[ "$output" == "no-commits:backend/pocs/demo:feat/idle:$path" ]]
}

@test "sync_repo: an untouched worktree at the base is left alone" {
    # A worktree cut from the current base and not used yet is waiting for work,
    # not finished with it
    path=$(mk_worktree 'feat/fresh')
    _sync_repo
    run _reported "$stale_wt_dir"
    [[ -z "$output" ]]
    run _reported "$active_dir"
    [[ "$output" == "backend/pocs/demo:feat/fresh::$path" ]]
}

@test "sync_repo: a dirty worktree is reported, never offered" {
    path=$(mk_worktree 'feat/dirty')
    echo work >"$path/work.txt"
    git -C "$path" add work.txt
    git -C "$path" commit --quiet -m 'work'
    _merge_upstream "$path"
    echo scratch >"$path/uncommitted.txt"
    _sync_repo
    run _reported "$stale_wt_dir"
    [[ -z "$output" ]]
    run _reported "$active_dir"
    [[ "$output" == "backend/pocs/demo:feat/dirty:dirty:$path" ]]
}

@test "sync_repo: an unpushed worktree is reported, never offered" {
    path=$(mk_worktree 'feat/unpushed')
    echo work >"$path/work.txt"
    git -C "$path" add work.txt
    git -C "$path" commit --quiet -m 'work'
    _sync_repo
    run _reported "$stale_wt_dir"
    [[ -z "$output" ]]
    run _reported "$active_dir"
    [[ "$output" == "backend/pocs/demo:feat/unpushed:+1:$path" ]]
}

@test "sync_repo: a worktree with nothing to measure against is flagged, not offered" {
    path=$(mk_worktree 'feat/unmeasurable')
    echo work >"$path/work.txt"
    git -C "$path" add work.txt
    git -C "$path" commit --quiet -m 'work'
    # No upstream, and a base that was never fetched: the commit above cannot be
    # counted, which must not read as "nothing to lose"
    git -C "$REPO" config worktree.base never-fetched
    _sync_repo
    run _reported "$stale_wt_dir"
    [[ -z "$output" ]]
    run _reported "$active_dir"
    [[ "$output" == "backend/pocs/demo:feat/unmeasurable:unpushed?:$path" ]]
}

@test "sync_repo: a worktree outside the mirror is never offered" {
    # Only the mirror's own tree is the sync's to delete
    git -C "$REPO" worktree add --quiet --track -b side "$TEST_DIR/manual" origin/main
    _advance_main side
    _sync_repo
    run _reported "$stale_wt_dir"
    [[ -z "$output" ]]
    run _reported "$active_dir"
    [[ "$output" == *"backend/pocs/demo:side:"* ]]
}

@test "sync_repo: prunes worktrees whose directory was deleted by hand" {
    path=$(mk_worktree 'feat/gone')
    # The whole point is a directory removed outside git's knowledge, so this one
    # test really does need rm. /bin/rm skips the PATH wrapper; the target is
    # inside $BATS_TEST_TMPDIR, which the sandbox allows.
    /bin/rm -rf "$path"
    SETUP="$REPO_ROOT" "$REPO_ROOT/sync/sync_repo.sh" "$REPO" "$TEST_DIR/work" >/dev/null
    run git -C "$REPO" worktree list
    [[ "$output" != *"feat-gone"* ]]
}

@test "sync_repo: fast-forwards a default branch stuck in a worktree" {
    # git wt refuses this, so it can only happen via a manual worktree add. The
    # sync must still advance the branch rather than silently skipping it.
    git push --quiet origin main:develop
    git fetch --quiet origin
    git -C "$REPO" worktree add --quiet --track -b develop "$TEST_DIR/dev-wt" origin/develop
    # Advance origin/develop by one commit from a scratch clone
    git clone --quiet "$ORIGIN" "$TEST_DIR/scratch" 2>/dev/null
    git -C "$TEST_DIR/scratch" checkout --quiet develop
    echo next >"$TEST_DIR/scratch/next.txt"
    git -C "$TEST_DIR/scratch" add next.txt
    git -C "$TEST_DIR/scratch" commit --quiet -m 'advance develop'
    git -C "$TEST_DIR/scratch" push --quiet origin develop

    SETUP="$REPO_ROOT" "$REPO_ROOT/sync/sync_repo.sh" "$REPO" "$TEST_DIR/work" >/dev/null
    run git -C "$TEST_DIR/dev-wt" rev-parse HEAD
    [[ "$output" == "$(git -C "$REPO" rev-parse origin/develop)" ]]
}

# ============================================
# repos.sh helpers
# ============================================

@test "_prune_empty_parents: stops at the worktree root" {
    source "$REPO_ROOT/sync/repos.sh"
    mkdir -p "$WT/feat-thing"
    _prune_empty_parents "$WT/feat-thing" "$WTROOT"
    # feat-thing itself is the caller's to remove; its empty parents go
    rmdir "$WT/feat-thing"
    _prune_empty_parents "$WT/feat-thing" "$WTROOT"
    [[ ! -d "$WTROOT/backend" ]]
    [[ -d "$WTROOT" ]]
    [[ -d "$TEST_DIR/work" ]]
}

@test "_prune_empty_parents: leaves non-empty parents alone" {
    source "$REPO_ROOT/sync/repos.sh"
    mkdir -p "$WT/feat-a" "$WT/feat-b"
    rmdir "$WT/feat-a"
    _prune_empty_parents "$WT/feat-a" "$WTROOT"
    [[ -d "$WT/feat-b" ]]
}

@test "_stale_worktree_dirs: leaves a live worktree alone" {
    source "$REPO_ROOT/sync/repos.sh"
    mk_worktree 'feat/live' >/dev/null
    run _stale_worktree_dirs "$WTROOT" "$TEST_DIR/work"
    [[ -z "$output" ]]
}

@test "_stale_worktree_dirs: reports scaffolding an untracked file kept alive" {
    # The real case: `git wt-rm` left the directory because something untracked
    # was sitting in it, so no worktree is registered but the tree is not empty
    source "$REPO_ROOT/sync/repos.sh"
    mkdir -p "$WT/feat-leftover"
    echo notes >"$WT/feat-leftover/scratch.code-workspace"
    run _stale_worktree_dirs "$WTROOT" "$TEST_DIR/work"
    [[ "$output" == "orphan:::$WT/feat-leftover" ]]
}

@test "_stale_worktree_dirs: a slug that matches a directory in the clone is safe" {
    # Branch slugs collide with ordinary directory names, so a walk that matched
    # them against ~/work would descend into this live checkout and offer its own
    # tracked source for deletion
    source "$REPO_ROOT/sync/repos.sh"
    mkdir "$REPO/docs"
    echo d >"$REPO/docs/readme.md"
    git -C "$REPO" add docs
    git -C "$REPO" commit --quiet -m 'add docs'
    path=$(mk_worktree 'docs')
    mkdir "$path/emptydir"
    run _stale_worktree_dirs "$WTROOT" "$TEST_DIR/work"
    [[ -z "$output" ]]
    # Not even the empty directories inside it, which go without a prompt
    [[ -d "$path/emptydir" ]]
}

@test "_stale_worktree_dirs: keeps the worktrees of a clone nested in the tree" {
    # GitLab cannot serve a project and a group at one path, but a repo cloned by
    # hand under another's path still owns real worktrees
    source "$REPO_ROOT/sync/repos.sh"
    nested="$TEST_DIR/work/backend/pocs/demo/vendor"
    git clone --quiet "$ORIGIN" "$nested" 2>/dev/null
    cd "$nested"
    mk_worktree 'feat/vendored' >/dev/null
    run _stale_worktree_dirs "$WTROOT" "$TEST_DIR/work"
    [[ -z "$output" ]]
}

@test "_stale_worktree_dirs: reports a repo directory with no worktrees left in it" {
    # The leftovers sit beside the removed worktree rather than inside it, which
    # is how an editor workspace file keeps a whole repo's directory alive
    source "$REPO_ROOT/sync/repos.sh"
    mkdir -p "$WT"
    echo notes >"$WT/demo.code-workspace"
    run _stale_worktree_dirs "$WTROOT" "$TEST_DIR/work"
    [[ "$output" == "leftover:::$WT" ]]
}

@test "_stale_worktree_dirs: a live worktree keeps its repo directory" {
    source "$REPO_ROOT/sync/repos.sh"
    mk_worktree 'feat/live' >/dev/null
    echo notes >"$WT/demo.code-workspace"
    run _stale_worktree_dirs "$WTROOT" "$TEST_DIR/work"
    [[ -z "$output" ]]
}

@test "_stale_worktree_dirs: reports a worktree whose clone is gone" {
    # What a re-clone leaves behind: the .git file points at admin data that the
    # new clone knows nothing about
    source "$REPO_ROOT/sync/repos.sh"
    mkdir -p "$WT/feat-broken"
    printf 'gitdir: %s\n' "$REPO/.git/worktrees/feat-broken" >"$WT/feat-broken/.git"
    run _stale_worktree_dirs "$WTROOT" "$TEST_DIR/work"
    [[ "$output" == "orphan:::$WT/feat-broken" ]]
}

@test "_stale_worktree_dirs: reports a repo that is no longer cloned" {
    source "$REPO_ROOT/sync/repos.sh"
    mkdir -p "$WTROOT/backend/pocs/deleted/feat-x"
    echo stuff >"$WTROOT/backend/pocs/deleted/feat-x/file.txt"
    run _stale_worktree_dirs "$WTROOT" "$TEST_DIR/work"
    # One prompt for the whole subtree, and never a walk into its contents
    [[ "$output" == "repo-gone:::$WTROOT/backend/pocs/deleted" ]]
}

@test "_stale_worktree_dirs: a placeholder is not a group on the way to a clone" {
    # With GITLAB_PLACEHOLDERS_ONLY set, an uncloned repo still has a directory
    # in ~/work. Reading it as a group would walk past it into worktrees whose
    # clone is not there, and report each of them instead of the repo once
    source "$REPO_ROOT/sync/repos.sh"
    _write_placeholder "$TEST_DIR/work" "backend/pocs/shelved"
    mkdir -p "$WTROOT/backend/pocs/shelved/feat-x"
    echo stuff >"$WTROOT/backend/pocs/shelved/feat-x/file.txt"
    run _stale_worktree_dirs "$WTROOT" "$TEST_DIR/work"
    [[ "$output" == "repo-gone:::$WTROOT/backend/pocs/shelved" ]]
}

@test "_stale_worktree_dirs: removes empty scaffolding without asking" {
    source "$REPO_ROOT/sync/repos.sh"
    mkdir -p "$WT/feat-empty"
    run _stale_worktree_dirs "$WTROOT" "$TEST_DIR/work"
    [[ -z "$output" ]]
    [[ ! -d "$WT/feat-empty" ]]
    # Its now-empty parents go with it, but never the root itself
    [[ ! -d "$WTROOT/backend" ]]
    [[ -d "$WTROOT" ]]
}

@test "_stale_worktree_dirs: ignores a full clone under the worktree tree" {
    source "$REPO_ROOT/sync/repos.sh"
    git clone --quiet "$ORIGIN" "$WT/interloper" 2>/dev/null
    run _stale_worktree_dirs "$WTROOT" "$TEST_DIR/work"
    [[ -z "$output" ]]
    [[ -d "$WT/interloper/.git" ]]
}

@test "repo scan: excludes the worktree tree" {
    mk_worktree 'feat/thing' >/dev/null
    # Mirrors the _find_repos pipeline in sync/repos.sh, so a worktree can never
    # be mistaken for a repo GitLab has never heard of and offered for deletion
    run bash -c 'fd --type d --hidden "^\.git\$" "$1" --exclude .worktrees | sed -E "s|/\.git/?\$||"' _ "$TEST_DIR/work"
    [[ "$output" == "$REPO" ]]
}

@test "stale deletion order: branch is deletable only after the worktree goes" {
    path=$(mk_worktree 'feat/thing')
    run git -C "$REPO" branch -D 'feat/thing'
    [[ "$status" -ne 0 ]]
    git -C "$REPO" worktree remove --force "$path"
    run git -C "$REPO" branch -D 'feat/thing'
    [[ "$status" -eq 0 ]]
}

# ============================================
# GIT_DIR leakage
# ============================================

@test "sourcing clears GIT_DIR so git -C is not overridden" {
    # A `!` git alias runs with GIT_DIR exported. Inside a linked worktree that
    # value is absolute, and GIT_DIR in the environment beats `git -C` — so
    # every `git -C "$other" ...` in this file acted on the invoking worktree
    # instead of the directory named. `git wt-diff trunk` then answered about
    # the wrong repository while printing the right path.
    GIT_DIR=/some/absolute/.git/worktrees/whatever
    GIT_WORK_TREE=/some/absolute
    GIT_INDEX_FILE=/some/absolute/.git/index
    export GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE

    # shellcheck source=/dev/null
    source "$REPO_ROOT/linked/git_functions.sh"

    [[ -z "${GIT_DIR:-}" ]]
    [[ -z "${GIT_WORK_TREE:-}" ]]
    [[ -z "${GIT_INDEX_FILE:-}" ]]
}

@test "git -C reaches the directory named once GIT_DIR is cleared" {
    # The observable consequence: with GIT_DIR set to one repo, asking another
    # for its branch returned the first one's.
    other="$BATS_TEST_TMPDIR/other"
    mkdir -p "$other"
    git -C "$other" init -q -b other-branch .
    git -C "$other" -c user.email=a@b -c user.name=a commit -q --allow-empty -m x

    GIT_DIR="$REPO/.git"
    export GIT_DIR
    # shellcheck source=/dev/null
    source "$REPO_ROOT/linked/git_functions.sh"

    run git -C "$other" branch --show-current
    [[ "$output" == "other-branch" ]]
}
