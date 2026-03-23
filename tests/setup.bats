#!/usr/bin/env bats
# Tests for setup scripts

# Load shared helpers (sources utility functions)
load test_helper

setup() {
    TEST_DIR="$(mktemp -d)"
    export BACKUPS="$TEST_DIR/backups"
    mkdir -p "$BACKUPS"
}

teardown() {
    [[ -d "$TEST_DIR" ]] && rm -rf "$TEST_DIR"
}

# ============================================
# strip_comments.sh tests
# ============================================

@test "strip_comments: removes comment after space" {
    run strip_comments "package # comment"
    [[ "$status" -eq 0 ]]
    [[ "$output" == "package" ]]
}

@test "strip_comments: handles package without comment" {
    run strip_comments "package"
    [[ "$status" -eq 0 ]]
    [[ "$output" == "package" ]]
}

@test "strip_comments: handles empty string" {
    run strip_comments ""
    [[ "$status" -eq 0 ]]
    [[ "$output" == "" ]]
}

@test "strip_comments: handles whitespace only" {
    run strip_comments "   "
    [[ "$status" -eq 0 ]]
    [[ "$output" == "" ]]
}

@test "strip_comments: handles tab-separated comment" {
    run strip_comments "package	comment"
    [[ "$status" -eq 0 ]]
    [[ "$output" == "package" ]]
}

@test "strip_comments: handles multiple spaces before comment" {
    run strip_comments "package   comment"
    [[ "$status" -eq 0 ]]
    [[ "$output" == "package" ]]
}

@test "strip_comments: preserves package with dashes" {
    run strip_comments "my-package"
    [[ "$status" -eq 0 ]]
    [[ "$output" == "my-package" ]]
}

@test "strip_comments: preserves package with slashes" {
    run strip_comments "tap/package"
    [[ "$status" -eq 0 ]]
    [[ "$output" == "tap/package" ]]
}

@test "strip_comments: skips comment-only lines" {
    run strip_comments "# this is a comment"
    [[ "$status" -eq 0 ]]
    [[ "$output" == "" ]]
}

# ============================================
# backup_or_delete.sh tests
# ============================================

@test "backup_or_delete: regular file creates timestamped backup" {
    echo "test content" > "$TEST_DIR/testfile.txt"

    run backup_or_delete "$TEST_DIR/testfile.txt"
    [[ "$status" -eq 0 ]]

    # Original should be gone
    [[ ! -e "$TEST_DIR/testfile.txt" ]]

    # Backup should exist with timestamp pattern
    run ls "$BACKUPS"/testfile.txt.backup.*
    [[ "$status" -eq 0 ]]
    [[ ${#lines[@]} -ge 1 ]]
}

@test "backup_or_delete: symlink removes without backup" {
    ln -s /nonexistent "$TEST_DIR/testlink"

    run backup_or_delete "$TEST_DIR/testlink"
    [[ "$status" -eq 0 ]]
    [[ ! -e "$TEST_DIR/testlink" ]]
    [[ ! -L "$TEST_DIR/testlink" ]]
}

@test "backup_or_delete: nonexistent file succeeds silently" {
    run backup_or_delete "$TEST_DIR/nonexistent"
    [[ "$status" -eq 0 ]]
}

@test "backup_or_delete: empty argument fails" {
    run backup_or_delete ""
    [[ "$status" -eq 1 ]]
}

@test "backup_or_delete: rejects root path" {
    run backup_or_delete "/"
    [[ "$status" -eq 1 ]]
    [[ "$output" == *"critical path"* ]]
}

@test "backup_or_delete: rejects /etc path" {
    run backup_or_delete "/etc/passwd"
    [[ "$status" -eq 1 ]]
    [[ "$output" == *"critical path"* ]]
}

@test "backup_or_delete: rejects /usr path" {
    run backup_or_delete "/usr/bin/ls"
    [[ "$status" -eq 1 ]]
    [[ "$output" == *"critical path"* ]]
}

@test "backup_or_delete: rejects home directory itself" {
    run backup_or_delete "$HOME"
    [[ "$status" -eq 1 ]]
    [[ "$output" == *"critical path"* ]]
}

@test "backup_or_delete: allows files under home" {
    # Should not reject paths under $HOME (just not $HOME itself)
    echo "test" > "$TEST_DIR/homefile.txt"
    run backup_or_delete "$TEST_DIR/homefile.txt"
    [[ "$status" -eq 0 ]]
}

# ============================================
# Symlink idempotency tests (ln -sfn)
# ============================================

@test "ln -sfn: creates new symlink" {
    echo "content" > "$TEST_DIR/target.txt"

    run ln -sfn "$TEST_DIR/target.txt" "$TEST_DIR/link.txt"
    [[ "$status" -eq 0 ]]
    [[ -L "$TEST_DIR/link.txt" ]]
}

@test "ln -sfn: overwrites existing symlink" {
    echo "old" > "$TEST_DIR/old.txt"
    echo "new" > "$TEST_DIR/new.txt"
    ln -sfn "$TEST_DIR/old.txt" "$TEST_DIR/link.txt"

    run ln -sfn "$TEST_DIR/new.txt" "$TEST_DIR/link.txt"
    [[ "$status" -eq 0 ]]
    [[ "$(readlink "$TEST_DIR/link.txt")" == "$TEST_DIR/new.txt" ]]
}

@test "ln -sfn: overwrites broken symlink" {
    echo "content" > "$TEST_DIR/target.txt"
    ln -sfn "/nonexistent" "$TEST_DIR/link.txt"

    run ln -sfn "$TEST_DIR/target.txt" "$TEST_DIR/link.txt"
    [[ "$status" -eq 0 ]]
    [[ "$(readlink "$TEST_DIR/link.txt")" == "$TEST_DIR/target.txt" ]]
}

@test "ln -sfn: idempotent when run twice" {
    echo "content" > "$TEST_DIR/target.txt"
    ln -sfn "$TEST_DIR/target.txt" "$TEST_DIR/link.txt"

    run ln -sfn "$TEST_DIR/target.txt" "$TEST_DIR/link.txt"
    [[ "$status" -eq 0 ]]
    [[ -L "$TEST_DIR/link.txt" ]]
}

# ============================================
# State file existence tests
# ============================================

@test "state/linked_files.txt exists" {
    [[ -f "$REPO_ROOT/state/linked_files.txt" ]]
}

@test "state/brew_packages.txt exists" {
    [[ -f "$REPO_ROOT/state/brew_packages.txt" ]]
}

@test "state/brew_casks.txt exists" {
    [[ -f "$REPO_ROOT/state/brew_casks.txt" ]]
}

@test "state/vscode_extensions.txt exists" {
    [[ -f "$REPO_ROOT/state/vscode_extensions.txt" ]]
}

@test "state/copied_files.txt exists" {
    [[ -f "$REPO_ROOT/state/copied_files.txt" ]]
}

# ============================================
# State file integrity tests
# ============================================

@test "all linked_files.txt entries exist in linked/" {
    local missing=()
    while IFS= read -r file; do
        [[ -z "$file" ]] && continue
        [[ -f "$REPO_ROOT/linked/$file" ]] || missing+=("$file")
    done < "$REPO_ROOT/state/linked_files.txt"

    [[ ${#missing[@]} -eq 0 ]] || {
        echo "Missing files: ${missing[*]}" >&2
        false
    }
}

@test "all copied_files.txt entries exist in copied/" {
    local missing=()
    while IFS= read -r file; do
        [[ -z "$file" ]] && continue
        [[ -f "$REPO_ROOT/copied/$file" ]] || missing+=("$file")
    done < "$REPO_ROOT/state/copied_files.txt"

    [[ ${#missing[@]} -eq 0 ]] || {
        echo "Missing files: ${missing[*]}" >&2
        false
    }
}

# ============================================
# Package utilities tests (packages.sh)
# ============================================

@test "PROTECTED_PACKAGES includes critical packages" {
    # Verify the protected list contains expected critical packages
    [[ "$PROTECTED_PACKAGES" == *"bash"* ]]
    [[ "$PROTECTED_PACKAGES" == *"git"* ]]
    [[ "$PROTECTED_PACKAGES" == *"openssl"* ]]
    [[ "$PROTECTED_PACKAGES" == *"curl"* ]]
    [[ "$PROTECTED_PACKAGES" == *"coreutils"* ]]
}
