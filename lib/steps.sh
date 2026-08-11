# shellcheck shell=bash
# shellcheck disable=SC2154 # Colors like $bold/$dim come from lib/colors.sh
# Step selection helpers for run.sh --skip / --only
#
# SKIP_STEPS and ONLY_STEPS accumulate as "3,7," - empty means the flag was
# not given. Membership is one glob match against ",N," instead of an array scan.
#
# Requires lib/colors.sh (for error()) to be sourced first.

# Short names for each step, in run order. Single source of truth for the step
# count and for the table printed by --help and by step number errors; the
# matching run_step calls in run.sh carry the longer human titles.
STEP_NAMES=(
	"update repo"
	"homebrew taps"
	"homebrew upgrade"
	"homebrew install"
	"cache cleanup"
	"tool updates"
	"vscode extensions"
	"symlinks"
	"configure tools"
	"macos"
	"gitlab sync"
	"privileged ops"
	"software update"
)
STEP_TOTAL=${#STEP_NAMES[@]}

# Prints the numbered step list, indented, in three column-major columns so
# reading down a column follows run order.
step_table() {
	local cols=3 n=${#STEP_NAMES[@]} rows
	rows=$(((n + cols - 1) / cols))
	local r c i line
	for ((r = 0; r < rows; r++)); do
		line=""
		for ((c = 0; c < cols; c++)); do
			i=$((c * rows + r))
			((i < n)) || continue
			# Pad every cell except the last one on its line.
			if ((i + rows < n)); then
				line+="$(printf '%2d %-20s' "$((i + 1))" "${STEP_NAMES[i]}")"
			else
				line+="$(printf '%2d %s' "$((i + 1))" "${STEP_NAMES[i]}")"
			fi
		done
		printf '  %s\n' "$line"
	done
}

# Pretty rejection for a bad step number: what was wrong, then the valid steps.
# $1=offending value quoted for display (empty when none was given), $2=reason
step_error() {
	local value="$1" reason="$2"
	if [[ -n "$value" ]]; then
		error "${bold}${value}${reset}${red} $reason"
	else
		error "$reason"
	fi
	{
		echo ""
		echo -e "  ${bold}Valid steps are 1-${STEP_TOTAL}:${reset}"
		echo ""
		step_table
		echo ""
		echo -e "  ${dim}Separate numbers with commas, spaces or both:${reset}"
		echo -e "  ${dim}  --skip 1,2   --skip 1, 2   --skip 1 2   --skip=1,2${reset}"
		echo ""
	} >&2
}

# Validates a list of step numbers into the variable named $2. Numbers may be
# separated by commas, spaces or both, so "3,7", "3, 7" and "3 7" are the same.
# $1=list value, $2=SKIP_STEPS or ONLY_STEPS
parse_step_list() {
	local -n out="$2"
	local -a items=()
	IFS=', ' read -ra items <<<"$1"
	((${#items[@]})) || {
		step_error "" "no step numbers given"
		return 1
	}
	local n
	for n in "${items[@]}"; do
		# read -ra yields an empty field for a doubled separator ("1,,2").
		[[ -n "$n" ]] || {
			step_error "" "empty step number (check for a doubled comma)"
			return 1
		}
		[[ "$n" =~ ^-[0-9]+$ ]] && {
			step_error "'$n'" "is negative; steps are numbered 1-$STEP_TOTAL"
			return 1
		}
		[[ "$n" =~ ^[0-9]+$ ]] || {
			step_error "'$n'" "is not a number"
			return 1
		}
		((10#$n >= 1 && 10#$n <= STEP_TOTAL)) || {
			step_error "'$n'" "is not a step number (1-$STEP_TOTAL)"
			return 1
		}
		out+="$((10#$n)),"
	done
}

# True when step number $1 won't run: excluded by --skip, or absent from --only.
# The leading comma is added here so the first list entry matches too.
step_disabled() {
	if [[ -n "$ONLY_STEPS" ]]; then
		[[ ",$ONLY_STEPS" != *",$1,"* ]]
	else
		[[ ",$SKIP_STEPS" == *",$1,"* ]]
	fi
}
