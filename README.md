# claude-code-notifier

macOS desktop notifications when a [Claude Code](https://claude.com/claude-code) agent finishes a turn. Fires only for long-running turns. Click the notification to jump back to the terminal tab that launched it.

## Features

- Fires only when a turn exceeds a threshold (default: 30s) — short turns stay quiet
- Shows working directory + truncated last user prompt
- Click the notification → activates the correct terminal window + tab
- Uses Claude.app's icon (optional swap on `terminal-notifier`'s bundle)

## Terminal compatibility

| Terminal       | Notification | Click-to-focus |
|----------------|--------------|----------------|
| iTerm2         | ✅            | ✅              |
| Terminal.app   | ✅            | ⚠️ best-effort  |
| Warp           | ✅            | ❌              |
| Alacritty      | ✅            | ❌              |
| Kitty          | ✅            | ❌              |
| Ghostty        | ✅            | ❌              |

The notification fires in any terminal. Click-to-focus needs stable AppleScript bindings — iTerm2 has them natively, Terminal.app is best-effort via `$TERM_SESSION_ID`. Other terminals show the notification but clicking does nothing.

## Requirements

- macOS (tested on Tahoe 26.x)
- Homebrew
- [Claude Code](https://claude.com/claude-code) CLI
- Optional: Claude desktop app at `/Applications/Claude.app` (icon source)

## Install

One-shot:

```bash
git clone https://github.com/nasrat-v/claude-code-notifier.git
cd claude-code-notifier
./setup.sh
```

`setup.sh` copies hooks, offers to install `terminal-notifier` + `jq` via brew, and optionally swaps the icon. Then merge `settings.snippet.json` into `~/.claude/settings.json`. If you already have hooks, append to the existing arrays:

```json
{
  "hooks": {
    "Stop": [
      { "hooks": [ { "type": "command", "command": "~/.claude/hooks/stop-notify.sh" } ] }
    ],
    "StopFailure": [
      { "hooks": [ { "type": "command", "command": "STATUS=fail ~/.claude/hooks/stop-notify.sh" } ] }
    ],
    "UserPromptSubmit": [
      { "hooks": [ { "type": "command", "command": "~/.claude/hooks/turn-start.sh" } ] }
    ]
  }
}
```

The `StopFailure` entry plays a different sound and prepends ❌ to the title when a turn errors.

### Manual install

```bash
brew install terminal-notifier jq

mkdir -p ~/.claude/hooks
cp hooks/*.sh ~/.claude/hooks/
chmod +x ~/.claude/hooks/*.sh
```

## Grant notification permission

On modern macOS, `terminal-notifier` is silently blocked until permission is granted.

1. Trigger one notification:
   ```bash
   terminal-notifier -title test -message test
   ```
2. Open **System Settings → Notifications**
3. Find `terminal-notifier`, enable **Allow Notifications** + **Sound**

If `terminal-notifier` is not listed, open its app bundle once to register it:

```bash
open "$(brew --cellar terminal-notifier)"/*/terminal-notifier.app
```

## Use Claude's icon

`terminal-notifier` ignores `-appIcon` on modern macOS — it always shows its bundled icon. Swap the bundle icon with Claude's:

```bash
BUNDLE="$(brew --cellar terminal-notifier)"/*/terminal-notifier.app/Contents/Resources
cp "$BUNDLE/Terminal.icns" "$BUNDLE/Terminal.icns.bak"
cp /Applications/Claude.app/Contents/Resources/electron.icns "$BUNDLE/Terminal.icns"
killall Dock
```

Revert: `cp "$BUNDLE/Terminal.icns.bak" "$BUNDLE/Terminal.icns"`.

Note: `brew upgrade terminal-notifier` overwrites this. Re-run after upgrade.

## Configuration

Override defaults via env vars in your shell profile (`~/.zshrc`, `~/.bashrc`):

| Var | Default | Purpose |
|-----|---------|---------|
| `CCN_THRESHOLD` | `30` | Min seconds before notifying |
| `CCN_SOUND` | `Glass` | Sound on success Stop |
| `CCN_FAIL_SOUND` | `Sosumi` | Sound on StopFailure |
| `CCN_ICON_PATH` | `/Applications/Claude.app/Contents/Resources/electron.icns` | `-appIcon` source |
| `CCN_ORPHAN_CLEANUP_MIN` | `1440` | Purge stale `/tmp/claude-turn-start-*` older than N minutes |

Available sound names live in `/System/Library/Sounds/` (Glass, Sosumi, Funk, Ping, etc.).

Prompt truncation length is hard-coded at 80 chars in `stop-notify.sh` (`head -c 80`).

## Files

| File | Hook event | Purpose |
|------|------------|---------|
| `setup.sh`                | — | One-shot installer: copies hooks, installs deps, swaps icon |
| `hooks/turn-start.sh`     | `UserPromptSubmit` | Stamps `/tmp/claude-turn-start-<sid>` with start time |
| `hooks/stop-notify.sh`    | `Stop` / `StopFailure` | Computes elapsed time, fires notification if ≥ threshold. Different sound + title on failure (set `STATUS=fail`). Also prunes orphan `/tmp` files. |
| `hooks/focus-iterm.sh`    | (click handler) | Activates iTerm2 window + selects session by `$ITERM_SESSION_ID` |
| `hooks/focus-terminal.sh` | (click handler) | Same for Terminal.app via `$TERM_SESSION_ID` |
| `settings.snippet.json`   | — | Hook config to merge into `~/.claude/settings.json` |

## Troubleshooting

**No notification fires.** Permission not granted. See [Grant notification permission](#grant-notification-permission).

**Notification hangs / never exits.** Earlier versions used `-sender` which hangs on macOS Tahoe. The current script uses `-appIcon` instead.

**Click does nothing.** Either your terminal isn't supported (see compatibility table), or `$TERM_PROGRAM` isn't reaching the hook. Verify:

```bash
echo '{}' | ~/.claude/hooks/stop-notify.sh
```

**Wrong tab selected.** Only iTerm2 has reliable per-session AppleScript IDs. Terminal.app matching is approximate.

## License

MIT
