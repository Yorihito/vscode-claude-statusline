#!/usr/bin/env bash
# Build and install the Claude Code status line extension on this machine,
# and point Claude Code's statusLine at the file the extension reads.
set -euo pipefail

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
python3 "$HERE/patch-settings.py"

echo
echo "Done. In VS Code run: Cmd+Shift+P -> Developer: Reload Window"
echo "The status bar fills in after the next Claude Code turn."
