#!/usr/bin/env bash
# Build and install the Claude Code usage indicator on this machine.
# It reads ~/.claude.json and changes no Claude Code configuration.
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

echo
echo "Done. In VS Code run: Cmd+Shift+P -> Developer: Reload Window"
echo "The entry fills in once you have opened /usage in Claude Code at least once."
