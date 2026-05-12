#!/bin/bash
THRESHOLD=30
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
TITLE="Claude Code · $DIR_NAME"

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
[ -z "$MSG" ] && MSG="Agent has finished"

CLICK_HANDLER=""
case "$TERM_PROGRAM" in
  iTerm.app)    CLICK_HANDLER="$HOME/.claude/hooks/focus-iterm.sh $ITERM_SESSION_ID" ;;
  Apple_Terminal) CLICK_HANDLER="$HOME/.claude/hooks/focus-terminal.sh $TERM_SESSION_ID" ;;
esac

ICON_ARGS=()
[ -f /Applications/Claude.app/Contents/Resources/electron.icns ] && \
  ICON_ARGS=(-appIcon /Applications/Claude.app/Contents/Resources/electron.icns)

EXEC_ARGS=()
[ -n "$CLICK_HANDLER" ] && EXEC_ARGS=(-execute "$CLICK_HANDLER")

terminal-notifier \
  -title "$TITLE" \
  -message "Subject: \"$MSG\"" \
  "${ICON_ARGS[@]}" \
  -sound Glass \
  "${EXEC_ARGS[@]}"
