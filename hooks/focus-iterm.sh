#!/bin/bash
SID="${1#*:}"
[ -z "$SID" ] && exit 0
osascript <<EOF
tell application "iTerm2"
  activate
  repeat with w in windows
    repeat with t in tabs of w
      repeat with s in sessions of t
        if id of s is "$SID" then
          set index of w to 1
          tell t to select
          tell s to select
          return
        end if
      end repeat
    end repeat
  end repeat
end tell
EOF
