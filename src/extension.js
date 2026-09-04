const vscode = require('vscode');
const fs = require('fs');
const os = require('os');
const path = require('path');

// The only account-wide usage figure Claude Code puts on disk. It is a cache:
// Claude Code refreshes it when the /usage view fetches from the API, and skips
// the write if the existing entry is under 5 minutes old. Nothing else updates
// it -- not a turn, not a session start. See README "What this can and cannot
// show" for how that was established.
const CLAUDE_JSON = path.join(os.homedir(), '.claude.json');

let item;
let ageTimer;
let lastGood;

function config() {
  return vscode.workspace.getConfiguration('claudeStatusline');
}

function clockOf(ms) {
  const d = new Date(ms);
  return `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`;
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

function read() {
  let cached;
  try {
    // Claude Code rewrites this file often, so a read can land mid-write; the
    // caller keeps the previous value rather than flashing "no data".
    cached = JSON.parse(fs.readFileSync(CLAUDE_JSON, 'utf8')).cachedUsageUtilization;
  } catch (err) {
    return null;
  }
  const usage = cached && cached.utilization;
  if (!usage || !cached.fetchedAtMs) return null;

  const windows = [['5h', usage.five_hour], ['7d', usage.seven_day]];
  const parts = [];
  const resets = [];
  for (const [label, entry] of windows) {
    if (!entry || typeof entry.utilization !== 'number') continue;
    parts.push(`${label}: ${Math.round(entry.utilization)}%`);
    const at = entry.resets_at && Date.parse(entry.resets_at);
    if (!at) continue;
    // A window that has already rolled over makes the cached percentage
    // meaningless rather than merely old, so say so instead of "resets now".
    resets.push(
      at <= Date.now()
        ? `${label} window has since reset — this figure is obsolete`
        : `${label} resets ${describeIn(at - Date.now())}`
    );
  }
  if (!parts.length) return null;

  return { text: parts.join(' | '), at: cached.fetchedAtMs, resets: resets.join(' · ') };
}

function render() {
  const data = read() || lastGood;

  if (!data) {
    item.text = '$(sparkle) Claude: no data';
    item.tooltip = new vscode.MarkdownString(
      `No usage figure in \`${CLAUDE_JSON}\` yet.\n\n` +
        'Open **/usage** in Claude Code once — that is what populates it.'
    );
    item.color = new vscode.ThemeColor('descriptionForeground');
    item.show();
    return;
  }
  lastGood = data;

  const age = Date.now() - data.at;
  const staleMs = Math.max(0, config().get('staleMinutes', 60)) * 60000;

  // The clock time is part of the label, not just the tooltip: this figure is
  // routinely hours old and a bare percentage would read as current.
  item.text = `$(sparkle) ${data.text} · ${clockOf(data.at)}`;
  item.tooltip = new vscode.MarkdownString(
    `**Claude Code usage — as of ${clockOf(data.at)} (${describeAge(age)})**\n\n` +
      `\`\`\`\n${data.text}\n\`\`\`\n\n` +
      (data.resets ? `${data.resets}\n\n` : '') +
      'This is Claude Code’s cached figure. It only refreshes when the ' +
      '**/usage** view fetches from the API, so it does not move as you work. ' +
      'Open /usage to bring it up to date.\n\n' +
      `Source: \`${CLAUDE_JSON}\``
  );
  item.color = staleMs > 0 && age > staleMs ? new vscode.ThemeColor('descriptionForeground') : undefined;
  item.show();
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
    vscode.commands.registerCommand('claudeStatusline.refresh', render)
  );

  context.subscriptions.push(
    vscode.workspace.onDidChangeConfiguration((e) => {
      if (e.affectsConfiguration('claudeStatusline')) render();
    })
  );

  // watchFile polls, so it also fires when the file is first created or replaced.
  fs.watchFile(CLAUDE_JSON, { interval: 2000 }, render);
  render();

  // Keep the "as of" age and the stale colour honest.
  ageTimer = setInterval(render, 60000);
  context.subscriptions.push({
    dispose() {
      clearInterval(ageTimer);
      fs.unwatchFile(CLAUDE_JSON);
    }
  });
}

function deactivate() {}

module.exports = { activate, deactivate };
