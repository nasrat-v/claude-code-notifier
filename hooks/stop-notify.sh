#!/bin/bash
# Resolve this script's own directory so the click handlers are found whether
# installed standalone (~/.claude/hooks) or as a plugin (${CLAUDE_PLUGIN_ROOT}/hooks).
HOOK_DIR="$(cd "$(dirname "$0")" && pwd)"
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
  MSG=$(perl -nle '
    use JSON::PP;
    BEGIN { our $last = "" }
    our $last;
    my $rec = eval { decode_json($_) };
    next unless $rec && ($rec->{type} // "") eq "user";
    my $c = $rec->{message}{content};
    my $text;
    if (!ref $c) { $text = $c }
    elsif (ref $c eq "ARRAY") {
      $text = join "\n", map { $_->{text} // "" }
        grep { ref $_ eq "HASH" && ($_->{type} // "") eq "text" } @$c;
    }
    next unless defined $text && length $text;
    $text =~ s|<system-reminder>.*?</system-reminder>||gs;
    $text =~ s|<user-prompt-submit-hook>.*?</user-prompt-submit-hook>||gs;
    $text =~ s|<local-command-[a-z-]+>.*?</local-command-[a-z-]+>||gs;
    $text =~ s{<command-(name|message|args)>.*?</command-\1>}{}gs;
    $text =~ s|\s+| |g;
    $text =~ s|^\s+||;
    $text =~ s|\s+$||;
    $last = $text if length $text;
    END { print substr($last, 0, 80) }
  ' "$TRANSCRIPT" 2>/dev/null)
fi
[ -z "$MSG" ] && MSG="$DEFAULT_MSG"

CLICK_HANDLER=""
case "$TERM_PROGRAM" in
  iTerm.app)      CLICK_HANDLER="$HOOK_DIR/focus-iterm.sh $ITERM_SESSION_ID" ;;
  Apple_Terminal) CLICK_HANDLER="$HOOK_DIR/focus-terminal.sh $TERM_SESSION_ID" ;;
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
