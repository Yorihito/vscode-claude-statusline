#!/usr/bin/env bash
# Diagnose why the VS Code status bar shows "Claude: no data".
# Safe to run: it only reads configuration and runs your statusLine command
# once against a fake payload, restoring the mirror file afterwards.

MIRROR="$HOME/.claude/statusline.txt"

echo "== mirror file =="
if [ -e "$MIRROR" ]; then
  ls -l "$MIRROR"
  if [ -s "$MIRROR" ]; then
    echo "content: $(cat "$MIRROR")"
    echo "-> the file is fine; the problem is on the VS Code side (see below)."
  else
    echo "-> the file exists but is EMPTY: your statusLine command ran but printed nothing."
  fi
else
  echo "missing: $MIRROR"
  echo "-> your statusLine command has never produced output on this machine."
fi

echo
echo "== settings files that can define statusLine =="
for f in "$HOME/.claude/settings.json" "$HOME/.claude/settings.local.json" \
         "$PWD/.claude/settings.json" "$PWD/.claude/settings.local.json"; do
  [ -f "$f" ] || continue
  python3 - "$f" <<'PY'
import json, sys, pathlib
p = pathlib.Path(sys.argv[1])
try:
    data = json.loads(p.read_text())
except json.JSONDecodeError as err:
    print(f"{p}: INVALID JSON ({err}) -- Claude Code ignores this file")
    raise SystemExit
sl = data.get("statusLine")
if sl is None:
    print(f"{p}: no statusLine key")
else:
    print(f"{p}:\n  {json.dumps(sl, ensure_ascii=False)}")
    cmd = sl.get("command") if isinstance(sl, dict) else None
    if cmd and "statusline.txt" not in cmd:
        print("  -> this command does NOT write to statusline.txt")
PY
done

echo
echo "== dependencies =="
command -v jq >/dev/null && echo "jq: $(command -v jq)" || echo "jq: MISSING (the default statusLine command needs it)"

echo
echo "== running your statusLine command against a fake payload =="
CMD="$(python3 - <<'PY'
import json, pathlib
p = pathlib.Path.home() / ".claude" / "settings.json"
try:
    sl = json.loads(p.read_text()).get("statusLine") or {}
except Exception:
    sl = {}
print(sl.get("command", "") if isinstance(sl, dict) else "")
PY
)"
if [ -z "$CMD" ]; then
  echo "no command configured in ~/.claude/settings.json -- run ./scripts/install.sh"
else
  PAYLOAD='{"model":{"display_name":"DoctorTest"},"rate_limits":{"five_hour":{"used_percentage":1},"seven_day":{"used_percentage":2}}}'
  # The command writes to the mirror file, so keep the real value and put it back.
  SAVED=""; [ -f "$MIRROR" ] && SAVED="$(cat "$MIRROR")"
  echo "--- stdout ---"
  printf '%s' "$PAYLOAD" | bash -c "$CMD"
  status=$?
  echo "--- exit status: $status ---"
  if [ -n "$SAVED" ]; then printf '%s\n' "$SAVED" > "$MIRROR"; else rm -f "$MIRROR"; fi
  if [ $status -ne 0 ]; then
    echo "-> the command FAILED. A syntax error here means nothing is ever written."
  fi
fi

echo
echo "== reminder =="
echo "statusLine config is read when a Claude Code session starts."
echo "After install.sh, start a NEW Claude Code session and run one turn,"
echo "then in VS Code: Cmd+Shift+P -> Developer: Reload Window."
