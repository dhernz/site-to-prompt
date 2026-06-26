#!/usr/bin/env bash
# site-to-prompt update notifier.
# Runs at SessionStart (plugin installs only). Throttled to once/24h, network-safe,
# and SILENT unless a newer version exists. It only GETs the public package.json from
# GitHub to read the latest version number — it sends no data about you anywhere.

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
DATA_DIR="${CLAUDE_PLUGIN_DATA:-$PLUGIN_ROOT/.cache}"
STAMP="$DATA_DIR/last-update-check"
REMOTE_URL="https://raw.githubusercontent.com/dhernz/site-to-prompt/main/package.json"

mkdir -p "$DATA_DIR" 2>/dev/null || exit 0

# --- Throttle: at most once per 24h ---
now=$(date +%s 2>/dev/null) || exit 0
if [ -f "$STAMP" ]; then
  last=$(cat "$STAMP" 2>/dev/null || echo 0)
  case "$last" in ''|*[!0-9]*) last=0 ;; esac
  [ $(( now - last )) -lt 86400 ] && exit 0
fi
# Record the attempt now so a failed/satisfied check still respects the 24h window.
printf '%s' "$now" > "$STAMP" 2>/dev/null || true

read_ver() {
  grep -m1 '"version"' "$1" 2>/dev/null \
    | sed -E 's/.*"version"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/'
}

# --- Local version (plugin.json, fall back to package.json) ---
local_ver=$(read_ver "$PLUGIN_ROOT/.claude-plugin/plugin.json")
[ -z "$local_ver" ] && local_ver=$(read_ver "$PLUGIN_ROOT/package.json")
[ -z "$local_ver" ] && exit 0

# --- Remote version (3s timeout; silent on any network failure) ---
remote_json=$(curl -fsS --max-time 3 "$REMOTE_URL" 2>/dev/null) || exit 0
remote_ver=$(printf '%s' "$remote_json" | grep -m1 '"version"' \
  | sed -E 's/.*"version"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/')
[ -z "$remote_ver" ] && exit 0

# --- Compare: notify only when remote is strictly newer ---
[ "$remote_ver" = "$local_ver" ] && exit 0
newer=$(printf '%s\n%s\n' "$local_ver" "$remote_ver" \
  | sort -t. -k1,1n -k2,2n -k3,3n 2>/dev/null | tail -1)
[ "$newer" != "$remote_ver" ] && exit 0

msg="site-to-prompt v${remote_ver} is available (installed: v${local_ver}). Update with: npx skills update site-to-prompt  — or  /plugin update site-to-prompt"
printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"%s"}}\n' "$msg"
exit 0
