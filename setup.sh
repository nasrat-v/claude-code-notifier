#!/bin/bash
set -e

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOK_DIR="$HOME/.claude/hooks"
SETTINGS="$HOME/.claude/settings.json"

echo "==> Installing hooks to $HOOK_DIR"
mkdir -p "$HOOK_DIR"
cp "$REPO_DIR"/hooks/*.sh "$HOOK_DIR"/
chmod +x "$HOOK_DIR"/*.sh
echo "    ok"

echo "==> Checking deps"
for tool in terminal-notifier jq; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "    missing: $tool"
    read -p "    install with brew? [y/N] " yn
    if [ "$yn" = "y" ] || [ "$yn" = "Y" ]; then
      brew install "$tool"
    else
      echo "    skipped (notifier won't work without it)"
    fi
  else
    echo "    $tool ok"
  fi
done

CLAUDE_ICON=/Applications/Claude.app/Contents/Resources/electron.icns
if [ -f "$CLAUDE_ICON" ] && command -v terminal-notifier >/dev/null 2>&1; then
  echo "==> Claude.app icon found"
  read -p "    Swap terminal-notifier bundled icon with Claude's? [y/N] " yn
  if [ "$yn" = "y" ] || [ "$yn" = "Y" ]; then
    BUNDLE_RES=$(echo "$(brew --cellar terminal-notifier)"/*/terminal-notifier.app/Contents/Resources)
    if [ -d "$BUNDLE_RES" ]; then
      [ ! -f "$BUNDLE_RES/Terminal.icns.bak" ] && cp "$BUNDLE_RES/Terminal.icns" "$BUNDLE_RES/Terminal.icns.bak"
      cp "$CLAUDE_ICON" "$BUNDLE_RES/Terminal.icns"
      killall Dock 2>/dev/null || true
      echo "    swapped (backup at Terminal.icns.bak)"
    else
      echo "    bundle not found at $BUNDLE_RES"
    fi
  fi
fi

echo
echo "==> Next steps"
echo "  1. Merge settings.snippet.json into $SETTINGS"
echo "  2. Trigger one notification to register the bundle:"
echo "       terminal-notifier -title test -message test"
echo "  3. If silently blocked, open System Settings > Notifications,"
echo "     find terminal-notifier, enable Allow Notifications + Sound."
echo
echo "==> Optional env vars (set in your shell profile)"
echo "  CCN_THRESHOLD=30          # min seconds before notifying"
echo "  CCN_SOUND=Glass           # success sound"
echo "  CCN_FAIL_SOUND=Sosumi     # failure sound"
echo "  CCN_ICON_PATH=/path.icns  # override icon (used by -appIcon)"
echo "  CCN_ORPHAN_CLEANUP_MIN=1440  # purge stale /tmp start files older than N min"
