#!/usr/bin/env bats
# Tests for step selection (--skip / --only) in lib/steps.sh

load test_helper

setup() {
    # STEP_TOTAL/STEP_NAMES come from lib/steps.sh via test_helper.
    SKIP_STEPS=""
    ONLY_STEPS=""
}

# ============================================
# step list metadata
# ============================================

@test "STEP_TOTAL is derived from STEP_NAMES" {
    [[ "$STEP_TOTAL" -eq "${#STEP_NAMES[@]}" ]]
}

@test "STEP_NAMES has one entry per step file" {
    local count
    count="$(find "$REPO_ROOT/steps" -name '[0-9][0-9]_*.sh' | wc -l)"
    [[ "$STEP_TOTAL" -eq "$count" ]]
}

@test "step_table lists every step exactly once" {
    run step_table
    [[ "$status" -eq 0 ]]
    local n
    for ((n = 1; n <= STEP_TOTAL; n++)); do
        [[ "$output" == *"${STEP_NAMES[n - 1]}"* ]]
    done
    # Three column-major columns over 13 steps => 5 rows.
    [[ "$(echo "$output" | wc -l)" -eq 5 ]]
}

# ============================================
# parse_step_list tests
# ============================================

@test "parse_step_list: single number" {
    parse_step_list "7" SKIP_STEPS
    [[ "$SKIP_STEPS" == "7," ]]
}

@test "parse_step_list: comma-separated numbers" {
    parse_step_list "3,7,11" SKIP_STEPS
    [[ "$SKIP_STEPS" == "3,7,11," ]]
}

@test "parse_step_list: space-separated numbers" {
    parse_step_list "3 7 11" SKIP_STEPS
    [[ "$SKIP_STEPS" == "3,7,11," ]]
}

@test "parse_step_list: comma-space separated numbers" {
    parse_step_list "3, 7, 11" SKIP_STEPS
    [[ "$SKIP_STEPS" == "3,7,11," ]]
}

@test "parse_step_list: trailing separators ignored" {
    parse_step_list "3,7, " SKIP_STEPS
    [[ "$SKIP_STEPS" == "3,7," ]]
}

@test "parse_step_list: empty list rejected" {
    run parse_step_list "" SKIP_STEPS
    [[ "$status" -eq 1 ]]
    [[ "$output" == *"no step numbers"* ]]
}

@test "parse_step_list: empty entry between commas rejected" {
    run parse_step_list "3,,7" SKIP_STEPS
    [[ "$status" -eq 1 ]]
    [[ "$output" == *"doubled comma"* ]]
}

@test "parse_step_list: negative number gets its own message" {
    run parse_step_list "-3" SKIP_STEPS
    [[ "$status" -eq 1 ]]
    [[ "$output" == *"is negative"* ]]
}

@test "parse_step_list: rejection lists the valid steps" {
    run parse_step_list "99" SKIP_STEPS
    [[ "$status" -eq 1 ]]
    [[ "$output" == *"Valid steps are 1-13"* ]]
    [[ "$output" == *"update repo"* ]]
    [[ "$output" == *"software update"* ]]
    [[ "$output" == *"--skip 1, 2"* ]]
}

@test "parse_step_list: nothing is recorded when validation fails" {
    run parse_step_list "3,99" SKIP_STEPS
    [[ "$status" -eq 1 ]]
    # The caller exits on failure, so a partial list must never be used.
    parse_step_list "3,99" SKIP_STEPS || true
    [[ "$SKIP_STEPS" != *"99"* ]]
}

@test "parse_step_list: leading zeros are not treated as octal" {
    parse_step_list "08,09" SKIP_STEPS
    [[ "$SKIP_STEPS" == "8,9," ]]
}

@test "parse_step_list: boundary values accepted" {
    parse_step_list "1,13" SKIP_STEPS
    [[ "$SKIP_STEPS" == "1,13," ]]
}

@test "parse_step_list: zero rejected" {
    run parse_step_list "0" SKIP_STEPS
    [[ "$status" -eq 1 ]]
    [[ "$output" == *"not a step number"* ]]
}

@test "parse_step_list: above STEP_TOTAL rejected" {
    run parse_step_list "14" SKIP_STEPS
    [[ "$status" -eq 1 ]]
}

@test "parse_step_list: non-numeric rejected" {
    run parse_step_list "abc" SKIP_STEPS
    [[ "$status" -eq 1 ]]
}

@test "parse_step_list: fills ONLY_STEPS too" {
    parse_step_list "8,9" ONLY_STEPS
    [[ "$ONLY_STEPS" == "8,9," ]]
}

# ============================================
# step_disabled tests
# ============================================

@test "step_disabled: nothing disabled by default" {
    for n in $(seq 1 13); do
        run step_disabled "$n"
        [[ "$status" -eq 1 ]]
    done
}

@test "step_disabled: skipped step is disabled" {
    parse_step_list "3" SKIP_STEPS
    run step_disabled 3
    [[ "$status" -eq 0 ]]
}

@test "step_disabled: unskipped step still runs" {
    parse_step_list "3" SKIP_STEPS
    run step_disabled 4
    [[ "$status" -eq 1 ]]
}

@test "step_disabled: first entry matches (sentinel comma)" {
    parse_step_list "1" SKIP_STEPS
    run step_disabled 1
    [[ "$status" -eq 0 ]]
}

@test "step_disabled: no substring false positive" {
    parse_step_list "1" SKIP_STEPS
    run step_disabled 13
    [[ "$status" -eq 1 ]]
    SKIP_STEPS=""
    parse_step_list "13" SKIP_STEPS
    run step_disabled 3
    [[ "$status" -eq 1 ]]
}

@test "step_disabled: --only keeps listed steps" {
    parse_step_list "8,9" ONLY_STEPS
    run step_disabled 8
    [[ "$status" -eq 1 ]]
    run step_disabled 9
    [[ "$status" -eq 1 ]]
}

@test "step_disabled: --only disables everything else" {
    parse_step_list "8,9" ONLY_STEPS
    run step_disabled 1
    [[ "$status" -eq 0 ]]
    run step_disabled 13
    [[ "$status" -eq 0 ]]
}

@test "step_disabled: --only wins over --skip" {
    parse_step_list "5" ONLY_STEPS
    parse_step_list "5" SKIP_STEPS
    run step_disabled 5
    [[ "$status" -eq 1 ]]
}

# ============================================
# run.sh CLI tests
# ============================================

@test "run.sh --help exits successfully" {
    run "$REPO_ROOT/run.sh" --help
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"--skip N..."* ]]
}

@test "run.sh rejects unknown option" {
    run "$REPO_ROOT/run.sh" --bogus
    [[ "$status" -eq 1 ]]
    [[ "$output" == *"unknown option"* ]]
}

@test "run.sh rejects a bad step number before doing any work" {
    run "$REPO_ROOT/run.sh" --skip 99
    [[ "$status" -ne 0 ]]
    [[ "$(strip_ansi "$output")" == *"not a step number"* ]]
    # Must fail during parsing, before the first step banner prints.
    [[ "$output" != *"Mac Configuration Script"* ]]
}

@test "run.sh step error shows the step table" {
    run "$REPO_ROOT/run.sh" --skip 99
    local clean
    clean="$(strip_ansi "$output")"
    [[ "$clean" == *"Valid steps are 1-13"* ]]
    [[ "$clean" == *"vscode extensions"* ]]
}

@test "run.sh --help and step errors show the same table" {
    run "$REPO_ROOT/run.sh" --help
    local help_table
    help_table="$(strip_ansi "$output")"
    run "$REPO_ROOT/run.sh" --skip 99
    local err_table
    err_table="$(strip_ansi "$output")"
    local n
    for ((n = 1; n <= 13; n++)); do
        [[ "$help_table" == *"${STEP_NAMES[n - 1]}"* ]]
        [[ "$err_table" == *"${STEP_NAMES[n - 1]}"* ]]
    done
}

@test "run.sh --skip with no value fails" {
    run "$REPO_ROOT/run.sh" --skip
    [[ "$status" -ne 0 ]]
    [[ "$(strip_ansi "$output")" == *"--skip needs at least one step number"* ]]
}

@test "run.sh --skip followed only by a flag fails" {
    run "$REPO_ROOT/run.sh" --skip --clean
    [[ "$status" -ne 0 ]]
    [[ "$(strip_ansi "$output")" == *"--skip needs at least one step number"* ]]
}

# The next three reach validation only if the space-separated numbers were
# collected; otherwise the parser would reject them as unknown options.
@test "run.sh accepts space-separated step numbers" {
    run "$REPO_ROOT/run.sh" --skip 1 99
    [[ "$(strip_ansi "$output")" == *"'99' is not a step number"* ]]
}

@test "run.sh accepts comma-space-separated step numbers" {
    run "$REPO_ROOT/run.sh" --only 1, 99
    [[ "$(strip_ansi "$output")" == *"'99' is not a step number"* ]]
}

@test "run.sh accepts --skip=N,... form" {
    run "$REPO_ROOT/run.sh" --skip=1,99
    [[ "$(strip_ansi "$output")" == *"'99' is not a step number"* ]]
}

@test "run.sh stops collecting step numbers at the next flag" {
    run "$REPO_ROOT/run.sh" --skip 1 2 --bogus
    [[ "$status" -eq 1 ]]
    [[ "$(strip_ansi "$output")" == *"unknown option: --bogus"* ]]
}

@test "step file prefixes match their run order in run.sh" {
    local -a files=()
    while IFS= read -r file; do files+=("$file"); done \
        < <(grep -oE 'steps/[0-9]{2}_[a-z_]+\.sh' "$REPO_ROOT/run.sh")

    [[ "${#files[@]}" -eq 13 ]]
    for i in "${!files[@]}"; do
        local prefix="${files[i]#steps/}"
        prefix="${prefix%%_*}"
        [[ "$((10#$prefix))" -eq "$((i + 1))" ]] || {
            echo "${files[i]} runs at position $((i + 1))" >&2
            false
        }
        [[ -f "$REPO_ROOT/${files[i]}" ]]
    done
}
