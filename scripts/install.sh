#!/usr/bin/env bash
# Build and install the Claude Code status line extension on this machine.
#
# The extension reads ~/.claude.json, which Claude Code maintains whichever way
# it was started, so no Claude Code configuration is required.
#
#   --mirror   also patch ~/.claude/settings.json so a CLI statusLine command
#              mirrors its output to a file. Only the CLI's TUI runs that
#              command, but it is per-turn fresh, so the extension prefers it
#              when it is newer. Pointless if you never use the CLI.
set -euo pipefail

MIRROR=0
for arg in "$@"; do
  case "$arg" in
    --mirror) MIRROR=1 ;;
    *) echo "usage: $0 [--mirror]" >&2; exit 2 ;;
  esac
done

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
NAME="claude-statusline-mirror"

if ! command -v code >/dev/null 2>&1; then
  echo "error: the 'code' CLI was not found." >&2
  echo "In VS Code run: Cmd+Shift+P -> Shell Command: Install 'code' command in PATH" >&2
  exit 1
fi

VERSION="$(python3 -c "import json;print(json.load(open('$ROOT/package.json'))['version'])")"
mkdir -p "$ROOT/dist"
VSIX="$ROOT/dist/$NAME-$VERSION.vsix"

# A .vsix is just a zip with a fixed layout, so this needs no network access.
BUILD="$(mktemp -d)"
trap 'rm -rf "$BUILD"' EXIT
mkdir -p "$BUILD/extension/src"
cp "$ROOT/package.json" "$ROOT/README.md" "$BUILD/extension/"
cp "$ROOT/src/extension.js" "$BUILD/extension/src/"
cp "$ROOT/build/extension.vsixmanifest" "$ROOT/build/[Content_Types].xml" "$BUILD/"
rm -f "$VSIX"
(cd "$BUILD" && zip -q -r "$VSIX" '[Content_Types].xml' extension.vsixmanifest extension)
echo "built $VSIX"

code --install-extension "$VSIX" --force
if [ "$MIRROR" = 1 ]; then
  python3 "$HERE/patch-settings.py"
fi

echo
echo "Done. In VS Code run: Cmd+Shift+P -> Developer: Reload Window"
echo "The status bar fills in once Claude Code has run at least one turn here."
