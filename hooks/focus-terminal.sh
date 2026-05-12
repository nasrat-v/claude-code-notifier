#!/bin/bash
SID="$1"
[ -z "$SID" ] && exit 0
osascript <<EOF
tell application "Terminal"
  activate
  repeat with w in windows
    repeat with t in tabs of w
      if tty of t is "$SID" or (id of t as string) contains "$SID" then
        set selected of t to true
        set index of w to 1
        return
      end if
    end repeat
  end repeat
end tell
EOF
