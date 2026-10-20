#!/bin/bash
# Learning-loop ledger. Appends one JSON line per delegation event to <data dir>/ledger.jsonl.
#   PostToolUse (matcher Agent|Task): what was asked + how long the call took.
#   SubagentStop: which agent finished, output size, and its FRICTION: line (if any).
. "$(dirname "$0")/lib.sh"
mkdir -p "$O/raw"
IN=$(cat)
EVENT=$(jq -r '.hook_event_name // empty' <<<"$IN")

# Keep the latest raw payload per event so the schema can be checked if fields drift.
printf '%s' "$IN" > "$O/raw/$EVENT.json"

case "$EVENT" in
  PostToolUse)
    # tool_response carries the cost data; the report text is in handbackReport (desktop app) or content.
    jq -c '(.tool_response | if type == "object" then . else {} end) as $r
      | ($r.handbackReport.text // ([$r.content[]? | select(.type == "text") | .text] | join("\n")) // "") as $rep
      | {
      ts: (now | todate), event: "call", session_id, cwd,
      tool_use_id,
      agent_id: ($r.agentId // null),
      agent_type: (.tool_input.subagent_type // $r.agentType // "general-purpose"),
      description: (.tool_input.description // ""),
      prompt_chars: ((.tool_input.prompt // "") | length),
      background: ((.tool_input.run_in_background // false) or ($r.status == "async_launched")),
      result: ($r.status // null),
      model: ($r.resolvedModel // .tool_input.model // null),
      tokens: ($r.totalTokens // null),
      tool_uses: ($r.totalToolUseCount // null),
      duration_ms: ($r.totalDurationMs // .duration_ms // null),
      report_chars: ($rep | length),
      status: ($rep | [splits("\n") | select(test("^\\**STATUS\\**:"; "i"))] | last // null),
      friction: ($rep | [splits("\n") | select(test("^\\**FRICTION\\**:"; "i"))] | last // null)
    }' <<<"$IN" >> "$O/ledger.jsonl"
    ;;
  SubagentStop)
    # Internal agents (prompt suggestions, /btw) report an empty agent_type: skip them.
    [ -z "$(jq -r '.agent_type // empty' <<<"$IN")" ] && exit 0
    # Background agents get no report or cost data at PostToolUse, so recover them here from the
    # agent's own transcript: the report is its last SubagentHandback message (desktop app) or
    # last text block, tokens = final context size + all output.
    TP=$(jq -r '.agent_transcript_path // empty' <<<"$IN")
    STATS='{}'
    if [ -f "$TP" ]; then
      STATS=$(jq -sc '[.[] | select(.type == "assistant")] as $a
        | ([$a[].message.content[]? | select(.type == "tool_use" and .name == "SubagentHandback") | .input.message]
           + [$a[].message.content[]? | select(.type == "text") | .text] | map(select(. != null and . != "")) ) as $texts
        | ($a | last | .message.usage // {}) as $u
        | {
          report: ([$a[].message.content[]? | select(.type == "tool_use" and .name == "SubagentHandback") | .input.message] | last
                   // ([$a[].message.content[]? | select(.type == "text") | .text] | last) // ""),
          tokens: ((($u.input_tokens // 0) + ($u.cache_read_input_tokens // 0) + ($u.cache_creation_input_tokens // 0))
                   + ([$a[].message.usage.output_tokens // 0] | add // 0)),
          tool_uses: ([$a[].message.content[]? | select(.type == "tool_use" and .name != "SubagentHandback")] | length)
        }' "$TP" 2>/dev/null || echo '{}')
    fi
    jq -c --argjson st "$STATS" '((.last_assistant_message // "") | if . == "" then ($st.report // "") else . end) as $rep
      | {
      ts: (now | todate), event: "done", session_id, cwd,
      agent_id, agent_type,
      tokens: ($st.tokens // null),
      tool_uses: ($st.tool_uses // null),
      output_chars: ($rep | length),
      status: ($rep | [splits("\n") | select(test("^\\**STATUS\\**:"; "i"))] | last // null),
      friction: ($rep | [splits("\n") | select(test("^\\**FRICTION\\**:"; "i"))] | last // null)
    }' <<<"$IN" >> "$O/ledger.jsonl"
    ;;
esac
exit 0
