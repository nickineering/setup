# Matched with contains, not equality or startswith: transcripts record both
# "claude-opus-5" and the prefixed "eu.anthropic.claude-opus-5", and Fable is
# "global.anthropic.claude-fable-5". An id that matches nothing still costs 0,
# so a new tier is a silent undercount rather than an error - check here first
# when a total looks too low.
#
# Fable before opus: tier order is cost order, highest first.
#
# Rates are this account's billed rates, from Cost Explorer over Aug-Nov 2026
# (usage types EUC1-MP:EUC1_*_tokens_*). eu.* profiles bill 1.1x the list rate;
# global.* profiles, which is all Fable has, bill list. Hence Fable at 10/50
# rather than 11/55.
def cost(model; i; o; cw; cr):
  if model | contains("claude-fable") then
    (i * 10.0 + cw * 12.5 + cr * 1.0 + o * 50.0) / 1e6
  elif model | contains("claude-opus") then
    (i * 5.5 + cw * 6.875 + cr * 0.55 + o * 27.5) / 1e6
  elif model | contains("claude-sonnet") then
    (i * 2.2 + cw * 2.75 + cr * 0.22 + o * 11.0) / 1e6
  elif model | contains("claude-haiku") then
    (i * 1.1 + cw * 1.375 + cr * 0.11 + o * 5.5) / 1e6
  else 0 end;

def pad(n): tostring | if length < n then ((n - length) * " ") + . else . end;
def rpad(n): tostring | if length < n then . + ((n - length) * " ") else . end;
def fmt_cost: . * 100 | round / 100 | tostring |
  if contains(".") then (split(".") | .[0] + "." + (.[1] + "00")[:2]) else . + ".00" end | "$" + .;
def fmt_tok: tostring | split("") | reverse | [
  foreach .[] as $c (0; .+1; {i: ., c: $c}) |
  if .i > 1 and ((.i - 1) % 3 == 0) then "\(.c)," else .c end
] | reverse | join("");

def entry_cost(e): cost(e.model; e.inputTokens; e.outputTokens; e.cacheCreationTokens; e.cacheReadTokens);

.entries as $all |
($all | group_by(.model) | map({
  model: .[0].model, turns: length,
  output: ([.[].outputTokens] | add),
  cw: ([.[].cacheCreationTokens] | add),
  cr: ([.[].cacheReadTokens] | add),
  input: ([.[].inputTokens] | add)
}) | map(. + {cost: cost(.model; .input; .output; .cw; .cr)})) | . as $models |

($models | map(.input) | add) as $total_input |
($models | map(.output) | add) as $total_output |
($models | map(.cw) | add) as $total_cw |
($models | map(.cr) | add) as $total_cr |
($models | map(.cost) | add) as $total_cost |
($models | map(.turns) | add) as $total_turns |
(if $total_cw > 0 then ($total_cr / $total_cw * 10 | round / 10) else 0 end) as $cache_ratio |
($total_cost / $total_turns * 100 | round / 100) as $cost_per_turn |
(cost("claude-opus-4-6"; 0; $total_output; 0; 0) / $total_cost * 100 | round) as $output_pct |
($models | map(select(.model | (contains("claude-opus") or contains("claude-fable")) | not)) | map(.turns) | add // 0) as $cheap_turns |
($cheap_turns / $total_turns * 100 | round) as $delegation_pct |
($all | map(entry_cost(.)) | sort | last) as $max_turn_cost |
(($all[-1].timestamp | split(".")[0] | split("T") | join(" ")) as $end |
 ($all[0].timestamp | split(".")[0] | split("T") | join(" ")) as $start |
 {start: $start, end: $end}) as $times |

"┌──────────────────┬────────────────┬──────────────┐",
"│ Category         │         Tokens │         Cost │",
"├──────────────────┼────────────────┼──────────────┤",
"│ Input (uncached) │ \($total_input | fmt_tok | pad(14)) │ \($total_input | . as $i | cost("claude-opus-4-6"; $i; 0; 0; 0) | fmt_cost | pad(12)) │",
"│ Cache write      │ \($total_cw | fmt_tok | pad(14)) │ \($total_cw | . as $c | cost("claude-opus-4-6"; 0; 0; $c; 0) | fmt_cost | pad(12)) │",
"│ Cache read       │ \($total_cr | fmt_tok | pad(14)) │ \($total_cr | . as $c | cost("claude-opus-4-6"; 0; 0; 0; $c) | fmt_cost | pad(12)) │",
"│ Output           │ \($total_output | fmt_tok | pad(14)) │ \($total_output | . as $o | cost("claude-opus-4-6"; 0; $o; 0; 0) | fmt_cost | pad(12)) │",
"├──────────────────┼────────────────┼──────────────┤",
"│ TOTAL            │ \($total_input + $total_output + $total_cw + $total_cr | fmt_tok | pad(14)) │ \($total_cost | fmt_cost | pad(12)) │",
"└──────────────────┴────────────────┴──────────────┘",
"",
"Efficiency",
"  Cache reuse:       \($cache_ratio)x read:write\(if $cache_ratio >= 10 then " ✓ excellent" elif $cache_ratio >= 5 then " ✓ good" elif $cache_ratio >= 2 then " ~ okay" else " ⚠ poor (<5x means cache writes aren't paying off)" end)",
"  Avg cost/turn:     \($cost_per_turn | fmt_cost)",
"  Output share:      \($output_pct)% of cost (output is 50x pricier than cache reads)",
"  Delegation:        \($delegation_pct)% turns on cheaper models (\($cheap_turns)/\($total_turns))",
"  Priciest turn:     \($max_turn_cost | fmt_cost)",
"",
($all | [.[-5:][] | .cacheReadTokens] | add / length | round) as $recent_cr |
($all | [.[:5][] | .cacheReadTokens] | add / length | round) as $early_cr |
($recent_cr * 0.55 / 1e6 * 100 | round / 100) as $per_turn_ctx_cost |
($recent_cr / (if $early_cr > 0 then $early_cr else 1 end) | . * 10 | round / 10) as $ctx_growth |

"Context pressure",
"  Per-turn context:  \($recent_cr | fmt_tok) tokens (~\($per_turn_ctx_cost | fmt_cost)/turn in cache reads)",
"  Growth since start: \($ctx_growth)x (\($early_cr | fmt_tok) → \($recent_cr | fmt_tok))",
(if $recent_cr > 180000 then "  ⚠ Nearing 200k limit — compaction imminent, consider /clear"
 elif $recent_cr > 150000 then "  ~ Context is large — /clear would save ~\($per_turn_ctx_cost | . * 2 | fmt_cost)/turn going forward"
 elif $ctx_growth > 8 then "  ~ Context has grown significantly — /clear if switching tasks"
 else "  ✓ Context size is manageable" end),
"",
"Models",
($models | sort_by(-.cost)[] | "  \(.model | rpad(30)) \(.cost | fmt_cost | pad(7))  (\(.turns) turns, \(.output | fmt_tok) out tok)")
