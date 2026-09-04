# Claude Code Usage (VS Code)

Shows Claude Code's rate limit usage in the VS Code status bar, with the time
the figure was taken:

    ✨ 5h: 12% | 7d: 34% · 13:50

**Read "What this can and cannot show" before installing.** The figure does not
advance as you work. That is a limitation of what Claude Code puts on disk, not
a bug here, and it is the reason the timestamp is part of the label.

## What this can and cannot show

Claude Code knows your live usage — every API response carries
`anthropic-ratelimit-unified-5h-utilization` and friends, and that is what the
in-panel "You've used N% of your session limit" banner reports. That value
lives in the `claude` process's memory (`rawUtilization`) and is never written
anywhere another program can read.

What *is* on disk is `cachedUsageUtilization` in `~/.claude.json`, which this
extension reads. Claude Code writes it in exactly one place: after the
**/usage** view fetches `GET /api/oauth/usage`, and only if the stored entry is
already more than 5 minutes old. No turn, no session start and no hook
refreshes it. So the number moves when you open /usage, and at no other time.

Routes that were checked and do not work:

| Route | Result |
|---|---|
| Live response headers | In-process only; not on disk |
| `statusLine` command | Its payload has `rate_limits`, but only the CLI's TUI runs it — verified with a sentinel file that survived VS Code turn boundaries |
| CLI `statusLine` mirror file | Reports the *CLI process's* own observations, so work done in VS Code never appears. Observed 51% in the mirror while the real figure was 91% |
| Hook payloads | The base hook input schema has no `rate_limits` |
| OpenTelemetry | No rate-limit metric is emitted |
| Claude Code's VS Code extension | Exports no API; its commands are UI actions only |
| Local relay via `ANTHROPIC_BASE_URL` | OAuth sessions use a hardcoded `https://api.anthropic.com/` plus a host allowlist |

A proper fix needs Claude Code to expose the data — `statusLine` support in the
VS Code extension, or `rate_limits` in a hook payload.

## Layout

    package.json          extension manifest
    src/extension.js      the extension itself
    build/                .vsix packaging metadata
    scripts/install.sh    build + install
    scripts/doctor.sh     report what the extension can see
    dist/                 built .vsix (generated)

## Settings

- `claudeStatusline.staleMinutes` — when to dim the entry (default 60)
- `claudeStatusline.alignment` — `left` or `right` (default right)

## Installing

    ./scripts/install.sh

It builds the `.vsix` locally (no network needed — a vsix is just a zip) and
installs it with `code --install-extension`. It changes no Claude Code
configuration. Then in VS Code: `Cmd+Shift+P` -> **Developer: Reload Window**.

Requirements: the `code` CLI on PATH, `python3` and `zip`.

## Troubleshooting

    ./scripts/doctor.sh

**Claude: no data** means `~/.claude.json` has no `cachedUsageUtilization` yet —
open /usage in Claude Code once. If the tooltip says a window *has since reset*,
the cached percentage is not merely old but obsolete; open /usage again.
