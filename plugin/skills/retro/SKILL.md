---
name: retro
description: Run the orchestrator learning-loop retro now, without waiting for the 5-delegation hook. Use when the user types /retro or /orch:retro, or asks for a retro on how delegation went.
---
Run the retro described under "Retro" in the Orchestrator mode instructions (injected at session start; they name this machine's retro data folder, default `~/.claude/orchestrator`).

1. Read this session's entries from `<data folder>/ledger.jsonl` (match the current session_id if you know it; otherwise use the latest entries for the current cwd). Also read the last few entries of `<data folder>/retros.md` for recurring themes.
2. Follow the Retro steps: find waste, append to retros.md, curate learnings.md, and tune or create agents only if the bar is met.
3. Give the user a 2-3 line summary.
