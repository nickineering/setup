#!/usr/bin/env bats
# Tests for the worktree helpers in linked/git_functions.sh, the Claude Code
# WorktreeCreate/WorktreeRemove hooks, and worktree handling in the repo sync.
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

    # The hooks source git_functions.sh by absolute path under $HOME, so mirror
    # that layout too — this also asserts that assumption still holds.
    mkdir -p "$TEST_DIR/projects/setup/linked"
    ln -s "$REPO_ROOT/linked/git_functions.sh" \
        "$TEST_DIR/projects/setup/linked/git_functions.sh"
    HOOKS="$REPO_ROOT/linked/claude/hooks"

    # git_functions.sh sources lib/git.sh from $SETUP, and the hooks run as
    # subprocesses, so it has to be exported rather than just set
    export SETUP="$REPO_ROOT"

    source "$REPO_ROOT/linked/git_functions.sh"
}


# Drive the WorktreeCreate hook with the payload Claude Code sends.
# $1=NAME, $2=CWD / default=the demo repo
_hook_create() {
    printf '{"session_id":"s1","transcript_path":"/tmp/t.jsonl","cwd":"%s","permission_mode":"default","hook_event_name":"WorktreeCreate","name":"%s"}' \
        "${2:-$REPO}" "$1" | "$HOOKS/worktree-create.sh"
}

# Drive the WorktreeRemove hook. $1=WORKTREE_PATH, $2=CWD / default=the demo repo
_hook_remove() {
    printf '{"session_id":"s1","transcript_path":"/tmp/t.jsonl","cwd":"%s","permission_mode":"default","hook_event_name":"WorktreeRemove","worktree_path":"%s"}' \
        "${2:-$REPO}" "$1" | "$HOOKS/worktree-remove.sh"
}

# ============================================
# path math
# ============================================

@test "_wt_slug: replaces slashes with dashes" {
    run _wt_slug 'feat/some/thing'
    [[ "$output" == "feat-some-thing" ]]
}

@test "_wt_repo_rel: repo path relative to the mirror root" {
    run _wt_repo_rel
    [[ "$status" -eq 0 ]]
    [[ "$output" == "backend/pocs/demo" ]]
}

@test "_wt_repo_rel: fails outside the mirror" {
    mkdir -p "$TEST_DIR/elsewhere"
    cd "$TEST_DIR/elsewhere"
    git init --quiet .
    run _wt_repo_rel
    [[ "$status" -ne 0 ]]
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
# wt_create
# ============================================

@test "wt_create: mirrors the repo path under .worktrees" {
    run wt_create 'feat/thing'
    [[ "$status" -eq 0 ]]
    [[ "$output" == "$WT/feat-thing" ]]
    [[ -d "$WT/feat-thing" ]]
}

@test "wt_create: leaves the main clone on its default branch" {
    wt_create 'feat/thing' >/dev/null
    run git -C "$REPO" branch --show-current
    [[ "$output" == "main" ]]
}

@test "wt_create: stdout is only the path, progress goes to stderr" {
    run --separate-stderr wt_create 'feat/thing'
    [[ "$output" == "$WT/feat-thing" ]]
}

@test "wt_create: refuses the default branch" {
    run wt_create main
    [[ "$status" -ne 0 ]]
    [[ "$output" == *"main clone owns the default branch"* ]]
}

@test "wt_create: reuse is idempotent" {
    wt_create 'feat/thing' >/dev/null
    run wt_create 'feat/thing'
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"$WT/feat-thing"* ]]
}

@test "wt_create: refuses a branch already checked out elsewhere" {
    git branch other
    git -C "$REPO" worktree add --quiet "$TEST_DIR/manual" other
    run wt_create other
    [[ "$status" -ne 0 ]]
    # git's own message, which names the worktree already holding the branch
    [[ "$output" == *"already used by worktree at"* ]]
    [[ "$output" == *"$TEST_DIR/manual"* ]]
}

@test "wt_create: tracks an existing remote branch" {
    git push --quiet origin main:feature/remote
    git fetch --quiet origin
    path=$(wt_create 'feature/remote')
    run git -C "$path" rev-parse --abbrev-ref '@{upstream}'
    [[ "$status" -eq 0 ]]
    [[ "$output" == "origin/feature/remote" ]]
}

@test "wt_create: a new branch gets no upstream, so push cannot go to the default" {
    path=$(wt_create 'feat/brand-new')
    run git -C "$path" rev-parse --abbrev-ref '@{upstream}'
    [[ "$status" -ne 0 ]]
}

@test "wt_create: new branch starts from the remote default" {
    path=$(wt_create 'feat/brand-new')
    run git -C "$path" rev-parse HEAD
    [[ "$output" == "$(git -C "$REPO" rev-parse origin/main)" ]]
}

@test "wt_create: git entry is a file, so the repo scan cannot see it" {
    path=$(wt_create 'feat/thing')
    [[ -f "$path/.git" ]]
    run fd --type d --hidden '^\.git$' "$WTROOT"
    [[ -z "$output" ]]
}

@test "wt_create: copies gitignored local config into the worktree" {
    printf 'SECRET=1\n' >"$REPO/.env"
    path=$(wt_create 'feat/thing')
    [[ -f "$path/.env" ]]
    run cat "$path/.env"
    [[ "$output" == "SECRET=1" ]]
}

@test "wt_create: fails outside the mirror" {
    mkdir -p "$TEST_DIR/elsewhere"
    cd "$TEST_DIR/elsewhere"
    git init --quiet .
    run wt_create 'feat/thing'
    [[ "$status" -ne 0 ]]
    [[ "$output" == *"~/work mirror"* ]]
}

# ============================================
# wt_remove
# ============================================

@test "wt_remove: removes the worktree, branch and empty parents" {
    wt_create 'feat/thing' >/dev/null
    run wt_remove 'feat/thing'
    [[ "$status" -eq 0 ]]
    [[ ! -d "$WT/feat-thing" ]]
    run git -C "$REPO" show-ref --verify --quiet refs/heads/feat/thing
    [[ "$status" -ne 0 ]]
    [[ ! -d "$WTROOT/backend" ]]
}

@test "wt_remove: keeps the worktree root itself" {
    wt_create 'feat/thing' >/dev/null
    wt_remove 'feat/thing'
    [[ -d "$WTROOT" ]]
}

@test "wt_remove: warns about uncommitted changes but still removes" {
    path=$(wt_create 'feat/thing')
    echo change >>"$path/README.md"
    run wt_remove 'feat/thing'
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"Discarding uncommitted changes"* ]]
    [[ ! -d "$path" ]]
}

@test "wt_remove: warns about unpushed commits but still removes" {
    path=$(wt_create 'feat/thing')
    echo more >"$path/new.txt"
    git -C "$path" add new.txt
    git -C "$path" commit --quiet -m 'work'
    run wt_remove 'feat/thing'
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"Discarding 1 unpushed commit"* ]]
    [[ ! -d "$path" ]]
}

@test "wt_remove: reports a missing worktree" {
    run wt_remove 'feat/nope'
    [[ "$status" -ne 0 ]]
    [[ "$output" == *"No worktree at"* ]]
}

# ============================================
# listing
# ============================================

@test "wt_list_all: says so when there are none" {
    run wt_list_all
    [[ "$output" == "No worktrees." ]]
}

@test "wt_list_all: lists the mirrored path and branch" {
    wt_create 'feat/thing' >/dev/null
    run wt_list_all
    [[ "$output" == *"backend/pocs/demo/feat-thing"* ]]
    [[ "$output" == *"feat/thing"* ]]
}

@test "wt_list_all: marks a dirty worktree" {
    path=$(wt_create 'feat/thing')
    echo change >>"$path/README.md"
    run wt_list_all
    [[ "$output" == *"[dirty]"* ]]
}

@test "wt_list_all: marks unpushed commits on a branch with no upstream" {
    path=$(wt_create 'feat/thing')
    echo more >"$path/new.txt"
    git -C "$path" add new.txt
    git -C "$path" commit --quiet -m 'work'
    run wt_list_all
    [[ "$output" == *"[+1]"* ]]
    [[ "$output" != *"[dirty]"* ]]
}

# ============================================
# WorktreeCreate / WorktreeRemove hooks
# ============================================

@test "hook create: relocates Claude Code worktrees into the mirror" {
    run _hook_create 'feat/agent'
    [[ "$status" -eq 0 ]]
    [[ "$output" == "$WT/feat-agent" ]]
    [[ -d "$WT/feat-agent" ]]
}

@test "hook create: resolves the repo from cwd, not the launch directory" {
    cd "$TEST_DIR"
    run _hook_create 'feat/agent'
    [[ "$status" -eq 0 ]]
    [[ "$output" == "$WT/feat-agent" ]]
}

@test "hook create: falls back in-repo for repos outside the mirror" {
    outside="$TEST_DIR/outside"
    mkdir -p "$outside"
    cd "$outside"
    git init --quiet .
    echo x >f.txt
    git add f.txt
    git commit --quiet -m 'initial'
    run --separate-stderr _hook_create 'solo' "$outside"
    [[ "$status" -eq 0 ]]
    [[ "$output" == "$outside/.claude/worktrees/solo" ]]
}

@test "hook create: fails outside a git repository" {
    plain="$TEST_DIR/plain"
    mkdir -p "$plain"
    run _hook_create 'solo' "$plain"
    [[ "$status" -ne 0 ]]
}

@test "hook remove: removes the worktree and prunes parents" {
    path=$(wt_create 'feat/agent')
    run _hook_remove "$path"
    [[ "$status" -eq 0 ]]
    [[ ! -d "$path" ]]
    [[ ! -d "$WTROOT/backend" ]]
}

@test "hook remove: reaps a branch holding nothing the remote lacks" {
    path=$(wt_create 'feat/agent')
    _hook_remove "$path"
    run git -C "$REPO" show-ref --verify --quiet refs/heads/feat/agent
    [[ "$status" -ne 0 ]]
}

@test "hook remove: keeps a branch with unpushed commits" {
    path=$(wt_create 'feat/agent')
    echo more >"$path/new.txt"
    git -C "$path" add new.txt
    git -C "$path" commit --quiet -m 'unpushed work'
    run _hook_remove "$path"
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"Kept branch feat/agent"* ]]
    run git -C "$REPO" show-ref --verify --quiet refs/heads/feat/agent
    [[ "$status" -eq 0 ]]
}

@test "hook remove: refuses paths outside the worktree root" {
    run _hook_remove "$REPO"
    [[ "$status" -eq 0 ]]
    [[ -d "$REPO" ]]
    [[ -f "$REPO/README.md" ]]
}

@test "hook remove: tolerates a path that no longer exists" {
    run _hook_remove "$WT/ghost"
    [[ "$status" -eq 0 ]]
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
    path=$(wt_create 'feat/live')
    stale_dir="$TEST_DIR/stale"
    active_dir="$TEST_DIR/active"
    mkdir -p "$stale_dir" "$active_dir"
    SETUP="$REPO_ROOT" run "$REPO_ROOT/sync/sync_repo.sh" \
        "$REPO" "$TEST_DIR/work" "$stale_dir" "$active_dir"
    [[ "$status" -eq 0 ]]
    run cat "$active_dir"/*
    [[ "$output" == "backend/pocs/demo:feat/live:$path" ]]
}

@test "sync_repo: a stale worktree branch records its worktree path" {
    path=$(wt_create 'feat/dead')
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
    path=$(wt_create 'feat/dead')
    _orphan_upstream "$path"
    stale_dir="$TEST_DIR/stale"
    active_dir="$TEST_DIR/active"
    mkdir -p "$stale_dir" "$active_dir"
    SETUP="$REPO_ROOT" "$REPO_ROOT/sync/sync_repo.sh" \
        "$REPO" "$TEST_DIR/work" "$stale_dir" "$active_dir" >/dev/null
    run bash -c 'cat "$1"/* 2>/dev/null || true' _ "$active_dir"
    [[ "$output" != *"feat/dead"* ]]
}

@test "sync_repo: prunes worktrees whose directory was deleted by hand" {
    path=$(wt_create 'feat/gone')
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

@test "_prune_worktree_parents: stops at the worktree root" {
    source "$REPO_ROOT/sync/repos.sh"
    mkdir -p "$WT/feat-thing"
    _prune_worktree_parents "$WT/feat-thing" "$WTROOT"
    # feat-thing itself is the caller's to remove; its empty parents go
    rmdir "$WT/feat-thing"
    _prune_worktree_parents "$WT/feat-thing" "$WTROOT"
    [[ ! -d "$WTROOT/backend" ]]
    [[ -d "$WTROOT" ]]
    [[ -d "$TEST_DIR/work" ]]
}

@test "_prune_worktree_parents: leaves non-empty parents alone" {
    source "$REPO_ROOT/sync/repos.sh"
    mkdir -p "$WT/feat-a" "$WT/feat-b"
    rmdir "$WT/feat-a"
    _prune_worktree_parents "$WT/feat-a" "$WTROOT"
    [[ -d "$WT/feat-b" ]]
}

@test "repo scan: excludes the worktree tree" {
    wt_create 'feat/thing' >/dev/null
    # Mirrors the _find_repos pipeline in sync/repos.sh, so a worktree can never
    # be mistaken for a repo GitLab has never heard of and offered for deletion
    run bash -c 'fd --type d --hidden "^\.git\$" "$1" --exclude .worktrees | sed -E "s|/\.git/?\$||"' _ "$TEST_DIR/work"
    [[ "$output" == "$REPO" ]]
}

@test "stale deletion order: branch is deletable only after the worktree goes" {
    path=$(wt_create 'feat/thing')
    run git -C "$REPO" branch -D 'feat/thing'
    [[ "$status" -ne 0 ]]
    git -C "$REPO" worktree remove --force "$path"
    run git -C "$REPO" branch -D 'feat/thing'
    [[ "$status" -eq 0 ]]
}
