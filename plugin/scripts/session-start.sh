#!/bin/bash
# SessionStart: inject the orchestrator instructions (with this machine's roster and data dir)
# and the curated learnings. Seeds learnings.md and retros.md on first run.
. "$(dirname "$0")/lib.sh"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOCAL="$HOME/.claude/agents"

[ -s "$O/learnings.md" ] || cp "$ROOT/templates/learnings.md" "$O/learnings.md"
[ -f "$O/retros.md" ] || printf '# Retros\n\n' > "$O/retros.md"

desc() { sed -n 's/^description: *//p' "$1" | head -1; }

ROSTER="| subagent_type | Use it for |
|---|---|"
for f in "$ROOT"/agents/*.md; do
  n=$(basename "$f" .md)
  if [ -f "$LOCAL/$n.md" ]; then ROSTER="$ROSTER
| \`$n\` (local) | $(desc "$LOCAL/$n.md") |"
  else ROSTER="$ROSTER
| \`orch:$n\` | $(desc "$f") |"
  fi
done
for f in "$LOCAL"/*.md; do
  [ -f "$f" ] || continue
  n=$(basename "$f" .md)
  [ -f "$ROOT/agents/$n.md" ] && continue
  ROSTER="$ROSTER
| \`$n\` (local) | $(desc "$f") |"
done

TEXT=$(cat "$ROOT/instructions/orchestrator.md")
TEXT=${TEXT//\{\{ROSTER\}\}/$ROSTER}
TEXT=${TEXT//\{\{DATA_DIR\}\}/$O}
TEXT=${TEXT//\{\{PLUGIN_ROOT\}\}/$ROOT}
printf '%s\n' "$TEXT"
if [ -s "$O/learnings.md" ]; then
  printf '\n## Orchestrator learnings (from past retros: %s/learnings.md)\n' "$O"
  cat "$O/learnings.md"
fi
exit 0
