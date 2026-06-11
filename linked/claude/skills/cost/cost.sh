#!/usr/bin/env bash
set -euo pipefail

RATES_FILE="$HOME/.claude/usage-data/rates.json"
SESSION_META_DIR="$HOME/.claude/usage-data/session-meta"
PROJECTS_DIR="$HOME/.claude/projects"
SESSIONS_DIR="$HOME/.claude/sessions"
REGION="eu-central-1"
CE_PROFILE="${CLAUDE_CE_PROFILE:-eon-dev}"

usage() {
	cat <<EOF
Usage: cost.sh [OPTIONS] [PERIOD]

Show AWS Bedrock cost for Claude Code sessions.

PERIOD:
  (none)          Current session only
  today           All sessions from today
  yesterday       All sessions from yesterday
  this-week       Sessions from Monday onwards
  last-7-days     Sessions from the last 7 days
  this-month      Sessions from the 1st of this month
  YYYY-MM-DD      Sessions from a specific date onwards
  YYYY-MM-DD:YYYY-MM-DD  Sessions in a date range

OPTIONS:
  --refresh-rates  Re-derive rates from Cost Explorer (requires AWS access)
  --help           Show this help
EOF
	exit 0
}

die() {
	echo "ERROR: $1" >&2
	exit 1
}

refresh_rates() {
	local start end
	start=$(date -v-30d +%Y-%m-%d 2>/dev/null || date -d '30 days ago' +%Y-%m-%d)
	end=$(date +%Y-%m-%d)

	aws --profile "$CE_PROFILE" sts get-caller-identity >/dev/null 2>&1 || die "No AWS access with profile '$CE_PROFILE'. Run: ! claude-aws dev"

	local services=(
		"Claude Opus 4.6 (Amazon Bedrock Edition)"
		"Claude Opus 4.7 (Amazon Bedrock Edition)"
		"Claude Opus 4.8 (Amazon Bedrock Edition)"
		"Claude Sonnet 4 (Amazon Bedrock Edition)"
		"Claude Sonnet 4.5 (Amazon Bedrock Edition)"
		"Claude Sonnet 4.6 (Amazon Bedrock Edition)"
		"Claude Haiku 4.5 (Amazon Bedrock Edition)"
	)

	local filter
	filter=$(printf '%s","' "${services[@]}")
	filter='{"Dimensions":{"Key":"SERVICE","Values":["'"${filter%\",\"}"'"]}}'

	local result
	result=$(aws --profile "$CE_PROFILE" ce get-cost-and-usage \
		--time-period "Start=$start,End=$end" \
		--granularity MONTHLY \
		--metrics "UnblendedCost" "UsageQuantity" \
		--group-by Type=DIMENSION,Key=SERVICE Type=DIMENSION,Key=USAGE_TYPE \
		--filter "$filter" \
		--region "$REGION" 2>&1) || die "Cost Explorer query failed: $result"

	# Parse rates grouped by tier
	echo "$result" | python3 -c "
import json, sys

data = json.load(sys.stdin)
tiers = {}

for period in data.get('ResultsByTime', []):
    for group in period.get('Groups', []):
        keys = group['Keys']
        service = keys[0]
        usage_type = keys[1]
        cost = float(group['Metrics']['UnblendedCost']['Amount'])
        qty = float(group['Metrics']['UsageQuantity']['Amount'])

        if 'Opus' in service:
            tier = 'opus'
        elif 'Sonnet' in service:
            tier = 'sonnet'
        elif 'Haiku' in service:
            tier = 'haiku'
        else:
            continue

        if tier not in tiers:
            tiers[tier] = {}

        if 'InputTokenCount-Units' in usage_type and 'Cache' not in usage_type:
            key = 'input'
        elif 'CacheWriteInputTokenCount-Units' in usage_type:
            key = 'cache_write'
        elif 'CacheReadInputTokenCount-Units' in usage_type:
            key = 'cache_read'
        elif 'OutputTokenCount-Units' in usage_type:
            key = 'output'
        else:
            continue

        if key not in tiers[tier]:
            tiers[tier][key] = {'cost': 0, 'qty': 0}
        tiers[tier][key]['cost'] += cost
        tiers[tier][key]['qty'] += qty

rates = {}
for tier, token_types in tiers.items():
    rates[tier] = {}
    for token_type, vals in token_types.items():
        if vals['qty'] > 0:
            rates[tier][token_type] = round(vals['cost'] / vals['qty'], 6)
        else:
            rates[tier][token_type] = 0

json.dump(rates, sys.stdout, indent=2)
print()
" >"$RATES_FILE"

	echo "Rates refreshed → $RATES_FILE" >&2
}

ensure_rates() {
	if [[ ! -f "$RATES_FILE" ]]; then
		refresh_rates
		return
	fi
	local max_age_days=7
	local file_age
	file_age=$(($(date +%s) - $(stat -f %m "$RATES_FILE" 2>/dev/null || stat -c %Y "$RATES_FILE" 2>/dev/null || echo 0)))
	if ((file_age > max_age_days * 86400)); then
		echo "Rates cache expired (older than ${max_age_days} days), refreshing..." >&2
		refresh_rates
	fi
}

resolve_period() {
	local period="${1:-session}"
	local start_ts end_ts

	case "$period" in
	session)
		echo "session"
		return
		;;
	today)
		start_ts=$(date -j -f "%Y-%m-%d %H:%M:%S" "$(date +%Y-%m-%d) 00:00:00" +%s 2>/dev/null ||
			date -d "$(date +%Y-%m-%d)" +%s)
		end_ts=$(date +%s)
		;;
	yesterday)
		start_ts=$(date -v-1d -j -f "%Y-%m-%d %H:%M:%S" "$(date -v-1d +%Y-%m-%d) 00:00:00" +%s 2>/dev/null ||
			date -d "yesterday" +%s)
		end_ts=$(date -j -f "%Y-%m-%d %H:%M:%S" "$(date +%Y-%m-%d) 00:00:00" +%s 2>/dev/null ||
			date -d "$(date +%Y-%m-%d)" +%s)
		;;
	this-week)
		local dow
		dow=$(date +%u)
		start_ts=$(date -v-"$((dow - 1))"d -j -f "%Y-%m-%d %H:%M:%S" "$(date -v-"$((dow - 1))"d +%Y-%m-%d) 00:00:00" +%s 2>/dev/null ||
			date -d "last monday" +%s)
		end_ts=$(date +%s)
		;;
	last-7-days)
		start_ts=$(date -v-7d +%s 2>/dev/null || date -d '7 days ago' +%s)
		end_ts=$(date +%s)
		;;
	this-month)
		start_ts=$(date -j -f "%Y-%m-%d %H:%M:%S" "$(date +%Y-%m-01) 00:00:00" +%s 2>/dev/null ||
			date -d "$(date +%Y-%m-01)" +%s)
		end_ts=$(date +%s)
		;;
	*:*)
		local from="${period%%:*}"
		local to="${period##*:}"
		start_ts=$(date -j -f "%Y-%m-%d %H:%M:%S" "$from 00:00:00" +%s 2>/dev/null || date -d "$from" +%s)
		end_ts=$(date -j -f "%Y-%m-%d %H:%M:%S" "$to 00:00:00" +%s 2>/dev/null || date -d "$to" +%s)
		end_ts=$((end_ts + 86400))
		;;
	[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9])
		start_ts=$(date -j -f "%Y-%m-%d %H:%M:%S" "$period 00:00:00" +%s 2>/dev/null || date -d "$period" +%s)
		end_ts=$(date +%s)
		;;
	*)
		die "Unknown period: $period. Use --help for options."
		;;
	esac

	echo "$start_ts:$end_ts"
}

sum_tokens_from_jsonl() {
	local file="$1"
	local start_iso="${2:-}"
	local end_iso="${3:-}"

	awk -v start="$start_iso" -v end="$end_iso" '
    function extract_ts(line,    i, s) {
      i = index(line, "\"timestamp\":\"")
      if (i == 0) return ""
      s = substr(line, i + 13)
      return substr(s, 1, index(s, "\"") - 1)
    }
    function add_token(line, key,    i, s, n) {
      i = index(line, "\"" key "\":")
      if (i == 0) return
      s = substr(line, i + length(key) + 3)
      n = ""
      while (substr(s, 1, 1) ~ /[0-9]/) {
        n = n substr(s, 1, 1)
        s = substr(s, 2)
      }
      if (n != "") sums[key] += n + 0
    }
    {
      if (start != "") {
        ts = extract_ts($0)
        if (ts == "" || ts < start || ts > end) next
      }
      add_token($0, "input_tokens")
      add_token($0, "cache_creation_input_tokens")
      add_token($0, "cache_read_input_tokens")
      add_token($0, "output_tokens")
    }
    END {
      printf "%d %d %d %d\n", sums["input_tokens"]+0, sums["cache_creation_input_tokens"]+0, sums["cache_read_input_tokens"]+0, sums["output_tokens"]+0
    }
  ' "$file" 2>/dev/null
}

detect_model_tier() {
	local file="$1"
	local model
	model=$(grep -o '"model":"[^"]*"' "$file" 2>/dev/null | sort | uniq -c | sort -rn | head -1 | sed 's/.*"model":"//;s/"//')
	if [[ "$model" == *opus* ]]; then
		echo "opus"
	elif [[ "$model" == *sonnet* ]]; then
		echo "sonnet"
	elif [[ "$model" == *haiku* ]]; then
		echo "haiku"
	else
		echo "opus"
	fi
}

format_tokens() {
	printf "%'d" "$1" 2>/dev/null || echo "$1"
}

BOX_WIDTH=83

box_line() {
	printf "│%-${BOX_WIDTH}s│\n" "$1"
}

calculate_cost() {
	local input=$1 cache_write=$2 cache_read=$3 output=$4 tier=$5
	python3 -c "
import json
with open('$RATES_FILE') as f:
    rates = json.load(f)
tier_rates = rates.get('$tier', rates.get('opus', {}))
input_rate = tier_rates.get('input', 0)
write_rate = tier_rates.get('cache_write', 0)
read_rate = tier_rates.get('cache_read', 0)
output_rate = tier_rates.get('output', 0)

input_cost = $input * input_rate / 1_000_000
write_cost = $cache_write * write_rate / 1_000_000
read_cost = $cache_read * read_rate / 1_000_000
output_cost = $output * output_rate / 1_000_000
total = input_cost + write_cost + read_cost + output_cost

# Cost for all three tiers
def tier_total(t):
    r = rates.get(t, {})
    return (
        $input * r.get('input', 0) / 1_000_000
        + $cache_write * r.get('cache_write', 0) / 1_000_000
        + $cache_read * r.get('cache_read', 0) / 1_000_000
        + $output * r.get('output', 0) / 1_000_000
    )

opus_total = tier_total('opus')
sonnet_total = tier_total('sonnet')
haiku_total = tier_total('haiku')

# Cache efficiency: read:write ratio
cache_ratio = $cache_read / $cache_write if $cache_write > 0 else 0

print(f'{input_cost:.2f}')
print(f'{write_cost:.2f}')
print(f'{read_cost:.2f}')
print(f'{output_cost:.2f}')
print(f'{total:.2f}')
print(f'{input_rate:.4f}')
print(f'{write_rate:.4f}')
print(f'{read_rate:.4f}')
print(f'{output_rate:.4f}')
print(f'{opus_total:.2f}')
print(f'{sonnet_total:.2f}')
print(f'{haiku_total:.2f}')
print(f'{cache_ratio:.1f}')
"
}

model_comparison_table() {
	local opus=$1 sonnet=$2 haiku=$3 current_tier=$4
	local sonnet_pct haiku_pct
	sonnet_pct=$(python3 -c "print(f'{(1-$sonnet/$opus)*100:.0f}' if $opus > 0 else '0')")
	haiku_pct=$(python3 -c "print(f'{(1-$haiku/$opus)*100:.0f}' if $opus > 0 else '0')")

	local opus_marker="" sonnet_marker="" haiku_marker=""
	case "$current_tier" in
	opus) opus_marker=" <--" ;;
	sonnet) sonnet_marker=" <--" ;;
	haiku) haiku_marker=" <--" ;;
	esac

	echo "┌───────────────────────────────────────────────────────────────────────────────────┐"
	box_line " MODEL COMPARISON"
	box_line " Same tokens, different models"
	echo "├──────────┬──────────┬─────────────────────────────────────────────────────────────┤"
	printf "│ %-8s │ %8s │ %-60s│\n" "Model" "Cost" "vs Opus"
	echo "├──────────┼──────────┼─────────────────────────────────────────────────────────────┤"
	printf "│ %-8s │ %8s │ %-60s│\n" "Opus" "\$${opus}" "baseline${opus_marker}"
	printf "│ %-8s │ %8s │ %-60s│\n" "Sonnet" "\$${sonnet}" "${sonnet_pct}% cheaper${sonnet_marker}"
	printf "│ %-8s │ %8s │ %-60s│\n" "Haiku" "\$${haiku}" "${haiku_pct}% cheaper${haiku_marker}"
	echo "└──────────┴──────────┴─────────────────────────────────────────────────────────────┘"
}

print_cost_breakdown() {
	local input=$1 cache_write=$2 cache_read=$3 output=$4
	local input_cost=$5 write_cost=$6 read_cost=$7 output_cost=$8 total_cost=$9

	echo ""
	echo "┌───────────────────────────────────────────────────────────────────────────────────┐"
	box_line " COST BREAKDOWN"
	echo "├──────────────────┬────────────────┬───────────────────────────────────────────────┤"
	printf "│ %-16s │ %14s │ %45s │\n" "Category" "Tokens" "Cost"
	echo "├──────────────────┼────────────────┼───────────────────────────────────────────────┤"
	printf "│ %-16s │ %'14d │ %45s │\n" "Input (uncached)" "$input" "\$${input_cost}"
	printf "│ %-16s │ %'14d │ %45s │\n" "Cache write" "$cache_write" "\$${write_cost}"
	printf "│ %-16s │ %'14d │ %45s │\n" "Cache read" "$cache_read" "\$${read_cost}"
	printf "│ %-16s │ %'14d │ %45s │\n" "Output" "$output" "\$${output_cost}"
	echo "├──────────────────┼────────────────┼───────────────────────────────────────────────┤"
	printf "│ %-16s │ %14s │ %45s │\n" "TOTAL" "" "\$${total_cost}"
	echo "└──────────────────┴────────────────┴───────────────────────────────────────────────┘"
}

print_cache_efficiency() {
	local cache_ratio=$1
	echo "┌───────────────────────────────────────────────────────────────────────────────────┐"
	box_line " CACHE EFFICIENCY"
	echo "├───────────────────────────────────────────────────────────────────────────────────┤"
	box_line "  Read:write ratio: ${cache_ratio}x"
	box_line "  Higher = better. Each cache write was reused ~${cache_ratio} times."
	box_line "  Below 5x suggests sessions are too short to benefit from caching."
	echo "└───────────────────────────────────────────────────────────────────────────────────┘"
}

print_rates_table() {
	local opus_in=$1 opus_cw=$2 opus_cr=$3 opus_out=$4
	local sonnet_in=$5 sonnet_cw=$6 sonnet_cr=$7 sonnet_out=$8
	local haiku_in=$9 haiku_cw=${10} haiku_cr=${11} haiku_out=${12}

	echo "┌───────────────────────────────────────────────────────────────────────────────────┐"
	box_line " RATES (\$/1M tokens)"
	echo "├──────────┬──────────────┬──────────────┬──────────────┬───────────────────────────┤"
	printf "│ %-8s │ %12s │ %12s │ %12s │ %25s │\n" "Model" "Input" "Cache Write" "Cache Read" "Output"
	echo "├──────────┼──────────────┼──────────────┼──────────────┼───────────────────────────┤"
	printf "│ %-8s │ %12s │ %12s │ %12s │ %25s │\n" "Opus" "\$${opus_in}" "\$${opus_cw}" "\$${opus_cr}" "\$${opus_out}"
	printf "│ %-8s │ %12s │ %12s │ %12s │ %25s │\n" "Sonnet" "\$${sonnet_in}" "\$${sonnet_cw}" "\$${sonnet_cr}" "\$${sonnet_out}"
	printf "│ %-8s │ %12s │ %12s │ %12s │ %25s │\n" "Haiku" "\$${haiku_in}" "\$${haiku_cw}" "\$${haiku_cr}" "\$${haiku_out}"
	echo "└──────────┴──────────────┴──────────────┴──────────────┴───────────────────────────┘"
}

find_session_jsonl() {
	local session_id="$1"
	find "$PROJECTS_DIR" -maxdepth 2 -name "${session_id}.jsonl" 2>/dev/null | head -1
}

get_session_start() {
	local session_id="$1"
	grep -l "$session_id" "$SESSIONS_DIR"/*.json 2>/dev/null | while read -r f; do
		grep -o '"startedAt":[0-9]*' "$f" | head -1 | cut -d: -f2
	done | head -1
}

display_current_session() {
	local session_id="${CLAUDE_CODE_SESSION_ID:-}"
	[[ -z "$session_id" ]] && die "Not in a Claude Code session (CLAUDE_CODE_SESSION_ID not set)"

	local jsonl
	jsonl=$(find_session_jsonl "$session_id")
	[[ -z "$jsonl" ]] && die "Session transcript not found for $session_id"

	local tokens tier
	tokens=$(sum_tokens_from_jsonl "$jsonl")

	local input cache_write cache_read output
	read -r input cache_write cache_read output <<<"$tokens"

	local model="${ANTHROPIC_MODEL:-unknown}"
	model="${model#eu.}"
	model="${model#global.}"

	# Derive tier from the session's configured model, not JSONL
	# (JSONL may contain skill invocations on cheaper models)
	if [[ "$model" == *opus* ]]; then
		tier="opus"
	elif [[ "$model" == *sonnet* ]]; then
		tier="sonnet"
	elif [[ "$model" == *haiku* ]]; then
		tier="haiku"
	else
		tier=$(detect_model_tier "$jsonl")
	fi

	local started_at duration_str
	started_at=$(get_session_start "$session_id")
	if [[ -n "$started_at" ]]; then
		local now elapsed_s hours mins
		now=$(date +%s)
		elapsed_s=$((now - started_at / 1000))
		hours=$((elapsed_s / 3600))
		mins=$(((elapsed_s % 3600) / 60))
		duration_str="${hours}h ${mins}m"
	else
		duration_str="unknown"
	fi

	local costs
	costs=$(calculate_cost "$input" "$cache_write" "$cache_read" "$output" "$tier")
	local input_cost write_cost read_cost output_cost total_cost
	local input_rate write_rate read_rate output_rate
	local opus_total sonnet_total haiku_total cache_ratio
	{
		read -r input_cost
		read -r write_cost
		read -r read_cost
		read -r output_cost
		read -r total_cost
		read -r input_rate
		read -r write_rate
		read -r read_rate
		read -r output_rate
		read -r opus_total
		read -r sonnet_total
		read -r haiku_total
		read -r cache_ratio
	} <<<"$costs"

	# Get all rates for the rates table
	local all_rates
	all_rates=$(python3 -c "
import json
with open('$RATES_FILE') as f:
    rates = json.load(f)
for tier in ['opus', 'sonnet', 'haiku']:
    r = rates.get(tier, {})
    print(f\"{r.get('input',0):.4f}\")
    print(f\"{r.get('cache_write',0):.4f}\")
    print(f\"{r.get('cache_read',0):.4f}\")
    print(f\"{r.get('output',0):.4f}\")
")
	local opus_in opus_cw opus_cr opus_out
	local sonnet_in sonnet_cw sonnet_cr sonnet_out
	local haiku_in haiku_cw haiku_cr haiku_out
	{
		read -r opus_in
		read -r opus_cw
		read -r opus_cr
		read -r opus_out
		read -r sonnet_in
		read -r sonnet_cw
		read -r sonnet_cr
		read -r sonnet_out
		read -r haiku_in
		read -r haiku_cw
		read -r haiku_cr
		read -r haiku_out
	} <<<"$all_rates"

	local hr
	hr=$(printf '━%.0s' $(seq 1 $BOX_WIDTH))

	echo ""
	echo "$hr"
	echo "  SESSION COST"
	echo "$hr"
	echo ""
	printf "  Model:     %s\n" "${model}"
	printf "  Session:   %s\n" "${session_id}"
	printf "  Duration:  %s\n" "${duration_str}"

	print_cost_breakdown "$input" "$cache_write" "$cache_read" "$output" \
		"$input_cost" "$write_cost" "$read_cost" "$output_cost" "$total_cost"
	echo ""
	model_comparison_table "$opus_total" "$sonnet_total" "$haiku_total" "$tier"
	echo ""
	print_cache_efficiency "$cache_ratio"
	echo ""
	print_rates_table "$opus_in" "$opus_cw" "$opus_cr" "$opus_out" \
		"$sonnet_in" "$sonnet_cw" "$sonnet_cr" "$sonnet_out" \
		"$haiku_in" "$haiku_cw" "$haiku_cr" "$haiku_out"
	echo ""
}

display_period() {
	local range="$1"
	local start_ts="${range%%:*}"
	local end_ts="${range##*:}"

	local start_date end_date
	start_date=$(date -r "$start_ts" +%Y-%m-%d 2>/dev/null || date -d "@$start_ts" +%Y-%m-%d)
	end_date=$(date -r "$end_ts" +%Y-%m-%d 2>/dev/null || date -d "@$end_ts" +%Y-%m-%d)

	# ISO timestamps for filtering JSONL messages
	# end_ts may have +86400 for session overlap detection; subtract 1s for message filtering
	local start_iso end_iso
	local end_ts_inclusive=$((end_ts - 1))
	start_iso=$(date -r "$start_ts" +%Y-%m-%dT%H:%M:%S 2>/dev/null || date -d "@$start_ts" +%Y-%m-%dT%H:%M:%S)
	end_iso=$(date -r "$end_ts_inclusive" +%Y-%m-%dT%H:%M:%S 2>/dev/null || date -d "@$end_ts_inclusive" +%Y-%m-%dT%H:%M:%S)

	# Find all sessions active in this period
	declare -a session_results=()
	local total_input=0 total_write=0 total_read=0 total_output=0
	local session_count=0

	# Check running sessions
	for f in "$SESSIONS_DIR"/*.json; do
		[[ -f "$f" ]] || continue
		local sid started updated
		sid=$(grep -o '"sessionId":"[^"]*"' "$f" | head -1 | sed 's/"sessionId":"//;s/"//')
		started=$(grep -o '"startedAt":[0-9]*' "$f" | head -1 | cut -d: -f2)
		updated=$(grep -o '"updatedAt":[0-9]*' "$f" | head -1 | cut -d: -f2)
		[[ -z "$sid" || -z "$started" ]] && continue
		[[ -z "$updated" ]] && updated="$started"

		local started_s=$((started / 1000))
		local updated_s=$((updated / 1000))
		if ((started_s <= end_ts && updated_s >= start_ts)); then
			local jsonl
			jsonl=$(find_session_jsonl "$sid")
			[[ -z "$jsonl" ]] && continue

			local tokens tier
			tokens=$(sum_tokens_from_jsonl "$jsonl" "$start_iso" "$end_iso")
			tier=$(detect_model_tier "$jsonl")
			local input cache_write cache_read output
			read -r input cache_write cache_read output <<<"$tokens"

			if ((input == 0 && cache_write == 0 && cache_read == 0 && output == 0)); then continue; fi

			local costs
			costs=$(calculate_cost "$input" "$cache_write" "$cache_read" "$output" "$tier")
			local session_cost
			session_cost=$(echo "$costs" | sed -n '5p')

			local cwd
			cwd=$(grep -o '"cwd":"[^"]*"' "$f" | head -1 | sed 's/"cwd":"//;s/"//')
			local project_name="${cwd##*/}"

			session_results+=("${session_cost}|${project_name}|${start_date}|${sid}")
			total_input=$((total_input + input))
			total_write=$((total_write + cache_write))
			total_read=$((total_read + cache_read))
			total_output=$((total_output + output))
			session_count=$((session_count + 1))
		fi
	done

	# Also check session-meta for historical sessions not currently running
	if [[ -d "$SESSION_META_DIR" ]]; then
		for f in "$SESSION_META_DIR"/*.json; do
			[[ -f "$f" ]] || continue
			local sid start_time
			sid=$(grep -o '"session_id"[[:space:]]*:[[:space:]]*"[^"]*"' "$f" | head -1 | sed 's/.*"session_id"[[:space:]]*:[[:space:]]*"//;s/"//')
			start_time=$(grep -o '"start_time"[[:space:]]*:[[:space:]]*"[^"]*"' "$f" | head -1 | sed 's/.*"start_time"[[:space:]]*:[[:space:]]*"//;s/"//')
			[[ -z "$sid" || -z "$start_time" ]] && continue

			# Skip if already counted from running sessions
			local already_counted=false
			for r in "${session_results[@]+"${session_results[@]}"}"; do
				if [[ "$r" == *"$sid"* ]]; then
					already_counted=true
					break
				fi
			done
			$already_counted && continue

			local meta_ts
			meta_ts=$(date -j -f "%Y-%m-%dT%H:%M:%S" "${start_time%%.*}" +%s 2>/dev/null || date -d "${start_time}" +%s 2>/dev/null || echo "")
			[[ -z "$meta_ts" ]] && continue

			if ((meta_ts >= start_ts && meta_ts <= end_ts)); then
				local jsonl
				jsonl=$(find_session_jsonl "$sid")
				if [[ -n "$jsonl" ]]; then
					local tokens tier
					tokens=$(sum_tokens_from_jsonl "$jsonl" "$start_iso" "$end_iso")
					tier=$(detect_model_tier "$jsonl")
					local input cache_write cache_read output
					read -r input cache_write cache_read output <<<"$tokens"

					if ((input == 0 && cache_write == 0 && cache_read == 0 && output == 0)); then continue; fi

					local costs
					costs=$(calculate_cost "$input" "$cache_write" "$cache_read" "$output" "$tier")
					local session_cost
					session_cost=$(echo "$costs" | sed -n '5p')

					local project_path
					project_path=$(grep -o '"project_path"[[:space:]]*:[[:space:]]*"[^"]*"' "$f" | head -1 | sed 's/.*"project_path"[[:space:]]*:[[:space:]]*"//;s/"//')
					local project_name="${project_path##*/}"
					local session_date="${start_time%%T*}"

					session_results+=("${session_cost}|${project_name}|${session_date}|${sid}")
					total_input=$((total_input + input))
					total_write=$((total_write + cache_write))
					total_read=$((total_read + cache_read))
					total_output=$((total_output + output))
					session_count=$((session_count + 1))
				fi
			fi
		done
	fi

	# Calculate total cost (use opus as base since period may span models)
	local tier="opus"
	local costs
	costs=$(calculate_cost "$total_input" "$total_write" "$total_read" "$total_output" "$tier")
	local input_cost write_cost read_cost output_cost total_cost
	local input_rate write_rate read_rate output_rate
	local opus_total sonnet_total haiku_total cache_ratio
	{
		read -r input_cost
		read -r write_cost
		read -r read_cost
		read -r output_cost
		read -r total_cost
		read -r input_rate
		read -r write_rate
		read -r read_rate
		read -r output_rate
		read -r opus_total
		read -r sonnet_total
		read -r haiku_total
		read -r cache_ratio
	} <<<"$costs"

	# Get all rates for the rates table
	local all_rates
	all_rates=$(python3 -c "
import json
with open('$RATES_FILE') as f:
    rates = json.load(f)
for tier in ['opus', 'sonnet', 'haiku']:
    r = rates.get(tier, {})
    print(f\"{r.get('input',0):.4f}\")
    print(f\"{r.get('cache_write',0):.4f}\")
    print(f\"{r.get('cache_read',0):.4f}\")
    print(f\"{r.get('output',0):.4f}\")
")
	local opus_in opus_cw opus_cr opus_out
	local sonnet_in sonnet_cw sonnet_cr sonnet_out
	local haiku_in haiku_cw haiku_cr haiku_out
	{
		read -r opus_in
		read -r opus_cw
		read -r opus_cr
		read -r opus_out
		read -r sonnet_in
		read -r sonnet_cw
		read -r sonnet_cr
		read -r sonnet_out
		read -r haiku_in
		read -r haiku_cw
		read -r haiku_cr
		read -r haiku_out
	} <<<"$all_rates"

	local hr
	hr=$(printf '━%.0s' $(seq 1 $BOX_WIDTH))

	echo ""
	echo "$hr"
	printf "  PERIOD COST: %s → %s\n" "$start_date" "$end_date"
	printf "  Sessions: %s\n" "$session_count"
	echo "$hr"

	print_cost_breakdown "$total_input" "$total_write" "$total_read" "$total_output" \
		"$input_cost" "$write_cost" "$read_cost" "$output_cost" "$total_cost"

	if ((${#session_results[@]} > 0)); then
		echo ""
		echo "┌───────────────────────────────────────────────────────────────────────────────────┐"
		box_line " SESSIONS"
		echo "├───────────────────────────────────────────────────────────────────────────────────┤"
		printf '%s\n' "${session_results[@]}" | sort -t'|' -k1 -rn | while IFS='|' read -r cost project sdate sid; do
			printf "│  %-34s %8s  %-30s│\n" "$project" "\$${cost}" "$sdate"
		done
		echo "└───────────────────────────────────────────────────────────────────────────────────┘"
	fi

	echo ""
	model_comparison_table "$opus_total" "$sonnet_total" "$haiku_total" "$tier"
	echo ""
	print_cache_efficiency "$cache_ratio"
	echo ""
	print_rates_table "$opus_in" "$opus_cw" "$opus_cr" "$opus_out" \
		"$sonnet_in" "$sonnet_cw" "$sonnet_cr" "$sonnet_out" \
		"$haiku_in" "$haiku_cw" "$haiku_cr" "$haiku_out"
	echo ""
}

# Main
period=""
do_refresh=false

for arg in "$@"; do
	case "$arg" in
	--refresh-rates) do_refresh=true ;;
	--help | -h) usage ;;
	*) period="$arg" ;;
	esac
done

if $do_refresh; then
	refresh_rates
fi

ensure_rates

resolved=$(resolve_period "${period:-session}")

if [[ "$resolved" == "session" ]]; then
	display_current_session
else
	display_period "$resolved"
fi
