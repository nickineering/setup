#!/usr/bin/env bats
# Tests for lib/packages.sh

load test_helper

setup() {
	TEST_DIR="$(mktemp -d)"
}

teardown() {
	[[ -d "$TEST_DIR" ]] && rm -rf "$TEST_DIR"
}

# ============================================
# parse_state_file tests
# ============================================

@test "parse_state_file: strips comments and preserves order" {
	cat >"$TEST_DIR/test.txt" <<'EOF'
zsh                     # comment
autojump                # another comment
bash-completion
EOF
	run parse_state_file "$TEST_DIR/test.txt"
	[[ "$status" -eq 0 ]]
	[[ "${lines[0]}" == "zsh" ]]
	[[ "${lines[1]}" == "autojump" ]]
	[[ "${lines[2]}" == "bash-completion" ]]
}

@test "parse_state_file: handles empty lines" {
	cat >"$TEST_DIR/test.txt" <<'EOF'
package1

package2
EOF
	run parse_state_file "$TEST_DIR/test.txt"
	[[ "$status" -eq 0 ]]
	[[ ${#lines[@]} -eq 2 ]]
}

@test "parse_state_file: skips comment-only lines" {
	cat >"$TEST_DIR/test.txt" <<'EOF'
package1
# This is a comment line
package2
EOF
	run parse_state_file "$TEST_DIR/test.txt"
	[[ "$status" -eq 0 ]]
	# Should only have 2 packages, not the comment line
	[[ ${#lines[@]} -eq 2 ]]
	[[ "${lines[0]}" == "package1" ]]
	[[ "${lines[1]}" == "package2" ]]
}

@test "parse_state_file: returns error for nonexistent file" {
	run parse_state_file "$TEST_DIR/nonexistent.txt"
	[[ "$status" -eq 1 ]]
}

@test "parse_state_file: handles packages with slashes" {
	cat >"$TEST_DIR/test.txt" <<'EOF'
hashicorp/tap/terraform # comment
regular-package
EOF
	run parse_state_file "$TEST_DIR/test.txt"
	[[ "$status" -eq 0 ]]
	[[ "${lines[0]}" == "hashicorp/tap/terraform" ]]
	[[ "${lines[1]}" == "regular-package" ]]
}

# ============================================
# set_difference tests
# ============================================

@test "set_difference: finds items only in second list" {
	list1=$'apple\nbanana\ncherry'
	list2=$'apple\nbanana\ncherry\ndate'
	run set_difference "$list1" "$list2"
	[[ "$status" -eq 0 ]]
	[[ "$output" == "date" ]]
}

@test "set_difference: returns empty when lists are identical" {
	list=$'apple\nbanana\ncherry'
	run set_difference "$list" "$list"
	[[ "$status" -eq 0 ]]
	[[ -z "$output" ]]
}

@test "set_difference: handles empty first list" {
	list2=$'apple\nbanana'
	run set_difference "" "$list2"
	[[ "$status" -eq 0 ]]
	[[ "$output" == "$list2" ]]
}

@test "set_difference: handles empty second list" {
	list1=$'apple\nbanana'
	run set_difference "$list1" ""
	[[ "$status" -eq 0 ]]
	[[ -z "$output" ]]
}

@test "set_difference: finds multiple missing items" {
	list1=$'apple'
	list2=$'apple\nbanana\ncherry'
	run set_difference "$list1" "$list2"
	[[ "$status" -eq 0 ]]
	[[ "${lines[0]}" == "banana" ]]
	[[ "${lines[1]}" == "cherry" ]]
}

@test "set_difference: works for finding removals (reversed args)" {
	old=$'apple\nbanana\ncherry'
	new=$'apple\ncherry'
	# set_difference "$new" "$old" = items in old but not new = removed
	run set_difference "$new" "$old"
	[[ "$status" -eq 0 ]]
	[[ "$output" == "banana" ]]
}

# ============================================
# get_installed_* tests (integration)
# ============================================

@test "get_installed_packages: returns list" {
	if ! command -v brew &>/dev/null; then
		skip "brew not installed"
	fi
	run get_installed_packages
	[[ "$status" -eq 0 ]]
}

@test "get_installed_casks: returns list" {
	if ! command -v brew &>/dev/null; then
		skip "brew not installed"
	fi
	run get_installed_casks
	[[ "$status" -eq 0 ]]
}

@test "get_installed_extensions: returns lowercase list" {
	if ! command -v code &>/dev/null; then
		skip "VSCode CLI not installed"
	fi
	run get_installed_extensions
	[[ "$status" -eq 0 ]]
	# Verify lowercase
	lowercase=$(echo "$output" | tr '[:upper:]' '[:lower:]')
	[[ "$output" == "$lowercase" ]]
}
