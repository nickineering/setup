#!/usr/bin/env bats
# Tests for the helper scripts in scripts/
#
# Step 08 links each scripts/*.py into ~/.local/bin without its extension, and
# runs it through uv. These tests pin the conventions that makes depend on:
# an executable bit, a uv shebang, and an inline PEP 723 dependency block.

load test_helper

# Lists scripts/*.py, or nothing at all when the directory is empty.
helper_scripts() {
    find "$REPO_ROOT/scripts" -maxdepth 1 -name '*.py' -type f
}

@test "scripts: every helper is executable" {
    while IFS= read -r script; do
        [[ -z "$script" ]] && continue
        [[ -x "$script" ]] || {
            echo "not executable: $script"
            return 1
        }
    done < <(helper_scripts)
}

@test "scripts: every helper has a uv script shebang" {
    while IFS= read -r script; do
        [[ -z "$script" ]] && continue
        run head -1 "$script"
        [[ "$output" == "#!/usr/bin/env -S uv run --script --quiet" ]] || {
            echo "bad shebang in $script: $output"
            return 1
        }
    done < <(helper_scripts)
}

@test "scripts: every helper declares inline PEP 723 metadata" {
    while IFS= read -r script; do
        [[ -z "$script" ]] && continue
        grep -q '^# /// script$' "$script" || {
            echo "missing '# /// script' block in $script"
            return 1
        }
    done < <(helper_scripts)
}

@test "scripts: helper names do not collide with existing commands" {
    while IFS= read -r script; do
        [[ -z "$script" ]] && continue
        name=$(basename "$script" .py)
        # A helper is linked into ~/.local/bin, which precedes the Homebrew and
        # system paths, so a shared name would silently shadow the real tool.
        found=$(command -v "$name" 2>/dev/null || true)
        [[ -z "$found" || "$found" == "$HOME/.local/bin/$name" ]] || {
            echo "$name would shadow $found"
            return 1
        }
    done < <(helper_scripts)
}
