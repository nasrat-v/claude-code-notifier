#!/bin/bash
THRESHOLD="${CCN_THRESHOLD:-30}"
ICON_PATH="${CCN_ICON_PATH:-/Applications/Claude.app/Contents/Resources/electron.icns}"
STATUS="${STATUS:-ok}"
ORPHAN_MIN="${CCN_ORPHAN_CLEANUP_MIN:-1440}"

if [ "$STATUS" = "fail" ]; then
  TITLE_PREFIX="❌ Claude Code"
  SOUND="${CCN_FAIL_SOUND:-Sosumi}"
  DEFAULT_MSG="Agent failed"
else
  TITLE_PREFIX="Claude Code"
  SOUND="${CCN_SOUND:-Glass}"
  DEFAULT_MSG="Agent has finished"
fi

find /tmp -maxdepth 1 -name 'claude-turn-start-*' -mmin "+$ORPHAN_MIN" -delete 2>/dev/null

INPUT=$(cat)
SID=$(jq -r '.session_id // empty' <<< "$INPUT")
TRANSCRIPT=$(jq -r '.transcript_path // empty' <<< "$INPUT")
CWD=$(jq -r '.cwd // empty' <<< "$INPUT")
START_FILE="/tmp/claude-turn-start-$SID"

if [ -n "$SID" ] && [ -f "$START_FILE" ]; then
  START=$(cat "$START_FILE")
  rm -f "$START_FILE"
  ELAPSED=$(( $(date +%s) - START ))
  [ "$ELAPSED" -lt "$THRESHOLD" ] && exit 0
fi

DIR_NAME=$(basename "${CWD:-$PWD}")
TITLE="$TITLE_PREFIX · $DIR_NAME"

MSG=""
if [ -n "$TRANSCRIPT" ] && [ -f "$TRANSCRIPT" ]; then
  PROMPT=$(jq -r '
    select(.type == "user") |
    .message.content |
    if type == "string" then .
    elif type == "array" then (.[] | select(.type? == "text") | .text)
    else empty end
  ' "$TRANSCRIPT" 2>/dev/null \
    | grep -v -E '^<command-name>|^<local-command-stdout>|^<command-message>|^<command-args>|^<system-reminder>' \
    | tail -1 \
    | tr '\n' ' ' \
    | head -c 80)
  MSG="$PROMPT"
fi
[ -z "$MSG" ] && MSG="$DEFAULT_MSG"

CLICK_HANDLER=""
case "$TERM_PROGRAM" in
  iTerm.app)      CLICK_HANDLER="$HOME/.claude/hooks/focus-iterm.sh $ITERM_SESSION_ID" ;;
  Apple_Terminal) CLICK_HANDLER="$HOME/.claude/hooks/focus-terminal.sh $TERM_SESSION_ID" ;;
esac

ICON_ARGS=()
[ -f "$ICON_PATH" ] && ICON_ARGS=(-appIcon "$ICON_PATH")

EXEC_ARGS=()
[ -n "$CLICK_HANDLER" ] && EXEC_ARGS=(-execute "$CLICK_HANDLER")

terminal-notifier \
  -title "$TITLE" \
  -message "Subject: \"$MSG\"" \
  "${ICON_ARGS[@]}" \
  -sound "$SOUND" \
  "${EXEC_ARGS[@]}"
