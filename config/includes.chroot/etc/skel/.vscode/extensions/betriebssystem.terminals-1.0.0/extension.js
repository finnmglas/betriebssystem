// BETRIEBSSYSTEM: open three xonsh terminals in the bottom panel on startup.
// Uses the default integrated-terminal profile (xonsh, set in settings.json).
const vscode = require('vscode');

function activate() {
    // Only seed terminals if none were restored from a persistent session.
    if (vscode.window.terminals.length > 0) {
        return;
    }
    let first;
    for (let i = 1; i <= 3; i++) {
        const term = vscode.window.createTerminal({ name: `xonsh ${i}` });
        if (i === 1) {
            first = term;
        }
    }
    if (first) {
        first.show(true);
    }
}

function deactivate() {}

module.exports = { activate, deactivate };
