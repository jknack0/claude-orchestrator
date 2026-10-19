#!/bin/bash
# Shared setup for the orch hooks: PATH for jq, and the retro data dir ($O).
# The data dir is the plugin's "data_dir" option, else ~/.claude/orchestrator.
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
O="${CLAUDE_PLUGIN_OPTION_DATA_DIR:-}"
[ -n "$O" ] || O="$HOME/.claude/orchestrator"
O="${O/#\~/$HOME}"
O="${O%/}"
mkdir -p "$O" 2>/dev/null || true
command -v jq >/dev/null 2>&1 || { echo "orch: jq not found; install it (brew install jq) for the retro loop." >&2; exit 0; }
