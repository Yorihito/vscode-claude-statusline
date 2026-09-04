const vscode = require('vscode');
const fs = require('fs');
const os = require('os');
const path = require('path');

// Claude Code caches the account's usage utilisation here regardless of how it
// was started, so this works for people who only ever use the VS Code
// extension and never launch the CLI.
const CLAUDE_JSON = path.join(os.homedir(), '.claude.json');

// Optional, and more accurate when present: a statusLine command run by the
// CLI's TUI can mirror its output to a file (see scripts/patch-settings.py).
// The VS Code extension runs Claude Code without a TUI, so it never produces
// this — it is a bonus for CLI users, not a requirement.
const DEFAULT_MIRROR = path.join(os.homedir(), '.claude', 'statusline.txt');

let item;
let watched = [];
let ageTimer;
let lastGood;

function config() {
  return vscode.workspace.getConfiguration('claudeStatusline');
}

function mirrorFile() {
  const custom = (config().get('file') || '').trim();
  if (!custom) return DEFAULT_MIRROR;
  return custom.startsWith('~') ? path.join(os.homedir(), custom.slice(1)) : custom;
}

function describeAge(ms) {
  const mins = Math.floor(ms / 60000);
  if (mins < 1) return 'just now';
  if (mins < 60) return `${mins} min ago`;
  const hours = Math.floor(mins / 60);
  if (hours < 24) return `${hours}h ${mins % 60}m ago`;
  return `${Math.floor(hours / 24)}d ago`;
}

function describeIn(ms) {
  if (ms <= 0) return 'now';
  const mins = Math.round(ms / 60000);
  if (mins < 60) return `in ${mins} min`;
  const hours = Math.floor(mins / 60);
  if (hours < 24) return `in ${hours}h ${mins % 60}m`;
  return `in ${Math.round(hours / 24)}d`;
}

function pct(entry) {
  const value = entry && entry.utilization;
  return typeof value === 'number' ? Math.round(value) : null;
}

function readClaudeJson() {
  let cached;
  try {
    // This file is rewritten often, so a read can land mid-write; the caller
    // keeps the previous value rather than flashing "no data".
    cached = JSON.parse(fs.readFileSync(CLAUDE_JSON, 'utf8')).cachedUsageUtilization;
  } catch (err) {
    return null;
  }
  const usage = cached && cached.utilization;
  if (!usage) return null;

  const five = pct(usage.five_hour);
  const week = pct(usage.seven_day);
  const parts = [];
  if (five !== null) parts.push(`5h: ${five}%`);
  if (week !== null) parts.push(`7d: ${week}%`);
  if (!parts.length) return null;

  const resets = [];
  for (const [label, entry] of [['5h', usage.five_hour], ['7d', usage.seven_day]]) {
    const at = entry && entry.resets_at && Date.parse(entry.resets_at);
    if (at) resets.push(`${label} resets ${describeIn(at - Date.now())}`);
  }

  return {
    text: parts.join(' | '),
    at: cached.fetchedAtMs || 0,
    detail: resets.join(' · '),
    origin: `\`~/.claude.json\` — Claude Code's cached usage, refreshed on its own schedule`
  };
}

function readMirror() {
  const file = mirrorFile();
  try {
    const text = fs.readFileSync(file, 'utf8').trim();
    if (!text) return null;
    return {
      text: text.split('\n')[0],
      at: fs.statSync(file).mtimeMs,
      detail: '',
      origin: `\`${file}\` — written by a CLI statusLine command`
    };
  } catch (err) {
    return null;
  }
}

function render() {
  const candidates = [readClaudeJson(), readMirror()].filter(Boolean);
  const best = candidates.length
    ? candidates.reduce((a, b) => (b.at > a.at ? b : a))
    : lastGood;

  if (!best) {
    item.text = '$(sparkle) Claude: no data';
    item.tooltip = new vscode.MarkdownString(
      'No usage data yet.\n\n' +
        `Looked in \`${CLAUDE_JSON}\` and \`${mirrorFile()}\`.\n\n` +
        'Run one Claude Code turn on this machine, then click here to refresh.'
    );
    item.color = new vscode.ThemeColor('descriptionForeground');
    item.show();
    return;
  }
  lastGood = best;

  const age = Date.now() - best.at;
  const staleMs = Math.max(0, config().get('staleMinutes', 60)) * 60000;

  item.text = `$(sparkle) ${best.text}`;
  item.tooltip = new vscode.MarkdownString(
    `**Claude Code usage**\n\n\`\`\`\n${best.text}\n\`\`\`\n\n` +
      (best.detail ? `${best.detail}\n\n` : '') +
      `Updated ${describeAge(age)}.\n\n` +
      `Source: ${best.origin}`
  );
  item.color = staleMs > 0 && age > staleMs ? new vscode.ThemeColor('descriptionForeground') : undefined;
  item.show();
}

function watch() {
  const files = [CLAUDE_JSON, mirrorFile()];
  if (files.length === watched.length && files.every((f, i) => f === watched[i])) return;
  for (const f of watched) fs.unwatchFile(f);
  watched = files;
  // watchFile polls, so it also fires when a file is first created or replaced.
  for (const f of watched) fs.watchFile(f, { interval: 2000 }, render);
}

function activate(context) {
  const alignment =
    config().get('alignment') === 'left'
      ? vscode.StatusBarAlignment.Left
      : vscode.StatusBarAlignment.Right;
  item = vscode.window.createStatusBarItem(alignment, 100);
  item.command = 'claudeStatusline.refresh';
  context.subscriptions.push(item);

  context.subscriptions.push(
    vscode.commands.registerCommand('claudeStatusline.refresh', () => {
      watch();
      render();
    })
  );

  context.subscriptions.push(
    vscode.workspace.onDidChangeConfiguration((e) => {
      if (e.affectsConfiguration('claudeStatusline')) {
        watch();
        render();
      }
    })
  );

  watch();
  render();

  // Keep the "updated N min ago" tooltip and the stale colour honest.
  ageTimer = setInterval(render, 60000);
  context.subscriptions.push({
    dispose() {
      clearInterval(ageTimer);
      for (const f of watched) fs.unwatchFile(f);
    }
  });
}

function deactivate() {}

module.exports = { activate, deactivate };
