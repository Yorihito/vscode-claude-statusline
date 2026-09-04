#!/usr/bin/env bash
# Report what the extension can see. Read-only.

CLAUDE_JSON="$HOME/.claude.json"

echo "== $CLAUDE_JSON =="
if [ ! -f "$CLAUDE_JSON" ]; then
  echo "missing -- Claude Code has never run for this account on this machine."
  OK=1
else
  python3 - "$CLAUDE_JSON" <<'PY'
import json, sys, time, pathlib, datetime
try:
    data = json.loads(pathlib.Path(sys.argv[1]).read_text())
except json.JSONDecodeError as err:
    print(f"INVALID JSON ({err})")
    raise SystemExit(1)
cached = data.get("cachedUsageUtilization") or {}
usage = cached.get("utilization") or {}
if not usage or not cached.get("fetchedAtMs"):
    print("no cachedUsageUtilization yet -- open /usage in Claude Code once.")
    raise SystemExit(1)
fetched = cached["fetchedAtMs"]
when = datetime.datetime.fromtimestamp(fetched / 1000).strftime("%H:%M:%S")
age = (time.time() * 1000 - fetched) / 60000
print(f"  fetched at {when} ({age:.0f} min ago)")
now = time.time()
for key, label in (("five_hour", "5h"), ("seven_day", "7d")):
    entry = usage.get(key) or {}
    resets = entry.get("resets_at")
    note = ""
    if resets:
        try:
            ts = datetime.datetime.fromisoformat(resets).timestamp()
            note = "  [window has since reset -- figure is obsolete]" if ts <= now else ""
        except ValueError:
            pass
    print(f"  {label}: {entry.get('utilization')}%  resets_at={resets}{note}")
raise SystemExit(0)
PY
  OK=$?
fi

echo
echo "== extension installed? =="
if command -v code >/dev/null 2>&1; then
  code --list-extensions 2>/dev/null | grep -i 'claude-statusline-mirror' \
    || echo "  NOT installed -- run ./scripts/install.sh"
else
  echo "  'code' CLI not on PATH; check the Extensions view manually."
fi

echo
echo "== verdict =="
if [ "${OK:-1}" = 0 ]; then
  echo "The extension has a figure to show."
  echo "It only advances when you open /usage in Claude Code -- by design,"
  echo "that is the only thing that refreshes this cache. See the README."
else
  echo "Nothing to show yet. Open /usage in Claude Code once, then re-run this."
fi
