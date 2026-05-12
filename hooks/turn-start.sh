#!/bin/bash
SID=$(jq -r '.session_id // empty')
[ -z "$SID" ] && exit 0
date +%s > "/tmp/claude-turn-start-$SID"
