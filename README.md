# Claude Code Status Line (VS Code)

Shows Claude Code's rate limit usage in the VS Code status bar.

    ✨ 5h: 12% | 7d: 34%

No Claude Code configuration is required, and you do not need to use the CLI.

## How it gets the numbers

Claude Code keeps a usage cache in `~/.claude.json`
(`cachedUsageUtilization`) whichever way it was started, so the extension reads
that. It is a cache with its own refresh schedule, not a live figure — the
tooltip always says how old the value is, and the entry dims once it is stale.

If you also use the Claude Code **CLI**, you can get per-turn accurate numbers.
The CLI's TUI runs the `statusLine` command from `~/.claude/settings.json`, and
`install.sh --mirror` makes that command also write its output to
`~/.claude/statusline.txt`. The extension prefers that file whenever it is
newer than the cache.

The VS Code extension runs Claude Code without a TUI (`--output-format
stream-json`), so it never executes `statusLine` commands. That is why the
mirror file alone is not enough for a VS Code-only setup, and why the cache is
the primary source.

## Layout

    package.json                  extension manifest
    src/extension.js              the extension itself
    build/                        .vsix packaging metadata (vsixmanifest, [Content_Types].xml)
    scripts/install.sh            build + install (--mirror also patches Claude Code settings)
    scripts/patch-settings.py     CLI-only: mirrors statusLine output to a file
    scripts/doctor.sh             diagnose an empty / "no data" entry
    dist/                         built .vsix (generated)

## Settings

- `claudeStatusline.staleMinutes` — when to dim the entry (default 60)
- `claudeStatusline.alignment` — `left` or `right` (default right)
- `claudeStatusline.file` — override the optional CLI mirror file path

## Installing

VS Code Settings Sync does not carry locally-installed extensions, so copy this
folder over (git, scp, Dropbox — anything) and run:

    ./scripts/install.sh          # VS Code only
    ./scripts/install.sh --mirror # also set up the CLI statusLine mirror

It builds the `.vsix` locally (no network needed — a vsix is just a zip) and
installs it with `code --install-extension`. Both steps are idempotent, and
`--mirror` backs up `settings.json` to `settings.json.bak` first, wrapping any
`statusLine` command you already have rather than replacing it.

Then in VS Code: `Cmd+Shift+P` -> **Developer: Reload Window**.

Requirements: the `code` CLI on PATH, `python3` and `zip`. `--mirror`
additionally wants `jq`, and only if you have no `statusLine` configured yet.

## Troubleshooting

    ./scripts/doctor.sh

It reports what each source holds, how stale the cache is, whether the
extension is installed, and ends with a verdict. The usual answer to **Claude:
no data** is that Claude Code has not yet run a turn for this account on this
machine — the VS Code panel counts, the CLI is not required.
