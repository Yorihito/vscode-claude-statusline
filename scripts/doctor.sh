#!/usr/bin/env bash
# Diagnose an empty or "no data" Claude usage entry in the VS Code status bar.
# Read-only: it inspects files and reports, it changes nothing.

CLAUDE_JSON="$HOME/.claude.json"
MIRROR="$HOME/.claude/statusline.txt"
PRIMARY_OK=0

echo "== primary source: $CLAUDE_JSON =="
if [ ! -f "$CLAUDE_JSON" ]; then
  echo "missing -- Claude Code has never run for this user account on this machine."
else
  python3 - "$CLAUDE_JSON" <<'PY'
import json, sys, time, pathlib
try:
    data = json.loads(pathlib.Path(sys.argv[1]).read_text())
except json.JSONDecodeError as err:
    print(f"INVALID JSON ({err})")
    raise SystemExit(1)
cached = data.get("cachedUsageUtilization") or {}
usage = cached.get("utilization") or {}
if not usage:
    print("no cachedUsageUtilization yet -- run one Claude Code turn, then re-check.")
    raise SystemExit(1)
for key, label in (("five_hour", "5h"), ("seven_day", "7d")):
    entry = usage.get(key) or {}
    print(f"  {label}: {entry.get('utilization')}%  resets_at={entry.get('resets_at')}")
fetched = cached.get("fetchedAtMs")
if fetched:
    age = (time.time() * 1000 - fetched) / 60000
    print(f"  fetched {age:.0f} min ago")
    print("  note: this is Claude Code's own cache; it lags real usage.")
raise SystemExit(0)
PY
  [ $? -eq 0 ] && PRIMARY_OK=1
fi

echo
echo "== optional source: $MIRROR =="
if [ -s "$MIRROR" ]; then
  echo "  content: $(cat "$MIRROR")"
  echo "  (used when newer than the cache above)"
elif [ -e "$MIRROR" ]; then
  echo "  exists but empty"
else
  echo "  absent -- normal unless you run the CLI and installed with --mirror."
  echo "  Only the CLI's TUI runs statusLine commands; the VS Code extension does not."
fi

echo
echo "== is the extension installed? =="
if command -v code >/dev/null 2>&1; then
  code --list-extensions 2>/dev/null | grep -i 'claude-statusline-mirror' \
    || echo "  NOT installed -- run ./scripts/install.sh"
else
  echo "  'code' CLI not on PATH; check the Extensions view manually."
fi

echo
echo "== verdict =="
if [ "$PRIMARY_OK" = 1 ]; then
  echo "The data the extension needs is present."
  echo "If the status bar still shows nothing:"
  echo "  VS Code: Cmd+Shift+P -> Developer: Reload Window"
  echo "  then click the status bar entry to force a refresh."
else
  echo "No usage data on this machine yet. Run one Claude Code turn"
  echo "(the VS Code panel is enough -- the CLI is not required), then re-run this."
fi
