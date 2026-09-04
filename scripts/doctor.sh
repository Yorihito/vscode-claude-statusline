#!/usr/bin/env bash
# Diagnose why the VS Code status bar shows "Claude: no data".
# Safe to run: it only reads configuration and runs your statusLine command
# once against a fake payload, restoring the mirror file afterwards.

MIRROR="$HOME/.claude/statusline.txt"

echo "== mirror file =="
MIRROR_STATE=missing
if [ -e "$MIRROR" ]; then
  ls -l "$MIRROR"
  if [ -s "$MIRROR" ]; then
    MIRROR_STATE=ok
    echo "content: $(cat "$MIRROR")"
    echo "-> the file is fine; the problem is on the VS Code side (see below)."
  else
    MIRROR_STATE=empty
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
echo "== verdict =="
# The test run above creates the mirror file; it is restored to its prior
# state, so MIRROR_STATE still describes what Claude Code itself has done.
if [ "$MIRROR_STATE" = ok ]; then
  echo "Claude Code is writing the mirror file. If VS Code still shows nothing,"
  echo "check claudeStatusline.file in your VS Code settings, then reload the window."
elif [ -n "$CMD" ] && [ "${status:-1}" -eq 0 ]; then
  echo "Your statusLine command works, but Claude Code has never run it here."
  echo "statusLine config is read when a session starts, so:"
  echo "  1. quit Claude Code on this machine and start it again"
  echo "  2. run one turn"
  echo "  3. ls -l $MIRROR   # should now exist"
  echo "  4. VS Code: Cmd+Shift+P -> Developer: Reload Window"
else
  echo "Your statusLine command itself is failing -- see the stdout/exit status above."
fi
