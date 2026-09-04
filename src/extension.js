const vscode = require('vscode');
const fs = require('fs');
const os = require('os');
const path = require('path');

const DEFAULT_FILE = path.join(os.homedir(), '.claude', 'statusline.txt');

let item;
let watched;
let ageTimer;

function config() {
  return vscode.workspace.getConfiguration('claudeStatusline');
}

function targetFile() {
  const custom = (config().get('file') || '').trim();
  if (!custom) return DEFAULT_FILE;
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

function render() {
  const file = targetFile();
  let text;
  let mtimeMs;
  try {
    text = fs.readFileSync(file, 'utf8').trim();
    mtimeMs = fs.statSync(file).mtimeMs;
  } catch (err) {
    item.text = '$(sparkle) Claude: no data';
    item.tooltip = `No status line data yet.\nExpected at: ${file}\n\nRun a Claude Code turn to populate it.`;
    item.color = new vscode.ThemeColor('descriptionForeground');
    item.show();
    return;
  }

  if (!text) {
    item.hide();
    return;
  }

  const age = Date.now() - mtimeMs;
  const staleMs = Math.max(0, config().get('staleMinutes', 10)) * 60000;

  item.text = `$(sparkle) ${text.split('\n')[0]}`;
  item.tooltip = new vscode.MarkdownString(
    `**Claude Code status line**\n\n\`\`\`\n${text}\n\`\`\`\n\n` +
      `Updated ${describeAge(age)} — only refreshes when a Claude Code turn runs.\n\n` +
      `Source: \`${file}\``
  );
  item.color = staleMs > 0 && age > staleMs ? new vscode.ThemeColor('descriptionForeground') : undefined;
  item.show();
}

function watch() {
  const file = targetFile();
  if (watched === file) return;
  if (watched) fs.unwatchFile(watched);
  watched = file;
  // watchFile polls, so it also fires when the file is first created or replaced.
  fs.watchFile(file, { interval: 2000 }, render);
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
      if (watched) fs.unwatchFile(watched);
    }
  });
}

function deactivate() {}

module.exports = { activate, deactivate };
