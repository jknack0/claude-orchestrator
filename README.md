# claude-orchestrator

A Claude Code plugin that turns the main chat into an **orchestrator**: it plans and delegates to a roster of subagents, logs every delegation, and every 5 delegations runs a **retro** that writes down what went wrong and updates the rules future sessions start with.

## What you get

- **8 subagents**: `orch:scout`, `orch:researcher`, `orch:planner`, `orch:worker`, `orch:tester`, `orch:debugger`, `orch:reviewer`, `orch:agent-author`. Each ends its reply with `STATUS:` and `FRICTION:` lines.
- **Orchestrator instructions**, injected at session start: when to delegate, parallel by default, how to brief, and the retro rules.
- **A delegation ledger**: one JSON line per subagent call and finish (tokens, duration, status, friction).
- **A retro gate**: after 5 subagent runs in a session, Claude is stopped once and asked to run a retro. `/orch:retro` runs one on demand.
- **Context budget**: agents cut filler but never facts (no pasted diffs, logs or narration), and the planner writes its plan to a file and returns an index, and the orchestrator follows lean-context rules (files over pastes, noisy work delegated, small screenshots). The retro summary shows each report's size.
- **Learnings**: a short rule list that each retro curates and every new session reads. A fresh install starts from a generic set.

## Install

You need [`jq`](https://jqlang.org) (`brew install jq`).

In Claude Code:

```
/plugin marketplace add jknack0/claude-orchestrator
/plugin install orch@claude-orchestrator
```

During install, Claude Code asks for the **retro data folder**: where `ledger.jsonl`, `retros.md` and `learnings.md` are saved. The default is `~/.claude/orchestrator`. Point it at a synced or git-tracked folder if you want your retro history backed up or shared between your own machines.

Or from a shell:

```bash
claude plugin marketplace add jknack0/claude-orchestrator
claude plugin install orch@claude-orchestrator --scope user --config data_dir=~/.claude/orchestrator
```

Start a new session. The first message context should contain an "Orchestrator mode" section listing the roster and your data folder.

Update later with `/plugin update orch` (or `claude plugin update orch`). Your data folder and any local agent edits are kept.

## Data folder

| File | Written by | What it is |
|---|---|---|
| `ledger.jsonl` | hooks | One line per subagent call/finish |
| `retros.md` | Claude, during a retro | 5–10 lines per retro: what went well, what was waste, what changed |
| `learnings.md` | Claude, during a retro | The rules injected into every new session (kept under ~40 lines) |
| `state/`, `raw/` | hooks | Retro counters per session; latest raw hook payloads for debugging |

To change the folder later, run `claude plugin configure orch` (or edit the plugin's options in `/plugin`), then move the old files across.

## Customising agents

Plugin files are replaced on update, so never edit them in place. To tune an agent, copy it to `~/.claude/agents/<name>.md` and edit the copy: from the next session the roster uses your local version (plain name, e.g. `scout` instead of `orch:scout`). Retros follow the same rule when they tune or add agents. Any other agents in `~/.claude/agents/` are listed in the roster too.

Set `RETRO_THRESHOLD` in your environment to change how many delegations trigger a retro (default 5).

## Work machines

If your organisation sets `allowManagedHooksOnly` in managed settings, plugin hooks won't run. The agents and `/orch:retro` still work, but nothing is logged or injected. Check with `/status`.

## License

MIT
