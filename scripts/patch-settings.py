#!/usr/bin/env python3
"""Make the Claude Code statusLine command also write its output to
~/.claude/statusline.txt, so the VS Code extension can display it."""

import json
import pathlib
import shutil
import sys

MIRROR = '~/.claude/statusline.txt'
TEE = ' | tee "$HOME/.claude/statusline.txt"'

# Used only when no statusLine is configured yet.
DEFAULT = (
    'input=$(cat); '
    'model=$(echo "$input" | jq -r \'.model.display_name\'); '
    'five=$(echo "$input" | jq -r \'.rate_limits.five_hour.used_percentage // empty\'); '
    'week=$(echo "$input" | jq -r \'.rate_limits.seven_day.used_percentage // empty\'); '
    'out="$model"; '
    'if [ -n "$five" ]; then out="$out | 5h: $(printf \'%.0f\' "$five")%"; fi; '
    'if [ -n "$week" ]; then out="$out | 7d: $(printf \'%.0f\' "$week")%"; fi; '
    'echo "$out"'
)

path = pathlib.Path.home() / ".claude" / "settings.json"
settings = {}
if path.exists():
    try:
        settings = json.loads(path.read_text())
    except json.JSONDecodeError as err:
        sys.exit(f"error: {path} is not valid JSON ({err}) — fix it and re-run")
else:
    path.parent.mkdir(parents=True, exist_ok=True)

status_line = settings.get("statusLine")
existing = ""
if isinstance(status_line, dict) and status_line.get("type") == "command":
    existing = status_line.get("command") or ""

if "statusline.txt" in existing:
    print(f"statusLine already mirrors to {MIRROR} — nothing to do")
    sys.exit(0)

if existing:
    # Wrap whatever is already configured; tee keeps stdout intact so the
    # terminal status line looks exactly the same.
    command = "{ " + existing + " ; }" + TEE
    note = "wrapped your existing statusLine command"
else:
    command = "{ " + DEFAULT + " ; }" + TEE
    note = "installed the default model + rate-limit statusLine command"
    if not shutil.which("jq"):
        print("warning: 'jq' is not installed; the default command needs it (brew install jq)")

if path.exists():
    shutil.copyfile(path, str(path) + ".bak")
    print(f"backed up {path} -> {path}.bak")

settings["statusLine"] = {"type": "command", "command": command}
path.write_text(json.dumps(settings, indent=2) + "\n")
print(f"{note}; output now mirrors to {MIRROR}")
