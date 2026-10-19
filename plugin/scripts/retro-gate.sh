#!/bin/bash
# Stop hook: once a session has finished RETRO_THRESHOLD (default 5) subagent runs since its
# last retro, block the stop and hand the orchestrator a retro brief built from the ledger.
. "$(dirname "$0")/lib.sh"
THRESHOLD="${RETRO_THRESHOLD:-5}"
IN=$(cat)

# Loop guard: never re-block while already continuing from a stop hook.
[ "$(jq -r '.stop_hook_active // false' <<<"$IN")" = "true" ] && exit 0

SID=$(jq -r '.session_id // empty' <<<"$IN")
[ -z "$SID" ] || [ ! -f "$O/ledger.jsonl" ] && exit 0

# Wait for running background agents, so the retro sees their results (the next stop re-checks).
[ "$(jq '[.background_tasks[]? | select((.status // "") | test("^(running|pending)$"))] | length' <<<"$IN")" -gt 0 ] && exit 0

# SubagentStop can fire more than once per agent, so count distinct agent_ids.
DONE=$(jq -s --arg s "$SID" '[.[] | select(.session_id == $s and .event == "done") | (.agent_id // .ts)] | unique | length' "$O/ledger.jsonl")
mkdir -p "$O/state"
MARK="$O/state/$SID.last"
# Marker holds "<done count> <ledger line count>" as of this session's last retro.
[ -f "$MARK" ] && read -r LAST LASTLINE < "$MARK"
LAST=${LAST:-0}; LASTLINE=${LASTLINE:-0}
NEW=$((DONE - LAST))
[ "$NEW" -lt "$THRESHOLD" ] && exit 0

# Record the retro before asking for it, so it fires exactly once per batch.
LINES=$(wc -l < "$O/ledger.jsonl" | tr -d ' ')
echo "$DONE $LINES" > "$MARK"

# One line per agent: its call row (what was asked, harness cost) merged with its last "done" row
# (STATUS/FRICTION, and cost for background runs). Rows without an agent_id stay on their own line.
SUMMARY=$(tail -n +$((LASTLINE + 1)) "$O/ledger.jsonl" | jq -rs --arg s "$SID" '[.[] | select(.session_id == $s)] as $rows
  | ($rows | map(select(.event == "done")) | to_entries | group_by(.value.agent_id // (.key | tostring)) | map(last.value)) as $dones
  | ($rows | map(select(.event == "call"))) as $calls
  | def k(f): if f == null then "?" else "\(f / 1000 | floor)k" end;
    ([$calls[] | . as $c | {c: $c, d: (if $c.agent_id then ($dones | map(select(.agent_id == $c.agent_id)) | first) else null end)}]
     + [$dones[] | . as $d | select([$calls[] | select(.agent_id != null and .agent_id == $d.agent_id)] | length == 0) | {c: null, d: $d}])
  | .[] | .c as $c | .d as $d
  | (($c.status // $d.status)) as $st | (($c.friction // $d.friction)) as $fr
  | if $c then
      "- \($c.agent_type) | \($c.description) | \($c.model // "?") | \(if $c.tokens then "\(k($c.tokens)) tok" elif $d.tokens then "~\(k($d.tokens)) tok" else "? tok" end) | \($c.tool_uses // $d.tool_uses // "?") tools | \(if $c.background then "bg" elif $c.duration_ms then "\($c.duration_ms / 1000 | floor)s" else "?" end) | brief \($c.prompt_chars)ch\(if $c.background and $c.agent_id and ($d == null) then " | still running" else "" end)\(if $st then " | \($st)" else "" end)\(if $fr then " | \($fr)" else "" end)"
    elif ($st or $fr) then
      "- \($d.agent_type) finished | \(if $d.tokens then "~\(k($d.tokens)) tok | " else "" end)\(if $d.tool_uses then "\($d.tool_uses) tools | " else "" end)\($st // "") | \($fr // "")"
    else empty end')

REASON="RETRO DUE ($NEW subagent runs since the last retro in this session). Before ending, run the learning-loop retro described under \"Retro\" in the Orchestrator mode instructions.

Recent delegations (from $O/ledger.jsonl):
$SUMMARY

Keep it short: append one entry to $O/retros.md, update $O/learnings.md only with changes that will alter future behaviour, and create or edit an agent only if the bar in those instructions is met. Then give the user a 2-3 line retro summary."

jq -n --arg r "$REASON" '{decision: "block", reason: $r}'
exit 0
