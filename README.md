# Claude Code Status Line (VS Code)

Mirrors the Claude Code TUI status line into the VS Code status bar.

Claude Code writes its status line to `~/.claude/statusline.txt` (via the
`statusLine` command in `~/.claude/settings.json`), and this extension watches
that file and shows the latest value.

Note: the underlying data only refreshes when a Claude Code turn runs — rate
limit percentages come from API responses, so there is nothing to poll between
turns. The tooltip shows how old the value is, and the entry dims once it is
stale.

## Layout

    package.json                  extension manifest
    src/extension.js              the extension itself
    build/                        .vsix packaging metadata (vsixmanifest, [Content_Types].xml)
    scripts/install.sh            build + install + patch Claude Code settings
    scripts/patch-settings.py     mirrors the statusLine output to a file
    dist/                         built .vsix (generated)

## Settings

- `claudeStatusline.file` — override the source file path
- `claudeStatusline.staleMinutes` — when to dim the entry (default 10)
- `claudeStatusline.alignment` — `left` or `right` (default right)

## Installing on another machine

VS Code Settings Sync does not carry locally-installed extensions, so copy this
folder over (git, scp, Dropbox — anything) and run:

    ./scripts/install.sh

It builds the `.vsix` locally (no network needed — a vsix is just a zip),
installs it with `code --install-extension`, and patches `~/.claude/settings.json`
so the status line is mirrored to `~/.claude/statusline.txt`. Both steps are
idempotent, and `settings.json` is backed up to `settings.json.bak` first.

Then in VS Code: `Cmd+Shift+P` -> **Developer: Reload Window**.

Requirements: the `code` CLI on PATH, `python3`, `zip`, and `jq` (only if you
have no `statusLine` configured yet and want the default one).

If you already have your own `statusLine` command, the patch wraps it rather
than replacing it, so your terminal status line is unchanged.
